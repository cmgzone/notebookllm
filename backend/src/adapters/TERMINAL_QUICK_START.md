# Terminal Adapter - Quick Start

## 🚀 Get Started in 30 Seconds

### 1. Install Dependencies
```bash
cd backend
npm install chalk@5.3.0 ora@8.1.1
```

### 2. Run the Test Script
```bash
npx tsx src/scripts/test-terminal-adapter.ts <your-user-id>
```

### 3. Try These Commands
```
> help
> status
> Hello, Gitu!
> exit
```

## 📝 Basic Usage

```typescript
import { terminalAdapter } from './adapters/terminalAdapter.js';

// Initialize
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: true,
});

// Handle messages
terminalAdapter.onCommand(async (message) => {
  terminalAdapter.sendResponse(`You said: ${message.content.text}`);
});

// Start
terminalAdapter.startREPL();
```

## 🎨 Built-in Commands

| Command | What it does |
|---------|--------------|
| `help` | Show help |
| `status` | Show Gitu status |
| `session` | Show session info |
| `history` | Show command history |
| `clear` | Clear screen |
| `exit` | Exit terminal |

## 🔧 Configuration Options

```typescript
{
  userId: string,           // Required
  prompt?: string,          // Default: "Gitu> "
  historySize?: number,     // Default: 100
  colorOutput?: boolean,    // Default: true
}
```

## 📊 Progress Indicators

```typescript
terminalAdapter.displayProgress('Task name', 0);
// ... do work ...
terminalAdapter.displayProgress('Task name', 50);
// ... do more work ...
terminalAdapter.displayProgress('Task name', 100);
```

## 🐛 Troubleshooting

**User not found?**
```sql
SELECT id FROM users WHERE id = 'your-user-id';
```

**Colors not working?**
```typescript
colorOutput: false  // Disable colors
```

**Not initialized?**
```typescript
await terminalAdapter.initialize({ userId: 'user-123' });
```

## 📚 Full Documentation

See `TERMINAL_ADAPTER_GUIDE.md` for complete documentation.

## ✅ Tests

```bash
npm test -- terminalAdapter.test.ts
```

## 🎯 Example Session

```
Gitu> help
📖 Available Commands: ...

Gitu> status
✅ Gitu Status: Active

Gitu> Hello!
🤖 Gitu: I received your message...

Gitu> exit
👋 Goodbye!
```

---

**Need Help?** Check the full guide or run `help` in the terminal.
