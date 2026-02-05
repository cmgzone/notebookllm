/**
 * Gitu Message Gateway
 * Handles all incoming messages from different platforms and normalizes them into a common format.
 * 
 * Requirements: US-1 (Multi-Platform Access), TR-1 (Architecture)
 * Design: Section 1 (Message Gateway)
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { gituMemoryExtractor } from './gituMemoryExtractor.js';

// ==================== INTERFACES ====================

/**
 * Platform types supported by Gitu
 */
export type Platform = 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal' | 'web';

/**
 * Attachment in a message
 */
export interface Attachment {
  type: 'image' | 'document' | 'audio' | 'video';
  data: Buffer;
  filename?: string;
  mimetype: string;
  size?: number;
}

/**
 * Message content
 */
export interface MessageContent {
  text?: string;
  attachments?: Attachment[];
  replyTo?: string;  // Message ID being replied to
}

/**
 * Normalized incoming message from any platform
 */
export interface IncomingMessage {
  id: string;
  userId: string;
  platform: Platform;
  platformUserId: string;  // Platform-specific user ID (e.g., WhatsApp number, Telegram chat ID)
  content: MessageContent;
  timestamp: Date;
  metadata: Record<string, any>;
}

/**
 * Raw message from a platform before normalization
 */
export interface RawMessage {
  platform: Platform;
  platformUserId: string;
  content: any;  // Platform-specific content format
  timestamp?: Date;
  metadata?: Record<string, any>;
}

/**
 * Message handler function type
 */
export type MessageHandler = (message: IncomingMessage) => void | Promise<void>;

/**
 * Platform detection result
 */
export interface PlatformDetection {
  platform: Platform;
  confidence: number;  // 0-1
  indicators: string[];  // What indicated this platform
}

// ==================== SERVICE CLASS ====================

class GituMessageGateway {
  private messageHandlers: Map<Platform, MessageHandler[]> = new Map();
  private outboundHandlers: Map<Platform, (userId: string, text: string) => Promise<void>> = new Map();
  private globalHandlers: MessageHandler[] = [];

  /**
   * Register a handler for sending outbound messages to a platform.
   * This allows the gateway to send notifications without hard dependencies on adapters.
   */
  registerOutboundHandler(platform: Platform, handler: (userId: string, text: string) => Promise<void>): void {
    this.outboundHandlers.set(platform, handler);
    console.log(`[Gitu Gateway] Registered outbound handler for ${platform}`);
  }

  /**
   * Track an outbound message to a user.
   * This is called by outbound handlers or the AI router to log the response
   * and trigger memory extraction.
   */
  async trackOutboundMessage(
      userId: string, 
      platform: Platform, 
      content: string, 
      options: { 
          replyToMessageId?: string;
          sessionId?: string;
          userMessageText?: string;
          metadata?: any;
      } = {}
  ): Promise<void> {
      // 1. Log the outbound message (optional, but good for history)
      // For now, we assume the AI Router logs the 'assistant' message to the session.
      // But we might want to log strictly platform-bound messages here too.

      // 2. Trigger Memory Extraction
      // We need the user's last message to provide context.
      // If replyToMessageId is provided, we fetch it.
      // Otherwise, we fetch the last user message from this platform.
      
      try {
          let userMessageText = typeof options.userMessageText === 'string' ? options.userMessageText : '';
          
          if (options.replyToMessageId) {
              const originalMsg = await this.getMessage(options.replyToMessageId);
              if (originalMsg?.content.text) {
                  userMessageText = originalMsg.content.text;
              }
          } else {
              // Fetch last user message
              const history = await this.getMessageHistory(userId, platform, 1);
              if (history.length > 0 && history[0].content.text) {
                  userMessageText = history[0].content.text;
              }
          }

          if (userMessageText) {
              // Fire and forget memory extraction
              gituMemoryExtractor.extractFromConversation(
                  userId,
                  userMessageText,
                  content,
                  { platform, sessionId: options.sessionId }
              ).catch(err => console.error('[Gitu Gateway] Memory extraction failed:', err));
          }
      } catch (error) {
          console.error('[Gitu Gateway] Error in trackOutboundMessage:', error);
      }
  }

