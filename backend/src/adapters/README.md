# Gitu Platform Adapters

This directory contains platform adapters for the Gitu universal AI assistant. Each adapter handles communication with a specific platform (Telegram, WhatsApp, Email, Terminal, etc.).

## Telegram Adapter

The Telegram adapter enables Gitu to communicate via Telegram Bot API.

### Setup

1. **Create a Telegram Bot**
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` and follow the instructions
   - Choose a name and username for your bot
   - Save the bot token provided by BotFather

2. **Configure Environment**
   Add the bot token to `backend/.env`:
   ```env
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```

3. **Link Telegram Account**
   Users must link their Telegram account to their NotebookLLM account:
   - Open NotebookLLM Flutter app
   - Go to Settings > Gitu > Connected Platforms
   - Click "Connect Telegram"
   - Follow the linking process

### Testing

Run the test script to verify the adapter works:

```bash
cd backend
tsx src/scripts/test-telegram-adapter.ts
```

The script will:
- Initialize the Telegram bot
- Display bot information
- Set up bot commands
- Check for linked accounts
- Listen for incoming messages

### Usage

```typescript
import { telegramAdapter } from './adapters/telegramAdapter.js';

// Initialize the adapter
await telegramAdapter.initialize(process.env.TELEGRAM_BOT_TOKEN!, {
  polling: true  // Use polling for development
});

// Set bot commands
await telegramAdapter.setCommands([
  { command: 'start', description: 'Start the bot' },
  { command: 'help', description: 'Show help message' },
]);

// Send a message
await telegramAdapter.sendMessage('chat_id', {
  markdown: '*Hello* from Gitu!',
});

// Handle incoming messages
telegramAdapter.onMessage(async (message) => {
  console.log('Received:', message.content.text);
});
```

### Features

- ✅ Text message sending and receiving
- ✅ Markdown formatting support
- ✅ Photo/document/audio attachments
- ✅ Inline keyboards (buttons)
- ✅ Bot commands (/start, /help, etc.)
- ✅ Callback query handling
- ✅ Chat actions (typing indicator)
- ✅ Message normalization via Message Gateway
- ✅ Session management integration

### Bot Commands

The following commands are available:

- `/start` - Welcome message and introduction
- `/help` - Show available commands
- `/status` - Check Gitu status and session info
- `/notebooks` - List user's notebooks
- `/session` - View current session details
- `/clear` - Clear conversation history
- `/settings` - View Gitu settings

### Architecture

```
Telegram User
     ↓
Telegram Bot API
     ↓
telegramAdapter.ts
     ↓
gituMessageGateway.ts (normalization)
     ↓
gituSessionService.ts (session management)
     ↓
AI Router / MCP Hub
```

### Error Handling

The adapter includes comprehensive error handling:
- Polling errors are logged
- Webhook errors are logged
- Message processing errors send user-friendly error messages
- Connection state tracking

### Production Deployment

For production, use webhook mode instead of polling:

```typescript
await telegramAdapter.initialize(process.env.TELEGRAM_BOT_TOKEN!, {
  webhookUrl: 'https://your-domain.com/api/telegram/webhook',
  polling: false
});
```

Then set up an Express route to handle webhook updates:

```typescript
app.post('/api/telegram/webhook', (req, res) => {
  telegramAdapter.bot.processUpdate(req.body);
  res.sendStatus(200);
});
```

### Security Considerations

- Bot token is stored in environment variables (never commit to git)
- User accounts must be linked before messaging
- All messages are logged for audit trail
- Platform-specific user IDs are mapped to NotebookLLM user IDs

### Troubleshooting

**Bot not responding:**
- Check that TELEGRAM_BOT_TOKEN is set correctly
- Verify the bot is initialized
- Check console for error messages
- Ensure polling or webhook is configured

**"Account not linked" error:**
- User must link their Telegram account in the NotebookLLM app first
- Check `gitu_linked_accounts` table for the user's entry

**Messages not being received:**
- Check that message handlers are set up
- Verify the bot has permission to receive messages
- Check Telegram Bot API status

### Future Enhancements

- [ ] Voice message transcription
- [ ] Video message support
- [ ] Group chat support
- [ ] Inline query support
- [ ] Payment integration
- [ ] Game integration
- [ ] Sticker support

## Other Adapters

### Terminal Adapter

The Terminal adapter provides a command-line interface (CLI) for interacting with Gitu via REPL (Read-Eval-Print Loop).

#### Features

- ✅ Interactive REPL interface
- ✅ Colored output with chalk
- ✅ Progress indicators with ora
- ✅ Command history
- ✅ Built-in commands (help, status, session, etc.)
- ✅ Message normalization via Message Gateway
- ✅ Session management integration

#### Setup

No special setup required. Just run the test script with a user ID:

```bash
cd backend
npx tsx src/scripts/test-terminal-adapter.ts <user-id>
```

#### Usage

```typescript
import { terminalAdapter } from './adapters/terminalAdapter.js';

// Initialize the adapter
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: true,
  historySize: 100,
});

// Register message handler
terminalAdapter.onCommand(async (message) => {
  console.log('Received:', message.content.text);
  
  // Process and respond
  terminalAdapter.sendResponse('Your response here');
});

// Start the REPL
terminalAdapter.startREPL();
```

#### Built-in Commands

- `help, ?` - Show help message
- `exit, quit, q` - Exit the terminal
- `clear, cls` - Clear the screen
- `history` - Show command history
- `status` - Show Gitu status
- `session` - Show current session info
- `clear-session` - Clear conversation history

#### Testing

```bash
# Test with a specific user ID
npx tsx src/scripts/test-terminal-adapter.ts test-user-123

# Once running, try these commands:
> help
> status
> session
> Hello, Gitu!
> exit
```

#### Architecture

```
Terminal User
     ↓
readline (Node.js)
     ↓
terminalAdapter.ts
     ↓
gituMessageGateway.ts (normalization)
     ↓
gituSessionService.ts (session management)
     ↓
AI Router / MCP Hub
```

#### Progress Indicators

The terminal adapter supports progress indicators for long-running tasks:

```typescript
// Show progress
terminalAdapter.displayProgress('Processing request', 50);

// Complete progress
terminalAdapter.displayProgress('Processing request', 100);
```

#### Color Output

The adapter uses chalk for colored output:
- Cyan: Prompts and headers
- Green: Success messages and responses
- Yellow: Warnings
- Red: Errors
- Gray: Secondary information

To disable colors:

```typescript
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: false,
});
```

### WhatsApp Adapter

**Status:** Coming soon - Uses Baileys library

### Email Adapter

**Status:** Coming soon - IMAP/SMTP integration

### Flutter Adapter

**Status:** Coming soon - WebSocket connection

## Contributing

When adding a new adapter:

1. Create a new file in this directory (e.g., `whatsappAdapter.ts`)
2. Implement the adapter interface
3. Integrate with `gituMessageGateway` for message normalization
4. Add tests in `src/__tests__/`
5. Update this README with setup instructions
