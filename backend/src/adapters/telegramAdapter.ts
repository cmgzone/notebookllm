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
import { gituPermissionManager } from '../services/gituPermissionManager.js';
import { gituAgentManager } from '../services/gituAgentManager.js';
import { gituAgentOrchestrator } from '../services/gituAgentOrchestrator.js';
import { gituMissionControl } from '../services/gituMissionControl.js';
import { gituToolExecutionService } from '../services/gituToolExecutionService.js';
import { mcpUserSettingsService } from '../services/mcpUserSettingsService.js';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

/**
 * Telegram message format
 */
export interface TelegramMessage {
  text?: string;
  markdown?: string;
  caption?: string; // Caption for photo/document
  photo?: Buffer;
  document?: { data: Buffer; filename: string };
  audio?: { url: string } | Buffer | string;
  data?: Buffer;
  filename?: string;
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
  private botUserId: string | null = null;
  private botUsername: string | null = null;

  private getGroupMode(): 'mentions' | 'all' {
    const raw = (process.env.GITU_TELEGRAM_GROUP_MODE || '').trim().toLowerCase();
    if (raw === 'all' || raw === 'everyone') return 'all';
    return 'mentions';
  }

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

    // Register outbound handler
    gituMessageGateway.registerOutboundHandler('telegram', async (chatId, text) => {
      if (this.bot) {
        await this.sendMessage(chatId, { text });
      }
    });

    this.initialized = true;
    console.log('Telegram adapter initialized successfully');