  /**
   * Send a notification to a user across all their connected platforms.
   */
  async notifyUser(userId: string, message: string): Promise<void> {
    try {
      // Find all connected platforms for this user
      const result = await pool.query(
        `SELECT platform, platform_user_id FROM gitu_linked_accounts 
         WHERE user_id = $1 AND status = 'active'`,
        [userId]
      );

      const notifications: Promise<void>[] = [];

      for (const row of result.rows) {
        const platform = row.platform as Platform;
        const platformUserId = row.platform_user_id;
        const handler = this.outboundHandlers.get(platform);

        if (handler) {
          // We pass the platformUserId (JID/ChatID) to the handler
          // The handler signature in registerOutboundHandler expects (targetId, text)
          notifications.push(
            handler(platformUserId, message).catch(err =>
              console.error(`Failed to notify user ${userId} on ${platform}:`, err)
            )
          );
        }
      }

      await Promise.all(notifications);

    } catch (error) {
      console.error(`[Gitu Gateway] Failed to notify user ${userId}:`, error);
    }
  }

  /**
   * Normalize a raw message from any platform into the standard IncomingMessage format.
   * 
   * @param rawMessage - The raw message from a platform
   * @returns Normalized IncomingMessage
   */
  async normalizeMessage(rawMessage: RawMessage): Promise<IncomingMessage> {
    const messageId = uuidv4();
    const timestamp = rawMessage.timestamp || new Date();

    // Resolve user ID from platform-specific user ID
    const userId = await this.resolveUserId(rawMessage.platform, rawMessage.platformUserId);

    // Normalize content based on platform
    const content = await this.normalizeContent(rawMessage.platform, rawMessage.content);

    // Build normalized message
    const normalizedMessage: IncomingMessage = {
      id: messageId,
      userId,
      platform: rawMessage.platform,
      platformUserId: rawMessage.platformUserId,
      content,
      timestamp,
      metadata: {
        ...rawMessage.metadata,
        normalizedAt: new Date(),
        originalPlatform: rawMessage.platform,
      },
    };

    // Store message in database for audit trail
    await this.storeMessage(normalizedMessage);

    return normalizedMessage;
  }

