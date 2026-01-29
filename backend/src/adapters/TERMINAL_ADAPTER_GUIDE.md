# Terminal CLI Adapter - Complete Guide

## Overview

The Terminal CLI Adapter provides a command-line interface (REPL) for interacting with Gitu, the universal AI assistant. It enables users to chat with Gitu directly from their terminal with a rich, interactive experience.

## Features

### Core Features
- ✅ **Interactive REPL** - Read-Eval-Print Loop for continuous interaction
- ✅ **Colored Output** - Beautiful terminal UI with chalk
- ✅ **Progress Indicators** - Visual feedback with ora spinners
- ✅ **Command History** - Navigate through previous commands
- ✅ **Built-in Commands** - Help, status, session management, etc.
- ✅ **Message Normalization** - Integrates with Gitu Message Gateway
- ✅ **Session Management** - Persistent conversation context
- ✅ **Error Handling** - Graceful error messages and recovery

### Built-in Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `help` | `?` | Show help message with available commands |
| `exit` | `quit`, `q` | Exit the terminal |
| `clear` | `cls` | Clear the screen |
| `history` | - | Show command history |
| `status` | - | Show Gitu status and statistics |
| `session` | - | Show current session information |
| `clear-session` | - | Clear conversation history |

## Installation

### Prerequisites

- Node.js >= 18.0.0
- PostgreSQL database with Gitu schema
- User account in the NotebookLLM system

### Dependencies

The terminal adapter requires the following npm packages:

```json
{
  "chalk": "^5.3.0",
  "ora": "^8.1.1",
  "readline": "built-in",
  "uuid": "^11.0.5"
}
```

Install dependencies:

```bash
cd backend
npm install chalk@5.3.0 ora@8.1.1
```

## Usage

### Quick Start

```bash
# Run the test script with your user ID
npx tsx src/scripts/test-terminal-adapter.ts <user-id>

# Example
npx tsx src/scripts/test-terminal-adapter.ts test-user-123
```

### Programmatic Usage

```typescript
import { terminalAdapter } from './adapters/terminalAdapter.js';
import { IncomingMessage } from './services/gituMessageGateway.js';

// Initialize the adapter
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: true,
  historySize: 100,
  prompt: 'Gitu> ',
});

// Register message handler
terminalAdapter.onCommand(async (message: IncomingMessage) => {
  console.log('Received:', message.content.text);
  
  // Process with AI service
  const response = await processWithAI(message);
  
  // Send response
  terminalAdapter.sendResponse(response);
});

// Start the REPL
terminalAdapter.startREPL();
```

## Configuration

### TerminalAdapterConfig

```typescript
interface TerminalAdapterConfig {
  userId: string;           // Required: NotebookLLM user ID
  prompt?: string;          // Optional: Custom prompt (default: "Gitu> ")
  historySize?: number;     // Optional: Command history size (default: 100)
  colorOutput?: boolean;    // Optional: Enable colors (default: true)
}
```

### Example Configurations

**Basic Configuration:**
```typescript
await terminalAdapter.initialize({
  userId: 'user-123',
});
```

**Custom Configuration:**
```typescript
await terminalAdapter.initialize({
  userId: 'user-123',
  prompt: '🤖 AI> ',
  historySize: 200,
  colorOutput: true,
});
```

**No Colors (for CI/CD):**
```typescript
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: false,
});
```

## API Reference

### Methods

#### `initialize(config: TerminalAdapterConfig): Promise<void>`

Initialize the terminal adapter with the given configuration.

**Parameters:**
- `config` - Configuration object

**Throws:**
- Error if user doesn't exist in database
- Error if already initialized

**Example:**
```typescript
await terminalAdapter.initialize({
  userId: 'user-123',
  colorOutput: true,
});
```

#### `startREPL(): void`

Start the Read-Eval-Print Loop. This begins accepting user input.

**Throws:**
- Error if not initialized

**Example:**
```typescript
terminalAdapter.startREPL();
```

#### `sendResponse(message: string): void`

Send a response message to the terminal.

**Parameters:**
- `message` - The message to display

**Example:**
```typescript
terminalAdapter.sendResponse('Hello! How can I help you?');
```

#### `onCommand(handler: MessageHandler): void`