    try {
      const me = await this.bot.getMe();
      this.botUserId = String(me.id);
      this.botUsername = typeof me.username === 'string' ? me.username : null;
      console.log(`[Telegram] Bot info: id=${this.botUserId}, username=${this.botUsername ?? 'N/A'}`);
    } catch (error) {
      console.error('[Telegram] Failed to load bot info:', error);
    }
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
      const rawText = typeof msg.text === 'string' ? msg.text.trim() : '';
      if (rawText.startsWith('/')) {
        return;
      }
      if (!this.shouldProcessMessageInChat(msg, rawText)) {
        return;
      }
      const platformUserId = msg.from?.id ? msg.from.id.toString() : msg.chat.id.toString();
      try {
        console.log(`📨 Received message from Telegram chat ID: ${msg.chat.id}`);
        await this.handleIncomingMessage(msg);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.error('Error handling Telegram message:', error);
        console.error(`❌ Error occurred for chat ID: ${msg.chat.id}`);
        if (
          errorMessage.includes('not linked') ||
          errorMessage.includes('Platform account not linked')
        ) {
          console.error(`💡 To link this account, run: npx tsx src/scripts/link-telegram-test-account.ts ${platformUserId}`);
          await this.sendErrorMessage(
            msg.chat.id,
            `Telegram not linked.\n\nYour Telegram User ID: ${platformUserId}\nYour Chat ID: ${msg.chat.id}\n\nIn NotebookLLM, open Gitu → Linked Accounts and link Telegram with your Telegram User ID, then send /start again.`
          );
          return;
        }

        await this.sendErrorMessage(
          msg.chat.id,
          `Temporary server error.\n\nPlease try again in a moment.`
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
/id - Show your Telegram User ID (for linking)
/help - Show this help message
/status - Check your Gitu status
/notebooks - List your notebooks
/session - View current session info
/clear - Clear conversation history
/clear - Clear conversation history
/settings - View your settings
/swarm <task> - Deploy an intelligent agent swarm
/agent spawn <task> - Spawn a single background agent
/gitu <message> - Ask Gitu in groups (recommended)

You can also just chat with me naturally! I'll understand your requests and help you accomplish tasks.
      `.trim();

      await this.sendMessage(chatId.toString(), {
        markdown: helpMessage,
      });
    });

    this.bot.onText(/\/id/, async (msg) => {
      const chatId = msg.chat.id.toString();
      const userId = msg.from?.id ? msg.from.id.toString() : chatId;
      const text = `Your Telegram User ID: ${userId}\nYour Chat ID: ${chatId}\n\nIn NotebookLLM → Gitu → Linked Accounts, link Telegram with your Telegram User ID.`;
      await this.sendMessage(chatId, { text });
    });

    // /status command
    this.bot.onText(/\/status/, async (msg) => {
      const chatId = msg.chat.id;
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId.toString();
        const userId = await this.getUserIdFromChatId(platformUserId);
        const session = await gituSessionService.getActiveSession(userId, 'universal');

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
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (errorMessage.includes('not linked') || errorMessage.includes('Platform account not linked')) {
          await this.sendMessage(chatId.toString(), {
            text: '❌ You need to link your Telegram account in the NotebookLLM app first. If linked, run /verify.',
          });
          return;
        }
        await this.sendMessage(chatId.toString(), {
          text: 'Temporary server error.\n\nPlease try again in a moment.',
        });
      }
    });

    this.bot.onText(/\/notebooks/, async (msg) => {
      const chatId = msg.chat.id.toString();
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId;
        const linked = await this.getLinkedAccountFromChatId(platformUserId);
        if (!linked.verified) {
          await this.sendMessage(chatId, {
            text: 'Your Telegram account is linked but not verified.\n\nPlease run /verify command here in this chat to verify ownership and enable access.',
          });
          return;
        }

        const hasPermission = await gituPermissionManager.checkPermission(linked.userId, {
          resource: 'notebooks',
          action: 'read',
        });

        if (!hasPermission) {
          await gituPermissionManager.requestPermission(
            linked.userId,
            {
              resource: 'notebooks',
              actions: ['read'],
              scope: {},
              expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
            },
            'Telegram requested permission to list notebooks'
          );

          await this.sendMessage(chatId, {
            text: "I don’t have permission to access your notebooks from Telegram yet.\n\nOpen NotebookLLM → Gitu → Permissions Requests and approve “notebooks:read”, then run /notebooks again.",
          });
          return;
        }

        const result = await pool.query(
          `SELECT id::text AS id, title, is_agent_notebook, updated_at
           FROM notebooks
           WHERE user_id::text = $1
           ORDER BY updated_at DESC
           LIMIT 10`,
          [linked.userId]
        );

        if (result.rows.length === 0) {
          await this.sendMessage(chatId, { text: 'No notebooks found for your account.' });
          return;
        }

        const lines = result.rows.map((row: any, index: number) => {
          const badge = row.is_agent_notebook ? ' [agent]' : '';
          const id = typeof row.id === 'string' ? row.id : String(row.id);
          const shortId = id.slice(0, 8);
          return `${index + 1}. ${row.title}${badge} (${shortId})`;
        });

        await this.sendMessage(chatId, {
          text: `Your notebooks (latest 10):\n\n${lines.join('\n')}\n\nTip: I can add /open <id> next if you want.`,
        });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (errorMessage.includes('not linked') || errorMessage.includes('Platform account not linked')) {
          await this.sendMessage(chatId, {
            text: '❌ You need to link your Telegram account in the NotebookLLM app first.\n\nUse /id to get your Chat ID.',
          });
          return;
        }
        await this.sendMessage(chatId, {
          text: 'Temporary server error.\n\nPlease try again in a moment.',
        });
      }
    });

    // /clear command
    this.bot.onText(/\/clear/, async (msg) => {
      const chatId = msg.chat.id;
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId.toString();
        const userId = await this.getUserIdFromChatId(platformUserId);
        const session = await gituSessionService.getActiveSession(userId, 'universal');

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

    // /verify command
    this.bot.onText(/\/verify/, async (msg) => {
      const chatId = msg.chat.id.toString();
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId;

        // Check if linked
        const userId = await this.getUserIdFromChatId(platformUserId);

        // Verify
        const { gituIdentityManager } = await import('../services/gituIdentityManager.js');
        await gituIdentityManager.verifyAccount(userId, 'telegram', platformUserId);

        await this.sendMessage(chatId, {
          text: '✅ *Account Verified!*\n\nYou can now use Gitu features like /notebooks and chat with your AI assistant.',
          markdown: '✅ *Account Verified!*\n\nYou can now use Gitu features like /notebooks and chat with your AI assistant.'
        });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (errorMessage.includes('not linked')) {
          await this.sendMessage(chatId, {
            text: '❌ Your Telegram account is not linked to NotebookLLM yet.\n\nIn the Gitu app, go to Linked Accounts and add this Telegram ID.',
          });
        } else {
          await this.sendMessage(chatId, { text: `❌ Verification failed: ${errorMessage}` });
        }
      }
    });

    // /agent command
    this.bot.onText(/\/agent (.+)/, async (msg, match) => {
      const chatId = msg.chat.id.toString();
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId;
        const userId = await this.getUserIdFromChatId(platformUserId);

        const fullCommand = match ? match[1] : '';
        const parts = fullCommand.split(' ');
        const subCommand = parts[0];
        const args = parts.slice(1).join(' ');

        if (subCommand === 'spawn' || subCommand === 'create') {
          if (!args) {
            await this.sendMessage(chatId, { text: '⚠️ Usage: /agent spawn <task description>' });
            return;
          }
          await this.sendMessage(chatId, { text: `🤖 Spawning agent for: "${args}"...` });
          const agent = await gituAgentManager.spawnAgent(userId, args, {
            role: 'autonomous_agent',
            focus: 'general',
            autoLoadPlugins: true
          });
          await this.sendMessage(chatId, { text: `✅ Agent spawned! ID: ${agent.id.substring(0, 8)}\nI will notify you when it completes.` });
          return;
        }

        if (subCommand === 'list') {
          const agents = await gituAgentManager.listAgents(userId);
          if (agents.length === 0) {
            await this.sendMessage(chatId, { text: 'No active agents found.' });
            return;
          }
          const list = agents.map(a =>
            `- *${a.task.substring(0, 30)}...*\n  Status: ${a.status}\n  ID: \`${a.id.substring(0, 8)}\``
          ).join('\n\n');
          await this.sendMessage(chatId, { markdown: `📋 *Your Agents:*\n\n${list}` });
          return;
        }

