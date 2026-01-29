/**
 * Gitu QR Authentication WebSocket Service
 * Provides real-time QR code authentication for terminal linking.
 * 
 * Flow:
 * 1. Terminal runs `gitu auth --qr`
 * 2. Terminal connects to WebSocket with device info
 * 3. Backend generates session ID and QR code data
 * 4. Terminal displays QR code
 * 5. User scans QR code in Flutter app
 * 6. Flutter app sends auth confirmation via HTTP
 * 7. Backend sends auth token to terminal via WebSocket
 * 8. Terminal stores token and closes connection
 */

import { WebSocket, WebSocketServer } from 'ws';
import { IncomingMessage } from 'http';
import { parse } from 'url';
import crypto from 'crypto';
import pool from '../config/database.js';
import { gituTerminalService } from './gituTerminalService.js';

// ==================== INTERFACES ====================

interface QRAuthConnection {
  ws: WebSocket;
  sessionId: string;
  deviceId: string;
  deviceName: string;
  connectedAt: Date;
  expiresAt: Date;
  status: 'pending' | 'scanned' | 'authenticated' | 'expired' | 'rejected';
}

interface QRAuthMessage {
  type: 'qr_data' | 'status_update' | 'auth_token' | 'error' | 'ping' | 'pong';
  payload?: any;
}

interface QRAuthSession {
  sessionId: string;
  deviceId: string;
  deviceName: string;
  qrData: string;
  status: 'pending' | 'scanned' | 'authenticated' | 'expired' | 'rejected';
  createdAt: Date;
  expiresAt: Date;
  userId?: string;
}

// ==================== SERVICE CLASS ====================

class GituQRAuthWebSocketService {
  private wss: WebSocketServer | null = null;
  private connections: Map<string, QRAuthConnection> = new Map(); // sessionId -> connection
  private sessions: Map<string, QRAuthSession> = new Map(); // sessionId -> session data
  private cleanupInterval: NodeJS.Timeout | null = null;

  /**
   * Initialize the WebSocket server
   */
  initialize(server: any): void {
    this.wss = new WebSocketServer({ 
      server,
      path: '/api/gitu/terminal/qr-auth',
    });

    this.wss.on('error', (error) => {
      console.error('[Gitu QR Auth] WebSocket server error:', error);
    });

    this.wss.on('connection', this.handleConnection.bind(this));

    // Start cleanup interval to remove expired sessions
    this.cleanupInterval = setInterval(() => {
      this.cleanupExpiredSessions();
    }, 30000); // Cleanup every 30 seconds

    console.log('🔌 Gitu QR Auth WebSocket service initialized at /api/gitu/terminal/qr-auth');
  }

  /**
   * Handle new WebSocket connection from terminal
   */
  private async handleConnection(ws: WebSocket, req: IncomingMessage): Promise<void> {
    const url = parse(req.url || '', true);
    const deviceId = url.query.deviceId as string;
    const deviceName = url.query.deviceName as string;

    // Validate required parameters
    if (!deviceId || !deviceName) {
      ws.close(4001, 'Missing deviceId or deviceName');
      return;
    }

    try {
      // Generate unique session ID
      const sessionId = this.generateSessionId();

      // Generate QR code data (URL that Flutter app will open)
      const qrData = this.generateQRData(sessionId, deviceId, deviceName);

      // Create session (expires in 2 minutes)
      const expiresAt = new Date(Date.now() + 2 * 60 * 1000);
      const session: QRAuthSession = {
        sessionId,
        deviceId,
        deviceName,
        qrData,
        status: 'pending',
        createdAt: new Date(),
        expiresAt,
      };

      this.sessions.set(sessionId, session);

      // Store the connection
      const connection: QRAuthConnection = {
        ws,
        sessionId,
        deviceId,
        deviceName,
        connectedAt: new Date(),
        expiresAt,
        status: 'pending',
      };

      this.connections.set(sessionId, connection);

      console.log(`[Gitu QR Auth] Terminal connected: ${deviceName} (${deviceId}), session: ${sessionId}`);

      // Set up message handler
      ws.on('message', (data) => this.handleMessage(sessionId, data));

      // Set up close handler
      ws.on('close', () => {
        this.connections.delete(sessionId);
        this.sessions.delete(sessionId);
        console.log(`[Gitu QR Auth] Terminal disconnected: ${deviceName} (session: ${sessionId})`);
      });

      // Set up error handler
      ws.on('error', (error) => {
        console.error(`[Gitu QR Auth] WebSocket error for session ${sessionId}:`, error);
      });

      // Send QR code data to terminal
      this.sendToTerminal(sessionId, {
        type: 'qr_data',
        payload: {
          sessionId,
          qrData,
          expiresAt: expiresAt.toISOString(),
          expiresInSeconds: 120,
          message: 'Scan this QR code in the NotebookLLM app to authenticate',
        },
      });

      // Set timeout to expire session
      setTimeout(() => {
        this.expireSession(sessionId);
      }, 2 * 60 * 1000);

    } catch (error) {
      console.error('[Gitu QR Auth] Error handling connection:', error);
      ws.close(4000, 'Internal server error');
    }
  }

