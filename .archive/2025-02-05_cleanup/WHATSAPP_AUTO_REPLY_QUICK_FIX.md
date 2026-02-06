# WhatsApp Auto-Reply - Quick Fix Guide 🚀

**Problem:** Bot not replying to WhatsApp messages

**Solution:** Enable auto-reply using one of these methods

---

## Method 1: Use Commands (Recommended) ✅

### Step 1: Test in Note to Self
Open WhatsApp and send a message to yourself:
```
ping
```

You should get: `pong 🏓 (Connection Verified)`

### Step 2: Enable for Specific Contacts
```
/gitu allow Mom
/gitu allow +1234567890
/gitu allow John
```

### Step 3: Test
Have that contact send a message - bot will now reply!

---

## Method 2: Enable for Everyone (Use with Caution) ⚠️

### Option A: Environment Variable

Add to `backend/.env`:
```bash
GITU_WHATSAPP_AUTO_REPLY_ALL=true
```

Restart backend:
```bash
cd backend
npm start
```

### Option B: Modify Code

**File:** `backend/src/adapters/whatsappAdapter.ts` (Line ~770)

Already updated! Just set the environment variable above.

---

## Quick Commands

| Command | What It Does |
|---------|-------------|
| `ping` | Test connection (Note to Self) |
| `/gitu allow` | Enable auto-reply for current chat |
| `/gitu allow John` | Enable for specific contact |
| `/gitu mute` | Disable auto-reply for current chat |
| `/gitu mute John` | Disable for specific contact |

---

## How It Works

The bot has 4 reply modes:

1. **Note to Self** - Always replies ✅
2. **Allowed Contacts** - Replies if you enabled them ✅
3. **Mentions** - Replies when someone says "gitu" or "@bot" ✅
4. **Commands** - Replies to messages starting with `/` ✅

Everyone else: Bot receives the message but doesn't reply (for privacy/spam prevention)

---

## Testing Steps

### 1. Test Note to Self
```
You: ping
Bot: pong 🏓 (Connection Verified)
```

### 2. Enable a Contact
```
You (to yourself): /gitu allow Mom
Bot: ✅ Auto-reply enabled for Mom (+1234567890).
```

### 3. Test with That Contact
```
Mom: Hello
Bot: Hi! How can I help you today?
```

### 4. Test Mention (Works for Anyone)
```
Friend: Hey @gitu, what's the weather?
Bot: [Replies with weather info]
```

---

## Why This Design?

- **Prevents spam** - Don't annoy your contacts
- **Saves money** - AI calls cost money
- **Privacy** - Don't expose your AI to everyone
- **WhatsApp compliance** - Avoid getting banned

---

## Troubleshooting

### Bot doesn't reply to anyone:
1. Check backend is running: `npm start`
2. Check WhatsApp is connected (look for QR code or "Opened connection")
3. Test with `ping` in Note to Self

### Bot doesn't reply to specific contact:
1. Enable them: `/gitu allow ContactName`
2. Or have them mention "gitu" in their message
3. Check contacts-store.json for `"auto_reply": true`

### Bot replies to everyone (unwanted):
1. Check `.env` for `GITU_WHATSAPP_AUTO_REPLY_ALL=true`
2. Remove or set to `false`
3. Restart backend

---

## Files Changed

✅ `backend/src/adapters/whatsappAdapter.ts` - Added `GITU_WHATSAPP_AUTO_REPLY_ALL` check  
✅ `backend/.env.example` - Added WhatsApp configuration section  
✅ `WHATSAPP_AUTO_REPLY_FIX.md` - Full documentation  
✅ `WHATSAPP_AUTO_REPLY_QUICK_FIX.md` - This quick guide  

---

## Next Steps

1. **Restart backend** if you changed `.env`
2. **Test with ping** in Note to Self
3. **Enable contacts** using `/gitu allow`
4. **Monitor logs** for "Blocked access" messages

---

**Status:** ✅ Auto-reply system working as designed. Use commands to control who gets replies!
