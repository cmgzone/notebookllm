import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import jwt from 'jsonwebtoken';
import { getJwtSecret } from '../config/secrets.js';
import { ShellExecuteRequest, ShellExecuteResult, ShellExecutionHooks } from './gituShellManager.js';

interface RemoteConnection {
    ws: WebSocket;
    userId: string;
    deviceId: string;
    deviceName: string;
    pendingRequests: Map<string, {
        resolve: (result: ShellExecuteResult) => void,
        reject: (error: any) => void,
        hooks: ShellExecutionHooks
    }>;
}

class GituRemoteTerminalService {
    private wss: WebSocketServer | null = null;
    private connections: Map<string, RemoteConnection[]> = new Map(); // userId -> connections

    initialize(server: any): void {
        this.wss = new WebSocketServer({ noServer: true });

        server.on('upgrade', (req: IncomingMessage, socket: any, head: Buffer) => {
            const { pathname } = parse(req.url || '', true);
            if (pathname === '/ws/remote-terminal' || pathname === '/ws/remote-terminal/') {
                this.wss?.handleUpgrade(req, socket, head, (ws) => {
                    this.handleConnection(ws, req);
                });
            }
        });
    }

    private async handleConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
        const url = parse(req.url || '', true);
        const token = url.query.token as string | undefined;
        const deviceId = url.query.deviceId as string || 'default';
        const deviceName = url.query.deviceName as string || 'Gitu CLI';

        if (!token) {
            ws.close(4001, 'Missing token');
            return;
        }

        const userId = this.verifyJwt(token);
        if (!userId) {
            ws.close(4002, 'Invalid token');
            return;
        }

        const connection: RemoteConnection = {
            ws,
            userId,
            deviceId,
            deviceName,
            pendingRequests: new Map()
        };

        if (!this.connections.has(userId)) {
            this.connections.set(userId, []);
        }
        this.connections.get(userId)!.push(connection);

        console.log(`[RemoteTerminal] User ${userId} connected from ${deviceName} (${deviceId})`);

        ws.on('message', (data) => this.handleMessage(connection, data));
        ws.on('close', () => this.handleDisconnect(connection));
        ws.on('error', () => this.handleDisconnect(connection));
    }

    private handleDisconnect(connection: RemoteConnection): void {
        const userConns = this.connections.get(connection.userId);
        if (userConns) {
            this.connections.set(
                connection.userId,
                userConns.filter(c => c !== connection)
            );
            if (this.connections.get(connection.userId)!.length === 0) {
                this.connections.delete(connection.userId);
            }
        }

        // Reject all pending requests
        for (const [id, req] of connection.pendingRequests) {
            req.reject(new Error('Connection closed'));
        }
        connection.pendingRequests.clear();
    }

    private handleMessage(connection: RemoteConnection, data: any): void {
        try {
            const message = JSON.parse(data.toString());

            if (message.type === 'execute_result' && message.id) {
                const pending = connection.pendingRequests.get(message.id);
                if (pending) {
                    pending.resolve(message.payload);
                    connection.pendingRequests.delete(message.id);
                }
            } else if (message.type === 'execute_output' && message.id) {
                const pending = connection.pendingRequests.get(message.id);
                if (pending) {
                    if (message.stream === 'stdout') {
                        pending.hooks.onStdoutChunk?.(Buffer.from(message.chunk));
                    } else {
                        pending.hooks.onStderrChunk?.(Buffer.from(message.chunk));
                    }
                }
            }
        } catch (err) {
            console.error('[RemoteTerminal] Error handling message:', err);
        }
    }

    private verifyJwt(token: string): string | null {
        try {
            const jwtSecret = getJwtSecret();
            const decoded = jwt.verify(token, jwtSecret) as { userId?: string };
            return decoded?.userId || null;
        } catch {
            return null;
        }
    }

    /**
     * Check if a user has any active remote terminal connections
     */
    hasConnection(userId: string): boolean {
        return this.connections.has(userId) && this.connections.get(userId)!.length > 0;
    }

    /**
     * Execute a command on a remote terminal
     */
    async executeRemote(userId: string, request: ShellExecuteRequest, hooks: ShellExecutionHooks = {}): Promise<ShellExecuteResult> {
        const userConns = this.connections.get(userId);
        if (!userConns || userConns.length === 0) {
            throw new Error('No remote terminal connected for this user');
        }

        // Pick the most recent connection (or first available)
        const connection = userConns[userConns.length - 1];
        const requestId = `req_${Date.now()}_${Math.random().toString(16).slice(2)}`;

        return new Promise<ShellExecuteResult>((resolve, reject) => {
            connection.pendingRequests.set(requestId, { resolve, reject, hooks });

            try {
                connection.ws.send(JSON.stringify({
                    type: 'execute',
                    id: requestId,
                    payload: request
                }));
            } catch (err) {
                connection.pendingRequests.delete(requestId);
                reject(err);
            }
        });
    }
}

export const gituRemoteTerminalService = new GituRemoteTerminalService();
