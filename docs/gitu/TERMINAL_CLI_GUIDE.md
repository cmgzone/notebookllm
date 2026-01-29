# Gitu Terminal CLI Guide

Bring the power of Gitu to your command line. The Terminal CLI allows you to chat with AI, manage tasks, and control your workspace without leaving your terminal.

## Installation

```bash
npm install -g gitu-cli
# or run directly via npx
npx gitu
```

## Authentication

Before using the CLI, you must link it to your Gitu account.

### Method 1: QR Code (Recommended)
1. Run:
   ```bash
   gitu auth --qr
   ```
2. Open the **NotebookLLM App** on your phone.
3. Go to **Settings > Terminal Connections > Scan QR Code**.
4. Scan the code displayed in your terminal.

### Method 2: Pairing Token
1. In the **NotebookLLM App**, go to **Settings > Terminal Connections**.
2. Tap **Generate Token**.
3. Run:
   ```bash
   gitu auth <your-token>
   ```

## Basic Usage

Start the interactive session:
```bash
gitu
```

Once inside the REPL (Read-Eval-Print Loop), you can type naturally:
```text
Gitu> Help me write a Python script to scrape a website.
Gitu> Summarize the README file in the current directory.
Gitu> Check my latest notifications.
```

## Commands

### Session Management
- `help`: Show available commands.
- `status`: Display connection status, user info, and usage stats.
- `session`: View current session details.
- `clear`: Clear the terminal screen.
- `clear-session`: Reset the conversation memory.
- `history`: Show your command history.
- `exit` / `quit`: Close the CLI.

### Model Management
Switch between different AI models directly from the CLI.

- List available models:
  ```bash
  gitu model list
  ```
- Set a preferred model:
  ```bash
  gitu model set <model_id>
  # Example: gitu model set claude-3-opus
  ```
- Check current model:
  ```bash
  gitu model get
  ```

### Authentication Commands
- `gitu auth status`: Check if you are currently logged in.
- `gitu auth refresh`: Manually refresh your access token.
- `gitu auth logout`: Unlink the current terminal.

## Tips
- **Context Awareness**: Gitu in the terminal can be aware of your current directory and project context if configured.
- **Rich Output**: The CLI supports Markdown rendering, code highlighting, and spinners for long-running tasks.
