# Gitu Terminal CLI Guide

Bring the power of Gitu to your command line. The Terminal CLI allows you to chat with AI, manage tasks, and control your workspace without leaving your terminal.

## Two Different CLIs

This repo includes two terminal experiences:
- **Standalone CLI (`gitu-cli/`)**: connects to the backend via HTTP/WebSockets and can optionally run commands on your local computer (Remote Terminal).
- **Backend REPL adapter (`backend/src/adapters/terminalAdapter.ts`)**: a developer REPL that runs inside the backend process.

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

### Chat Slash Commands (Standalone `gitu chat`)

Inside `gitu chat`, you can use these slash commands:
- `/help`: Show available slash commands
- `/whoami`: Show current user
- `/shell <command>`: Execute a shell command (backend or Remote Terminal)
- `/code <objective>`: Start a coding autonomous agent mission (swarm)
- `/notebooks`: List notebooks
- `/notebook <id> <question>`: Query a notebook
- `/agent list`: List agents
- `/agent spawn <task>`: Spawn an agent
- `/config show`: Print CLI config summary
- `/remote on|off`: Enable/disable Remote Terminal
- `/confirm on|off`: Require/disable local confirmation for remote commands
- `/allow <prefix|*>`: Add remote allow rule
- `/allow-clear`: Clear remote allow rules
- `/clear`: Clear screen
- `/exit`: Exit chat

## Tips
- **Context Awareness**: Gitu in the terminal can be aware of your current directory and project context if configured.
- **Rich Output**: The CLI supports Markdown rendering, code highlighting, and spinners for long-running tasks.

## Security Notes (Remote Terminal + Admin)

- If you enable Remote Terminal on the standalone CLI, the backend may send command execution requests to your machine. Those commands run with the permissions of the local user running the CLI.
- The CLI cannot silently elevate privileges. To run commands as admin, you must start the CLI as admin (Windows) or set up a privileged helper/service yourself.

## Coding Autonomous Agent (Swarm)

You can start a multi-step coding mission from the CLI:
```bash
gitu code "Fix the failing tests and open a PR-ready change"
```

Watch progress:
```bash
gitu mission watch <mission-id>
```