  /**
   * Normalize message content based on platform-specific format.
   * 
   * @param platform - The platform the message came from
   * @param rawContent - Platform-specific content
   * @returns Normalized MessageContent
   */
  private async normalizeContent(platform: Platform, rawContent: any): Promise<MessageContent> {
    const content: MessageContent = {};

    switch (platform) {
      case 'flutter':
        content.text = rawContent.text || rawContent.message;
        content.attachments = rawContent.attachments || [];
        content.replyTo = rawContent.replyTo;
        break;

      case 'whatsapp':
        // WhatsApp via Baileys
        if (rawContent.message) {
          const msg = rawContent.message;
          const mediaBuffer = rawContent.media || Buffer.from([]);

          // Text message
          if (msg.conversation) {
            content.text = msg.conversation;
          } else if (msg.extendedTextMessage) {
            content.text = msg.extendedTextMessage.text;
            content.replyTo = msg.extendedTextMessage.contextInfo?.stanzaId;
          }

          // Image
          if (msg.imageMessage) {
            content.attachments = content.attachments || [];
            content.attachments.push({
              type: 'image',
              data: mediaBuffer.length > 0 ? mediaBuffer : (msg.imageMessage.jpegThumbnail || Buffer.from([])),
              filename: msg.imageMessage.caption || 'image.jpg',
              mimetype: msg.imageMessage.mimetype || 'image/jpeg',
            });
            if (msg.imageMessage.caption) {
              content.text = msg.imageMessage.caption;
            }
          }

          // Document
          if (msg.documentMessage) {
            content.attachments = content.attachments || [];
            content.attachments.push({
              type: 'document',
              data: mediaBuffer,
              filename: msg.documentMessage.fileName || 'document',
              mimetype: msg.documentMessage.mimetype || 'application/octet-stream',
            });
            if (msg.documentMessage.caption) {
              content.text = msg.documentMessage.caption;
            }
          }

          // Audio
          if (msg.audioMessage) {
            content.attachments = content.attachments || [];
            content.attachments.push({
              type: 'audio',
              data: mediaBuffer,
              filename: 'audio.ogg',
              mimetype: msg.audioMessage.mimetype || 'audio/ogg',
            });
          }

          // Video
          if (msg.videoMessage) {
            content.attachments = content.attachments || [];
            content.attachments.push({
              type: 'video',
              data: mediaBuffer,
              filename: msg.videoMessage.caption || 'video.mp4',
              mimetype: msg.videoMessage.mimetype || 'video/mp4',
            });
            if (msg.videoMessage.caption) {
              content.text = msg.videoMessage.caption;
            }
          }
        }
        break;

      case 'telegram':
        // Telegram Bot API
        content.text = rawContent.text || rawContent.caption;
        content.replyTo = rawContent.reply_to_message?.message_id?.toString();

        // Handle attachments
        if (rawContent.photo) {
          content.attachments = content.attachments || [];
          const largestPhoto = rawContent.photo[rawContent.photo.length - 1];
          content.attachments.push({
            type: 'image',
            data: Buffer.from([]), // File ID, actual data downloaded separately
            filename: 'photo.jpg',
            mimetype: 'image/jpeg',
          });
        }

        if (rawContent.document) {
          content.attachments = content.attachments || [];
          content.attachments.push({
            type: 'document',
            data: Buffer.from([]), // File ID, actual data downloaded separately
            filename: rawContent.document.file_name || 'document',
            mimetype: rawContent.document.mime_type || 'application/octet-stream',
          });
        }

        if (rawContent.voice || rawContent.audio) {
          content.attachments = content.attachments || [];
          const audioData = rawContent.voice || rawContent.audio;
          content.attachments.push({
            type: 'audio',
            data: Buffer.from([]), // File ID, actual data downloaded separately
            filename: audioData.file_name || 'audio.ogg',
            mimetype: audioData.mime_type || 'audio/ogg',
          });
        }

        if (rawContent.video) {
          content.attachments = content.attachments || [];
          content.attachments.push({
            type: 'video',
            data: Buffer.from([]), // File ID, actual data downloaded separately
            filename: rawContent.video.file_name || 'video.mp4',
            mimetype: rawContent.video.mime_type || 'video/mp4',
          });
        }
        break;

      case 'email':
        // Email (IMAP)
        content.text = rawContent.text || rawContent.html || rawContent.body;
        content.replyTo = rawContent.inReplyTo;

        if (rawContent.attachments && Array.isArray(rawContent.attachments)) {
          content.attachments = rawContent.attachments.map((att: any) => ({
            type: this.detectAttachmentType(att.contentType || att.mimetype),
            data: att.content || Buffer.from([]),
            filename: att.filename || att.name,
            mimetype: att.contentType || att.mimetype || 'application/octet-stream',
          }));
        }
        break;

      case 'terminal':
        // Terminal CLI
        content.text = rawContent.command || rawContent.text || rawContent;
        break;

      default:
        // Fallback: try to extract text
        content.text = typeof rawContent === 'string' ? rawContent : JSON.stringify(rawContent);
    }

    return content;
  }

  /**
   * Detect attachment type from mimetype.
   */
  private detectAttachmentType(mimetype: string): 'image' | 'document' | 'audio' | 'video' {
    if (mimetype.startsWith('image/')) return 'image';
    if (mimetype.startsWith('audio/')) return 'audio';
    if (mimetype.startsWith('video/')) return 'video';
    return 'document';
  }

  /**
   * Resolve NotebookLLM user ID from platform-specific user ID.
   * This links platform accounts to NotebookLLM users.
   * 
   * @param platform - The platform
   * @param platformUserId - Platform-specific user ID
   * @returns NotebookLLM user ID
   */
  private async resolveUserId(platform: Platform, platformUserId: string): Promise<string> {
    // Check if this platform account is linked to a user
    const result = await pool.query(
      `SELECT user_id FROM gitu_linked_accounts 
       WHERE platform = $1 AND platform_user_id = $2 AND status = 'active'`,
      [platform, platformUserId]
    );

    if (result.rows.length > 0) {
      return result.rows[0].user_id;
    }

    // If not linked, this is an error - user must link their account first
    throw new Error(
      `Platform account not linked. User must connect their ${platform} account in the NotebookLLM app first.`
    );
  }

