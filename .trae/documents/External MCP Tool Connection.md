## Answer (How users connect external MCP tools)
### A) Today (Already Supported): connect NotebookLLM MCP server to external clients
- Users can connect **Claude Desktop / Kiro / other MCP clients** to NotebookLLM’s MCP server using a stdio config.
- Docs: [MCP_INTEGRATION_GUIDE.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/docs/gitu/MCP_INTEGRATION_GUIDE.md), [README.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/mcp-server/README.md)
- Backend also provides install/config endpoints: [mcpDownload.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/mcpDownload.ts)

### B) What you want: connect any external MCP server *into* Gitu
Right now, Gitu does **not** truly connect out to external MCP servers (the client is a placeholder): [gituMCPClient.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/mcp/gituMCPClient.ts)

You clarified the target design:
- Each user has **their own sandboxed container**
- It includes **sandboxed shell + network**
- Users can install their own MCP servers/tools inside that container

## Refined Implementation Plan (matches your sandbox requirement)
### 1) Create Per-User Sandbox Container Service
- Add a backend service to **ensure a dedicated container per user** (start/reuse/stop).
- Security profile: `--cap-drop=ALL`, `--security-opt=no-new-privileges`, CPU/memory limits, no privileged mode.
- Persistent workspace volume per user for installing MCP servers.
- Build on the Docker security approach already used by [dockerPluginRunner.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/plugins/dockerPluginRunner.ts) (but change from one-shot `--rm` to long-running).

### 2) Run an MCP Proxy inside the Sandbox
- Add a small “mcp-proxy” process that runs **inside the user container** and exposes an HTTP port to the backend.
- The proxy:
  - Accepts “register server” requests: `{ name, command, args, env }`
  - Spawns the external MCP server inside the container (stdio)
  - Uses MCP SDK to `listTools` and `callTool`
  - Keeps sessions alive so tools are fast and reliable

### 3) User-Facing Tools to Manage External MCP
- Add tools in Gitu (server-side tools) to manage connections:
  - `connect_external_mcp` (register server in the sandbox + return discovered tools)
  - `list_external_mcp` (show connected MCP servers + their tools)
  - `disconnect_external_mcp`
- Store configs per-user using the existing DB field from [update_plugins_mcp.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/update_plugins_mcp.sql) (`gitu_plugins.mcp_config`).

### 4) Make External Tools Available to the AI via gituMCPHub
- Extend [gituMCPHub.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMCPHub.ts) to dynamically register proxy tools like:
  - `ext_{connectionId}_{toolName}`
- When called, those tools proxy to the correct sandbox container + MCP proxy.

### 5) Documentation
- Add a new guide in `docs/gitu/` describing:
  - How a user installs an MCP server inside their sandbox
  - How they connect it from chat (connect/list/disconnect)
  - Coolify notes (env formatting, network, troubleshooting)

## Result
- Users can install any MCP server (npm/pip/etc) inside their own sandbox container.
- Gitu can reliably discover and call those tools without needing host shell permissions.
