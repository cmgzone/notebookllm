
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { gituWebSocketService } from '../services/gituWebSocketService.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';

// Mock dependencies
jest.mock('ws');
jest.mock('jsonwebtoken');
jest.mock('../services/gituAIRouter.js');

describe('Gitu Flutter/Web Integration Tests', () => {
  const testUserId = 'test-user-flutter-' + Date.now();
  const testToken = 'valid-jwt-token';
  let mockWss: any;
  let mockWs: any;

  beforeEach(async () => {
    jest.clearAllMocks();

    // Create test user
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash) 
       VALUES ($1, $2, $3, $4) 
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
    );

    // Mock WebSocket Server
    mockWss = {
      on: jest.fn(),
      close: jest.fn(),
    };
    (WebSocketServer as unknown as jest.Mock).mockImplementation(() => mockWss);

    // Mock WebSocket Client
    mockWs = {
      on: jest.fn(),
      send: jest.fn(),
      close: jest.fn(),
      readyState: 1, // OPEN
    };

    // Mock JWT
    (jwt.verify as jest.Mock).mockReturnValue({ userId: testUserId });

    // Mock AIRouter
    (gituAIRouter.route as any).mockImplementation(async () => ({
      content: 'Flutter response',
      model: 'gemini-2.0-flash',
      tokensUsed: 10,
      cost: 0.001,
      finishReason: 'stop',
    }));

    // Initialize service
    gituWebSocketService.initialize({});
  });

  afterEach(async () => {
    // Cleanup
    gituWebSocketService.shutdown();
    await pool.query('DELETE FROM gitu_messages WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_sessions WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
  });

  it('should handle full chat flow via WebSocket', async () => {
    // 1. Connection
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];
    await connectionHandler(mockWs, { url: `/ws/gitu-web?token=${testToken}` });

    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('"type":"connected"'));

    // 2. Client sends message
    const messageHandler = mockWs.on.mock.calls.find((call: any) => call[0] === 'message')[1];
    const clientMsg = {
      type: 'user_message',
      payload: { text: 'Hello from Flutter' },
    };
    await messageHandler(JSON.stringify(clientMsg));

    // 3. Verify Session created
    const session = await gituSessionService.getActiveSession(testUserId, 'web');
    expect(session).toBeDefined();
    expect(session!.context.conversationHistory).toHaveLength(2); // User + Assistant

    // 4. Verify AI Response sent back
    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('"type":"assistant_response"'));
    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('Flutter response'));
  });

  it('should restore previous session context', async () => {
    // Create session with history
    const session = await gituSessionService.getOrCreateSession(testUserId, 'web');
    await gituSessionService.addMessage(session.id, { role: 'user', content: 'Old message', platform: 'web' });

    // Connection
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];
    await connectionHandler(mockWs, { url: `/ws/gitu-web?token=${testToken}` });

    // Client sends message with sessionId
    const messageHandler = mockWs.on.mock.calls.find((call: any) => call[0] === 'message')[1];
    const clientMsg = {
      type: 'user_message',
      payload: { 
        text: 'New message',
        sessionId: session.id 
      },
    };
    await messageHandler(JSON.stringify(clientMsg));

    // Verify AI Router received full context
    expect(gituAIRouter.route).toHaveBeenCalledWith(expect.objectContaining({
      context: expect.arrayContaining([expect.stringContaining('Old message')]),
    }));
  });
});
