import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import pool from '../config/database.js';

/**
 * Helper: Check if a recipient ID matches the user's linked account
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
 * Tool: Get Messaging Profile
 */
const getMessagingProfileTool: MCPTool = {
    name: 'get_messaging_profile',
    description: 'Get the user\'s linked messaging identities (WhatsApp, Telegram).',
    schema: {
        type: 'object',
        properties: {},
    },
    handler: async (args: any, context: MCPContext) => {
        const waIdentity = await getLinkedIdentity(context.userId, 'whatsapp');
        const tgIdentity = await getLinkedIdentity(context.userId, 'telegram');

        return {
            userId: context.userId,
            identities: {
                whatsapp: waIdentity ? {
                    status: 'linked',
                    phoneNumber: waIdentity.split('@')[0],
                    jid: waIdentity,
                    isMe: true
                } : { status: 'not_linked' },
                telegram: tgIdentity ? {
                    status: 'linked',
                    chatId: tgIdentity,
                    isMe: true
                } : { status: 'not_linked' }
            }
        };
    }
};

/**
 * Tool: Send WhatsApp
 */
const sendWhatsAppTool: MCPTool = {
    name: 'send_whatsapp',
    description: 'Send a WhatsApp message (text or image) to a specific phone number or your linked account.',
    schema: {
        type: 'object',
        properties: {
            message: { type: 'string', description: 'The message content to send' },
            recipient: {
                type: 'string',
                description: 'Target phone number (e.g. "15550001234") or "self".'
            },
            image: { type: 'string', description: 'Optional: Image URL or Base64 string (starts with data:image...)' }
        },
        required: ['message', 'recipient']
    },
    handler: async (args: any, context: MCPContext) => {
        const { message, recipient, image } = args;

        try {
            const myIdentity = await getLinkedIdentity(context.userId, 'whatsapp');
            let targetJid: string;
            let recipientType: 'owner' | 'external' = 'external';

            if (recipient === 'self' || (myIdentity && recipient.includes(myIdentity.split('@')[0]))) {
                if (!myIdentity) throw new Error('No linked WhatsApp account found.');
                targetJid = myIdentity;
                recipientType = 'owner';
            } else {
                const cleanNumber = recipient.replace(/\D/g, '');
                if (cleanNumber.length < 10) throw new Error('Invalid phone number.');
                targetJid = `${cleanNumber}@s.whatsapp.net`;

                // Final check against identity
                if (myIdentity && targetJid === myIdentity) recipientType = 'owner';
            }

            await whatsappAdapter.sendMessage(targetJid, {
                text: message,
                image: image,
                caption: message
            });

            const debugInfo = recipientType === 'owner'
                ? `Sent to Owner (You) at ${targetJid.split('@')[0]}`
                : `Sent to External Contact: ${targetJid.split('@')[0]}`;

            return {
                success: true,
                recipientType,
                recipientId: targetJid,
                message: debugInfo
            };

        } catch (error: any) {
            throw new Error(`WhatsApp Error: ${error.message}`);
        }
    }
};

/**
 * Tool: Send Telegram
 */
const sendTelegramTool: MCPTool = {
    name: 'send_telegram',
    description: 'Send a Telegram message (text or image) to a specific chat ID or your linked account.',
    schema: {
        type: 'object',
        properties: {
            message: { type: 'string', description: 'The message content (Markdown supported)' },
            recipient: {
                type: 'string',
                description: 'Target Chat ID (e.g. "123456789") or "self".',
                default: 'self'
            },
            image: { type: 'string', description: 'Optional: Image Base64 string (no URL support yet)' }
        },
        required: ['message']
    },
    handler: async (args: any, context: MCPContext) => {
        const { message, recipient = 'self', image } = args;

        try {
            const myIdentity = await getLinkedIdentity(context.userId, 'telegram');
            let targetChatId: string;
            let recipientType: 'owner' | 'external' = 'external';

            if (recipient === 'self' || (myIdentity && recipient === myIdentity)) {
                if (!myIdentity) throw new Error('No linked Telegram account found.');
                targetChatId = myIdentity;
                recipientType = 'owner';
            } else {
                targetChatId = recipient;
                if (myIdentity && targetChatId === myIdentity) recipientType = 'owner';
            }

            const telegramMsg: any = { markdown: message };

            if (image) {
                // Convert base64 to buffer
                let buffer: Buffer;
                if (image.startsWith('data:image')) {
                    buffer = Buffer.from(image.split(',')[1], 'base64');
                } else {
                    buffer = Buffer.from(image, 'base64');
                }
                telegramMsg.photo = buffer;
                telegramMsg.caption = message; // Use message as caption
                delete telegramMsg.markdown; // Prefer caption if photo is sent
            }

            await telegramAdapter.sendMessage(targetChatId, telegramMsg);

            const debugInfo = recipientType === 'owner'
                ? `Sent to Owner (You) at ${targetChatId}`
                : `Sent to External Contact: ${targetChatId}`;

            return {
                success: true,
                recipientType,
                recipientId: targetChatId,
                message: debugInfo
            };

        } catch (error: any) {
            throw new Error(`Telegram Error: ${error.message}`);
        }
    }
};

/**
 * Register Messaging Tools
 */
export function registerMessagingTools() {
    gituMCPHub.registerTool(sendWhatsAppTool);
    gituMCPHub.registerTool(sendTelegramTool);
    gituMCPHub.registerTool(getMessagingProfileTool);
    console.log('[MessagingMCPTools] Registered messaging tools with image support');
}