  /**
   * Handle incoming message from terminal
   */
  private handleMessage(sessionId: string, data: any): void {
    try {
      const message: QRAuthMessage = JSON.parse(data.toString());

      switch (message.type) {
        case 'ping':
          this.sendToTerminal(sessionId, { type: 'pong' });
          break;

        default:
          console.log(`[Gitu QR Auth] Unknown message type: ${message.type}`);
      }
    } catch (error) {
      console.error('[Gitu QR Auth] Error handling message:', error);
    }
  }

  /**
   * Send message to terminal
   */
  private sendToTerminal(sessionId: string, message: QRAuthMessage): void {
    const connection = this.connections.get(sessionId);
    if (!connection || connection.ws.readyState !== WebSocket.OPEN) {
      return;
    }

    try {
      connection.ws.send(JSON.stringify(message));
    } catch (error) {
      console.error('[Gitu QR Auth] Error sending message to terminal:', error);
    }
  }

  /**
   * Handle QR code scan from Flutter app
   * Called by HTTP endpoint when user scans QR code
   */
  async handleQRScan(sessionId: string, userId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error('Session not found or expired');
    }

    if (session.status !== 'pending') {
      throw new Error(`Session already ${session.status}`);
    }

    if (new Date() > session.expiresAt) {
      throw new Error('Session expired');
    }

    // Update session status
    session.status = 'scanned';
    session.userId = userId;
    this.sessions.set(sessionId, session);

    // Notify terminal that QR was scanned
    this.sendToTerminal(sessionId, {
      type: 'status_update',
      payload: {
        status: 'scanned',
        message: 'QR code scanned, authenticating...',
      },
    });

