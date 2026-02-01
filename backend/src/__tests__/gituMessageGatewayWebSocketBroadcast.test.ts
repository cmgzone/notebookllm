import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import { gituMessageGateway } from '../services/gituMessageGateway.js';

describe('GituMessageGateway WebSocket broadcasting', () => {
  const userId = 'user-1';

  beforeEach(() => {
    const anyGateway: any = gituMessageGateway as any;
    anyGateway.wsClients?.clear?.();
  });

  it('broadcasts mission updates to all registered sockets', () => {
    const ws1 = { readyState: 1, send: jest.fn() };
    const ws2 = { readyState: 1, send: jest.fn() };

    gituMessageGateway.registerWebSocketClient(userId, ws1);
    gituMessageGateway.registerWebSocketClient(userId, ws2);

    gituMessageGateway.broadcastMissionUpdate(userId, 'm1', 'active');

    expect(ws1.send).toHaveBeenCalledTimes(1);
    expect(ws2.send).toHaveBeenCalledTimes(1);
  });

  it('unregisters only the specified socket', () => {
    const ws1 = { readyState: 1, send: jest.fn() };
    const ws2 = { readyState: 1, send: jest.fn() };

    gituMessageGateway.registerWebSocketClient(userId, ws1);
    gituMessageGateway.registerWebSocketClient(userId, ws2);

    gituMessageGateway.unregisterWebSocketClient(userId, ws1);
    gituMessageGateway.broadcastMissionUpdate(userId, 'm1', 'active');

    expect(ws1.send).toHaveBeenCalledTimes(0);
    expect(ws2.send).toHaveBeenCalledTimes(1);
  });
});

