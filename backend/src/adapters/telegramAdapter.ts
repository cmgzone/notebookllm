/**
 * Telegram Bot Adapter for Gitu
 * Handles Telegram Bot API integration for the Gitu universal AI assistant.
 * 
 * Requirements: US-1 (Multi-Platform Access), US-1.1 (Telegram Integration)
 * Design: Section 1 (Message Gateway - Telegram Adapter)
 */

import TelegramBot from 'node-telegram-bot-api';
import { gituMessageGateway, IncomingMessage, RawMessage } from '../services/gituMessageGateway.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

/**
 * Telegram message format
 */
export interface TelegramMessage {
  text?: string;
  markdown?: string;
  photo?: Buffer;
  document?: { data: Buffer; filename: string };
  replyMarkup?: TelegramBot.InlineKeyboardMarkup;
}

/**
 * Bot command definition
 */
export interface BotCommand {
  command: string;
  description: string;
}

/**
 * Telegram adapter configuration
 */
export interface TelegramAdapterConfig {
  botToken: string;
  webhookUrl?: string;
  polling?: boolean;
}

// ==================== ADAPTER CLASS ====================

class TelegramAdapter {
  private bot: TelegramBot | null = null;
  private initialized: boolean = false;
  private config: TelegramAdapterConfig | null = null;

  /**
   * Initialize the Telegram Bot API.
   * 
   * @param botToken - The Telegram bot token from BotFather
   * @param options - Optional configuration (webhook or polling)
   */
  async initialize(botToken: string, options?: { webhookUrl?: string; polling?: boolean }): Promise<void> {
    if (this.initialized) {
      console.log('Telegram adapter already initialized');
      return;
    }

    this.config = {
      botToken,
      webhookUrl: options?.webhookUrl,
      polling: options?.polling !== false, // Default to polling
    };

    // Create bot instance
    if (this.config.webhookUrl) {
      // Webhook mode (for production)
      this.bot = new TelegramBot(botToken, { webHook: true });
      await this.bot.setWebHook(this.config.webhookUrl);
      console.log(`Telegram bot initialized with webhook: ${this.config.webhookUrl}`);
    } else {
      // Polling mode (for development)
      this.bot = new TelegramBot(botToken, { polling: this.config.polling });
      console.log('Telegram bot initialized with polling');
    }

    // Set up message handlers
    this.setupMessageHandlers();

    // Set up command handlers
    this.setupCommandHandlers();

    this.initialized = true;
    console.log('Telegram adapter initialized successfully');
  }

  /**
   * Set up message handlers to receive and process incoming messages.
   */
  private setupMessageHandlers(): void {
    if (!this.bot) {
      throw new Error('Bot not initialized');
    }

    // Handle text messages
    this.bot.on('message', async (msg) => {
      try {
        console.log(`📨 Received message from Telegram chat ID: ${msg.chat.id}`);
        await this.handleIncomingMessage(msg);
      } catch (error) {
        console.error('Error handling Telegram message:', error);
        console.error(`❌ Error occurred for chat ID: ${msg.chat.id}`);
        console.error(`💡 To link this account, run: npx tsx src/scripts/link-telegram-test-account.ts ${msg.chat.id}`);
        await this.sendErrorMessage(
          msg.chat.id,
          `Telegram not linked.\n\nYour Chat ID: ${msg.chat.id}\n\nIn NotebookLLM, open Gitu → Linked Accounts and link Telegram with this Chat ID, then send /start again.`
        );
      }
    });

    // Handle callback queries (inline button presses)
    this.bot.on('callback_query', async (query) => {
      try {
        await this.handleCallbackQuery(query);
      } catch (error) {
        console.error('Error handling callback query:', error);
      }
    });

    // Handle errors
    this.bot.on('polling_error', (error) => {
      console.error('Telegram polling error:', error);
    });

    this.bot.on('webhook_error', (error) => {
      console.error('Telegram webhook error:', error);
    });
  }

