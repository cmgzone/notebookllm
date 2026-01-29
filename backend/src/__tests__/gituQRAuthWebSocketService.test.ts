import http from 'http';
import WebSocket from 'ws';
import { describe, it, expect, beforeAll, afterAll, jest } from '@jest/globals';
import { gituQRAuthWebSocketService } from '../services/gituQRAuthWebSocketService.js';
import { gituTerminalService } from '../services/gituTerminalService.js';

describe('GituQRAuthWebSocketService', () => {
  let server: http.Server;
  let port: number;

  beforeAll(async () => {
    server = http.createServer();
    await new Promise<void>((resolve) => {
      server.listen(0, '127.0.0.1', () => resolve());
    });

    const address = server.address();
    if (!address || typeof address === 'string') {
      throw new Error('Failed to bind test server');
    }
    port = address.port;

    gituQRAuthWebSocketService.initialize(server);
  });

  afterAll(async () => {
    gituQRAuthWebSocketService.shutdown();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  });

  it('should complete QR auth flow and send auth token', async () => {
    const linkSpy = jest
      .spyOn(gituTerminalService, 'linkTerminalForUser')
      .mockResolvedValue({
        authToken: 'test-terminal-token',
        userId: 'user-123',
        expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
        expiresInDays: 90,
      });

    const wsUrl = `ws://127.0.0.1:${port}/api/gitu/terminal/qr-auth?deviceId=test-device&deviceName=${encodeURIComponent('Test Device')}`;
    const ws = new WebSocket(wsUrl);

    const received: string[] = [];

    const result = await new Promise<any>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('timeout')), 10000);

      ws.on('message', async (data: WebSocket.RawData) => {
        const message = JSON.parse(data.toString());
        received.push(message.type);

        if (message.type === 'qr_data') {
          const sessionId = message.payload.sessionId as string;
          try {
            await gituQRAuthWebSocketService.handleQRScan(sessionId, 'user-123');
            await gituQRAuthWebSocketService.completeAuthentication(sessionId, 'user-123');
          } catch (e) {
            clearTimeout(timeout);
            reject(e);
          }
        }

        if (message.type === 'auth_token') {
          clearTimeout(timeout);
          resolve(message.payload);
        }
      });

      ws.on('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });

    expect(received).toContain('qr_data');
    expect(received).toContain('status_update');
    expect(received).toContain('auth_token');

    expect(result.authToken).toBe('test-terminal-token');
    expect(result.userId).toBe('user-123');
    expect(result.expiresInDays).toBe(90);

    expect(linkSpy).toHaveBeenCalledTimes(1);

    ws.close();
    linkSpy.mockRestore();
  });
});

