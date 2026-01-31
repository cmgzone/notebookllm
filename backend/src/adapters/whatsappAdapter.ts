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

import { gituAgentManager } from '../services/gituAgentManager.js';
import { gituAgentOrchestrator } from '../services/gituAgentOrchestrator.js';
import { gituMissionControl } from '../services/gituMissionControl.js';

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
            authDir: config.authDir || process.env.GITU_WHATSAPP_AUTH_DIR || path.join(process.cwd(), 'auth_info_baileys'),
            printQRInTerminal: config.printQRInTerminal !== false, // Default true
        };

        await this.connectToWhatsApp();

        // Register outbound handler
        gituMessageGateway.registerOutboundHandler('whatsapp', async (jid, text) => {
            if (this.connectionState === 'connected') {
                await this.sendMessage(jid, text);
            }
        });

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
            syncFullHistory: true, // Help with decryption of older messages
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
                const error = lastDisconnect?.error as Boom | undefined;
                const statusCode = error?.output?.statusCode;

                const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
                this.logger.info(`Connection closed: ${statusCode}, reconnecting: ${shouldReconnect}`);

                // Conflict (409) or Logged Out
                const isConflict = statusCode === 409 || error?.message?.includes('conflict');
                const isLoggedOut = statusCode === DisconnectReason.loggedOut;

                if (isConflict || isLoggedOut) {
                    this.logger.warn(`Session terminated (${isConflict ? 'Conflict' : 'Logged Out'}). Clearing session.`);

                    // Clear auth directory
                    if (this.config?.authDir && fs.existsSync(this.config.authDir)) {
                        try {
                            fs.rmSync(this.config.authDir, { recursive: true, force: true });
                        } catch (e) {
                            this.logger.error({ err: e }, 'Failed to clear auth dir');
                        }
                    }

                    // Restart to generate new QR
                    this.connectionState = 'disconnected';
                    this.connectedAccountJid = null;
                    this.connectedAccountName = null;
                    await this.connectToWhatsApp();
                } else if (shouldReconnect) {
                    // Generic disconnect - Just reconnect, preserve session
                    await this.connectToWhatsApp();
                } else {
                    this.connectionState = 'disconnected';
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
                        const jid = msg.key.remoteJid || '';

                        // Ignore newsletters, broadcasts, and status updates
                        if (jid.includes('@newsletter') || jid.includes('@broadcast') || jid === 'status@broadcast') {
                            continue;
                        }

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
                    {}
                ) as Buffer;
                if (!text) text = '[Image]';
            } else if (msg.message?.videoMessage) {
                mediaType = 'video';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    {}
                ) as Buffer;
                if (!text) text = '[Video]';
            } else if (msg.message?.audioMessage) {
                mediaType = 'audio';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    {}
                ) as Buffer;
                if (!text) text = '[Audio]';
            } else if (msg.message?.documentMessage) {
                mediaType = 'document';
                mediaBuffer = await downloadMediaMessage(
                    toWAMessage(msg),
                    'buffer',
                    {}
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

        // Debug command: Ping
        if (text.toLowerCase() === 'ping' && isNoteToSelf) {
            await this.sendMessage(remoteJid, 'pong 🏓 (Connection Verified)');
            return;
        }

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

            // ================== COMMAND HANDLING ==================
            if (text.startsWith('/agent')) {
                const parts = text.split(' ');
                const command = parts[1];
                const args = parts.slice(2).join(' ');

                if (command === 'spawn' || command === 'create') {
                    if (!args) {
                        await this.sendMessage(remoteJid, '⚠️ Usage: /agent spawn <task description>');
                        return;
                    }
                    await this.sendMessage(remoteJid, `🤖 Spawning agent for: "${args}"...`);
                    try {
                        const agent = await gituAgentManager.spawnAgent(userId, args, {
                            role: 'autonomous_agent',
                            focus: 'general',
                            autoLoadPlugins: true
                        });
                        await this.sendMessage(remoteJid, `✅ Agent spawned! ID: ${agent.id.substring(0, 8)}\nI will notify you when it completes.`);
                    } catch (e: any) {
                        await this.sendMessage(remoteJid, `❌ Failed to spawn agent: ${e.message}`);
                    }
                    return;
                }

                if (command === 'list') {
                    const agents = await gituAgentManager.listAgents(userId);
                    if (agents.length === 0) {
                        await this.sendMessage(remoteJid, 'No active agents found.');
                        return;
                    }
                    const list = agents.map(a =>
                        `- *${a.task.substring(0, 30)}...*\n  Status: ${a.status}\n  ID: ${a.id.substring(0, 8)}`
                    ).join('\n\n');
                    await this.sendMessage(remoteJid, `📋 *Your Agents:*\n\n${list}`);
                    return;
                }

                await this.sendMessage(remoteJid, 'ℹ️ Available commands:\n/agent spawn <task>\n/agent list');
                return;
            }

            // ================== SWARM HANDLING ==================
            if (text.startsWith('/swarm')) {
                const parts = text.split(' ');
                const command = parts[1]; // status or task
                const args = parts.slice(1).join(' ');

                if (command === 'status') {
                    try {
                        const missions = await gituMissionControl.listActiveMissions(userId);
                        if (missions.length === 0) {
                            await this.sendMessage(remoteJid, 'No active swarm missions.');
                            return;
                        }
                        const list = missions.map(m =>
                            `- *${m.name}*\n  Status: ${m.status.toUpperCase()}\n  Agents: ${m.agentCount}`
                        ).join('\n\n');
                        await this.sendMessage(remoteJid, `🛸 *Active Swarms:*\n\n${list}`);
                    } catch (e: any) {
                        await this.sendMessage(remoteJid, `❌ Error: ${e.message}`);
                    }
                    return;
                }

                if (!args) {
                    await this.sendMessage(remoteJid, '⚠️ Usage: /swarm <complex objective>');
                    return;
                }

                await this.sendMessage(remoteJid, `🛸 Deploying Swarm: "${args}"...`);
                try {
                    const mission = await gituAgentOrchestrator.createMission(userId, args);
                    await this.sendMessage(remoteJid, `✅ **Swarm Deployed!**\nMission ID: ${mission.id.substring(0, 8)}\nI will notify you when finished.`);
                } catch (e: any) {
                    await this.sendMessage(remoteJid, `❌ Failed to deploy swarm: ${e.message}`);
                }
                return;
            }
            // ======================================================

            // Route to AI
            try {
                const aiResponse = await gituAIRouter.route({
                    userId,
                    platform: 'whatsapp',
                    platformUserId: remoteJid, // Use original remoteJid for routing context
                    content: text,
                    metadata: {
                        isNoteToSelf,
                        messageId: msg.key.id,
                        pushName: msg.pushName
                    },
                    taskType: 'chat',
                    useRetrieval: true // Enable RAG so AI knows about notebooks/sources
                });

                // Send response
                if (aiResponse && aiResponse.content) {
                    await this.sendMessage(remoteJid, aiResponse.content);
                }
            } catch (aiError) {
                this.logger.error({ err: aiError }, 'Error processing AI response');
                if (isNoteToSelf) {
                    await this.sendMessage(remoteJid, `⚠️ AI Error: ${aiError instanceof Error ? aiError.message : 'Unknown error'}`);
                }
            }

        } catch (authError) {
            // This catch block handles User ID lookup failures (Auth errors)
            // Downgrade to info as this is common for unlinked users
            this.logger.info(`Message from unlinked or unsupported WhatsApp account ${remoteJid}: ${authError instanceof Error ? authError.message : authError}`);

            if (isNoteToSelf) {
                await this.sendMessage(remoteJid,
                    '⚠️ Account not linked properly.\n' +
                    'Please open the Gitu App > Settings > Link WhatsApp and click "Link Current Session".'
                );
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
    async sendMessage(jid: string, content: string | { text?: string; image?: string; caption?: string }): Promise<void> {
        if (!this.sock) throw new Error('Socket not initialized');

        if (typeof content === 'string') {
            // Format text (Markdown -> WhatsApp)
            let formattedText = content
                .replace(/\*\*(.*?)\*\*/g, '*$1*') // Bold
                .replace(/\*(.*?)\*/g, '_$1_')     // Italic
                .replace(/~~(.*?)~~/g, '~$1~');    // Strikethrough

            await this.sock.sendMessage(jid, { text: formattedText });
        } else if (content.image) {
            // Handle Image
            let image: any = content.image;

            // If base64 data URI, strip prefix and convert to buffer
            if (typeof image === 'string' && image.startsWith('data:image')) {
                const base64Data = image.split(',')[1];
                image = Buffer.from(base64Data, 'base64');
            } else if (typeof image === 'string' && !image.startsWith('http')) {
                // Assume raw base64
                image = Buffer.from(image, 'base64');
            } else if (typeof image === 'string' && image.startsWith('http')) {
                // URL - pass as object for Baileys to download
                image = { url: image };
            }

            await this.sock.sendMessage(jid, {
                image: image,
                caption: content.caption || content.text
            });
        } else if (content.text) {
            await this.sendMessage(jid, content.text);
        }
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
