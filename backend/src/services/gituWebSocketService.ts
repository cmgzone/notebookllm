import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { gituMessageGateway, type IncomingMessage as GituIncomingMessage, type RawMessage } from './gituMessageGateway.js';
import { gituSessionService } from './gituSessionService.js';
import { gituAIRouter } from './gituAIRouter.js';
import { gituToolExecutionService } from './gituToolExecutionService.js';
import { gituMemoryExtractor } from './gituMemoryExtractor.js';
import { getJwtSecret } from '../config/secrets.js';

type WSMessage =
  | { type: 'ping' }
  | { type: 'user_message'; payload: { text: string; sessionId?: string; context?: string[] } }
  | { type: 'subscribe'; payload?: { channels?: string[] } };

type WSEvent =
  | { type: 'connected'; payload: { connectionId: string; userId: string } }
  | { type: 'pong' }
  | { type: 'incoming_message'; payload: GituIncomingMessage }
  | { type: 'assistant_typing'; payload: { sessionId?: string; isTyping: boolean } }
  | { type: 'assistant_response'; payload: { sessionId: string; content: string; model: string; tokensUsed: number; cost: number } }
  | { type: 'error'; payload: { error: string } };

interface Connection {
  ws: WebSocket;
  connectionId: string;
  userId: string;
  connectedAt: Date;
  lastPing: Date;
}

class GituWebSocketService {
  private wss: WebSocketServer | null = null;
  private connections: Map<string, Connection> = new Map();
  private userConnections: Map<string, Set<string>> = new Map();
  private pingInterval: NodeJS.Timeout | null = null;
  private connectionCounter = 0;
  private gatewaySubscribed = false;

  // Constructor injection for testing
  private _wsServerConstructor: any = WebSocketServer;

  setWebSocketServerConstructor(ctor: any) {
    this._wsServerConstructor = ctor;
  }

  initialize(server: any): void {
    if (this.wss) return;

    this.wss = new this._wsServerConstructor({
      noServer: true
    });

    this.wss?.on('error', (error) => {
      console.error('[Gitu Web WS] Server error:', error);
    });

    this.wss?.on('connection', (ws, req) => this.handleConnection(ws, req));

    this.pingInterval = setInterval(() => {
      this.pingAllConnections();
    }, 30000);

    if (!this.gatewaySubscribed) {
      this.gatewaySubscribed = true;
      gituMessageGateway.onAnyMessage(async (message) => {
        // Broadcast incoming messages to user's connected clients (so they see their own messages or updates)
        this.broadcastToUser(message.userId, { type: 'incoming_message', payload: message });
      });
    }
  }

  handleUpgrade(req: IncomingMessage, socket: any, head: Buffer): void {
    this.wss?.handleUpgrade(req, socket, head, (ws) => {
      this.wss?.emit('connection', ws, req);
    });
  }

  shutdown(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }

