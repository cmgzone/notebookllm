I will implement granular control for WhatsApp auto-replies and add status posting capabilities.

### **1. Granular Auto-Reply Permissions**
**File:** `backend/src/adapters/whatsappAdapter.ts`
- **Logic:** I will modify the message handler to check an `auto_reply` flag for each contact/group.
- **Commands:** You will be able to control this directly from WhatsApp:
  - Send `/gitu allow` in any group or chat: **Enables** the bot to reply to all messages in that chat.
  - Send `/gitu mute` in any group or chat: **Disables** auto-replies (bot only replies to mentions/commands).
- **Default Behavior:** By default, the bot will only reply to **Notes to Self** and **Mentions** (safest). You must explicitly "allow" a group for full participation.
- **Persistence:** These permissions will be saved in `whatsapp_contacts.json`.

### **2. Post WhatsApp Status**
**File:** `backend/src/services/messagingMCPTools.ts` & `whatsappAdapter.ts`
- **New Tool:** `post_whatsapp_status`
- **Functionality:** Allows the AI to post text or image updates to your WhatsApp Status.
- **Usage:** You can say "Post a status update saying 'Coding with Gitu'".

### **3. Read Messages (From Previous Plan)**
**File:** `backend/src/services/messagingMCPTools.ts`
- **New Tool:** `list_messages`
- **Functionality:** Allows the AI to read recent message history from any chat (even if auto-reply is off), addressing "check my messages".

### **4. Verification**
- I will verify by checking the code compilation.
- You can test by:
  1. Sending `/gitu allow` in a group.
  2. Asking the bot "Post a status".
  3. Asking "What are the last messages in the group?".