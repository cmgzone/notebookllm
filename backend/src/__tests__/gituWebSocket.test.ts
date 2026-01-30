import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { gituWebSocketService } from '../services/gituWebSocketService.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { gituMessageGateway } from '../services/gituMessageGateway.js';
import pool from '../config/database.js';
import { WebSocketServer } from 'ws';

describe('GituWebSocketService', () => {
  let mockWss: any;
  let mockWs: any;
  let MockWebSocketServer: any;
  const mockUserId = 'user-123';
  const mockToken = 'valid-token';

  beforeEach(() => {
    jest.clearAllMocks();

    // Mock WebSocketServer instance
    mockWss = {
      on: jest.fn(),
      close: jest.fn(),
      clients: new Set(),
    };

    // Mock WebSocketServer constructor
    MockWebSocketServer = jest.fn(() => mockWss);
    
    // Inject mock constructor
    gituWebSocketService.setWebSocketServerConstructor(MockWebSocketServer);

    // Mock WebSocket instance
    mockWs = {
      on: jest.fn(),
      send: jest.fn(),
      close: jest.fn(),
      readyState: 1, // OPEN
    };
    
    // Mock verifyJwt (private method)
    jest.spyOn(gituWebSocketService as any, 'verifyJwt').mockReturnValue(mockUserId);

    // Mock dependencies via spyOn
    jest.spyOn(pool, 'query').mockResolvedValue({
      rows: [{ display_name: 'Test User' }],
      rowCount: 1,
      command: 'SELECT',
      oid: 0,
      fields: []
    });

    jest.spyOn(gituMessageGateway, 'processMessage');
    jest.spyOn(gituSessionService, 'getOrCreateSession');
    jest.spyOn(gituSessionService, 'getSession');
    jest.spyOn(gituSessionService, 'addMessage');
    jest.spyOn(gituAIRouter, 'route');
  });

  afterEach(() => {
    gituWebSocketService.shutdown();
    jest.restoreAllMocks();
  });

  it('should initialize WebSocket server', () => {
    gituWebSocketService.initialize({});
    expect(MockWebSocketServer).toHaveBeenCalledWith(expect.objectContaining({ path: '/ws/gitu-web' }));
  });

  it('should handle connection and authentication', async () => {
    gituWebSocketService.initialize({});
    const connectionHandler = mockWss.on.mock.calls.find((call: any) => call[0] === 'connection')[1];

    const mockReq = { url: `/ws/gitu-web?token=${mockToken}` };
    await connectionHandler(mockWs, mockReq);

    // expect(jwt.verify).toHaveBeenCalled(); // verifyJwt is spied on, which calls jwt.verify internally, but we mocked verifyJwt result directly.
    // So jwt.verify won't be called if we mock verifyJwt to return value directly!
    // But wait, I used spyOn().mockReturnValue(). So real implementation is NOT called.
    // So jwt.verify is NOT called.
    expect((gituWebSocketService as any).verifyJwt).toHaveBeenCalledWith(mockToken);
    expect(mockWs.send).toHaveBeenCalledWith(expect.stringContaining('"type":"connected"'));
  });

  it('should reject connection with invalid token', async () => {
    // (jwt.verify as jest.Mock).mockImplementation(() => { throw new Error('Invalid token'); });
    // Make verifyJwt return null to simulate failure
    (gituWebSocketService as any).verifyJwt.mockReturnValue(null);
    
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
    (gituSessionService.addMessage as any).mockResolvedValue(undefined); // Mock addMessage to avoid DB errors
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
