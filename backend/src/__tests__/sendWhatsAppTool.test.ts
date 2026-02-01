import { describe, it, expect, jest } from '@jest/globals';

const mockSendMessage = jest.fn(async () => {});

jest.unstable_mockModule('../adapters/whatsappAdapter.js', () => {
  return {
    __esModule: true,
    whatsappAdapter: {
      sendMessage: mockSendMessage,
      searchContacts: jest.fn(async () => []),
    },
  };
});

jest.unstable_mockModule('../config/database.js', () => {
  return {
    __esModule: true,
    default: {
      query: jest.fn(async () => ({ rows: [] })),
    },
  };
});

jest.unstable_mockModule('../services/mcpLimitsService.js', () => {
  return {
    __esModule: true,
    mcpLimitsService: {
      getUserUsage: jest.fn(async () => ({})),
      getUserQuota: jest.fn(async () => ({ isMcpEnabled: true, apiCallsRemaining: 999, isPremium: true })),
      incrementApiUsage: jest.fn(async () => {}),
    },
  };
});

jest.unstable_mockModule('../services/mcpUserSettingsService.js', () => {
  return {
    __esModule: true,
    mcpUserSettingsService: {},
  };
});

jest.unstable_mockModule('../services/gituAgentOrchestrator.js', () => {
  return {
    __esModule: true,
    gituAgentOrchestrator: {
      createMission: jest.fn(async () => ({ id: 'm1', status: 'created' })),
    },
  };
});

describe('send_whatsapp tool', () => {
  it('normalizes recipient phone number into a WhatsApp JID', async () => {
    const { registerMessagingTools } = await import('../services/messagingMCPTools.js');
    const { gituMCPHub } = await import('../services/gituMCPHub.js');

    registerMessagingTools();

    await gituMCPHub.executeTool(
      'send_whatsapp',
      { message: 'hello', recipient: '+1 (555) 000-1234' },
      { userId: 'u1' }
    );

    expect(mockSendMessage).toHaveBeenCalledWith(
      '15550001234@s.whatsapp.net',
      expect.objectContaining({ text: 'hello' })
    );
  });
});

