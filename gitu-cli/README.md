# Gitu CLI

Command-line interface for **Gitu**, your Universal AI Assistant.

## Installation

```bash
npm install -g @cmgzone/gitu-cli
```

### Windows One-Liner Install

```powershell
irm https://raw.githubusercontent.com/cmgzone/gitucli/HEAD/scripts/install-cli.ps1 | iex
```

### Cross-Platform PowerShell One-Liner

```bash
pwsh -NoProfile -Command "irm https://raw.githubusercontent.com/cmgzone/gitucli/HEAD/scripts/install-cli.ps1 | iex"
```

### macOS / Linux One-Liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/cmgzone/gitucli/HEAD/scripts/install-cli.sh | bash
```

### Install From GitHub Release

If you publish `@cmgzone/gitu-cli` as a GitHub Release asset (`cmgzone-gitu-cli-<version>.tgz`), users can install it with:

```bash
npm install -g https://github.com/cmgzone/gitucli/releases/download/v1.2.3/cmgzone-gitu-cli-1.2.3.tgz
```

### Install From GitHub Packages (npm.pkg.github.com)

Create or update your user `.npmrc`:

```text
@cmgzone:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN
```

Then install:

```bash
npm install -g @cmgzone/gitu-cli
```

### Install From Your Own Registry (Self-Hosted)

If you run an npm-compatible registry on your own server (example: `backend.taskiumnetwork.com`), configure your user `.npmrc`:

```text
@cmgzone:registry=https://backend.taskiumnetwork.com/
```

Then install:

```bash
npm install -g @cmgzone/gitu-cli
```

Setup guide: [SELF_HOSTED_REGISTRY.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/gitu-cli/SELF_HOSTED_REGISTRY.md)

### Direct Download From Your Server (No npm registry)

If you want users to download/install directly from your server (standalone binaries or a `.tgz`), see:

- [SELF_HOSTED_DOWNLOADS.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/gitu-cli/SELF_HOSTED_DOWNLOADS.md)

### Standalone Binaries (No Node.js required)

You can download standalone executables for Windows, macOS, and Linux from the [Releases](https://github.com/cmgzone/gitucli/releases) page.

**Windows:**
Download `gitu-win-x64.exe`, rename it to `gitu.exe` (optional), and run it from your terminal. Add it to your PATH for global access.

**macOS:**
Download `gitu-macos-x64`.
```bash
chmod +x gitu-macos-x64
mv gitu-macos-x64 /usr/local/bin/gitu
```

**Linux:**
Download `gitu-linux-x64`.
```bash
chmod +x gitu-linux-x64
mv gitu-linux-x64 /usr/local/bin/gitu
```

## Getting Started

1. **Initialize Configuration**
   Run the interactive setup wizard to connect to your Gitu backend.
   ```bash
   gitu init
   ```

2. **Onboarding (Recommended)**
   Link your device, configure Remote Terminal, and request permissions:
   ```bash
   gitu onboard
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

## Permissions

List permissions:
```bash
gitu permissions list
```

Request shell execution permission (example):
```bash
gitu permissions request --resource shell --actions execute --allowed-commands "git ,npm " --reason "Run tasks" --allow-unsandboxed
```

## WhatsApp / Telegram Linking (Backend-Managed)

WhatsApp:
```bash
gitu whatsapp connect
gitu whatsapp link-current
```

Telegram:
```bash
gitu telegram status
gitu telegram link <telegramUserId>
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

## GitHub Release Publishing (Maintainer)

This repo includes a GitHub Actions workflow that creates a release when you push a tag like:

```bash
git tag v1.2.3
git push origin v1.2.3
```

It uploads:
- `cmgzone-gitu-cli-<version>.tgz` (installable with npm)
- `SHA256SUMS.txt`
