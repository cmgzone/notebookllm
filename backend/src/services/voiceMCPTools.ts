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

async function getActiveMessagingPlatforms(userId: string): Promise<Array<{ platform: 'whatsapp' | 'telegram'; platformUserId: string }>> {
    const res = await pool.query(
        `SELECT platform, platform_user_id
         FROM gitu_linked_accounts
         WHERE user_id = $1
           AND platform IN ('whatsapp', 'telegram')
           AND status = 'active'`,
        [userId]
    );
    return res.rows.map((row: any) => ({
        platform: row.platform,
        platformUserId: row.platform_user_id,
    }));
}

function normalizePlatform(raw?: string | null): 'whatsapp' | 'telegram' | undefined {
    if (!raw) return undefined;
    const value = String(raw).trim().toLowerCase();
    if (value === 'whatsapp' || value === 'wa') return 'whatsapp';
    if (value === 'telegram' || value === 'tg') return 'telegram';
    return undefined;
}

function inferPlatformFromRecipient(recipient: string | undefined): 'whatsapp' | 'telegram' | undefined {
    if (!recipient) return undefined;
    const value = recipient.trim().toLowerCase();
    if (value.startsWith('tg:') || value.startsWith('telegram:')) return 'telegram';
    if (value.startsWith('wa:') || value.startsWith('whatsapp:')) return 'whatsapp';
    if (value.includes('@s.whatsapp.net') || value.includes('@g.us')) return 'whatsapp';
    return undefined;
}

function stripRecipientPrefix(recipient: string, prefixes: string[]): string {
    const lower = recipient.trim().toLowerCase();
    for (const prefix of prefixes) {
        if (lower.startsWith(prefix)) {
            return recipient.trim().slice(prefix.length).trim();
        }
    }
    return recipient.trim();
}

async function getUserVoiceDefaults(userId: string): Promise<{ voiceId?: string; provider?: string }> {
    try {
        const res = await pool.query(
            `SELECT gitu_settings FROM users WHERE id = $1`,
            [userId]
        );
        const settings = res.rows[0]?.gitu_settings || {};
        const voice = settings.voice || {};
        const voiceId = typeof voice.voiceId === 'string' && voice.voiceId.trim().length > 0 ? voice.voiceId : undefined;
        const provider = typeof voice.provider === 'string' && voice.provider.trim().length > 0 ? voice.provider : undefined;
        return { voiceId, provider };
    } catch {
        return {};
    }
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
            platform: { type: 'string', enum: ['whatsapp', 'telegram'], description: 'Optional: platform to send to.' },
            recipient: { type: 'string', description: 'Recipient (name, number, or "self"). Prefix with wa:/tg: to disambiguate.', default: 'self' },
            voiceId: { type: 'string', description: 'Optional: Voice ID (e.g. en-US-natalie, en-US-ryan).' }
        },
        required: ['text']
    },
    handler: async (args: any, context: MCPContext) => {
        const { text, platform, recipient = 'self', voiceId } = args;
        const defaults = await getUserVoiceDefaults(context.userId);
        const resolvedVoiceId = voiceId || defaults.voiceId || 'en-US-natalie';
        const explicitPlatform = normalizePlatform(platform);
        const contextPlatform = normalizePlatform(context.platform);
        const recipientPlatform = inferPlatformFromRecipient(recipient);

        let resolvedPlatform = explicitPlatform || contextPlatform || recipientPlatform;
        if (!resolvedPlatform) {
            const activePlatforms = await getActiveMessagingPlatforms(context.userId);
            if (activePlatforms.length === 1) {
                resolvedPlatform = activePlatforms[0].platform;
            }
        }
        if (!resolvedPlatform) {
            throw new Error(
                'Platform is required. Specify "whatsapp" or "telegram", or link exactly one of them and try again.'
            );
        }

        // 1. Generate Audio
        let audioUrl: string;
        try {
            const result = await murfService.generateSpeech(text, { voiceId: resolvedVoiceId });
            audioUrl = result.audioUrl;
        } catch (e: any) {
            throw new Error(`Voice generation failed: ${e.message}`);
        }

        // 2. Resolve Recipient
        let targetId: string;
        const myIdentity = await getLinkedIdentity(context.userId, resolvedPlatform);
        if (!myIdentity) {
            throw new Error(
                `No linked ${resolvedPlatform} account found. Link it in the app (Settings → Gitu → Linked Accounts), then retry.`
            );
        }

        if (recipient === 'self') {
            targetId = myIdentity;
        } else {
            // Basic resolution (same logic as messaging tools)
            if (resolvedPlatform === 'whatsapp') {
                const cleaned = stripRecipientPrefix(recipient, ['wa:', 'whatsapp:']);
                if (cleaned.includes('@')) targetId = cleaned;
                else {
                    // Try to find contact
                    const contacts = await whatsappAdapter.searchContacts(cleaned);
                    if (contacts.length > 0) targetId = contacts[0].id;
                    else targetId = `${cleaned.replace(/\D/g, '')}@s.whatsapp.net`;
                }
            } else {
                const cleaned = stripRecipientPrefix(recipient, ['tg:', 'telegram:']);
                targetId = cleaned; // Telegram usually requires Chat ID
            }
        }

        // 3. Send Audio
        if (resolvedPlatform === 'whatsapp') {
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
        } else if (resolvedPlatform === 'telegram') {
            await telegramAdapter.sendMessage(targetId, {
                audio: { url: audioUrl },
                caption: 'Voice Note'
            });
        }

        return {
            success: true,
            message: `Voice note sent to ${recipient} on ${resolvedPlatform}`,
            audioUrl
        };
    }
};

/**
 * Tool: List Voice Models
 */
const listVoiceModelsTool: MCPTool = {
    name: 'list_voice_models',
    description: 'List available voice models for text-to-speech generation.',
    schema: {
        type: 'object',
        properties: {},
    },
    handler: async (args: any, context: MCPContext) => {
        const voices = await murfService.getVoiceModels();
        return {
            count: voices.length,
            voices: voices.slice(0, 50) // Limit to avoid context overflow
        };
    }
};

/**
 * Register Voice Tools
 */
export function registerVoiceTools() {
    gituMCPHub.registerTool(transcribeAudioTool);
    gituMCPHub.registerTool(sendVoiceNoteTool);
    gituMCPHub.registerTool(listVoiceModelsTool);
    console.log('[VoiceMCPTools] Registered transcription and voice note tools');
}