Register a message handler to process incoming messages.

**Parameters:**
- `handler` - Function to handle incoming messages

**Example:**
```typescript
terminalAdapter.onCommand(async (message) => {
  const response = await processMessage(message);
  terminalAdapter.sendResponse(response);
});
```

#### `displayProgress(task: string, progress: number): void`

Display a progress indicator for long-running tasks.

**Parameters:**
- `task` - Task description
- `progress` - Progress percentage (0-100)

**Example:**
```typescript
terminalAdapter.displayProgress('Processing request', 50);
// ... do work ...
terminalAdapter.displayProgress('Processing request', 100);
```

#### `getConnectionState(): 'connected' | 'disconnected' | 'error'`

Get the current connection state.

**Returns:**
- Connection state string

**Example:**
```typescript
const state = terminalAdapter.getConnectionState();
console.log(`Connection state: ${state}`);
```

#### `isInitialized(): boolean`

Check if the adapter is initialized.

**Returns:**
- `true` if initialized, `false` otherwise

**Example:**
```typescript
if (terminalAdapter.isInitialized()) {
  terminalAdapter.startREPL();
}
```

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Terminal User                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              readline (Node.js built-in)                 │
│  • Input handling                                        │
│  • Line editing                                          │
│  • History management                                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              terminalAdapter.ts                          │
│  • REPL interface                                        │
│  • Built-in commands                                     │
│  • Progress indicators                                   │
│  • Message handling                                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           gituMessageGateway.ts                          │
│  • Message normalization                                 │
│  • Platform detection                                    │
│  • User resolution                                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           gituSessionService.ts                          │
│  • Session management                                    │
│  • Conversation history                                  │
│  • Context tracking                                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              AI Router / MCP Hub                         │
│  • Model selection                                       │
│  • Tool execution                                        │
│  • Response generation                                   │
└─────────────────────────────────────────────────────────┘
```

### Message Flow

1. **User Input** → User types a message in the terminal
2. **Command Check** → Check if it's a built-in command
3. **Message Creation** → Create RawMessage object
4. **Normalization** → Process through Message Gateway
5. **Handler Notification** → Notify registered handlers
6. **AI Processing** → Route to AI service (in production)
7. **Response Display** → Show response in terminal

## Examples

### Example 1: Basic Chat

```typescript
import { terminalAdapter } from './adapters/terminalAdapter.js';

await terminalAdapter.initialize({ userId: 'user-123' });

terminalAdapter.onCommand(async (message) => {
  // Echo back the message
  terminalAdapter.sendResponse(`You said: ${message.content.text}`);
});

terminalAdapter.startREPL();
```

**Terminal Session:**
```
╔════════════════════════════════════════╗
║     🤖 Gitu Terminal CLI v1.0         ║
╚════════════════════════════════════════╝

Your universal AI assistant in the terminal.
Type help for commands, exit to quit.

Gitu> Hello!
🤖 Gitu: You said: Hello!

Gitu> exit
👋 Goodbye!
```

### Example 2: With Progress Indicators

```typescript
terminalAdapter.onCommand(async (message) => {
  terminalAdapter.displayProgress('Processing request', 0);
  
  // Simulate work
  await new Promise(resolve => setTimeout(resolve, 1000));
  terminalAdapter.displayProgress('Processing request', 50);
  
  await new Promise(resolve => setTimeout(resolve, 1000));
  terminalAdapter.displayProgress('Processing request', 100);
  
  terminalAdapter.sendResponse('Request completed!');
});
```

### Example 3: Integration with AI Service

```typescript
import { gituAIRouter } from './services/gituAIRouter.js';

terminalAdapter.onCommand(async (message) => {
  try {
    // Show processing indicator
    terminalAdapter.displayProgress('Thinking', 0);
    
    // Route to AI
    const response = await gituAIRouter.route({
      userId: message.userId,
      sessionId: message.metadata.sessionId,
      prompt: message.content.text || '',
      context: [],
      taskType: 'chat',
    });
    
    terminalAdapter.displayProgress('Thinking', 100);
    
    // Send response
    terminalAdapter.sendResponse(response.content);
  } catch (error) {
    terminalAdapter.sendResponse(`Error: ${error.message}`);
  }
});
```

## Testing

### Running Tests

```bash
# Run all terminal adapter tests
npm test -- terminalAdapter.test.ts

