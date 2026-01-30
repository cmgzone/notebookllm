
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { randomUUID } from 'crypto';
import pool from '../config/database.js';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { gituPermissionManager } from '../services/gituPermissionManager.js';

// Mock dependencies
jest.mock('node-telegram-bot-api');

describe('Gitu Telegram Integration Tests', () => {
  const testUserId = randomUUID();
  const testChatId = '123456789';
  let mockBot: any;

  beforeEach(async () => {
    // Reset mocks
    jest.clearAllMocks();

    // Create test user and link account
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash) 
       VALUES ($1, $2, $3, $4) 
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
    );

    await pool.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, status)
       VALUES ($1, 'telegram', $2, 'active')
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           status = 'active',
           last_used_at = NOW()`,
      [testUserId, testChatId]
    );

    // Mock TelegramBot instance
    mockBot = {
      on: jest.fn(),
      onText: jest.fn(),
      sendMessage: (jest.fn() as any).mockResolvedValue({}),
      sendChatAction: (jest.fn() as any).mockResolvedValue({}),
      setWebHook: (jest.fn() as any).mockResolvedValue({}),
      stopPolling: (jest.fn() as any).mockResolvedValue({}),
      getMe: (jest.fn() as any).mockResolvedValue({ id: 999, username: 'test_bot' }),
    };

    // Inject mock bot into adapter
    (telegramAdapter as any).bot = mockBot;
    (telegramAdapter as any).initialized = true;
    (telegramAdapter as any).setupMessageHandlers(); // Re-attach handlers to mock bot
  });

  afterEach(async () => {
    jest.restoreAllMocks();
    // Clean up
    await pool.query('DELETE FROM gitu_messages WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_sessions WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM notebooks WHERE user_id::text = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
  });

  it('should process incoming message and send AI response', async () => {
    // Mock AI response
    jest.spyOn(gituAIRouter, 'route').mockResolvedValue({
      content: 'Hello from AI!',
      model: 'gemini-2.0-flash',
      tokensUsed: 10,
      cost: 0.001,
      finishReason: 'stop',
    } as any);

    // Simulate incoming message
    const messageHandler = mockBot.on.mock.calls.find((call: any) => call[0] === 'message')[1];
    
    const incomingMsg = {
      message_id: 1,
      chat: { id: parseInt(testChatId), type: 'private' },
      from: { id: parseInt(testChatId), first_name: 'Test', last_name: 'User' },
      date: Math.floor(Date.now() / 1000),
      text: 'Hello Gitu',
    };

    // Execute handler
    await messageHandler(incomingMsg);

    // Verify AI Router called
    expect(gituAIRouter.route).toHaveBeenCalledWith(expect.objectContaining({
      userId: testUserId,
      prompt: 'Hello Gitu',
      taskType: 'chat',
    }));

    // Verify response sent to Telegram
    expect(mockBot.sendMessage).toHaveBeenCalledWith(
      testChatId,
      'Hello from AI!',
      expect.any(Object)
    );
  });

  it('should handle unlinked account gracefully', async () => {
    // Use unlinked chat ID
    const unlinkedChatId = '999999999';
    
    const messageHandler = mockBot.on.mock.calls.find((call: any) => call[0] === 'message')[1];
    
    const incomingMsg = {
      message_id: 2,
      chat: { id: parseInt(unlinkedChatId), type: 'private' },
      from: { id: parseInt(unlinkedChatId), first_name: 'Unknown', last_name: 'User' },
      date: Math.floor(Date.now() / 1000),
      text: 'Hello',
    };

    await messageHandler(incomingMsg);

    // Should send error/link message
    expect(mockBot.sendMessage).toHaveBeenCalledWith(
      parseInt(unlinkedChatId),
      expect.stringContaining('Telegram not linked')
    );
  });

  it('should handle /status command', async () => {
    // Need to setup command handlers manually since we mocked initialize
    (telegramAdapter as any).setupCommandHandlers();
    
    const statusHandler = mockBot.onText.mock.calls.find((call: any) => call[0].toString() === '/\\/status/')[1];
    
    const incomingMsg = {
      message_id: 3,
      chat: { id: parseInt(testChatId), type: 'private' },
      from: { id: parseInt(testChatId), first_name: 'Test', last_name: 'User' },
      date: Math.floor(Date.now() / 1000),
      text: '/status',
    };

    // Ensure session exists
    await gituSessionService.getOrCreateSession(testUserId, 'universal');

    await statusHandler(incomingMsg);

    expect(mockBot.sendMessage).toHaveBeenCalledWith(
      testChatId,
      expect.stringContaining('Gitu Status'),
      expect.objectContaining({ parse_mode: 'Markdown' })
    );
  });

  it('should handle /notebooks command when permitted', async () => {
    jest.spyOn(gituPermissionManager, 'checkPermission').mockResolvedValue(true as any);

    await pool.query(
      `UPDATE gitu_linked_accounts SET verified = true WHERE user_id = $1 AND platform = 'telegram' AND platform_user_id = $2`,
      [testUserId, testChatId]
    );

    await pool.query(
      `INSERT INTO notebooks (id, user_id, title, created_at, updated_at)
       VALUES (gen_random_uuid(), $1, 'First Notebook', NOW(), NOW()),
              (gen_random_uuid(), $1, 'Second Notebook', NOW(), NOW())`,
      [testUserId]
    );

    (telegramAdapter as any).setupCommandHandlers();

    const notebooksHandler = mockBot.onText.mock.calls.find((call: any) => call[0].toString() === '/\\/notebooks/')[1];

    const incomingMsg = {
      message_id: 4,
      chat: { id: parseInt(testChatId), type: 'private' },
      from: { id: parseInt(testChatId), first_name: 'Test', last_name: 'User' },
      date: Math.floor(Date.now() / 1000),
      text: '/notebooks',
    };

    await notebooksHandler(incomingMsg);

    expect(mockBot.sendMessage).toHaveBeenCalledWith(
      testChatId,
      expect.stringContaining('Your notebooks'),
      expect.any(Object)
    );
  });
});
