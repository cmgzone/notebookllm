import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { gituMessageGateway, type IncomingMessage as GituIncomingMessage, type RawMessage } from '../services/gituMessageGateway.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { getJwtSecret } from '../config/secrets.js';

type FlutterWSMessage =
  | { type: 'ping' }
  | { type: 'user_message'; payload: { text: string } }
  | { type: 'subscribe'; payload?: { channels?: string[] } };

type FlutterWSEvent =
  | { type: 'connected'; payload: { connectionId: string; userId: string } }
  | { type: 'pong' }
  | { type: 'incoming_message'; payload: GituIncomingMessage }
  | { type: 'assistant_response'; payload: { sessionId: string; content: string; model: string; tokensUsed: number; cost: number } }
  | { type: 'error'; payload: { error: string } };

interface FlutterConnection {
  ws: WebSocket;
  connectionId: string;
  userId: string;
  connectedAt: Date;
  lastPing: Date;
}

class FlutterAdapter {
  private wss: WebSocketServer | null = null;
  private connections: Map<string, FlutterConnection> = new Map();
  private userConnections: Map<string, Set<string>> = new Map();
  private pingInterval: NodeJS.Timeout | null = null;
  private connectionCounter = 0;
  private gatewaySubscribed = false;

  initialize(server: any): void {
    if (this.wss) return;

    this.wss = new WebSocketServer({
      noServer: true
    });

    this.wss.on('error', (error) => {
      console.error('[Gitu Flutter WS] Server error:', error);
    });

    this.wss.on('connection', (ws, req) => this.handleConnection(ws, req));

    this.pingInterval = setInterval(() => {
      this.pingAllConnections();
    }, 30000);

    if (!this.gatewaySubscribed) {
      this.gatewaySubscribed = true;
      gituMessageGateway.onAnyMessage(async (message) => {
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

    const connectionId = `gitu_flutter_${++this.connectionCounter}_${Date.now()}`;
    const connection: FlutterConnection = {
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

    try {
      await this.ensureFlutterLinkedAccount(userId);
    } catch (error: any) {
      this.sendToConnection(connectionId, { type: 'error', payload: { error: error.message || 'Failed to link flutter account' } });
    }

    this.sendToConnection(connectionId, { type: 'connected', payload: { connectionId, userId } });

    ws.on('message', (data) => this.handleMessage(connectionId, data));
    ws.on('close', () => this.handleDisconnect(connectionId));
    ws.on('error', (error) => {
      console.error(`[Gitu Flutter WS] Error (${connectionId}):`, error);
    });
  }

  private handleDisconnect(connectionId: string): void {
    const connection = this.connections.get(connectionId);
    if (!connection) return;

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

    let message: FlutterWSMessage;
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
        if (!text) {
          this.sendToConnection(connectionId, { type: 'error', payload: { error: 'Message text is required' } });
          return;
        }

        try {
          await this.ensureFlutterLinkedAccount(connection.userId);

          const rawMessage: RawMessage = {
            platform: 'flutter',
            platformUserId: connection.userId,
            content: { text },
            timestamp: new Date(),
            metadata: {
              source: 'flutter_ws',
              connectionId,
            },
          };

          const normalized = await gituMessageGateway.processMessage(rawMessage);

          const session = await gituSessionService.getOrCreateSession(connection.userId, 'universal');
          session.context.conversationHistory.push({
            role: 'user',
            content: normalized.content.text || text,
            timestamp: new Date(),
            platform: 'flutter',
          });

          const context = session.context.conversationHistory
            .slice(-101, -1)
            .map(m => `${m.role}: ${m.content}`);

          const aiResponse = await gituAIRouter.route({
            userId: connection.userId,
            sessionId: session.id,
            prompt: normalized.content.text || text,
            context,
            taskType: 'chat',
          });

          session.context.conversationHistory.push({
            role: 'assistant',
            content: aiResponse.content,
            timestamp: new Date(),
            platform: 'flutter',
          });

          await gituSessionService.updateSession(session.id, { context: session.context });

          this.sendToConnection(connectionId, {
            type: 'assistant_response',
            payload: {
              sessionId: session.id,
              content: aiResponse.content,
              model: aiResponse.model,
              tokensUsed: aiResponse.tokensUsed,
              cost: aiResponse.cost,
            },
          });
        } catch (error: any) {
          this.sendToConnection(connectionId, { type: 'error', payload: { error: error.message || 'Failed to process message' } });
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

  private async ensureFlutterLinkedAccount(userId: string): Promise<void> {
    const userResult = await pool.query(
      `SELECT email, display_name FROM users WHERE id = $1`,
      [userId]
    );
    if (userResult.rows.length === 0) {
      throw new Error('User not found');
    }

    const displayName = userResult.rows[0].display_name || userResult.rows[0].email || userId;

    await pool.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified, status)
       VALUES ($1, 'flutter', $2, $3, true, 'active')
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           display_name = EXCLUDED.display_name,
           verified = true,
           status = 'active',
           last_used_at = NOW()`,
      [userId, userId, displayName]
    );
  }

  private sendToConnection(connectionId: string, event: FlutterWSEvent): void {
    const connection = this.connections.get(connectionId);
    if (!connection || connection.ws.readyState !== WebSocket.OPEN) return;
    try {
      connection.ws.send(JSON.stringify(event));
    } catch { }
  }

  private broadcastToUser(userId: string, event: FlutterWSEvent): void {
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

export const flutterAdapter = new FlutterAdapter();
export default flutterAdapter;
