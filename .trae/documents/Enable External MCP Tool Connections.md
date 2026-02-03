To allow users to connect external MCP tools (like a local weather service or a database connector), I will implement a full integration with the **Model Context Protocol (MCP)** SDK.

### **The Plan**

1.  **Add Dependency:** Add `@modelcontextprotocol/sdk` to the backend's `package.json` to enable real MCP connections.
2.  **Implement MCP Client:** specific logic in `backend/src/services/mcp/gituMCPClient.ts` to:
    *   Establish connections via `StdioClientTransport` (for local executables).
    *   Discover tools from the external server (`listTools`).
    *   Execute tools on the external server (`callTool`).
3.  **Create Connection Tool:** Add a new tool `connect_external_mcp` to `backend/src/services/pluginMCPTools.ts`.
    *   This allows the user to say: *"Connect to the weather MCP server running at /usr/bin/weather-mcp"*
    *   It saves the configuration as a persistent "Plugin" in the database.
4.  **Update MCP Hub:** Modify `backend/src/services/gituMCPHub.ts` to:
    *   Load these external MCP plugins on startup.
    *   Dynamically register their tools into the Gitu ecosystem (proxying requests to the external server).

### **Why this works**
*   **Unified Interface:** External tools will appear just like native Gitu tools to the AI.
*   **Persistence:** Connections are saved as plugins, so they persist across restarts.
*   **Extensibility:** Users can bring any standard MCP server into Gitu.

I will start by updating the `package.json` and then implementing the client and tools.