  /**
   * Detect which platform a message came from based on content and metadata.
   * Useful for auto-detection scenarios.
   * 
   * @param rawContent - Raw message content
   * @param metadata - Message metadata
   * @returns Platform detection result
   */
  detectPlatform(rawContent: any, metadata?: Record<string, any>): PlatformDetection {
    const indicators: string[] = [];
    let platform: Platform = 'flutter';
    let confidence = 0.5;

    // Check metadata first
    if (metadata?.platform) {
      platform = metadata.platform as Platform;
      confidence = 1.0;
      indicators.push('explicit platform in metadata');
      return { platform, confidence, indicators };
    }

    // WhatsApp detection
    if (rawContent.key?.remoteJid || rawContent.message?.conversation) {
      platform = 'whatsapp';
      confidence = 0.95;
      indicators.push('WhatsApp message structure detected');
    }
    // Telegram detection
    else if (rawContent.message_id && rawContent.chat?.id) {
      platform = 'telegram';
      confidence = 0.95;
      indicators.push('Telegram message structure detected');
    }
    // Email detection
    else if (rawContent.from && rawContent.subject && rawContent.messageId) {
      platform = 'email';
      confidence = 0.95;
      indicators.push('Email message structure detected');
    }
    // Terminal detection
    else if (rawContent.command || metadata?.source === 'cli') {
      platform = 'terminal';
      confidence = 0.9;
      indicators.push('Terminal command structure detected');
    }
    // Flutter app detection (default)
    else if (rawContent.text || rawContent.message) {
      platform = 'flutter';
      confidence = 0.7;
      indicators.push('Generic message structure, assuming Flutter app');
    }

    return { platform, confidence, indicators };
  }

  /**
   * Register a message handler for a specific platform.
   * 
   * @param platform - The platform to handle messages for
   * @param handler - The handler function
   */
  onMessage(platform: Platform, handler: MessageHandler): void {
    if (!this.messageHandlers.has(platform)) {
      this.messageHandlers.set(platform, []);
    }
    this.messageHandlers.get(platform)!.push(handler);
  }

  /**
   * Register a global message handler that receives all messages.
   * 
   * @param handler - The handler function
   */
  onAnyMessage(handler: MessageHandler): void {
    this.globalHandlers.push(handler);
  }

  /**
   * Route a normalized message to registered handlers.
   * 
   * @param message - The normalized message
   */
  async routeMessage(message: IncomingMessage): Promise<void> {
    // Call platform-specific handlers
    const platformHandlers = this.messageHandlers.get(message.platform) || [];
    for (const handler of platformHandlers) {
      try {
        await handler(message);
      } catch (error) {
        console.error(`Error in platform handler for ${message.platform}:`, error);
      }
    }

    // Call global handlers
    for (const handler of this.globalHandlers) {
      try {
        await handler(message);
      } catch (error) {
        console.error('Error in global message handler:', error);
      }
    }
  }

  /**
   * Process a raw message: normalize and route to handlers.
   * This is the main entry point for incoming messages.
   * 
   * @param rawMessage - The raw message from a platform
   * @returns The normalized message
   */
  async processMessage(rawMessage: RawMessage): Promise<IncomingMessage> {
    // Normalize the message
    const normalizedMessage = await this.normalizeMessage(rawMessage);

    // Route to handlers
    await this.routeMessage(normalizedMessage);

    return normalizedMessage;
  }

