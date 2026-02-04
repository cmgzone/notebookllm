# WhatsApp Auto-Reply Fix 🔧

**Issue:** Bot is not replying to WhatsApp messages unless you're available or mentioned

**Root Cause:** The WhatsApp adapter has a permission system that blocks auto-replies by default for security/privacy reasons.

---

## Current Behavior

The bot only replies to:
1. ✅ **Note to Self** (messages you send to yourself)
2. ✅ **Contacts with `auto_reply: true`** enabled
3. ✅ **Messages mentioning "gitu" or "@bot"**
4. ✅ **Commands starting with `/`**

For all other contacts/groups, the bot **receives and stores** the message but **does not reply**.

---

## Solution Options

### Option 1: Enable Auto-Reply for Specific Contacts (Recommended)

Use commands in WhatsApp to control who gets auto-replies:

#### Enable for Current Chat:
```
/gitu allow
```

#### Enable for Specific Contact:
```
/gitu allow John
/gitu allow +1234567890
```

#### Disable for Current Chat:
```
/gitu mute
```

#### Disable for Specific Contact:
```
/gitu mute John
```

---

### Option 2: Enable Auto-Reply for ALL Contacts (Not Recommended)

If you want the bot to reply to EVERYONE automatically, modify the code:

**File:** `backend/src/adapters/whatsappAdapter.ts`

**Find this section (around line 770):**
```typescript
// Check Permissions
const isAllowed = contactsStore[remoteJid]?.auto_reply === true;
const isMention = text.toLowerCase().includes('gitu') || text.toLowerCase().includes('@bot');
const isCommand = text.startsWith('/');

// Determine if we should reply
let shouldReply = false;

if (isNoteToSelf) {
    shouldReply = true;
} else if (isAllowed) {
    shouldReply = true;
} else if (isMention || isCommand) {
    shouldReply = true;
}
```

**Replace with:**
```typescript
// Check Permissions
const isAllowed = contactsStore[remoteJid]?.auto_reply === true;
const isMention = text.toLowerCase().includes('gitu') || text.toLowerCase().includes('@bot');
const isCommand = text.startsWith('/');

// Determine if we should reply
let shouldReply = false;

if (isNoteToSelf) {
    shouldReply = true;
} else if (isAllowed) {
    shouldReply = true;
} else if (isMention || isCommand) {
    shouldReply = true;
} else {
    // AUTO-REPLY TO EVERYONE (CAUTION!)
    shouldReply = true;
}
```

**⚠️ Warning:** This will make the bot reply to EVERY message from EVERY contact and group. This can:
- Spam your contacts
- Consume API credits rapidly
- Violate WhatsApp's terms of service
- Get your number banned

---

### Option 3: Enable Auto-Reply for All Contacts via Environment Variable

Add this to your `.env` file:

```bash
GITU_WHATSAPP_AUTO_REPLY_ALL=true
```

Then modify the code to check this variable:

**File:** `backend/src/adapters/whatsappAdapter.ts`

**Find the same section and replace with:**
```typescript
// Check Permissions
const isAllowed = contactsStore[remoteJid]?.auto_reply === true;
const isMention = text.toLowerCase().includes('gitu') || text.toLowerCase().includes('@bot');
const isCommand = text.startsWith('/');
const autoReplyAll = process.env.GITU_WHATSAPP_AUTO_REPLY_ALL === 'true';

// Determine if we should reply
let shouldReply = false;

if (isNoteToSelf) {
    shouldReply = true;
} else if (isAllowed) {
    shouldReply = true;
} else if (isMention || isCommand) {
    shouldReply = true;
} else if (autoReplyAll) {
    shouldReply = true;
}
```

---

## How to Use Commands

### 1. Send to Note to Self (Your Own Chat)

Open WhatsApp and send a message to yourself:
```
/gitu allow John
```

The bot will reply:
```
✅ Auto-reply enabled for John (+1234567890).
```

### 2. Enable for Multiple Contacts

