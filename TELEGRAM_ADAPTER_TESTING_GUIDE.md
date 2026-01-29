# Telegram Adapter Testing Guide

## Quick Start

You've successfully implemented the Telegram Bot Adapter! Now let's test it.

## Current Status

✅ Telegram bot token is configured in `backend/.env`
✅ Telegram adapter is implemented
✅ Test scripts are ready
⚠️ Need to link your Telegram account to test

## Testing Steps

### 1. Find Your Telegram User ID

The error message you saw contains your Telegram User ID (chat ID). Look for a number in the error message like:

```
Error: Platform account not linked. User must connect their telegram account...
```

The chat ID is the number that was used when you sent the message to the bot.

### 2. Link Your Telegram Account

From the `backend` directory, run:

```powershell
.\link-telegram.ps1 <YOUR_TELEGRAM_USER_ID>
```

**Example:**
```powershell
.\link-telegram.ps1 123456789
```

Or if you want to link to a specific email:
```powershell
.\link-telegram.ps1 123456789 test@example.com
```

### 3. Restart the Bot

Make sure the bot is running:
```powershell
.\test-telegram.ps1
```

### 4. Test It!

Send a message to your bot on Telegram. It should now respond!

## Available Bot Commands

Once your account is linked, try these commands:

- `/start` - Get a welcome message
- `/help` - See available commands
- `/status` - Check your session status
- `/clear` - Clear conversation history

## What Happens Next?

When you send a message:
1. Telegram sends it to your bot
2. The adapter receives it
3. Message Gateway normalizes it
4. AI Router processes it
5. AI generates a response
6. Bot sends the response back to you

## Troubleshooting

### "Platform account not linked" error
→ Run the `link-telegram.ps1` script with your Telegram User ID

### "tsx: The term 'tsx' is not recognized"
→ Use the `.ps1` helper scripts instead, or use `npx tsx`

### Bot not responding
→ Check that:
- The bot is running (console shows "Telegram bot started")
- Your account is linked (run link script again)
- Your bot token is correct in `.env`

## Files Created

- `backend/src/adapters/telegramAdapter.ts` - Main adapter implementation
- `backend/src/scripts/test-telegram-adapter.ts` - Test script
- `backend/src/scripts/link-telegram-test-account.ts` - Account linking script
- `backend/test-telegram.ps1` - PowerShell helper for testing
- `backend/link-telegram.ps1` - PowerShell helper for linking accounts
- `backend/src/adapters/README.md` - Adapter documentation

## Next Steps After Testing

Once testing is successful:
1. The adapter can be integrated into the main Gitu system
2. Webhook mode can be configured for production
3. Additional features can be added (voice, video, etc.)

## Need Help?

Check the full documentation in:
- `TELEGRAM_ADAPTER_IMPLEMENTATION.md` - Complete implementation details
- `backend/src/adapters/README.md` - Adapter usage guide
- `.kiro/specs/gitu-universal-assistant/design.md` - System design

---

**Ready to test?** Run `.\link-telegram.ps1 <your_telegram_user_id>` from the backend directory!
