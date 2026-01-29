import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { gituWebSocketService } from '../services/gituWebSocketService.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { gituMessageGateway } from '../services/gituMessageGateway.js';
import pool from '../config/database.js';
import jwt from 'jsonwebtoken';
import { WebSocketServer } from 'ws';

// Mock dependencies
jest.mock('../config/database.js');
jest.mock('../services/gituSessionService.js');
jest.mock('../services/gituAIRouter.js');
jest.mock('../services/gituMessageGateway.js');
jest.mock('ws');
jest.mock('jsonwebtoken');

describe('GituWebSocketService', () => {
  let mockWss: any;
  let mockWs: any;
  const mockUserId = 'user-123';
  const mockToken = 'valid-token';

  beforeEach(() => {
    jest.clearAllMocks();

    // Mock WebSocketServer instance
    mockWss = {
      on: jest.fn(),
      close: jest.fn(),
    };
    (WebSocketServer as any).mockImplementation(() => mockWss);

    // Mock WebSocket instance
    mockWs = {
      on: jest.fn(),
      send: jest.fn(),
      close: jest.fn(),
      readyState: 1, // OPEN
    };

    // Mock JWT verification
    (jwt.verify as jest.Mock).mockReturnValue({ userId: mockUserId });

    // Mock pool query for user check
    (pool.query as any).mockResolvedValue({
      rows: [{ display_name: 'Test User' }]
    });
  });

  it('should initialize WebSocket server', () => {
    gituWebSocketService.initialize({});
    expect(WebSocketServer).toHaveBeenCalledWith(expect.objectContaining({ path: '/ws/gitu-web' }));
  });

  it('should handle connection and authentication', async () => {
    gituWebSocketService.initialize({});
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];

    const mockReq = { url: `/ws/gitu-web?token=${mockToken}` };
    await connectionHandler(mockWs, mockReq);

    expect(jwt.verify).toHaveBeenCalled();
    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('"type":"connected"'));
  });

  it('should reject connection with invalid token', async () => {
    (jwt.verify as jest.Mock).mockImplementation(() => { throw new Error('Invalid token'); });
    gituWebSocketService.initialize({});
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];

    const mockReq = { url: `/ws/gitu-web?token=invalid` };
    await connectionHandler(mockWs, mockReq);

    expect(mockWs.close).toHaveBeenCalledWith(4002, 'Invalid token');
  });

  it('should handle user message and send response', async () => {
    gituWebSocketService.initialize({});
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];
    await connectionHandler(mockWs, { url: `/ws/gitu-web?token=${mockToken}` });

    const messageHandler = mockWs.on.mock.calls.find((call: any) => call[0] === 'message')[1];

    // Mock services
    (gituMessageGateway.processMessage as any).mockResolvedValue({
        content: { text: 'Hello' },
        userId: mockUserId
    });
    const mockSession = { id: 'session-123', userId: mockUserId, context: { conversationHistory: [] } };
    (gituSessionService.getOrCreateSession as any).mockResolvedValue(mockSession);
    (gituSessionService.getSession as any).mockResolvedValue(mockSession);
    (gituAIRouter.route as any).mockImplementation(async () => ({
      content: 'Hello human',
      model: 'test-model',
      tokensUsed: 10,
      cost: 0.001
    }));

    // Simulate user message
    const message = {
      type: 'user_message',
      payload: { text: 'Hello' }
    };
    await messageHandler(JSON.stringify(message));

    expect(gituMessageGateway.processMessage).toHaveBeenCalled();
    expect(gituSessionService.addMessage).toHaveBeenCalledTimes(2); // User + Assistant
    expect(gituAIRouter.route).toHaveBeenCalled();
    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('"type":"assistant_response"'));
  });
});