  /**
   * Set up command handlers for bot commands.
   */
  private setupCommandHandlers(): void {
    if (!this.bot) {
      throw new Error('Bot not initialized');
    }

    // /start command
    this.bot.onText(/\/start/, async (msg) => {
      const chatId = msg.chat.id;
      const welcomeMessage = `
🤖 *Welcome to Gitu!*

I'm your universal AI assistant. I can help you with:
• 📚 Access your NotebookLLM notebooks
• 📧 Manage your Gmail
• 🛍️ Check your Shopify store
• 💻 Execute tasks and commands
• 🔍 Research and answer questions

To get started, make sure you've linked your Telegram account in the NotebookLLM app.

Use /help to see available commands.
      `.trim();

      await this.sendMessage(chatId.toString(), {
        markdown: welcomeMessage,
      });
    });

    // /help command
    this.bot.onText(/\/help/, async (msg) => {
      const chatId = msg.chat.id;
      const helpMessage = `
📖 *Available Commands:*

/start - Start the bot
/id - Show your Telegram Chat ID (for linking)
/help - Show this help message
/status - Check your Gitu status
/notebooks - List your notebooks
/session - View current session info
/clear - Clear conversation history
/settings - View your settings

You can also just chat with me naturally! I'll understand your requests and help you accomplish tasks.
      `.trim();

      await this.sendMessage(chatId.toString(), {
        markdown: helpMessage,
      });
    });

    this.bot.onText(/\/id/, async (msg) => {
      const chatId = msg.chat.id.toString();
      const text = `Your Chat ID: ${chatId}\n\nIn NotebookLLM → Gitu → Linked Accounts, link Telegram with this Chat ID.`;
      await this.sendMessage(chatId, { text });
    });

    // /status command
    this.bot.onText(/\/status/, async (msg) => {
      const chatId = msg.chat.id;
      try {
        const userId = await this.getUserIdFromChatId(chatId.toString());
        const session = await gituSessionService.getActiveSession(userId, 'telegram');
        
        if (session) {
          const stats = await gituSessionService.getSessionStats(userId);
          const statusMessage = `
✅ *Gitu Status*

🟢 Active Session
📊 Total Messages: ${stats.messageCount}
📱 Active Sessions: ${stats.activeSessions}
📚 Active Notebooks: ${session.context.activeNotebooks.length}
🔌 Active Integrations: ${session.context.activeIntegrations.length}

Last Activity: ${session.lastActivityAt.toLocaleString()}
          `.trim();

          await this.sendMessage(chatId.toString(), {
            markdown: statusMessage,
          });
        } else {
          await this.sendMessage(chatId.toString(), {
            text: '❌ No active session. Send me a message to start!',
          });
        }
      } catch (error) {
        await this.sendMessage(chatId.toString(), {
          text: '❌ You need to link your Telegram account in the NotebookLLM app first.',
        });
      }
    });

    // /clear command
    this.bot.onText(/\/clear/, async (msg) => {
      const chatId = msg.chat.id;
      try {
        const userId = await this.getUserIdFromChatId(chatId.toString());
        const session = await gituSessionService.getActiveSession(userId, 'telegram');
        
        if (session) {
          // Clear conversation history
          session.context.conversationHistory = [];
          await gituSessionService.updateSession(session.id, { context: session.context });
          
          await this.sendMessage(chatId.toString(), {
            text: '✅ Conversation history cleared!',
          });
        }
      } catch (error) {
        await this.sendMessage(chatId.toString(), {
          text: '❌ Error clearing conversation history.',
        });
      }
    });
  }

  /**
   * Handle incoming Telegram message.
   */
  private async handleIncomingMessage(msg: TelegramBot.Message): Promise<void> {
    const chatId = msg.chat.id.toString();
    
    // Skip if it's a command (already handled by command handlers)
    if (msg.text && msg.text.startsWith('/')) {
      return;
    }

    // Build raw message
    const rawMessage: RawMessage = {
      platform: 'telegram',
      platformUserId: chatId,
      content: msg,
      timestamp: new Date(msg.date * 1000),
      metadata: {
        messageId: msg.message_id,
        chatType: msg.chat.type,
        from: msg.from,
      },
    };

    // Process through message gateway
    const normalizedMessage = await gituMessageGateway.processMessage(rawMessage);

    // Send typing indicator
    await this.sendChatAction(chatId, 'typing');

    const session = await gituSessionService.getOrCreateSession(normalizedMessage.userId, 'telegram');
    const userText = normalizedMessage.content.text || '[attachment]';

    session.context.conversationHistory.push({
      role: 'user',
      content: userText,
      timestamp: new Date(),
      platform: 'telegram',
    });

    const context = session.context.conversationHistory
      .slice(-21, -1)
      .map(m => `${m.role}: ${m.content}`);

    const aiResponse = await gituAIRouter.route({
      userId: normalizedMessage.userId,
      sessionId: session.id,
      prompt: userText,
      context,
      taskType: 'chat',
    });

    session.context.conversationHistory.push({
      role: 'assistant',
      content: aiResponse.content,
      timestamp: new Date(),
      platform: 'telegram',
    });

    await gituSessionService.updateSession(session.id, { context: session.context });

    const parts = this.splitMessageText(aiResponse.content);
    for (const part of parts) {
      await this.sendMessage(chatId, { text: part });
    }
  }

  /**
   * Handle callback query (inline button press).
   */
  private async handleCallbackQuery(query: TelegramBot.CallbackQuery): Promise<void> {
    if (!this.bot) return;

    const chatId = query.message?.chat.id.toString();
    const data = query.data;

    // Answer the callback query to remove loading state
    await this.bot.answerCallbackQuery(query.id);

    // Handle different callback actions
    if (data && chatId) {
      // TODO: Implement callback handling based on data
      await this.sendMessage(chatId, {
        text: `Button pressed: ${data}`,
      });
    }
  }

