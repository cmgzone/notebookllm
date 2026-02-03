# External MCP in Gitu (User Sandbox)

This project supports running external MCP servers inside a per-user sandbox container, then proxying those MCP tools into Gitu’s tool system.

## What this enables
- Each user gets a dedicated Docker container with a persistent `/workspace`.
- The sandbox has network enabled so the user can install dependencies.
- Gitu can connect to MCP servers started inside the sandbox and expose their tools to the AI.

## User Workflow
### 0) One-step option (install + connect)
Use `auto_install_and_connect_mcp` to install an MCP server in the sandbox and connect it in one call.

Example (npm install into sandbox, then start with node):
```json
{
  "name": "my-tools",
  "install": { "type": "npm", "spec": "@acme/my-mcp-server" },
  "start": { "command": "node", "args": ["/workspace/external-mcp/my-tools/server.js"] },
  "env": { "API_BASE_URL": "https://example.com" }
}
```

Notes:
- `env` is **not persisted** (not stored in DB). Provide it again if you reconnect.
- For git installs, use `https://...` URLs.

### 1) Install tools inside the sandbox
Use the `sandbox_shell_exec` tool to run commands inside the user sandbox container.

Example inputs:
```json
{
  "command": "pwd && ls -la",
  "cwd": "/workspace"
}
```

To install an MCP server inside `/workspace`, run whatever install commands your MCP server requires (npm/pip/git/etc). The sandbox is persistent, so files under `/workspace` remain across restarts.

### 2) Connect an MCP server (stdio)
Use `connect_external_mcp` with:
- `name`: a label for this connection (unique per user)
- `command`: the executable to start the MCP server inside the sandbox
- `args`: optional command args
- `env`: optional env vars for the server

Example:
```json
{
  "name": "my-tools",
  "command": "node",
  "args": ["/workspace/my-mcp-server/index.js"],
  "env": {}
}
```

Gitu registers each remote MCP tool as a new tool named:
`ext_{connectionId}_{toolName}`

### 3) List / disconnect
- `list_external_mcp` shows stored connections for the user.
- `disconnect_external_mcp` stops the MCP session and removes the registered proxy tools.

## Notes
- The sandbox uses Docker. The backend must be able to run Docker commands on the host.
- Shell execution inside the sandbox still respects Gitu’s permission model (resource `shell`, action `execute`).
- For security, external MCP `env` values are not persisted; only env keys are tracked.
