import http from 'http';
import WebSocket from 'ws';
import jwt from 'jsonwebtoken';
import { describe, it, expect, beforeAll, afterAll, jest } from '@jest/globals';

process.env.JWT_SECRET = 'test-jwt-secret';

const mockPool = {
  query: jest.fn() as any,
};

type AnyMessageHandler = (message: any) => void | Promise<void>;

const anyMessageHandlers: AnyMessageHandler[] = [];

const mockMessageGateway = {
  onAnyMessage: (handler: AnyMessageHandler) => {
    anyMessageHandlers.push(handler);
  },
  processMessage: async (raw: any) => {
    const normalized = {
      id: 'msg-1',
      userId: raw.platformUserId,
      platform: raw.platform,
      platformUserId: raw.platformUserId,
      content: { text: raw.content.text },
      timestamp: new Date(),
      metadata: raw.metadata || {},
    };

    for (const handler of anyMessageHandlers) {
      await handler(normalized);
    }

    return normalized;
  },
};

const mockSessionService = {
  getOrCreateSession: async () => ({
    id: 'session-1',
    userId: 'user-1',
    platform: 'flutter',
    status: 'active',
    context: {
      conversationHistory: [],
      activeNotebooks: [],
      activeIntegrations: [],
      variables: {},
    },
    startedAt: new Date(),
    lastActivityAt: new Date(),
  }),
  updateSession: async () => ({
    id: 'session-1',
  }),
};

const mockAIRouter = {
  route: async () => ({
    content: 'Mock assistant response',
    model: 'gemini-2.0-flash',
    tokensUsed: 10,
    cost: 0.001,
    finishReason: 'stop',
  }),
};

await jest.unstable_mockModule('../config/database.js', () => ({
  default: mockPool,
}));

await jest.unstable_mockModule('../services/gituMessageGateway.js', () => ({
  gituMessageGateway: mockMessageGateway,
}));

await jest.unstable_mockModule('../services/gituSessionService.js', () => ({
  gituSessionService: mockSessionService,
}));

await jest.unstable_mockModule('../services/gituAIRouter.js', () => ({
  gituAIRouter: mockAIRouter,
}));

const { flutterAdapter } = await import('../adapters/flutterAdapter.js');

describe('FlutterAdapter WebSocket', () => {
  let server: http.Server;
  let port: number;

  beforeAll(async () => {
    mockPool.query.mockReset();
    mockPool.query.mockImplementation(async (sql: any) => {
      const queryText = typeof sql === 'string' ? sql : sql?.text || '';
      if (queryText.includes('SELECT email, display_name FROM users')) {
        return { rows: [{ email: 'user-1@example.com', display_name: 'User One' }] };
      }
      if (queryText.includes('INSERT INTO gitu_linked_accounts')) {
        return { rows: [] };
      }
      return { rows: [] };
    });

    server = http.createServer();
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('failed to bind server');
    port = address.port;

    flutterAdapter.initialize(server);

    expect(server.listenerCount('upgrade')).toBeGreaterThan(0);
  });

  afterAll(async () => {
    flutterAdapter.shutdown();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  });

  it('accepts authenticated connection and returns assistant response', async () => {
    const token = jwt.sign({ userId: 'user-1', email: 'user-1@example.com' }, process.env.JWT_SECRET!, {
      expiresIn: '1h',
    });

    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws/gitu?token=${encodeURIComponent(token)}`, {
      handshakeTimeout: 2000,
    } as any);
    const events: any[] = [];

    const completed = await new Promise<boolean>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error(`timeout; events=${JSON.stringify(events)}`)), 8000);

      ws.on('open', () => {
        events.push({ type: 'ws_open' });
      });

      ws.on('message', (data) => {
        const msg = JSON.parse(data.toString());
        events.push(msg);

        if (msg.type === 'connected') {
          ws.send(JSON.stringify({ type: 'user_message', payload: { text: 'Hello' } }));
        }

        if (msg.type === 'assistant_response') {
          clearTimeout(timeout);
          resolve(true);
        }
      });

      ws.on('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });

      ws.on('unexpected-response', (_req, res) => {
        clearTimeout(timeout);
        reject(new Error(`unexpected-response: ${res.statusCode}`));
      });

      ws.on('close', (code, reason) => {
        clearTimeout(timeout);
        reject(new Error(`closed: ${code} ${reason.toString()}`));
      });
    });

    expect(completed).toBe(true);
    expect(events.some(e => e.type === 'connected')).toBe(true);
    expect(events.some(e => e.type === 'incoming_message')).toBe(true);
    const response = events.find(e => e.type === 'assistant_response');
    expect(response.payload.content).toBe('Mock assistant response');

    ws.close();
  });
});