    for (const [, connection] of this.connections) {
      try {
        connection.ws.close(1000, 'Server shutting down');
      } catch { }
    }
    this.connections.clear();
    this.userConnections.clear();

    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }
  }

  private async handleConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
    const url = parse(req.url || '', true);
    const token = url.query.token as string | undefined;

    if (!token) {
      ws.close(4001, 'Missing token');
      return;
    }

    const userId = this.verifyJwt(token);
    if (!userId) {
      ws.close(4002, 'Invalid token');
      return;
    }

    const connectionId = `gitu_web_${++this.connectionCounter}_${Date.now()}`;
    const connection: Connection = {
      ws,
      connectionId,
      userId,
      connectedAt: new Date(),
      lastPing: new Date(),
    };

    this.connections.set(connectionId, connection);
    if (!this.userConnections.has(userId)) {
      this.userConnections.set(userId, new Set());
    }
    this.userConnections.get(userId)!.add(connectionId);

    // Ensure account is linked (for web, it's implicit, but good to have consistency)
    try {
      await this.ensureLinkedAccount(userId);
    } catch (error: any) {
      console.warn(`[Gitu Web WS] Failed to link account for ${userId}:`, error);
    }

    // Register WebSocket for real-time broadcasting
    gituMessageGateway.registerWebSocketClient(userId, ws);

    this.sendToConnection(connectionId, { type: 'connected', payload: { connectionId, userId } });

    ws.on('message', (data) => this.handleMessage(connectionId, data));
    ws.on('close', () => this.handleDisconnect(connectionId));
    ws.on('error', (error) => {
      console.error(`[Gitu Web WS] Error (${connectionId}):`, error);
    });
  }

  private handleDisconnect(connectionId: string): void {
    const connection = this.connections.get(connectionId);
    if (!connection) return;

    // Unregister WebSocket from broadcasting
    gituMessageGateway.unregisterWebSocketClient(connection.userId, connection.ws);

    this.connections.delete(connectionId);
    const set = this.userConnections.get(connection.userId);
    if (set) {
      set.delete(connectionId);
      if (set.size === 0) this.userConnections.delete(connection.userId);
    }
  }

  private async handleMessage(connectionId: string, data: any): Promise<void> {
    const connection = this.connections.get(connectionId);
    if (!connection) return;

    let message: WSMessage;
    try {
      message = JSON.parse(data.toString());
    } catch {
      this.sendToConnection(connectionId, { type: 'error', payload: { error: 'Invalid JSON message' } });
      return;
    }

    switch (message.type) {
      case 'ping':
        connection.lastPing = new Date();
        this.sendToConnection(connectionId, { type: 'pong' });
        return;

      case 'subscribe':
        this.sendToConnection(connectionId, { type: 'pong' });
        return;

      case 'user_message': {
        const text = message.payload?.text?.trim();
        const existingSessionId = message.payload?.sessionId;
        const context = message.payload?.context || [];

        if (!text) {
          this.sendToConnection(connectionId, { type: 'error', payload: { error: 'Message text is required' } });
          return;
        }

        let typingSessionId: string | undefined;
        let typingSent = false;
        try {
          // Normalize message
          const rawMessage: RawMessage = {
            platform: 'web',
            platformUserId: connection.userId,
            content: { text },
            timestamp: new Date(),
            metadata: {
              source: 'web_ws',
              connectionId,
            },
          };

          const normalized = await gituMessageGateway.processMessage(rawMessage);

          // Get or create session
          let session;
          if (existingSessionId) {
            session = await gituSessionService.getSession(existingSessionId);
            if (!session || session.userId !== connection.userId) {
              // Fallback to creating new if not found
              session = await gituSessionService.getOrCreateSession(connection.userId, 'web');
            }
          } else {
            session = await gituSessionService.getOrCreateSession(connection.userId, 'web');
          }

          typingSessionId = session.id;
          this.sendToConnection(connectionId, {
            type: 'assistant_typing',
            payload: { sessionId: typingSessionId, isTyping: true }
          });
          typingSent = true;

          // Add user message to session
          await gituSessionService.addMessage(session.id, {
            role: 'user',
            content: normalized.content.text || text,
            platform: 'web',
          });

          // Prepare conversation history for tool execution
          const conversationHistory = session.context.conversationHistory
            .slice(-20) // Last 20 messages
            .map(m => ({
              role: m.role as 'user' | 'assistant' | 'system' | 'tool',
              content: m.content
            }));

          // Use Tool Execution Service instead of direct Router call
          const result = await gituToolExecutionService.processWithTools(
            connection.userId,
            normalized.content.text || text,
            conversationHistory,
            {
              platform: 'web',
              sessionId: session.id,
            }
          );

          // Add assistant response to session
          await gituSessionService.addMessage(session.id, {
            role: 'assistant',
            content: result.response,
            platform: 'web',
          });

          // Send response back to client
          this.sendToConnection(connectionId, {
            type: 'assistant_response',
            payload: {
              sessionId: session.id,
              content: result.response,
              model: result.model,
              tokensUsed: result.tokensUsed,
              // Calculate cost approx if not returned
              cost: (result.tokensUsed / 1000) * 0.0001,
            },
          });

          // Background: Extract and store memories
          gituMemoryExtractor.extractFromConversation(
            connection.userId,
            normalized.content.text || text,
            result.response,
            { platform: 'web', sessionId: session.id }
          ).catch(err => console.error('[Gitu WS] Memory extraction error:', err));
        } catch (error: any) {
          console.error('[Gitu Web WS] Error processing message:', error);
          this.sendToConnection(connectionId, { type: 'error', payload: { error: error.message || 'Failed to process message' } });
        } finally {
          if (typingSent) {
            this.sendToConnection(connectionId, {
              type: 'assistant_typing',
              payload: { sessionId: typingSessionId, isTyping: false }
            });
          }
        }
        return;
      }
    }
  }

  private verifyJwt(token: string): string | null {
    try {
      const jwtSecret = getJwtSecret();
      const decoded = jwt.verify(token, jwtSecret) as { userId?: string };
      if (!decoded?.userId) return null;
      return decoded.userId;
    } catch {
      return null;
    }
  }

  private async ensureLinkedAccount(userId: string): Promise<void> {
    const userResult = await pool.query(
      `SELECT email, display_name FROM users WHERE id = $1`,
      [userId]
    );
    if (userResult.rows.length === 0) return;

    const displayName = userResult.rows[0].display_name || userResult.rows[0].email || userId;

    await pool.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified, status)
         VALUES ($1, 'web', $2, $3, true, 'active')
         ON CONFLICT (platform, platform_user_id) DO UPDATE
         SET user_id = EXCLUDED.user_id,
             display_name = EXCLUDED.display_name,
             verified = true,
             status = 'active',
             last_used_at = NOW()`,
      [userId, userId, displayName]
    );
  }

  private sendToConnection(connectionId: string, event: WSEvent): void {
    const connection = this.connections.get(connectionId);
    if (!connection || connection.ws.readyState !== WebSocket.OPEN) return;
    try {
      connection.ws.send(JSON.stringify(event));
    } catch { }
  }

  private broadcastToUser(userId: string, event: WSEvent): void {
    const connectionIds = this.userConnections.get(userId);
    if (!connectionIds) return;
    for (const id of connectionIds) {
      this.sendToConnection(id, event);
    }
  }

  private pingAllConnections(): void {
    const now = Date.now();
    for (const [id, conn] of this.connections) {
      const msSincePing = now - conn.lastPing.getTime();
      if (msSincePing > 2 * 60 * 1000) {
        try {
          conn.ws.close(1000, 'Ping timeout');
        } catch { }
        this.handleDisconnect(id);
        continue;
      }

      if (conn.ws.readyState === WebSocket.OPEN) {
        try {
          conn.ws.send(JSON.stringify({ type: 'ping' }));
        } catch { }
      }
    }
  }
}

export const gituWebSocketService = new GituWebSocketService();
export default gituWebSocketService;
