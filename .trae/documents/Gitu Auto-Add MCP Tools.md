## Can Gitu add MCP tools by itself?
Yes, but it depends what “add” means:

### 1) Add new *built-in* MCP tools (server code)
- **Not by itself at runtime.** Those tools are compiled into the backend and registered on startup. Adding a new built-in tool requires a code change + redeploy.
- Example of built-in registration: [index.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/index.ts), tool registry: [gituMCPHub.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMCPHub.ts)

### 2) Add *user-level tools* without redeploy (recommended)
Gitu can effectively “add tools” in two ways already:
- **Plugins (JS/container):** Gitu can generate and create plugins via tool APIs (these act like new capabilities). See tool registration: [pluginMCPTools.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/pluginMCPTools.ts).
- **External MCP tools in a user sandbox:** If the MCP server runs inside the user’s sandbox container, Gitu can connect and expose its tools automatically.
  - Connect flow + sandbox shell exec: [externalMCPTools.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/externalMCPTools.ts)
  - Sandbox manager: [gituUserSandboxService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituUserSandboxService.ts)
  - Usage guide: [EXTERNAL_MCP_SANDBOX.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/docs/gitu/EXTERNAL_MCP_SANDBOX.md)

## Improvement Plan (make it truly “by itself”)
Implement one higher-level tool so users don’t manually run multiple steps:

### A) Add `auto_install_and_connect_mcp`
- Inputs: `{ name, install: { type: 'npm'|'git'|'pip', spec }, start: { command, args }, env }`
- Behavior:
  1. Uses `sandbox_shell_exec` to install dependencies into `/workspace`.
  2. Calls `connect_external_mcp` to register the MCP server.
  3. Returns the discovered tools and their new names.

### B) Add guardrails
- Require `shell.execute` permission for sandbox installation.
- Restrict install commands to a safe allowlist (npm/pip/git + specific flags).
- Never log or store secrets; pass them only via `env`.

### C) Update docs
- Add examples for npm/git/pip installs and common troubleshooting.

If you confirm, I will implement `auto_install_and_connect_mcp` + guardrails + docs update.