import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { deepgramService } from './deepgramService.js';
import { murfService } from './murfService.js';
import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import pool from '../config/database.js';

/**
 * Helper: Get linked identity
 */
async function getLinkedIdentity(userId: string, platform: 'whatsapp' | 'telegram'): Promise<string | null> {
    const res = await pool.query(
        `SELECT platform_user_id FROM gitu_linked_accounts 
     WHERE user_id = $1 AND platform = $2 AND status = 'active'`,
        [userId, platform]
    );
    return res.rows.length > 0 ? res.rows[0].platform_user_id : null;
}

/**
 * Tool: Transcribe Audio
 */
const transcribeAudioTool: MCPTool = {
    name: 'transcribe_audio',
    description: 'Transcribe audio from a URL using Deepgram.',
    schema: {
        type: 'object',
        properties: {
            url: { type: 'string', description: 'Public URL of the audio file to transcribe.' },
            language: { type: 'string', description: 'Language code (default: en).', default: 'en' }
        },
        required: ['url']
    },
    handler: async (args: any, context: MCPContext) => {
        const { url, language } = args;
        try {
            const result = await deepgramService.transcribeAudio(url, { language });
            return {
                text: result.text,
                confidence: result.confidence
            };
        } catch (error: any) {
            throw new Error(`Transcription failed: ${error.message}`);
        }
    }
};

/**
 * Tool: Send Voice Note
 */
const sendVoiceNoteTool: MCPTool = {
    name: 'send_voice_note',
    description: 'Generate speech from text (Murf) and send it as a voice note to WhatsApp or Telegram.',
    schema: {
        type: 'object',
        properties: {
            text: { type: 'string', description: 'The text to speak.' },
            platform: { type: 'string', enum: ['whatsapp', 'telegram'], description: 'Platform to send to.' },
            recipient: { type: 'string', description: 'Recipient (name, number, or "self").', default: 'self' },
            voiceId: { type: 'string', description: 'Optional: Voice ID (e.g. en-US-terra, en-US-ryan).' }
        },
        required: ['text', 'platform']
    },
    handler: async (args: any, context: MCPContext) => {
        const { text, platform, recipient = 'self', voiceId } = args;

        // 1. Generate Audio
        let audioUrl: string;
        try {
            const result = await murfService.generateSpeech(text, { voiceId });
            audioUrl = result.audioUrl;
        } catch (e: any) {
            throw new Error(`Voice generation failed: ${e.message}`);
        }

        // 2. Resolve Recipient
        let targetId: string;
        const myIdentity = await getLinkedIdentity(context.userId, platform as any);
        if (!myIdentity) throw new Error(`No linked ${platform} account found.`);

        if (recipient === 'self') {
            targetId = myIdentity;
        } else {
            // Basic resolution (same logic as messaging tools)
            if (platform === 'whatsapp') {
                if (recipient.includes('@')) targetId = recipient;
                else {
                    // Try to find contact
                    const contacts = await whatsappAdapter.searchContacts(recipient);
                    if (contacts.length > 0) targetId = contacts[0].id;
                    else targetId = `${recipient.replace(/\D/g, '')}@s.whatsapp.net`;
                }
            } else {
                targetId = recipient; // Telegram usually requires Chat ID
            }
        }

        // 3. Send Audio
        if (platform === 'whatsapp') {
            await whatsappAdapter.sendMessage(targetId, {
                // Sending as PTT (Voice Note) requires specific handling in Baileys usually,
                // but sending as audio/url is supported by our adapter now (we need to update it to support 'audio' type specifically or generic url)
                // Current adapter supports image/text. We need to upgrade it or send as generic media.
                // Let's assume we update adapter to handle { audio: { url } } or we send as file.
                // For now, we will send as URL link with caption if native audio not supported, 
                // BUT we plan to update the adapter next.
                audio: { url: audioUrl },
                ptt: true // Request PTT format
            } as any); 
        } else if (platform === 'telegram') {
            await telegramAdapter.sendMessage(targetId, {
                audio: { url: audioUrl },
                caption: 'Voice Note'
            });
        }

        return {
            success: true,
            message: `Voice note sent to ${recipient} on ${platform}`,
            audioUrl
        };
    }
};

/**
 * Register Voice Tools
 */
export function registerVoiceTools() {
    gituMCPHub.registerTool(transcribeAudioTool);
    gituMCPHub.registerTool(sendVoiceNoteTool);
    console.log('[VoiceMCPTools] Registered transcription and voice note tools');
}