    console.log(`[Gitu QR Auth] QR scanned for session ${sessionId} by user ${userId}`);
  }

  /**
   * Complete authentication and send token to terminal
   * Called by HTTP endpoint after user confirms in Flutter app
   */
  async completeAuthentication(sessionId: string, userId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error('Session not found or expired');
    }

    if (session.status !== 'scanned') {
      throw new Error(`Cannot complete authentication, session status is ${session.status}`);
    }

    if (session.userId !== userId) {
      throw new Error('User ID mismatch');
    }

    if (new Date() > session.expiresAt) {
      throw new Error('Session expired');
    }

    try {
      // Link terminal and generate auth token
      const result = await gituTerminalService.linkTerminalForUser(
        userId,
        session.deviceId,
        session.deviceName
      );

      // Update session status
      session.status = 'authenticated';
      this.sessions.set(sessionId, session);

      // Send auth token to terminal
      this.sendToTerminal(sessionId, {
        type: 'auth_token',
        payload: {
          authToken: result.authToken,
          userId: result.userId,
          expiresAt: result.expiresAt.toISOString(),
          expiresInDays: result.expiresInDays,
          message: 'Authentication successful! You can now use Gitu.',
        },
      });

      console.log(`[Gitu QR Auth] Authentication completed for session ${sessionId}`);

      // Close connection after 5 seconds
      setTimeout(() => {
        const connection = this.connections.get(sessionId);
        if (connection) {
          connection.ws.close(1000, 'Authentication completed');
        }
        this.connections.delete(sessionId);
        this.sessions.delete(sessionId);
      }, 5000);

    } catch (error: any) {
      console.error('[Gitu QR Auth] Error completing authentication:', error);

      // Send error to terminal
      this.sendToTerminal(sessionId, {
        type: 'error',
        payload: {
          error: error.message || 'Authentication failed',
        },
      });

      // Update session status
      session.status = 'rejected';
      this.sessions.set(sessionId, session);
    }
  }

  /**
   * Reject authentication
   * Called by HTTP endpoint if user rejects in Flutter app
   */
  async rejectAuthentication(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error('Session not found or expired');
    }

    // Update session status
    session.status = 'rejected';
    this.sessions.set(sessionId, session);

    // Notify terminal
    this.sendToTerminal(sessionId, {
      type: 'status_update',
      payload: {
        status: 'rejected',
        message: 'Authentication rejected by user',
      },
    });

    console.log(`[Gitu QR Auth] Authentication rejected for session ${sessionId}`);

    // Close connection after 2 seconds
    setTimeout(() => {
      const connection = this.connections.get(sessionId);
      if (connection) {
        connection.ws.close(1000, 'Authentication rejected');
      }
      this.connections.delete(sessionId);
      this.sessions.delete(sessionId);
    }, 2000);
  }

  /**
   * Expire a session
   */
  private expireSession(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (!session || session.status !== 'pending') {
      return;
    }

    // Update session status
    session.status = 'expired';
    this.sessions.set(sessionId, session);

    // Notify terminal
    this.sendToTerminal(sessionId, {
      type: 'status_update',
      payload: {
        status: 'expired',
        message: 'QR code expired. Please try again.',
      },
    });

    console.log(`[Gitu QR Auth] Session expired: ${sessionId}`);

    // Close connection after 2 seconds
    setTimeout(() => {
      const connection = this.connections.get(sessionId);
      if (connection) {
        connection.ws.close(1000, 'Session expired');
      }
      this.connections.delete(sessionId);
      this.sessions.delete(sessionId);
    }, 2000);
  }

  /**
   * Cleanup expired sessions
   */
  private cleanupExpiredSessions(): void {
    const now = new Date();
    const expiredSessions: string[] = [];

    for (const [sessionId, session] of this.sessions.entries()) {
      if (now > session.expiresAt && session.status === 'pending') {
        expiredSessions.push(sessionId);
      }
    }

    for (const sessionId of expiredSessions) {
      this.expireSession(sessionId);
    }

    if (expiredSessions.length > 0) {
      console.log(`[Gitu QR Auth] Cleaned up ${expiredSessions.length} expired sessions`);
    }
  }

  /**
   * Generate unique session ID
   */
  private generateSessionId(): string {
    return `qr_${Date.now()}_${crypto.randomBytes(8).toString('hex')}`;
  }

  /**
   * Generate QR code data
   * This will be a URL that the Flutter app can open
   */
  private generateQRData(sessionId: string, deviceId: string, deviceName: string): string {
    // Format: notebookllm://gitu/qr-auth?session=xxx&device=xxx&name=xxx
    const baseUrl = 'notebookllm://gitu/qr-auth';
    const params = new URLSearchParams({
      session: sessionId,
      device: deviceId,
      name: deviceName,
    });
    return `${baseUrl}?${params.toString()}`;
  }

  /**
   * Get session info (for HTTP endpoints)
   */
  getSession(sessionId: string): QRAuthSession | undefined {
    return this.sessions.get(sessionId);
  }

  /**
   * Shutdown the service
   */
  shutdown(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }

    // Close all connections
    for (const [sessionId, connection] of this.connections.entries()) {
      connection.ws.close(1000, 'Server shutting down');
    }

    this.connections.clear();
    this.sessions.clear();

    if (this.wss) {
      this.wss.close();
    }

    console.log('[Gitu QR Auth] WebSocket service shut down');
  }
}

// Export singleton instance
export const gituQRAuthWebSocketService = new GituQRAuthWebSocketService();
