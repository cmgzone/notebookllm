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

### Permission Model (Gitu vs OpenClaw)

**Gitu (this repo)**
- Identity gate: requires an active row in `gitu_linked_accounts` for `platform='telegram'` and `status='active'`.
- Verification gate (for protected features): some commands require `verified=true` and/or explicit permissions via `gituPermissionManager` (example: `/notebooks`).
- Group gate: by default only processes group messages that mention the bot / reply to the bot / contain mention entities; override with `GITU_TELEGRAM_GROUP_MODE=all`.

Implementation reference: [telegramAdapter.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/adapters/telegramAdapter.ts)

**OpenClaw**
- DM gate: `dmPolicy` defaults to `pairing` (deny-by-default); unknown users get a pairing code and are blocked until approved.
- Allowlist gate: `allowFrom` supports Telegram user IDs and usernames (supports `tg:` / `telegram:` prefixes) and can merge with a persisted allow-from store.
- Group gate: `channels.telegram.groups` creates an allowlist of accepted groups and supports `requireMention` plus per-topic overrides.
- Command gate: control commands can be blocked unless the sender is authorized by the allowlist.

Docs: [openclow Telegram channel](file:///c:/Users/Admin/Documents/project/openclow/docs/channels/telegram.md)  
Implementation: [bot-message-context.ts](file:///c:/Users/Admin/Documents/project/openclow/src/telegram/bot-message-context.ts) and [bot-access.ts](file:///c:/Users/Admin/Documents/project/openclow/src/telegram/bot-access.ts)

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

## WhatsApp Adapter

The WhatsApp adapter enables Gitu to communicate via WhatsApp Web using Baileys.

### Setup

1. **Link WhatsApp session owner**
   - The WhatsApp account that runs the session must exist in `gitu_linked_accounts` as `platform='whatsapp'` and `status='active'`.
   - The adapter attributes all inbound chats (DMs/groups) to the *session owner* (the connected WhatsApp account).

2. **Configure Environment**
   Add to `backend/.env` as needed:
   ```env
   GITU_WHATSAPP_AUTH_DIR=/absolute/path/to/whatsapp-auth
   GITU_WHATSAPP_CONTACTS_STORE_PATH=/absolute/path/to/contacts-store.json
   GITU_WHATSAPP_SEND_WELCOME_TO_SELF=false
   ```

### Testing

```bash
cd backend
tsx src/scripts/test-whatsapp-adapter.ts
```

### Permission Model (Gitu)

Gitu WhatsApp replies are controlled per chat (remoteJid) using a local `auto_reply` flag:

- **Always replies** to "Note to Self" (messages to your own WhatsApp account).
- **Replies** to a chat if `auto_reply` for that chat is enabled.
- **Replies** if the message includes a mention trigger (`gitu` / `@bot`) or starts with `/` (command).
- **Does not reply** to messages you sent from your phone (`fromMe`) unless it is Note to Self.

Commands:
- `/gitu allow` enables auto-reply for the current chat
- `/gitu mute` disables auto-reply for the current chat
- `/gitu allow <query>` and `/gitu mute <query>` update auto-reply by searching the local contacts store

Implementation reference: [whatsappAdapter.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/adapters/whatsappAdapter.ts)

### Permission Model (OpenClaw)

OpenClaw uses a stricter inbound access-control layer:

- **DM policy** (`pairing` default): unknown senders do not reach the model until approved (pairing code flow).
- **Allowlist**: `allowFrom` (plus a persisted allow-from store) controls who can DM.
- **Group policy**: `open|allowlist|disabled` controls group inbound acceptance.
- **Self-chat mode**: the linked number is implicitly trusted and treated specially.

Implementation reference: [access-control.ts](file:///c:/Users/Admin/Documents/project/openclow/src/web/inbound/access-control.ts) and docs: [whatsapp.md](file:///c:/Users/Admin/Documents/project/openclow/docs/channels/whatsapp.md)

### Key Differences (Why it matters)

- OpenClaw defaults to **deny-by-default** for DMs (`pairing`), Gitu defaults to **reply-on-mention/command** unless muted.
- OpenClaw approvals are **channel-level** (pairing/allowFrom), Gitu approvals are **chat-level** (`auto_reply` per remoteJid).
- OpenClaw can prevent “first contact” spam by design; Gitu can respond to an unapproved DM if the sender uses `/...` or mentions `gitu`.

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
