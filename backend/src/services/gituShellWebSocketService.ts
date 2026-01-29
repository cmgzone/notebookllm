import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import jwt from 'jsonwebtoken';
import { gituShellManager, type ShellExecuteRequest, type ShellExecuteResult, type ShellExecutionHooks } from './gituShellManager.js';
import { getJwtSecret } from '../config/secrets.js';

type WSMessage =
  | { type: 'ping' }
  | { type: 'execute'; payload: ShellExecuteRequest }
  | { type: 'cancel'; payload: { executionId: string } };

type WSEvent =
  | { type: 'connected'; payload: { connectionId: string; userId: string } }
  | { type: 'pong' }
  | { type: 'shell_started'; payload: { executionId: string } }
  | { type: 'shell_output'; payload: { executionId: string; stream: 'stdout' | 'stderr'; chunk: string } }
  | { type: 'shell_completed'; payload: { executionId: string; result: ShellExecuteResult } }
  | { type: 'error'; payload: { error: string; executionId?: string } };

interface Connection {
  ws: WebSocket;
  connectionId: string;
  userId: string;
}

export interface GituShellWebSocketServiceDeps {
  shellManager?: { execute: (userId: string, request: ShellExecuteRequest, hooks?: ShellExecutionHooks) => Promise<ShellExecuteResult> };
}

class GituShellWebSocketService {
  private wss: WebSocketServer | null = null;
  private connections: Map<string, Connection> = new Map();
  private userConnections: Map<string, Set<string>> = new Map();
  private executionCancels: Map<string, Map<string, () => void>> = new Map();
  private connectionCounter = 0;
  private readonly shellManager: GituShellWebSocketServiceDeps['shellManager'];

  constructor(deps: GituShellWebSocketServiceDeps = {}) {
    this.shellManager = deps.shellManager ?? gituShellManager;
  }

  initialize(server: any): void {
    if (this.wss) return;

    this.wss = new WebSocketServer({
      server,
      path: '/ws/shell',
    });

    this.wss.on('connection', (ws, req) => this.handleConnection(ws, req));
  }

  shutdown(): void {
    for (const [, c] of this.connections) {
      try {
        c.ws.close(1000, 'Server shutting down');
      } catch {}
    }
    this.connections.clear();
    this.userConnections.clear();
    this.executionCancels.clear();

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

    const connectionId = `shell_ws_${++this.connectionCounter}_${Date.now()}`;
    const connection: Connection = { ws, connectionId, userId };

    this.connections.set(connectionId, connection);
    if (!this.userConnections.has(userId)) this.userConnections.set(userId, new Set());
    this.userConnections.get(userId)!.add(connectionId);
    this.executionCancels.set(connectionId, new Map());

    this.sendToConnection(connectionId, { type: 'connected', payload: { connectionId, userId } });

    ws.on('message', (data) => this.handleMessage(connectionId, data));
    ws.on('close', () => this.handleDisconnect(connectionId));
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

    const cancels = this.executionCancels.get(connectionId);
    if (cancels) {
      for (const [, cancel] of cancels) {
        try {
          cancel();
        } catch {}
      }
    }
    this.executionCancels.delete(connectionId);
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

    if (message.type === 'ping') {
      this.sendToConnection(connectionId, { type: 'pong' });
      return;
    }

    if (message.type === 'cancel') {
      const executionId = message.payload?.executionId;
      if (!executionId) {
        this.sendToConnection(connectionId, { type: 'error', payload: { error: 'executionId is required' } });
        return;
      }
      const cancels = this.executionCancels.get(connectionId);
      const cancel = cancels?.get(executionId);
      if (cancel) {
        try {
          cancel();
        } catch {}
      }
      return;
    }

    if (message.type !== 'execute') {
      this.sendToConnection(connectionId, { type: 'error', payload: { error: 'Unknown message type' } });
      return;
    }

    const request = message.payload;
    if (!request || typeof request.command !== 'string') {
      this.sendToConnection(connectionId, { type: 'error', payload: { error: 'payload.command is required' } });
      return;
    }

    const executionId = `exec_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    this.sendToConnection(connectionId, { type: 'shell_started', payload: { executionId } });

    const maxChunkChars = 8192;
    const hooks: ShellExecutionHooks = {
      registerCancel: (cancel) => {
        const cancels = this.executionCancels.get(connectionId);
        if (cancels) cancels.set(executionId, cancel);
      },
      onStdoutChunk: (chunk) => {
        const text = chunk.toString('utf8');
        const safe = text.length > maxChunkChars ? text.slice(0, maxChunkChars) : text;
        this.sendToConnection(connectionId, { type: 'shell_output', payload: { executionId, stream: 'stdout', chunk: safe } });
      },
      onStderrChunk: (chunk) => {
        const text = chunk.toString('utf8');
        const safe = text.length > maxChunkChars ? text.slice(0, maxChunkChars) : text;
        this.sendToConnection(connectionId, { type: 'shell_output', payload: { executionId, stream: 'stderr', chunk: safe } });
      },
    };

    try {
      const result = await this.shellManager!.execute(connection.userId, request, hooks);
      this.executionCancels.get(connectionId)?.delete(executionId);
      this.sendToConnection(connectionId, { type: 'shell_completed', payload: { executionId, result } });
    } catch (error: any) {
      this.executionCancels.get(connectionId)?.delete(executionId);
      this.sendToConnection(connectionId, { type: 'error', payload: { error: error?.message || 'Execution failed', executionId } });
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

  private sendToConnection(connectionId: string, event: WSEvent): void {
    const connection = this.connections.get(connectionId);
    if (!connection) return;
    if (connection.ws.readyState !== WebSocket.OPEN) return;

    try {
      connection.ws.send(JSON.stringify(event));
    } catch {}
  }
}

export const gituShellWebSocketService = new GituShellWebSocketService();
export { GituShellWebSocketService };
