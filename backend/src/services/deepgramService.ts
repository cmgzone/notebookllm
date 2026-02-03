import axios from 'axios';
import fs from 'fs';
import FormData from 'form-data';

export interface TranscriptionOptions {
    model?: string;
    smart_format?: boolean;
    punctuate?: boolean;
    diarize?: boolean;
    language?: string;
}

export interface TranscriptionResult {
    text: string;
    confidence: number;
    words?: any[];
}

class DeepgramService {
    private apiKey: string;
    private baseUrl = 'https://api.deepgram.com/v1/listen';

    constructor() {
        this.apiKey = process.env.DEEPGRAM_API_KEY || '';
        if (!this.apiKey) {
            console.warn('[DeepgramService] DEEPGRAM_API_KEY is not set. Transcription will fail.');
        }
    }

    /**
     * Transcribe audio from a URL or Buffer.
     */
    async transcribeAudio(audioSource: Buffer | string, options: TranscriptionOptions = {}): Promise<TranscriptionResult> {
        if (!this.apiKey) throw new Error('Deepgram API key not configured.');

        const params = new URLSearchParams({
            model: options.model || 'nova-2',
            smart_format: String(options.smart_format !== false),
            punctuate: String(options.punctuate !== false),
            diarize: String(options.diarize || false),
            language: options.language || 'en',
        });

        const url = `${this.baseUrl}?${params.toString()}`;
        let headers: any = {
            'Authorization': `Token ${this.apiKey}`,
            'Content-Type': 'application/json',
        };
        let data: any;

        if (Buffer.isBuffer(audioSource)) {
            headers['Content-Type'] = 'audio/wav'; // Default fallback, Deepgram detects automatically usually
            data = audioSource;
        } else if (typeof audioSource === 'string' && audioSource.startsWith('http')) {
            data = { url: audioSource };
        } else if (typeof audioSource === 'string' && fs.existsSync(audioSource)) {
            // Local file path
            data = fs.readFileSync(audioSource);
            headers['Content-Type'] = 'application/octet-stream';
        } else {
            throw new Error('Invalid audio source. Must be Buffer, URL, or file path.');
        }

        try {
            const response = await axios.post(url, data, { headers });
            
            const result = response.data.results?.channels[0]?.alternatives[0];
            if (!result) {
                throw new Error('No transcription results found.');
            }

            return {
                text: result.transcript,
                confidence: result.confidence,
                words: result.words,
            };
        } catch (error: any) {
            console.error('[DeepgramService] Transcription error:', error.response?.data || error.message);
            throw new Error(`Transcription failed: ${error.response?.data?.err_msg || error.message}`);
        }
    }
}

export const deepgramService = new DeepgramService();
export default deepgramService;
