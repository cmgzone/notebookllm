import { jest } from '@jest/globals';
import { whatsappHealthMonitor } from '../services/whatsappHealthMonitor.js';

jest.mock('../adapters/whatsappAdapter.js', () => {
  return {
    whatsappAdapter: {
      getConnectionState: jest.fn(),
      reconnect: (jest.fn() as any).mockResolvedValue(null),
    },
  };
});

jest.mock('../services/notificationService.js', () => {
  return {
    notificationService: {
      sendBroadcastNotification: (jest.fn() as any).mockResolvedValue({ sent: 0, failed: 0 } as any),
    },
  };
});

import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import { notificationService } from '../services/notificationService.js';

describe('WhatsAppHealthMonitor', () => {
  beforeEach(() => {
    (notificationService as any).sendBroadcastNotification = (jest.fn() as any).mockResolvedValue({ sent: 0, failed: 0 } as any);
  });
  afterEach(async () => {
    (whatsappAdapter as any).getConnectionState = jest.fn().mockReturnValue('connected');
    await whatsappHealthMonitor.checkNow();
    jest.clearAllMocks();
  });

  test('attempts reconnect when disconnected and below failure threshold', async () => {
    (whatsappAdapter as any).getConnectionState = jest.fn().mockReturnValue('disconnected');
    (whatsappAdapter as any).reconnect = (jest.fn() as any).mockResolvedValue(undefined as any);
    await whatsappHealthMonitor.checkNow();
    expect(whatsappAdapter.reconnect).toHaveBeenCalledTimes(1);
    expect(notificationService.sendBroadcastNotification).not.toHaveBeenCalled();
  });

  test('sends outage notification after exceeding failure threshold', async () => {
    (whatsappAdapter as any).getConnectionState = jest.fn().mockReturnValue('disconnected');
    await whatsappHealthMonitor.checkNow();
    await whatsappHealthMonitor.checkNow();
    await whatsappHealthMonitor.checkNow();
    await whatsappHealthMonitor.checkNow();
    expect(notificationService.sendBroadcastNotification).toHaveBeenCalledTimes(1);
  });
});