        await this.sendMessage(chatId, { text: 'ℹ️ Available commands:\n/agent spawn <task>\n/agent list' });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await this.sendMessage(chatId, { text: `❌ Error: ${errorMessage}` });
      }
    });

    // /sources command
    this.bot.onText(/\/sources(.*)/, async (msg, match) => {
      const chatId = msg.chat.id.toString();
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId;
        const linked = await this.getLinkedAccountFromChatId(platformUserId);

        if (!linked.verified) {
          await this.sendMessage(chatId, { text: '❌ Please run /verify to enable access to sources.' });
          return;
        }

        const query = match ? match[1].trim() : '';

        // If query provided, search
        if (query) {
          await this.sendMessage(chatId, { text: `🔍 Searching sources for: "${query}"...` });
          const result = await pool.query(
            `SELECT s.id, s.title, s.type, n.title as notebook_title
              FROM sources s
              JOIN notebooks n ON s.notebook_id = n.id
              WHERE n.user_id = $1 AND (s.title ILIKE $2 OR s.content ILIKE $2)
              ORDER BY s.updated_at DESC LIMIT 5`,
            [linked.userId, `%${query}%`]
          );

          if (result.rows.length === 0) {
            await this.sendMessage(chatId, { text: 'No sources found matching your query.' });
            return;
          }

          const list = result.rows.map((r: any) => `- *${r.title}* (${r.type || 'text'}) in _${r.notebook_title}_`).join('\n');
          await this.sendMessage(chatId, { markdown: `found:\n${list}` });
        } else {
          // List recent
          const result = await pool.query(
            `SELECT s.id, s.title, s.type, n.title as notebook_title
              FROM sources s
              JOIN notebooks n ON s.notebook_id = n.id
              WHERE n.user_id = $1
              ORDER BY s.updated_at DESC LIMIT 10`,
            [linked.userId]
          );

          if (result.rows.length === 0) {
            await this.sendMessage(chatId, { text: 'No sources found. Add some in the app!' });
            return;
          }

          const list = result.rows.map((r: any) => `- *${r.title}* (${r.type || 'text'})`).join('\n');
          await this.sendMessage(chatId, { markdown: `📚 *Recent Sources:*\n\n${list}\n\nTip: Use \`/sources <query>\` to search.` });
        }
      } catch (error) {
        await this.sendMessage(chatId, { text: '❌ Error listing sources.' });
      }
    });

    // /settings command
    this.bot.onText(/\/settings/, async (msg) => {
      const chatId = msg.chat.id;
      try {
        const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId.toString();
        const linked = await this.getLinkedAccountFromChatId(platformUserId);

        if (!linked.verified) {
          await this.sendMessage(chatId.toString(), { text: '❌ Please /verify your account to access settings.' });
          return;
        }

        const settings = await mcpUserSettingsService.getSettings(linked.userId);
        const analysisStatus = settings.codeAnalysisEnabled ? '✅ Enabled' : '❌ Disabled';

        const text = `
⚙️ *Gitu Settings*

👤 *Account*: Verified
🆔 *User ID*: \`${linked.userId.substring(0, 8)}...\`
🧠 *Code Analysis*: ${analysisStatus}

_Click buttons below to change settings:_
          `.trim();

        await this.sendMessage(chatId.toString(), {
          markdown: text,
          replyMarkup: {
            inline_keyboard: [
              [{ text: `${settings.codeAnalysisEnabled ? '🔴 Disable' : '🟢 Enable'} Code Analysis`, callback_data: 'settings:toggle_analysis' }],
              [{ text: '🔄 Refresh', callback_data: 'settings:refresh' }]
            ]
          }
        });

      } catch (error) {
        await this.sendMessage(chatId.toString(), { text: '❌ Error loading settings.' });
      }
    });

    this.bot.onText(/\/gitu(?:@\w+)?(?:\s+([\s\S]+))?/, async (msg, match) => {
      const chatId = msg.chat.id.toString();
      const rawArg = (match && typeof match[1] === 'string') ? match[1].trim() : '';

      if (!rawArg) {
        await this.sendMessage(chatId, {
          text: `Usage: /gitu <message>\n\nExample: /gitu summarize the last 10 messages and suggest a reply`,
        });
        return;
      }

      const syntheticMsg: TelegramBot.Message = { ...(msg as any), text: rawArg };
      await this.handleIncomingMessage(syntheticMsg);
    });
  }

  private shouldProcessMessageInChat(msg: TelegramBot.Message, rawText: string): boolean {
    if (msg.chat.type === 'private') return true;

    if (this.getGroupMode() === 'all') return true;

    const lowered = rawText.toLowerCase();
    if (this.botUsername && lowered.includes(`@${this.botUsername.toLowerCase()}`)) {
      return true;
    }

    const replyFromId = (msg as any)?.reply_to_message?.from?.id;
    if (replyFromId && this.botUserId && String(replyFromId) === this.botUserId) {
      return true;
    }

    const entities = (msg as any)?.entities;
    if (Array.isArray(entities) && entities.some((e: any) => e?.type === 'mention' || e?.type === 'text_mention')) {
      return true;
    }

    return false;
  }

  /**
   * Handle incoming Telegram message.
   */
  private async handleIncomingMessage(msg: TelegramBot.Message): Promise<void> {
    const chatId = msg.chat.id.toString();
    const platformUserId = msg.from?.id ? msg.from.id.toString() : chatId;

    // Handle /unlink command (robust check)
    const text = (msg.text || '').trim().toLowerCase();
    if (text === '/unlink' || text === 'unlink' || text.startsWith('/unlink ')) {
      try {
        await pool.query(
          `UPDATE gitu_linked_accounts SET status = 'inactive' 
           WHERE platform = 'telegram' AND platform_user_id = $1`,
          [platformUserId]
        );
        await this.sendMessage(chatId, { text: '✅ Account unlinked successfully. You can now link this Telegram account to a different NotebookLLM user.' });
      } catch (error) {
        console.error('Unlink error:', error);
        await this.sendMessage(chatId, { text: '❌ Failed to unlink account.' });
      }
      return;
    }

    // Skip if it's a command (already handled by command handlers)
    if (msg.text && msg.text.startsWith('/')) {
      return;
    }

    // Build raw message
    const rawMessage: RawMessage = {
      platform: 'telegram',
      platformUserId,
      content: msg,
      timestamp: new Date(msg.date * 1000),
      metadata: {
        messageId: msg.message_id,
        chatType: msg.chat.type,
        from: msg.from,
      },
    };

    try {
      // Process through message gateway
      const normalizedMessage = await gituMessageGateway.processMessage(rawMessage);

      // Send typing indicator
      await this.sendChatAction(chatId, 'typing');

      const session = await gituSessionService.getOrCreateSession(normalizedMessage.userId, 'universal');
      const userText = normalizedMessage.content.text || '[attachment]';

      session.context.conversationHistory.push({
        role: 'user',
        content: userText,
        timestamp: new Date(),
        platform: 'telegram',
      });

      const context = session.context.conversationHistory
        .slice(-20)
        .map(m => ({
          role: m.role as 'user' | 'assistant' | 'system' | 'tool',
          content: m.content
        }));

      // Use Tool Execution Service for smart responses
      const result = await gituToolExecutionService.processWithTools(
        normalizedMessage.userId,
        userText,
        context,
        {
          platform: 'telegram',
          sessionId: session.id,
        }
      );

      session.context.conversationHistory.push({
        role: 'assistant',
        content: result.response,
        timestamp: new Date(),
        platform: 'telegram',
      });

      await gituSessionService.updateSession(session.id, { context: session.context });

      await gituMessageGateway.trackOutboundMessage(normalizedMessage.userId, 'telegram', result.response, {
        sessionId: session.id,
        replyToMessageId: normalizedMessage.id,
        userMessageText: userText,
      });

      const parts = this.splitMessageText(result.response);
      for (const part of parts) {
        await this.sendMessage(chatId, { text: part });
      }
    } catch (error: any) {
      const errorMessage = error?.message || String(error);
      console.error('[Telegram] Message processing error:', errorMessage);

      if (errorMessage.includes('not linked') || errorMessage.includes('Platform account')) {
        await this.sendMessage(chatId, {
          text: `❌ Your Telegram account is not linked to NotebookLLM.\n\n` +
            `Your Telegram User ID: ${platformUserId}\n\n` +
            `To fix this:\n` +
            `1. Open the NotebookLLM app\n` +
            `2. Go to Settings → Gitu → Linked Accounts\n` +
            `3. Tap "Link Telegram"\n` +
            `4. Enter your Telegram User ID: ${platformUserId}\n` +
            `5. Confirm\n\n` +
            `Then send me a message again!`
        });
      } else {
        await this.sendMessage(chatId, {
          text: `❌ Error: ${errorMessage.substring(0, 200)}`
        });
      }
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

    if (data && chatId) {
      if (data.startsWith('settings:')) {
        try {
          const parts = data.split(':');
          const action = parts[1];

          const platformUserId = query.from.id.toString();
          const linked = await this.getLinkedAccountFromChatId(platformUserId);

          if (action === 'toggle_analysis') {
            const current = await mcpUserSettingsService.getSettings(linked.userId);
            await mcpUserSettingsService.updateSettings(linked.userId, {
              codeAnalysisEnabled: !current.codeAnalysisEnabled
            });
          }

          // Refresh view for both 'refresh' and 'toggle_analysis'
          const settings = await mcpUserSettingsService.getSettings(linked.userId);
          const analysisStatus = settings.codeAnalysisEnabled ? '✅ Enabled' : '❌ Disabled';

          const text = `
⚙️ *Gitu Settings*

👤 *Account*: Verified
🆔 *User ID*: \`${linked.userId.substring(0, 8)}...\`
🧠 *Code Analysis*: ${analysisStatus}

_Click buttons below to change settings:_
                `.trim();

          await this.bot.editMessageText(text, {
            chat_id: chatId,
            message_id: query.message?.message_id,
            parse_mode: 'Markdown',
            reply_markup: {
              inline_keyboard: [
                [{ text: `${settings.codeAnalysisEnabled ? '🔴 Disable' : '🟢 Enable'} Code Analysis`, callback_data: 'settings:toggle_analysis' }],
                [{ text: '🔄 Refresh', callback_data: 'settings:refresh' }]
              ]
            }
          });
        } catch (error) {
          console.error('Error handling settings callback:', error);
        }
      } else {
        await this.sendMessage(chatId, {
          text: `Button pressed: ${data}`,
        });
      }
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
          caption: message.caption || message.text || message.markdown, // Use provided caption or fallback
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

      // Send audio/voice
      if (message.audio) {
        // If it has a URL property, use that, otherwise use the value directly
        const audioSource = (typeof message.audio === 'object' && 'url' in message.audio) 
          ? message.audio.url 
          : message.audio;
          
        await this.bot.sendVoice(chatId, audioSource, {
          caption: message.caption,
          reply_markup: message.replyMarkup,
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

    console.log(`[Telegram Lookup] chatId=${chatId} -> found=${result.rows.length > 0 ? result.rows[0].user_id : 'NONE'}`);

    if (result.rows.length === 0) {
      throw new Error('Telegram account not linked. Please link your account in the NotebookLLM app.');
    }

    return result.rows[0].user_id;
  }

  private async getLinkedAccountFromChatId(chatId: string): Promise<{ userId: string; verified: boolean }> {
    const result = await pool.query(
      `SELECT user_id, verified
       FROM gitu_linked_accounts
       WHERE platform = 'telegram' AND platform_user_id = $1 AND status = 'active'
       LIMIT 1`,
      [chatId]
    );

    console.log(`[Telegram Linked Lookup] chatId=${chatId} -> found=${result.rows.length > 0}`);

    if (result.rows.length === 0) {
      throw new Error('Telegram account not linked. Please link your account in the NotebookLLM app.');
    }

    const row = result.rows[0] as any;
    return { userId: String(row.user_id), verified: Boolean(row.verified) };
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
