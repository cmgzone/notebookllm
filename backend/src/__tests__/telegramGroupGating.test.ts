import { describe, it, expect } from '@jest/globals';

describe('Telegram group gating', () => {
  const previousMode = process.env.GITU_TELEGRAM_GROUP_MODE;

  afterEach(() => {
    if (previousMode === undefined) {
      delete process.env.GITU_TELEGRAM_GROUP_MODE;
    } else {
      process.env.GITU_TELEGRAM_GROUP_MODE = previousMode;
    }
  });

  it('is effectively addressed when mention is present', async () => {
    const { telegramAdapter } = await import('../adapters/telegramAdapter.js');
    const adapter: any = telegramAdapter as any;
    adapter.botUsername = 'MyBot';
    adapter.botUserId = '999';

    const msg: any = { chat: { type: 'supergroup' }, reply_to_message: undefined, entities: [] };
    expect(adapter.shouldProcessMessageInChat(msg, 'hello @MyBot')).toBe(true);
  });

  it('is effectively addressed when replying to the bot', async () => {
    const { telegramAdapter } = await import('../adapters/telegramAdapter.js');
    const adapter: any = telegramAdapter as any;
    adapter.botUsername = 'MyBot';
    adapter.botUserId = '999';

    const msg: any = { chat: { type: 'group' }, reply_to_message: { from: { id: 999 } }, entities: [] };
    expect(adapter.shouldProcessMessageInChat(msg, 'hello')).toBe(true);
  });

  it('ignores non-addressed group messages', async () => {
    const { telegramAdapter } = await import('../adapters/telegramAdapter.js');
    const adapter: any = telegramAdapter as any;
    adapter.botUsername = 'MyBot';
    adapter.botUserId = '999';

    const msg: any = { chat: { type: 'group' }, reply_to_message: undefined, entities: [] };
    expect(adapter.shouldProcessMessageInChat(msg, 'hello everyone')).toBe(false);
  });

  it('processes all group messages when GITU_TELEGRAM_GROUP_MODE=all', async () => {
    process.env.GITU_TELEGRAM_GROUP_MODE = 'all';

    const { telegramAdapter } = await import('../adapters/telegramAdapter.js');
    const adapter: any = telegramAdapter as any;
    adapter.botUsername = 'MyBot';
    adapter.botUserId = '999';

    const msg: any = { chat: { type: 'group' }, reply_to_message: undefined, entities: [] };
    expect(adapter.shouldProcessMessageInChat(msg, 'hello everyone')).toBe(true);
  });
});