  /**
   * Store a message in the database for audit trail and history.
   * 
   * @param message - The normalized message
   */
  private async storeMessage(message: IncomingMessage): Promise<void> {
    await pool.query(
      `INSERT INTO gitu_messages 
       (id, user_id, platform, platform_user_id, content, timestamp, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        message.id,
        message.userId,
        message.platform,
        message.platformUserId,
        JSON.stringify(message.content),
        message.timestamp,
        JSON.stringify(message.metadata),
      ]
    );
  }

  /**
   * Get message history for a user.
   * 
   * @param userId - The user's ID
   * @param platform - Optional platform filter
   * @param limit - Maximum number of messages to return
   * @returns Array of messages
   */
  async getMessageHistory(
    userId: string,
    platform?: Platform,
    limit: number = 50
  ): Promise<IncomingMessage[]> {
    const query = platform
      ? `SELECT * FROM gitu_messages 
         WHERE user_id = $1 AND platform = $2 
         ORDER BY timestamp DESC 
         LIMIT $3`
      : `SELECT * FROM gitu_messages 
         WHERE user_id = $1 
         ORDER BY timestamp DESC 
         LIMIT $2`;

    const params = platform ? [userId, platform, limit] : [userId, limit];
    const result = await pool.query(query, params);

    return result.rows.map(row => this.mapRowToMessage(row));
  }

  /**
   * Get a specific message by ID.
   * 
   * @param messageId - The message ID
   * @returns The message or null if not found
   */
  async getMessage(messageId: string): Promise<IncomingMessage | null> {
    const result = await pool.query(
      `SELECT * FROM gitu_messages WHERE id = $1`,
      [messageId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToMessage(result.rows[0]);
  }

  /**
   * Delete old messages (for cleanup).
   * 
   * @param daysOld - Delete messages older than this many days
   * @returns Number of messages deleted
   */
  async cleanupOldMessages(daysOld: number = 90): Promise<number> {
    const result = await pool.query(
      `DELETE FROM gitu_messages 
       WHERE timestamp < NOW() - INTERVAL '${daysOld} days'
       RETURNING id`
    );

    return result.rowCount || 0;
  }

  /**
   * Get message statistics for a user.
   * 
   * @param userId - The user's ID
   * @returns Message statistics
   */
  async getMessageStats(userId: string): Promise<{
    totalMessages: number;
    messagesByPlatform: Record<Platform, number>;
    messagesLast24h: number;
    messagesLast7d: number;
    averageMessagesPerDay: number;
  }> {
    // Total messages
    const totalResult = await pool.query(
      `SELECT COUNT(*) as count FROM gitu_messages WHERE user_id = $1`,
      [userId]
    );
    const totalMessages = parseInt(totalResult.rows[0].count);

    // Messages by platform
    const platformResult = await pool.query(
      `SELECT platform, COUNT(*) as count 
       FROM gitu_messages 
       WHERE user_id = $1 
       GROUP BY platform`,
      [userId]
    );
    const messagesByPlatform: Record<string, number> = {};
    platformResult.rows.forEach(row => {
      messagesByPlatform[row.platform] = parseInt(row.count);
    });

    // Messages last 24 hours
    const last24hResult = await pool.query(
      `SELECT COUNT(*) as count 
       FROM gitu_messages 
       WHERE user_id = $1 AND timestamp > NOW() - INTERVAL '24 hours'`,
      [userId]
    );
    const messagesLast24h = parseInt(last24hResult.rows[0].count);

    // Messages last 7 days
    const last7dResult = await pool.query(
      `SELECT COUNT(*) as count 
       FROM gitu_messages 
       WHERE user_id = $1 AND timestamp > NOW() - INTERVAL '7 days'`,
      [userId]
    );
    const messagesLast7d = parseInt(last7dResult.rows[0].count);

    // Average messages per day (based on first message date)
    const firstMessageResult = await pool.query(
      `SELECT MIN(timestamp) as first_message 
       FROM gitu_messages 
       WHERE user_id = $1`,
      [userId]
    );
    let averageMessagesPerDay = 0;
    if (firstMessageResult.rows[0].first_message) {
      const firstMessageDate = new Date(firstMessageResult.rows[0].first_message);
      const daysSinceFirst = Math.max(1, Math.floor((Date.now() - firstMessageDate.getTime()) / (1000 * 60 * 60 * 24)));
      averageMessagesPerDay = Math.round(totalMessages / daysSinceFirst * 10) / 10;
    }

    return {
      totalMessages,
      messagesByPlatform: messagesByPlatform as Record<Platform, number>,
      messagesLast24h,
      messagesLast7d,
      averageMessagesPerDay,
    };
  }

  /**
   * Map a database row to an IncomingMessage object.
   */
  private mapRowToMessage(row: any): IncomingMessage {
    return {
      id: row.id,
      userId: row.user_id,
      platform: row.platform,
      platformUserId: row.platform_user_id,
      content: typeof row.content === 'string' ? JSON.parse(row.content) : row.content,
      timestamp: new Date(row.timestamp),
      metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
    };
  }

  // ==================== WEBSOCKET BROADCASTING ====================

  private wsClients: Map<string, Set<any>> = new Map(); // userId -> Set<WebSocket>

  /**
   * Register a WebSocket client for a user.
   * This allows broadcasting real-time updates to connected clients.
   */
  registerWebSocketClient(userId: string, ws: any): void {
    if (!this.wsClients.has(userId)) {
      this.wsClients.set(userId, new Set());
    }
    this.wsClients.get(userId)!.add(ws);
    console.log(`[Gitu Gateway] WebSocket registered for user ${userId}`);
  }

  /**
   * Unregister a WebSocket client.
   */
  unregisterWebSocketClient(userId: string, ws: any): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    set.delete(ws);
    if (set.size === 0) {
      this.wsClients.delete(userId);
    }
    console.log(`[Gitu Gateway] WebSocket unregistered for user ${userId}`);
  }

  /**
   * Broadcast insights update to user's WebSocket.
   */
  broadcastInsightsUpdate(userId: string): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'insights_updated',
            payload: { timestamp: new Date().toISOString() }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast insights update to ${userId}:`, error);
        }
      }
    }
  }

  /**
   * Broadcast mission status update to user's WebSocket.
   */
  broadcastMissionUpdate(
    userId: string,
    missionId: string,
    status: string,
    options?: {
      message?: string;
      summary?: {
        total: number;
        completed: number;
        failed: number;
        inProgress: number;
        pending: number;
      };
      startedAt?: string;
      updatedAt?: string;
      completedAt?: string | null;
    }
  ): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'mission_updated',
            payload: {
              missionId,
              status,
              timestamp: new Date().toISOString(),
              message: options?.message,
              summary: options?.summary,
              startedAt: options?.startedAt,
              updatedAt: options?.updatedAt,
              completedAt: options?.completedAt ?? null
            }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast mission update to ${userId}:`, error);
        }
      }
    }
  }

  /**
   * Broadcast agent status update to user's WebSocket.
   */
  broadcastAgentUpdate(
    userId: string,
    update: {
      agentId: string;
      missionId?: string;
      task?: string;
      status: string;
      message?: string;
      updatedAt?: string;
    }
  ): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'agent_updated',
            payload: {
              ...update,
              timestamp: new Date().toISOString()
            }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast agent update to ${userId}:`, error);
        }
      }
    }
  }

  /**
   * Broadcast WhatsApp QR code to user's WebSocket.
   */
  broadcastWhatsAppQr(userId: string, qr: string): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'whatsapp_qr',
            payload: { qr, timestamp: new Date().toISOString() }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast WhatsApp QR to ${userId}:`, error);
        }
      }
    }
  }

  /**
   * Broadcast incoming platform message to user's WebSocket.
   */
  broadcastIncomingMessage(userId: string, platform: Platform, message: string): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'incoming_message',
            payload: { platform, message, timestamp: new Date().toISOString() }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast incoming message to ${userId}:`, error);
        }
      }
    }
  }

  /**
   * Broadcast generic notification to user's WebSocket.
   */
  broadcastNotification(userId: string, title: string, body: string, type: 'info' | 'success' | 'warning' | 'error' = 'info'): void {
    const set = this.wsClients.get(userId);
    if (!set) return;
    for (const ws of set) {
      if (ws && ws.readyState === 1) {
        try {
          ws.send(JSON.stringify({
            type: 'notification',
            payload: { title, body, notificationType: type, timestamp: new Date().toISOString() }
          }));
        } catch (error) {
          console.error(`[Gitu Gateway] Failed to broadcast notification to ${userId}:`, error);
        }
      }
    }
  }
}

// Export singleton instance
export const gituMessageGateway = new GituMessageGateway();
export default gituMessageGateway;

