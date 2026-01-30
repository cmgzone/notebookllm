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
     * Normalize a JID by removing device suffix.
     * e.g. 123456789:12@s.whatsapp.net -> 123456789@s.whatsapp.net
     */
    private normalizeJid(jid: string): string {
        if (!jid) return '';
        return jid.split(':')[0].split('@')[0] + '@s.whatsapp.net';
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
                
                // Special handling for conflict errors (Stream Errored)
                const isConflict = (lastDisconnect?.error as any)?.message?.includes('conflict') || 
                                   (lastDisconnect?.error as any)?.output?.statusCode === 409;

                if (isConflict) {
                     this.logger.warn('Conflict detected (Stream Errored). Clearning auth session and restarting...');
                     // Clear auth directory to force fresh login
                     if (this.config?.authDir && fs.existsSync(this.config.authDir)) {
                         fs.rmSync(this.config.authDir, { recursive: true, force: true });
                     }
                     // Reconnect will generate a new QR code
                     await this.connectToWhatsApp();
                } else if (shouldReconnect) {
                    await this.connectToWhatsApp();
                } else {
                    this.logger.info('Connection closed. You are logged out. Auto-clearing session and restarting.');
                    this.connectionState = 'disconnected';
                    this.connectedAccountJid = null;
                    this.connectedAccountName = null;
                    
                    // Auto-cleanup on logout to ensure fresh start
                    if (this.config?.authDir && fs.existsSync(this.config.authDir)) {
                        try {
                            fs.rmSync(this.config.authDir, { recursive: true, force: true });
                        } catch (e) {
                            this.logger.error({ err: e }, 'Failed to clear auth dir on logout');
                        }
                    }
                    
                    // Restart connection flow immediately to generate new QR
                    await this.connectToWhatsApp();
                }
            } else if (connection === 'open') {
                this.logger.info('Opened connection to WhatsApp');
                this.qrCode = null;
                this.connectionState = 'connected';
                const jid = (this.sock as any)?.user?.id;
                const name = (this.sock as any)?.user?.name;
                this.connectedAccountJid = typeof jid === 'string' ? this.normalizeJid(jid) : null;
                this.connectedAccountName = typeof name === 'string' ? name : null;

                // Attempt to send welcome message to self if linked
                if (this.connectedAccountJid) {
                    try {
                        const userId = await this.getUserIdFromJid(this.connectedAccountJid);
                        await this.sendMessage(this.connectedAccountJid, '🟢 *Gitu is Online*\n\nI am ready to assist you! Send me a message here (Note to Self) to start chatting.');
                    } catch (e) {
                        // Not linked yet, silent fail
                    }
                }
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

        // Check for Note to Self or direct user messages
        // Trust msg.key.fromMe explicitly for sent messages (Note to Self)
        const normalizedRemoteJid = this.normalizeJid(remoteJid);
        const isNoteToSelf = msg.key.fromMe || normalizedRemoteJid === this.connectedAccountJid;
        
        // If it's not a note to self and not a direct message from a user, we might want to ignore it
        // But for now, let's process everything that looks like a user message
        
        this.logger.info(`Received message from ${remoteJid}: ${text} (fromMe: ${msg.key.fromMe}, Connected: ${this.connectedAccountJid}, Note to Self: ${isNoteToSelf})`);

        try {
            // Attempt to get user ID, with auto-linking check if needed
            let userId: string;
            try {
                // If fromMe is true, we should look up the user based on the CONNECTED account JID, not necessarily the remoteJid
                // (remoteJid in Note to Self is usually the user's own JID, but let's be safe)
                const targetJid = isNoteToSelf && this.connectedAccountJid ? this.connectedAccountJid : remoteJid;
                userId = await this.getUserIdFromJid(targetJid);
            } catch (error) {
                // If it's a note to self, we might be able to auto-link if we have a pending session
                if (isNoteToSelf && this.connectedAccountJid) {
                     // Try to match against connected account JID variations
                     userId = await this.getUserIdFromJid(this.connectedAccountJid);
                } else {
                    throw error;
                }
            }
            
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
                    isNoteToSelf
                },
            };

            // Process through gateway
            const normalizedMessage = await gituMessageGateway.processMessage(rawMessage);
            
            // Only reply if it's a Note to Self OR if we have explicit permission/logic for other users
            // For now, Gitu only replies to the linked owner
            if (isNoteToSelf) {
                // Send typing indicator
                await this.sock.sendPresenceUpdate('composing', remoteJid);

                const session = await gituSessionService.getOrCreateSession(userId, 'universal');
                
                session.context.conversationHistory.push({
                    role: 'user',
                    content: text,
                    timestamp: new Date(),
                    platform: 'whatsapp',
                });

                const context = session.context.conversationHistory
                    .slice(-101, -1)
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
            } else {
                this.logger.info(`Ignoring message from ${remoteJid} (not Note to Self). Connected: ${this.connectedAccountJid}, Remote: ${normalizedRemoteJid}`);
            }

        } catch (error) {
            this.logger.warn(`User not linked for JID: ${remoteJid}. Run manual linking script.`);
            
            // If it's a Note to Self but linking failed, send a helpful error
            if (isNoteToSelf) {
                 await this.sendMessage(remoteJid, '⚠️ *Gitu Error*: Your WhatsApp account is not correctly linked to your Gitu profile. Please re-link via the app.');
            }
        }
    }

    /**
     * Send a proactive message to a user (e.g. Welcome or Reminder)
     */
    async sendProactiveMessage(userId: string, text: string): Promise<void> {
        if (!this.sock) return; // Silent fail if not connected, or throw?
        
        try {
            // Find the JID for this user
            const result = await pool.query(
                `SELECT platform_user_id FROM gitu_linked_accounts 
                 WHERE user_id = $1 AND platform = 'whatsapp' AND status = 'active'`,
                [userId]
            );
            
            if (result.rows.length > 0) {
                const jid = result.rows[0].platform_user_id;
                await this.sendMessage(jid, text);
            }
        } catch (error) {
            this.logger.error({ err: error }, `Failed to send proactive message to user ${userId}`);
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
        // Normalize JID: remove device specific suffix (e.g. :12@s.whatsapp.net -> @s.whatsapp.net)
        // Standard user JID format: 1234567890@s.whatsapp.net
        const normalizedJid = this.normalizeJid(jid);

        // Try exact match first
        let result = await pool.query(
            `SELECT user_id FROM gitu_linked_accounts 
             WHERE platform = 'whatsapp' AND platform_user_id = $1 AND status = 'active'`,
            [jid]
        );

        if (result.rows.length === 0) {
            // Try normalized match
            result = await pool.query(
                `SELECT user_id FROM gitu_linked_accounts 
                 WHERE platform = 'whatsapp' AND platform_user_id = $1 AND status = 'active'`,
                [normalizedJid]
            );
        }

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
