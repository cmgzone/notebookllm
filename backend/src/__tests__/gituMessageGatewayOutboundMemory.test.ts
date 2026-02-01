import { describe, it, expect, jest, beforeEach, beforeAll } from '@jest/globals';

const mockDbPool = {
  query: jest.fn<(...args: any[]) => Promise<any>>(),
  connect: jest.fn(),
  on: jest.fn(),
};

const mockExtractFromConversation = jest.fn<() => Promise<void>>().mockResolvedValue(undefined);

jest.unstable_mockModule('../config/database.js', () => {
  return {
    __esModule: true,
    default: mockDbPool,
  };
});

jest.unstable_mockModule('../services/gituMemoryExtractor.js', () => {
  return {
    __esModule: true,
    gituMemoryExtractor: {
      extractFromConversation: mockExtractFromConversation,
    },
  };
});

let gituMessageGateway: any;

beforeAll(async () => {
  ({ gituMessageGateway } = await import('../services/gituMessageGateway.js'));
});

describe('GituMessageGateway outbound memory hook', () => {
  beforeEach(() => {
    mockDbPool.query.mockReset();
    mockExtractFromConversation.mockClear();
  });

  it('uses provided userMessageText when tracking outbound message', async () => {
    mockDbPool.query.mockResolvedValueOnce({ rows: [] });

    await gituMessageGateway.trackOutboundMessage('user-1', 'telegram', 'assistant reply', {
      sessionId: 'session-1',
      userMessageText: 'hello',
    });

    expect(mockExtractFromConversation).toHaveBeenCalledTimes(1);
    expect(mockExtractFromConversation).toHaveBeenCalledWith('user-1', 'hello', 'assistant reply', {
      platform: 'telegram',
      sessionId: 'session-1',
    });
  });
});
