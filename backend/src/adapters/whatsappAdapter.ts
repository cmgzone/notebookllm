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
import fsPromises from 'fs/promises';
import { fileURLToPath } from 'url';
import { gituMessageGateway, IncomingMessage, RawMessage } from '../services/gituMessageGateway.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import pool from '../config/database.js';

import { gituAgentManager } from '../services/gituAgentManager.js';
import { gituAgentOrchestrator } from '../services/gituAgentOrchestrator.js';
import { gituMissionControl } from '../services/gituMissionControl.js';
import { gituToolExecutionService } from '../services/gituToolExecutionService.js';

// ==================== INTERFACES ====================

export interface WhatsAppAdapterConfig {
    authDir?: string;
    printQRInTerminal?: boolean;
}

// ==================== STORE SETUP ====================
const ADAPTER_DIR = path.dirname(fileURLToPath(import.meta.url));
const CONTACTS_FILE = path.resolve(ADAPTER_DIR, '..', '..', '..', 'whatsapp_contacts.json');
let contactsStore: Record<string, any> = {};

try {
    if (fs.existsSync(CONTACTS_FILE)) {
        const raw = fs.readFileSync(CONTACTS_FILE, 'utf-8');
        contactsStore = JSON.parse(raw || '{}');
    }
} catch (err) {
    console.error('Failed to read WhatsApp contacts store file:', err);
}

const upsertContacts = (contacts: any[] | undefined) => {
    if (!Array.isArray(contacts)) return;
    for (const contact of contacts) {
        const id = contact?.id || contact?.jid || contact?.remoteJid;
        if (!id || typeof id !== 'string') continue;
        contactsStore[id] = { ...(contactsStore[id] || {}), ...contact };
    }
};

const upsertChats = (chats: any[] | undefined) => {
    if (!Array.isArray(chats)) return;
    for (const chat of chats) {
        const id = chat?.id || chat?.jid || chat?.remoteJid;
        if (!id || typeof id !== 'string') continue;
        const name = chat?.name || chat?.subject || chat?.pushName || chat?.verifiedName || chat?.notify;
        contactsStore[id] = {
            ...(contactsStore[id] || {}),
            ...chat,
            ...(typeof name === 'string' && name.trim().length > 0 ? { name } : {}),
        };
    }
};

const shouldPersistContactsStore = !(process.env.NODE_ENV === 'test' || process.env.JEST_WORKER_ID);

