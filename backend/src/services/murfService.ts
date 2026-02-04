import axios from 'axios';

export interface MurfVoiceOptions {
    voiceId?: string; // e.g., 'en-US-terra'
    style?: string;   // e.g., 'Promo', 'Conversational'
    rate?: number;    // -50 to 50
    pitch?: number;   // -50 to 50
    format?: 'MP3' | 'WAV' | 'FLAC';
    encodeAsBase64?: boolean;
}

export interface MurfResult {
    audioUrl: string;
    audioBase64?: string;
    duration?: number;
}

class MurfService {
    private apiKey: string;
    private baseUrl = 'https://api.murf.ai/v1/speech/generate';

    constructor() {
        this.apiKey = process.env.MURF_API_KEY || '';
        if (!this.apiKey) {
            console.warn('[MurfService] MURF_API_KEY is not set. Synthesis will fail.');
        }
    }

    /**
     * Generate speech from text using Murf.ai
     */
    async generateSpeech(text: string, options: MurfVoiceOptions = {}): Promise<MurfResult> {
        if (!this.apiKey) throw new Error('Murf API key not configured.');

        const payload = {
            voiceId: options.voiceId || 'en-US-terra', // Default Terra
            text: text,
            style: options.style || 'Conversational',
            rate: options.rate || 0,
            pitch: options.pitch || 0,
            sampleRate: 48000,
            format: options.format || 'MP3',
            channel: 'MONO',
            encodeAsBase64: options.encodeAsBase64 || false,
        };

        try {
            const response = await axios.post(this.baseUrl, payload, {
                headers: {
                    'api-key': this.apiKey,
                    'Content-Type': 'application/json',
                },
            });

            return {
                audioUrl: response.data.audioFile,
                audioBase64: response.data.encodedAudio,
                duration: response.data.audioDuration,
            };
        } catch (error: any) {
            console.error('[MurfService] Synthesis error:', error.response?.data || error.message);
            throw new Error(`Speech synthesis failed: ${error.response?.data?.message || error.message}`);
        }
    }

    /**
     * List available voices (cached or fetched)
     * Note: Full list implementation would require another endpoint.
     * This is a helper for common voices.
     */
    async getVoiceModels(): Promise<Array<{ id: string; name: string; language: string; gender: string }>> {
        if (!this.apiKey) return this.getCommonVoices();

        try {
            const response = await axios.get('https://api.murf.ai/v1/speech/voices', {
                headers: { 'api-key': this.apiKey },
            });
            return response.data.map((v: any) => ({
                id: v.voiceId,
                name: v.displayName,
                language: v.language,
                gender: v.gender,
            }));
        } catch (error: any) {
            console.error('[MurfService] Failed to fetch voices:', error.message);
            return this.getCommonVoices();
        }
    }

    /**
     * List available voices (cached or fetched)
     * Note: Full list implementation would require another endpoint.
     * This is a helper for common voices.
     */
    getCommonVoices() {
        return [
            { id: 'en-US-natalie', name: 'Natalie', gender: 'Female', language: 'English (US)' },
            { id: 'en-US-ryan', name: 'Ryan', gender: 'Male', language: 'English (US)' },
            { id: 'en-UK-gabriel', name: 'Gabriel', gender: 'Male', language: 'English (UK)' },
        ];
    }
}

export const murfService = new MurfService();
export default murfService;