# Run with coverage
npm test -- --coverage terminalAdapter.test.ts
```

### Test Coverage

The test suite covers:
- ✅ Initialization
- ✅ Connection state
- ✅ Message handler registration
- ✅ Response sending
- ✅ Progress display
- ✅ Interface compliance
- ✅ Method signatures

### Manual Testing

```bash
# Start the test script
npx tsx src/scripts/test-terminal-adapter.ts test-user-123

# Try these commands:
> help
> status
> session
> Hello, Gitu!
> What can you do?
> history
> clear
> exit
```

## Troubleshooting

### Common Issues

**Issue: "User not found" error**
```
Solution: Ensure the user ID exists in the users table:
SELECT id FROM users WHERE id = 'your-user-id';
```

**Issue: Colors not showing**
```
Solution: Check if your terminal supports colors:
- Windows: Use Windows Terminal or PowerShell
- Linux/Mac: Most terminals support colors by default
- Or disable colors: colorOutput: false
```

**Issue: "Readline interface not initialized"**
```
Solution: Call initialize() before startREPL():
await terminalAdapter.initialize({ userId: 'user-123' });
terminalAdapter.startREPL();
```

**Issue: Commands not responding**
```
Solution: Check that message handlers are registered:
terminalAdapter.onCommand(async (message) => {
  // Your handler code
});
```

## Best Practices

### 1. Always Initialize First

```typescript
// ❌ Bad
terminalAdapter.startREPL();

// ✅ Good
await terminalAdapter.initialize({ userId: 'user-123' });
terminalAdapter.startREPL();
```

### 2. Handle Errors Gracefully

```typescript
terminalAdapter.onCommand(async (message) => {
  try {
    const response = await processMessage(message);
    terminalAdapter.sendResponse(response);
  } catch (error) {
    terminalAdapter.sendResponse(`Error: ${error.message}`);
  }
});
```

### 3. Use Progress Indicators for Long Tasks

```typescript
terminalAdapter.onCommand(async (message) => {
  terminalAdapter.displayProgress('Processing', 0);
  
  // Do work...
  
  terminalAdapter.displayProgress('Processing', 100);
  terminalAdapter.sendResponse('Done!');
});
```

### 4. Provide Helpful Responses

```typescript
// ❌ Bad
terminalAdapter.sendResponse('Error');

// ✅ Good
terminalAdapter.sendResponse(
  'I encountered an error processing your request. ' +
  'Please try rephrasing your question or type "help" for assistance.'
);
```

## Security Considerations

### User Authentication

The terminal adapter requires a valid user ID. Always verify:
- User exists in the database
- User has appropriate permissions
- User account is active

### Input Validation

All user input is processed through the Message Gateway, which:
- Sanitizes input
- Validates message format
- Logs all interactions for audit

### Session Security

Sessions are managed by the Session Service, which:
- Isolates user data
- Tracks session activity
- Enforces session timeouts

## Performance

### Memory Usage

- Command history: ~1KB per 100 commands
- Session context: Varies by conversation length
- Readline buffer: Minimal (~1KB)

### Optimization Tips

1. **Limit History Size**: Set `historySize` to a reasonable value (100-200)
2. **Clear Sessions**: Use `clear-session` to free memory
3. **Disable Colors**: Set `colorOutput: false` for CI/CD environments

## Future Enhancements

- [ ] Multi-line input support
- [ ] Tab completion for commands
- [ ] Syntax highlighting for code blocks
- [ ] File upload/download
- [ ] Voice input integration
- [ ] Custom themes
- [ ] Plugin system for custom commands
- [ ] Session persistence across restarts

## Contributing

When contributing to the terminal adapter:

1. Follow the existing code style
2. Add tests for new features
3. Update this documentation
4. Test on multiple platforms (Windows, Linux, macOS)
5. Ensure colors work correctly
6. Handle errors gracefully

## License

Part of the NotebookLLM project. See main LICENSE file.

## Support

For issues or questions:
- Check this documentation
- Review the test files
- Check the main Gitu documentation
- Open an issue on GitHub
