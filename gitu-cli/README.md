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