if (shouldPersistContactsStore) {
    setInterval(() => {
        try {
            const dir = path.dirname(CONTACTS_FILE);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
            fs.writeFileSync(CONTACTS_FILE, JSON.stringify(contactsStore, null, 2), 'utf-8');
        } catch (err) {
            console.error('Failed to save WhatsApp contacts store file:', err);
        }
    }, 10_000);
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
    private connectedAccountLid: string | null = null;
    private connectedAccountName: string | null = null;
    private sentMessageIds = new Set<string>();
    private reconnectTimer: NodeJS.Timeout | null = null;
    private reconnectAttempts = 0;

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

    private normalizeLid(jid: string): string {
        if (!jid) return '';
        if (!jid.includes('@lid')) return '';
        return jid.split(':')[0].split('@')[0] + '@lid';
    }

    private isSelfChat(remoteJid: string): boolean {
        if (!remoteJid) return false;
        const normalizedJid = this.normalizeJid(remoteJid);
        const normalizedLid = this.normalizeLid(remoteJid);

        if (this.connectedAccountJid) {
            if (remoteJid === this.connectedAccountJid) return true;
            if (normalizedJid === this.connectedAccountJid) return true;
        }
        if (this.connectedAccountLid) {
            if (remoteJid === this.connectedAccountLid) return true;
            if (normalizedLid && normalizedLid === this.connectedAccountLid) return true;
        }
        return false;
    }

    /**
     * Connect to WhatsApp using Baileys.
     */
    private async connectToWhatsApp(): Promise<void> {
        if (!this.config) throw new Error('Config not initialized');

        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }

        if (this.sock) {
            try {
                (this.sock as any)?.ev?.removeAllListeners?.();
            } catch {}
            try {
                (this.sock as any)?.end?.();
            } catch {}
            this.sock = null;
        }

        this.connectionState = 'connecting';
        this.connectedAccountJid = null;
        this.connectedAccountLid = null;
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
            syncFullHistory: process.env.GITU_WHATSAPP_SYNC_FULL_HISTORY === 'true',
            connectTimeoutMs: 60_000,
            defaultQueryTimeoutMs: 60_000,
        });
        
        // Keep a lightweight contacts store without relying on Baileys internal store exports
        this.sock.ev.on('contacts.set' as any, (payload: any) => {
            upsertContacts(payload?.contacts);
        });
        this.sock.ev.on('contacts.upsert' as any, (contacts: any[]) => {
            upsertContacts(contacts);
        });
        this.sock.ev.on('contacts.update' as any, (updates: any[]) => {
            upsertContacts(updates);
        });

        this.sock.ev.on('chats.set' as any, (payload: any) => {
            upsertChats(payload?.chats);
        });
        this.sock.ev.on('chats.upsert' as any, (chats: any[]) => {
            upsertChats(chats);
        });
        this.sock.ev.on('chats.update' as any, (updates: any[]) => {
            upsertChats(updates);
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
                const errorMessage = String((error as any)?.message || '');
                const isConflict =
                    statusCode === 440 ||
                    statusCode === 409 ||
                    errorMessage.toLowerCase().includes('conflict');
                const isLoggedOut = statusCode === DisconnectReason.loggedOut;

                if (isLoggedOut) {
                    this.logger.warn('Session logged out. Clearing auth state and requiring re-pair.');
                    if (this.config?.authDir && fs.existsSync(this.config.authDir)) {
                        await this.safeRemoveDir(this.config.authDir);
                    }
                    this.connectionState = 'disconnected';
                    this.connectedAccountJid = null;
                    this.connectedAccountLid = null;
                    this.connectedAccountName = null;
                    this.scheduleReconnect('logged_out', 1000);
                } else if (isConflict) {
                    this.logger.warn('Session conflict (replaced). Backing off before reconnecting.');
                    this.connectionState = 'disconnected';
                    this.connectedAccountJid = null;
                    this.connectedAccountLid = null;
                    this.connectedAccountName = null;
                    this.scheduleReconnect('conflict', 30_000);
                } else if (shouldReconnect) {
                    // Generic disconnect - Just reconnect, preserve session
                    const delayMs = Math.min(60_000, 2_000 * Math.pow(2, this.reconnectAttempts));
                    this.scheduleReconnect('reconnect', delayMs);
                } else {
                    this.connectionState = 'disconnected';
                }
            } else if (connection === 'open') {
                this.logger.info('Opened connection to WhatsApp');
                this.qrCode = null;
                this.connectionState = 'connected';
                this.reconnectAttempts = 0;
                if (this.reconnectTimer) {
                    clearTimeout(this.reconnectTimer);
                    this.reconnectTimer = null;
                }
                const jid = (this.sock as any)?.user?.id;
                const lid = (this.sock as any)?.user?.lid;
                const name = (this.sock as any)?.user?.name;
                this.connectedAccountJid = typeof jid === 'string' ? this.normalizeJid(jid) : null;
                this.connectedAccountLid = typeof lid === 'string' ? this.normalizeLid(lid) : null;
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

                        // Handle "fromMe" messages (Note to Self via Phone) vs Bot Output
                        if (msg.key.fromMe) {
                            // Check for Bot Echoes (prevent loop)
                            if (msg.key.id && this.sentMessageIds.has(msg.key.id)) {
                                this.sentMessageIds.delete(msg.key.id);
                                continue;
                            }
                            // Check for Note to Self
                            const remoteJid = msg.key.remoteJid || '';
                            if (!this.isSelfChat(remoteJid)) {
                                continue;
                            }
                        }

                        // Process message
                        await this.handleIncomingMessage(msg);
                    }
                }
            } catch (error) {
                this.logger.error({ err: error }, 'Error processing incoming message');
            }
        });
    }

    private scheduleReconnect(reason: string, delayMs: number) {
        if (this.reconnectTimer) return;
        this.reconnectAttempts += 1;
        const delay = Math.max(500, Math.min(delayMs, 120_000));
        this.logger.info({ reason, delayMs: delay, attempt: this.reconnectAttempts }, 'Scheduling WhatsApp reconnect');

        this.reconnectTimer = setTimeout(async () => {
            this.reconnectTimer = null;
            try {
                await this.connectToWhatsApp();
            } catch (e) {
                this.logger.error({ err: e }, 'Reconnect attempt failed');
                this.scheduleReconnect('reconnect_failed', Math.min(120_000, delay * 2));
            }
        }, delay);
    }

    private async safeRemoveDir(dir: string) {
        const maxAttempts = 6;
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                await fsPromises.rm(dir, { recursive: true, force: true });
                return;
            } catch (e: any) {
                const code = String(e?.code || '');
                const retryable = code === 'EBUSY' || code === 'EPERM' || code === 'ENOTEMPTY';
                if (!retryable || attempt === maxAttempts) {
                    this.logger.error({ err: e }, 'Failed to clear auth dir');
                    return;
                }
                await new Promise(resolve => setTimeout(resolve, 250 * attempt));
            }
        }
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
        const isNoteToSelf = this.isSelfChat(remoteJid);

        // If it's not a note to self and not a direct message from a user, we might want to ignore it
        // But for now, let's process everything that looks like a user message

        this.logger.info(`Received message from ${remoteJid}: ${text} (fromMe: ${msg.key.fromMe}, Connected: ${this.connectedAccountJid || this.connectedAccountLid}, Note to Self: ${isNoteToSelf})`);

        // Debug command: Ping
        if (text.toLowerCase() === 'ping' && isNoteToSelf) {
            const replyJid = this.connectedAccountJid || remoteJid;
            await this.sendMessage(replyJid, 'pong 🏓 (Connection Verified)');
            return;
        }

        try {
            // Attempt to get user ID, with auto-linking check if needed
            let userId: string;
            const targetJid = isNoteToSelf && this.connectedAccountJid ? this.connectedAccountJid : remoteJid;
            try {
                // If fromMe is true, we should look up the user based on the CONNECTED account JID, not necessarily the remoteJid
                // (remoteJid in Note to Self is usually the user's own JID, but let's be safe)
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

            let gatewayMessageId: string | undefined;
            try {
                const normalized = await gituMessageGateway.processMessage({
                    platform: 'whatsapp',
                    platformUserId: targetJid,
                    content: { message: msg.message, media: mediaBuffer },
                    timestamp: new Date(),
                    metadata: {
                        remoteJid,
                        messageId: msg.key.id,
                        pushName: msg.pushName,
                        fromMe: msg.key.fromMe,
                        isNoteToSelf,
                    },
                });
                gatewayMessageId = normalized.id;
            } catch (e: any) {
                this.logger.debug(`Failed to store WhatsApp message in gateway: ${e?.message || e}`);
            }

            // ================== COMMAND HANDLING ==================
            if (text.startsWith('/agent')) {
                const replyJid = isNoteToSelf && this.connectedAccountJid ? this.connectedAccountJid : remoteJid;
                const parts = text.split(' ');
                const command = parts[1];
                const args = parts.slice(2).join(' ');

                if (command === 'spawn' || command === 'create') {
                    if (!args) {
                        await this.sendMessage(replyJid, '⚠️ Usage: /agent spawn <task description>');
                        return;
                    }
                    await this.sendMessage(replyJid, `🤖 Spawning agent for: "${args}"...`);
                    try {
                        const agent = await gituAgentManager.spawnAgent(userId, args, {
                            role: 'autonomous_agent',
                            focus: 'general',
                            autoLoadPlugins: true
                        });
                        await this.sendMessage(replyJid, `✅ Agent spawned! ID: ${agent.id.substring(0, 8)}\nI will notify you when it completes.`);
                    } catch (e: any) {
                        await this.sendMessage(replyJid, `❌ Failed to spawn agent: ${e.message}`);
                    }
                    return;
                }

                if (command === 'list') {
                    const agents = await gituAgentManager.listAgents(userId);
                    if (agents.length === 0) {
                        await this.sendMessage(replyJid, 'No active agents found.');
                        return;
                    }
                    const list = agents.map(a =>
                        `- *${a.task.substring(0, 30)}...*\n  Status: ${a.status}\n  ID: ${a.id.substring(0, 8)}`
                    ).join('\n\n');
                    await this.sendMessage(replyJid, `📋 *Your Agents:*\n\n${list}`);
                    return;
                }

                await this.sendMessage(replyJid, 'ℹ️ Available commands:\n/agent spawn <task>\n/agent list');
                return;
            }

            // ================== SWARM HANDLING ==================
            if (text.startsWith('/swarm')) {
                const replyJid = isNoteToSelf && this.connectedAccountJid ? this.connectedAccountJid : remoteJid;
                const parts = text.split(' ');
                const command = parts[1]; // status or task
                const args = parts.slice(1).join(' ');

                if (command === 'status') {
                    try {
                        const missions = await gituMissionControl.listActiveMissions(userId);
                        if (missions.length === 0) {
                            await this.sendMessage(replyJid, 'No active swarm missions.');
                            return;
                        }
                        const list = missions.map(m =>
                            `- *${m.name}*\n  Status: ${m.status.toUpperCase()}\n  Agents: ${m.agentCount}`
                        ).join('\n\n');
                        await this.sendMessage(replyJid, `🛸 *Active Swarms:*\n\n${list}`);
                    } catch (e: any) {
                        await this.sendMessage(replyJid, `❌ Error: ${e.message}`);
                    }
                    return;
                }

                if (!args) {
                    await this.sendMessage(replyJid, '⚠️ Usage: /swarm <complex objective>');
                    return;
                }

                await this.sendMessage(replyJid, `🛸 Deploying Swarm: "${args}"...`);
                try {
                    const mission = await gituAgentOrchestrator.createMission(userId, args);
                    await this.sendMessage(replyJid, `✅ **Swarm Deployed!**\nMission ID: ${mission.id.substring(0, 8)}\nI will notify you when finished.`);
                } catch (e: any) {
                    await this.sendMessage(replyJid, `❌ Failed to deploy swarm: ${e.message}`);
                }
                return;
            }
            // ======================================================

            // Route to AI
            try {
                // Ensure session exists
                const session = await gituSessionService.getOrCreateSession(userId, 'universal');

                // Add User Message to History
                await gituSessionService.addMessage(session.id, {
                    role: 'user',
                    content: text || '',
                    platform: 'whatsapp'
                });

                // Prepare context
                const history = session.context.conversationHistory || [];
                const contextStart = Math.max(0, history.length - 10);
                const recentHistory = history.slice(contextStart).map(m => ({
                    role: m.role as 'user' | 'assistant' | 'system' | 'tool',
                    content: m.content
                }));

                // Use Tool Execution Service for smart responses
                const result = await gituToolExecutionService.processWithTools(
                    userId,
                    text || '',
                    recentHistory,
                    {
                        platform: 'whatsapp',
                        sessionId: session.id,
                        isNoteToSelf,
                        messageId: msg.key.id,
                        pushName: msg.pushName
                    } as any
                );

                // Add Assistant Response to History
                await gituSessionService.updateActivity(session.id);
                await gituSessionService.addMessage(session.id, {
                    role: 'assistant',
                    content: result.response,
                    platform: 'whatsapp'
                });

                // Send Response
                await this.sendMessage(remoteJid, result.response);
                await gituMessageGateway.trackOutboundMessage(userId, 'whatsapp', result.response, {
                    sessionId: session.id,
                    replyToMessageId: gatewayMessageId,
                    userMessageText: text || '',
                });
            } catch (aiError) {
                this.logger.error({ err: aiError }, 'Error processing AI response');
                if (isNoteToSelf) {
                    await this.sendMessage(remoteJid, `⚠️ AI Error: ${aiError instanceof Error ? aiError.message : 'Unknown error'}`);
                }
            }

        } catch (authError) {
            // This catch block handles User ID lookup failures (Auth errors)
            const isSpam = !isNoteToSelf;

            if (isSpam) {
                // Low-level debug log for spam to avoid clutter
                this.logger.debug(`Ignored unlinked message from ${remoteJid}`);
            } else {
                // Genuine user setup issue - Log Warning and Notify
                this.logger.warn(`Message from unlinked Note-to-Self account ${remoteJid}: ${authError instanceof Error ? authError.message : authError}`);

                if (isNoteToSelf) {
                    await this.sendMessage(remoteJid,
                        '⚠️ Account not linked properly.\n' +
                        'Please open the Gitu App > Settings > Link WhatsApp and click "Link Current Session".'
                    );
                }
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

        const trackSentMsg = (msg: proto.IWebMessageInfo | undefined) => {
            const id = msg?.key?.id;
            if (id) {
                this.sentMessageIds.add(id);
                // Auto-cleanup after 15s
                setTimeout(() => this.sentMessageIds.delete(id), 15000);
            }
        };

        if (typeof content === 'string') {
            // Format text (Markdown -> WhatsApp)
            let formattedText = content
                .replace(/\*\*(.*?)\*\*/g, '*$1*') // Bold
                .replace(/\*(.*?)\*/g, '_$1_')     // Italic
                .replace(/~~(.*?)~~/g, '~$1~');    // Strikethrough

            const sent = await this.sock.sendMessage(jid, { text: formattedText });
            trackSentMsg(sent);
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

            const sent = await this.sock.sendMessage(jid, {
                image: image,
                caption: content.caption || content.text
            });
            trackSentMsg(sent);
        } else if (content.text) {
            await this.sendMessage(jid, content.text);
        }
    }

    /**
     * Search for contacts in the local store.
     */
    async searchContacts(query: string): Promise<Array<{ id: string; name: string; notify?: string }>> {
        const q = query.trim().toLowerCase();
        const qDigits = query.replace(/\D/g, '');
        const results: Array<{ id: string; name: string; notify?: string }> = [];

        if (q.length === 0 && qDigits.length === 0) return [];

        for (const id in contactsStore) {
            const contact = contactsStore[id];
            const name = contact.name || contact.notify || contact.verifiedName || contact.pushName || contact.subject || '';
            const idBare = id.split('@')[0] || id;
            const idDigits = idBare.replace(/\D/g, '');
            const nameText = typeof name === 'string' ? name.toLowerCase() : '';
            
            // Search by name or phone number
            const matchesName = q.length > 0 && nameText.includes(q);
            const matchesId = q.length > 0 && idBare.toLowerCase().includes(q);
            const matchesDigits = qDigits.length > 0 && idDigits.includes(qDigits);

            if (matchesName || matchesId || matchesDigits) {
                results.push({
                    id: id,
                    name: name || 'Unknown',
                    notify: contact.notify
                });
            }
        }
        
        // Limit results
        return results.slice(0, 10);
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
        this.connectedAccountLid = null;
        this.connectedAccountName = null;
    }
}

// Export singleton
export const whatsappAdapter = new WhatsAppAdapter();
export default whatsappAdapter;
