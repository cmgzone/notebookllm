/**
 * WhatsApp Adapter for Gitu (via Baileys)
 * Handles WhatsApp integration for the Gitu universal AI assistant.
 * 
 * Requirements: Phase 2 - Multi-Platform & Memory
 * Task: 2.1.1 Baileys Setup
 */

import makeWASocket, {
    DisconnectReason,
    useMultiFileAuthState,
    fetchLatestBaileysVersion,
    makeCacheableSignalKeyStore,
    WASocket,
    BaileysEventMap,
    downloadMediaMessage,
    proto,
    WAMessage
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import pino from 'pino';
import path from 'path';
import fs from 'fs';
import { gituMessageGateway, IncomingMessage, RawMessage } from '../services/gituMessageGateway.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

export interface WhatsAppAdapterConfig {
    authDir?: string;
    printQRInTerminal?: boolean;
}

// ==================== ADAPTER CLASS ====================

class WhatsAppAdapter {
    private sock: WASocket | null = null;
    private initialized: boolean = false;
    private config: WhatsAppAdapterConfig | null = null;
    private logger = pino({ level: 'info' });
    private qrCode: string | null = null;
    private connectionState: 'connected' | 'disconnected' | 'connecting' = 'disconnected';
    private connectedAccountJid: string | null = null;
    private connectedAccountName: string | null = null;

    /**
     * Initialize the WhatsApp Adapter.
     * 
     * @param config - Configuration options
     */
    async initialize(config: WhatsAppAdapterConfig = {}): Promise<void> {
        if (this.initialized) {
            this.logger.info('WhatsApp adapter already initialized');
            return;
        }

        this.config = {
            authDir: config.authDir || path.join(process.cwd(), 'auth_info_baileys'),
            printQRInTerminal: config.printQRInTerminal !== false, // Default true
        };

        await this.connectToWhatsApp();
        this.initialized = true;
    }

    /**
     * Connect to WhatsApp using Baileys.
     */
    private async connectToWhatsApp(): Promise<void> {
        if (!this.config) throw new Error('Config not initialized');
        this.connectionState = 'connecting';
        this.connectedAccountJid = null;
        this.connectedAccountName = null;

        const { state, saveCreds } = await useMultiFileAuthState(this.config.authDir!);
        const { version, isLatest } = await fetchLatestBaileysVersion();
        
        this.logger.info(`Using WhatsApp v${version.join('.')}, isLatest: ${isLatest}`);

        this.sock = makeWASocket({
            version,
            logger: this.logger,
            printQRInTerminal: this.config.printQRInTerminal,
            auth: {
                creds: state.creds,
                keys: makeCacheableSignalKeyStore(state.keys, this.logger),
            },
            generateHighQualityLinkPreview: true,
        });

        // Handle connection update
        this.sock.ev.on('connection.update', async (update) => {
            const { connection, lastDisconnect, qr } = update;

            if (qr) {
                this.qrCode = qr;
                this.connectionState = 'connecting';
                this.logger.info('QR Code received');
                // TODO: Emit QR code to frontend via WebSocket if needed
            }

            if (connection === 'close') {
                const shouldReconnect = (lastDisconnect?.error as Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
                this.logger.info(`Connection closed due to ${lastDisconnect?.error}, reconnecting: ${shouldReconnect}`);
                
                if (shouldReconnect) {
                    await this.connectToWhatsApp();
                } else {
                    this.logger.info('Connection closed. You are logged out.');
                    this.connectionState = 'disconnected';
                    this.connectedAccountJid = null;
                    this.connectedAccountName = null;
                    // Clean up auth dir if logged out to force fresh login next time?
                    // Maybe not, user might want to re-login manually.
                }
            } else if (connection === 'open') {
                this.logger.info('Opened connection to WhatsApp');
                this.qrCode = null;
                this.connectionState = 'connected';
                const jid = (this.sock as any)?.user?.id;
                const name = (this.sock as any)?.user?.name;
                this.connectedAccountJid = typeof jid === 'string' ? jid : null;
                this.connectedAccountName = typeof name === 'string' ? name : null;
            }
        });

        // Handle creds update
        this.sock.ev.on('creds.update', saveCreds);

        // Handle messages
        this.sock.ev.on('messages.upsert', async (upsert) => {
            try {
                if (upsert.type === 'notify') {
                    for (const msg of upsert.messages) {
                        if (!msg.key.fromMe) {
                            await this.handleIncomingMessage(msg);
                        }
                    }
                }
            } catch (error) {
                this.logger.error({ err: error }, 'Error processing incoming message');
            }
        });
    }

    /**
     * Handle incoming WhatsApp message.
     */
    private async handleIncomingMessage(msg: proto.IWebMessageInfo): Promise<void> {
        if (!this.sock) return;

        if (!msg.key) return;
        const remoteJid = msg.key.remoteJid;

        // Normalize message to satisfy Baileys WAMessage typing
        const toWAMessage = (m: proto.IWebMessageInfo): any => {
            const normalizedRemoteJid = m.key?.remoteJid || remoteJid || '';
            const normalizedId =
                m.key?.id ||
                m.message?.extendedTextMessage?.contextInfo?.stanzaId ||
                `${Date.now()}`;
            return {
                ...m,
                key: {
                    remoteJid: normalizedRemoteJid,
                    fromMe: !!m.key?.fromMe,
                    id: normalizedId,
                },
            };
        };
        if (!remoteJid) return;

        // Basic text extraction
        let text = msg.message?.conversation || 
                     msg.message?.extendedTextMessage?.text || 
                     msg.message?.videoMessage?.caption || 
                     msg.message?.documentMessage?.caption || 
                     '';

        // Check for media
        let mediaBuffer: Buffer | undefined;
        let mediaType: 'image' | 'video' | 'audio' | 'document' | undefined;

        try {
            if (msg.message?.imageMessage) {
                mediaType = 'image';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    { }
                ) as Buffer;
                if (!text) text = '[Image]';
            } else if (msg.message?.videoMessage) {
                mediaType = 'video';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    { }
                ) as Buffer;
                if (!text) text = '[Video]';
            } else if (msg.message?.audioMessage) {
                mediaType = 'audio';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    { }
                ) as Buffer;
                if (!text) text = '[Audio]';
            } else if (msg.message?.documentMessage) {
                mediaType = 'document';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    { }
                ) as Buffer;
                if (!text) text = '[Document]';
            }
        } catch (error) {
            this.logger.error({ err: error }, 'Failed to download media');
        }

        if (!text && !mediaBuffer) return; // Skip empty messages

        this.logger.info(`Received message from ${remoteJid}: ${text}`);

        // TODO: Map WhatsApp user to Gitu user
        // For now, we need a way to link accounts. 
        // Maybe we can reuse the "link-telegram" logic but for WhatsApp?
        // Or assume a single-user mode for now if running locally?
        
        // Let's try to find the user in `gitu_linked_accounts`
        // We need to implement the linking flow first.
        // For testing, we can print the JID so the developer can manually insert it into DB.
        
        try {
            const userId = await this.getUserIdFromJid(remoteJid);
            
            // Build raw message
            const rawMessage: RawMessage = {
                platform: 'whatsapp',
                platformUserId: remoteJid,
                content: { 
                    message: msg.message,
                    text,
                    media: mediaBuffer,
                    mediaType
                },
                timestamp: new Date((msg.messageTimestamp as number) * 1000),
                metadata: {
                    messageId: msg.key.id,
                    pushName: msg.pushName,
                },
            };

            // Process through gateway
            const normalizedMessage = await gituMessageGateway.processMessage(rawMessage);
            
            // Send typing indicator
            await this.sock.sendPresenceUpdate('composing', remoteJid);

            const session = await gituSessionService.getOrCreateSession(userId, 'whatsapp');
            
            session.context.conversationHistory.push({
                role: 'user',
                content: text,
                timestamp: new Date(),
                platform: 'whatsapp',
            });

            const context = session.context.conversationHistory
                .slice(-21, -1)
                .map(m => `${m.role}: ${m.content}`);

            const aiResponse = await gituAIRouter.route({
                userId: userId,
                sessionId: session.id,
                prompt: text,
                context,
                taskType: 'chat',
            });

            session.context.conversationHistory.push({
                role: 'assistant',
                content: aiResponse.content,
                timestamp: new Date(),
                platform: 'whatsapp',
            });

            await gituSessionService.updateSession(session.id, { context: session.context });

            // Send response
            await this.sendMessage(remoteJid, aiResponse.content);

        } catch (error) {
            this.logger.warn(`User not linked for JID: ${remoteJid}. Run manual linking script.`);
            // Optionally reply with "Account not linked" if we want to be helpful
            // await this.sendMessage(remoteJid, 'Account not linked. Please link your WhatsApp account.');
        }
    }

    /**
     * Send a message to a JID.
     */
    async sendMessage(jid: string, text: string): Promise<void> {
        if (!this.sock) throw new Error('Socket not initialized');
        
        // Format text (Markdown -> WhatsApp)
        // **bold** -> *bold*
        // *italic* -> _italic_
        // ~~strike~~ -> ~strike~
        // `code` -> ```code```
        
        let formattedText = text
            .replace(/\*\*(.*?)\*\*/g, '*$1*') // Bold
            .replace(/\*(.*?)\*/g, '_$1_')     // Italic (single asterisk to underscore)
            .replace(/~~(.*?)~~/g, '~$1~');    // Strikethrough

        await this.sock.sendMessage(jid, { text: formattedText });
    }

    /**
     * Get user ID from JID.
     */
    private async getUserIdFromJid(jid: string): Promise<string> {
        const result = await pool.query(
            `SELECT user_id FROM gitu_linked_accounts 
             WHERE platform = 'whatsapp' AND platform_user_id = $1 AND status = 'active'`,
            [jid]
        );

        if (result.rows.length === 0) {
            throw new Error('WhatsApp account not linked.');
        }

        return result.rows[0].user_id;
    }

    /**
     * Get the current QR code.
     */
    getQRCode(): string | null {
        return this.qrCode;
    }

    /**
     * Get the current connection state.
     */
    getConnectionState(): 'connected' | 'disconnected' | 'connecting' {
        if (!this.initialized) return 'disconnected';
        return this.connectionState;
    }

    getConnectedAccount(): { jid: string; name?: string } | null {
        if (this.connectionState !== 'connected') return null;
        if (!this.connectedAccountJid) return null;
        return {
            jid: this.connectedAccountJid,
            name: this.connectedAccountName || undefined,
        };
    }

    /**
     * Force a reconnection.
     */
    async reconnect(): Promise<void> {
        this.logger.info('Forcing reconnection...');
        await this.disconnect();
        await this.connectToWhatsApp();
    }

    /**
     * Disconnect the adapter.
     */
    async disconnect(): Promise<void> {
        if (this.sock) {
            this.sock.end(undefined);
            this.sock = null;
        }
        this.initialized = false;
        this.connectionState = 'disconnected';
        this.qrCode = null;
        this.connectedAccountJid = null;
        this.connectedAccountName = null;
    }
}

// Export singleton
export const whatsappAdapter = new WhatsAppAdapter();
export default whatsappAdapter;
