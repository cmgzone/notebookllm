# Gitu CLI

Command-line interface for **Gitu**, your Universal AI Assistant.

## Installation

```bash
npm install -g @notebookllm/gitu-cli
```

## Getting Started

1. **Initialize Configuration**
   Run the interactive setup wizard to connect to your Gitu backend.
   ```bash
   gitu init
   ```

2. **Verify Connection**
   ```bash
   gitu whoami
   ```

## Key Features

### 🤖 AI Chat
Start an interactive chat session with Gitu directly in your terminal.
```bash
gitu chat
```

Inside `gitu chat`, you can also use slash commands:
```text
/help
/whoami
/shell git status
/code "Fix failing tests in backend"
/notebooks
/notebook <id> <question>
/agent list
/agent spawn <task>
```

### 🧠 Notebooks
Manage and query your NotebookLLM knowledge base.
```bash
# List all notebooks
gitu notebook list

# Ask a question to a specific notebook
gitu notebook query <notebook-id> "What are the key takeaways?"
```

### 🕵️ Autonomous Agents
Spawn background agents to perform complex tasks.
```bash
# Spawn a new agent
gitu agent spawn "Research the latest React 19 features"

# List active agents
gitu agent list

# Watch an agent's thought process in real-time
gitu agent watch <agent-id>
```

### ⚡ Quick Commands
Execute single natural language instructions.
```bash
gitu run "List all PDF files in ./documents"
```

## Coding Autonomous Agent (Swarm Mission)

Start an autonomous coding mission that can plan and execute multi-step work:
```bash
gitu code "Implement login endpoint and add tests"
```

Watch mission status:
```bash
gitu mission watch <mission-id>
```

Notes:
- The agent can only run shell/file actions if the backend permissions allow them.
- If Remote Terminal is enabled, some commands may run on your local computer (with local confirmation by default).

## Remote Terminal (Runs Commands On Your Computer)

If you enable Remote Terminal, the backend may send command execution requests to this CLI over a WebSocket connection. Those commands run locally with the same permissions as the user running `gitu`.

- Remote Terminal is **disabled by default**.
- Enable/disable it with:
  - `gitu config remote-terminal on`
  - `gitu config remote-terminal off`
- By default, Remote Terminal requires **local confirmation** before running remote commands:
  - `gitu config remote-confirm on|off`
  - `gitu config remote-allow "<prefix>"` (prefix allowlist, or `*`)

### Admin / “Run as Administrator”

- The CLI **cannot** silently elevate privileges.
- Commands run “as admin” only if you start the CLI as admin (Windows) or use a privileged install/service you configure manually.

### 🐚 Shell Integration
Generate alias scripts for your shell (Bash, Zsh, PowerShell).
```bash
# For PowerShell
gitu alias powershell | Invoke-Expression

# For Bash/Zsh (add to .bashrc)
eval "$(gitu alias bash)"
```
Once configured, you can use the `??` alias:
```bash
?? "How do I undo the last git commit?"
```

## Development

```bash
# Install dependencies
npm install

# Run locally
npm run dev -- <command>
```