  /**
   * Send a message to a Telegram chat.
   * 
   * @param chatId - The Telegram chat ID
   * @param message - The message to send
   */
  async sendMessage(chatId: string, message: TelegramMessage): Promise<void> {
    if (!this.bot) {
      throw new Error('Bot not initialized');
    }

    try {
      // Send text message
      if (message.text) {
        await this.bot.sendMessage(chatId, message.text, {
          reply_markup: message.replyMarkup,
        });
      }

      // Send markdown message
      if (message.markdown) {
        await this.bot.sendMessage(chatId, message.markdown, {
          parse_mode: 'Markdown',
          reply_markup: message.replyMarkup,
        });
      }

      // Send photo
      if (message.photo) {
        await this.bot.sendPhoto(chatId, message.photo, {
          reply_markup: message.replyMarkup,
        });
      }

      // Send document
      if (message.document) {
        await this.bot.sendDocument(chatId, message.document.data, {
          reply_markup: message.replyMarkup,
        }, {
          filename: message.document.filename,
        });
      }
    } catch (error) {
      console.error('Error sending Telegram message:', error);
      throw error;
    }
  }

  private splitMessageText(text: string, maxLength: number = 4000): string[] {
    const normalized = (text || '').trim();
    if (!normalized) return [''];
    if (normalized.length <= maxLength) return [normalized];

    const parts: string[] = [];
    let remaining = normalized;
    while (remaining.length > maxLength) {
      const slice = remaining.slice(0, maxLength);
      let splitAt = slice.lastIndexOf('\n\n');
      if (splitAt < 0) splitAt = slice.lastIndexOf('\n');
      if (splitAt < 0) splitAt = slice.lastIndexOf(' ');
      if (splitAt < 0) splitAt = maxLength;

      const chunk = remaining.slice(0, splitAt).trim();
      if (chunk) parts.push(chunk);
      remaining = remaining.slice(splitAt).trim();
    }
    if (remaining) parts.push(remaining);
    return parts;
  }

  /**
   * Send a chat action (typing, uploading, etc.).
   * 
   * @param chatId - The Telegram chat ID
   * @param action - The action to send
   */
  async sendChatAction(chatId: string, action: TelegramBot.ChatAction): Promise<void> {
    if (!this.bot) {
      throw new Error('Bot not initialized');
    }

    try {
      await this.bot.sendChatAction(chatId, action);
    } catch (error) {
      console.error('Error sending chat action:', error);
    }
  }

  /**
   * Send an error message to the user.
   * 
   * @param chatId - The Telegram chat ID
   * @param errorMessage - The error message to send
   */
  private async sendErrorMessage(chatId: number, errorMessage: string): Promise<void> {
    if (!this.bot) return;

    try {
      await this.bot.sendMessage(chatId, `❌ ${errorMessage}`);
    } catch (error) {
      console.error('Error sending error message:', error);
    }
  }

  /**
   * Set bot commands (shown in Telegram UI).
   * 
   * @param commands - Array of bot commands
   */
  async setCommands(commands: BotCommand[]): Promise<void> {
    if (!this.bot) {
      throw new Error('Bot not initialized');
    }

    try {
      await this.bot.setMyCommands(commands);
      console.log('Bot commands set successfully');
    } catch (error) {
      console.error('Error setting bot commands:', error);
      throw error;
    }
  }

  /**
   * Get user ID from Telegram chat ID.
   * Looks up the linked account in the database.
   * 
   * @param chatId - The Telegram chat ID
   * @returns The NotebookLLM user ID
   */
  private async getUserIdFromChatId(chatId: string): Promise<string> {
    const result = await pool.query(
      `SELECT user_id FROM gitu_linked_accounts 
       WHERE platform = 'telegram' AND platform_user_id = $1 AND status = 'active'`,
      [chatId]
    );

    if (result.rows.length === 0) {
      throw new Error('Telegram account not linked. Please link your account in the NotebookLLM app.');
    }

    return result.rows[0].user_id;
  }

  /**
   * Register a message handler.
   * 
   * @param handler - The handler function
   */
  onMessage(handler: (message: IncomingMessage) => void | Promise<void>): void {
    gituMessageGateway.onMessage('telegram', handler);
  }

  /**
   * Disconnect the bot.
   */
  async disconnect(): Promise<void> {
    if (this.bot) {
      await this.bot.stopPolling();
      this.bot = null;
      this.initialized = false;
      console.log('Telegram bot disconnected');
    }
  }

  /**
   * Get connection state.
   */
  getConnectionState(): 'connected' | 'disconnected' | 'error' {
    if (!this.bot || !this.initialized) {
      return 'disconnected';
    }
    return 'connected';
  }

  /**
   * Get bot info.
   */
  async getBotInfo(): Promise<TelegramBot.User | null> {
    if (!this.bot) {
      return null;
    }

    try {
      return await this.bot.getMe();
    } catch (error) {
      console.error('Error getting bot info:', error);
      return null;
    }
  }
}

// Export singleton instance
export const telegramAdapter = new TelegramAdapter();
export default telegramAdapter;