```
/gitu allow Mom
/gitu allow Dad
/gitu allow Work Group
```

### 3. Check Who Has Access

The permissions are stored in:
```
.gitu/credentials/whatsapp/contacts-store.json
```

Look for contacts with `"auto_reply": true`:
```json
{
  "1234567890@s.whatsapp.net": {
    "id": "1234567890@s.whatsapp.net",
    "name": "John",
    "auto_reply": true
  }
}
```

---

## Testing

### Test 1: Note to Self (Should Always Work)
1. Open WhatsApp
2. Send a message to yourself: "Hello Gitu"
3. Bot should reply immediately

### Test 2: Unauthorized Contact (Should NOT Reply)
1. Have a friend send you a message
2. Bot receives it but does NOT reply
3. Check backend logs: "Blocked access from unauthorized user"

### Test 3: Enable Auto-Reply
1. Send to yourself: `/gitu allow +1234567890`
2. Have that friend send another message
3. Bot should now reply

### Test 4: Mention (Should Always Work)
1. Have anyone send: "Hey @gitu, what's the weather?"
2. Bot should reply even without permission

---

## Why This Design?

The permission system exists to:
1. **Prevent spam** - Don't annoy your contacts
2. **Save costs** - AI API calls cost money
3. **Privacy** - Don't expose your AI to everyone
4. **WhatsApp compliance** - Avoid getting banned for bot behavior

---

## Recommended Workflow

1. **Start with Note to Self** - Test everything in your own chat
2. **Enable for trusted contacts** - Use `/gitu allow` for family/friends
3. **Use mentions in groups** - Let people opt-in by mentioning @gitu
4. **Monitor usage** - Check logs and API costs

---

## Quick Commands Reference

| Command | Description |
|---------|-------------|
| `/gitu allow` | Enable auto-reply for current chat |
| `/gitu allow <name>` | Enable for specific contact |
| `/gitu mute` | Disable auto-reply for current chat |
| `/gitu mute <name>` | Disable for specific contact |
| `ping` | Test connection (Note to Self only) |
| `/agent spawn <task>` | Create an autonomous agent |
| `/agent list` | List active agents |
| `/swarm <objective>` | Deploy agent swarm |
| `/swarm status` | Check swarm missions |

---

## Troubleshooting

### Bot receives but doesn't reply:
1. Check if contact has `auto_reply: true` in contacts-store.json
2. Try mentioning "gitu" in the message
3. Use `/gitu allow` command
4. Check backend logs for "Blocked access" messages

### Bot replies to everyone:
1. Check if you modified the code to enable auto-reply for all
2. Check `.env` for `GITU_WHATSAPP_AUTO_REPLY_ALL=true`
3. Review contacts-store.json for contacts with `auto_reply: true`

### Commands not working:
1. Make sure you're sending to Note to Self (your own chat)
2. Check backend is running and connected
3. Look for errors in backend logs

---

## Implementation Status

✅ Permission system implemented  
✅ `/gitu allow` command working  
✅ `/gitu mute` command working  
✅ Mention detection working  
✅ Note to Self always enabled  
✅ Contacts store persistence  
✅ Search by name/number  

---

## Next Steps

1. **Test in Note to Self:**
   ```
   ping
   ```

2. **Enable for a contact:**
   ```
   /gitu allow Mom
   ```

3. **Test with that contact:**
   - Have them send a message
   - Bot should reply

4. **Monitor logs:**
   ```bash
   cd backend
   npm start
   ```
   Look for: "Received message from..." and "Blocked access from..."

---

## Security Note

The permission system is designed to protect you and your contacts. Only enable auto-reply for:
- ✅ Trusted family/friends
- ✅ Work colleagues who know about the bot
- ✅ Groups where bot usage is approved

Do NOT enable for:
- ❌ Unknown contacts
- ❌ Public groups
- ❌ Business contacts without permission
- ❌ Everyone by default

---

**Status:** Permission system is working as designed. Use `/gitu allow` to enable auto-reply for specific contacts.
