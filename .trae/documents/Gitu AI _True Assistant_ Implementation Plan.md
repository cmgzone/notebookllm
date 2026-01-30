# Gitu AI "True Assistant" Upgrade Plan

This plan transforms Gitu into a proactive, secure, and context-aware system with strict role-based access control and persistent knowledge across platforms.

## 1. Security & Permission Hardening (Admin Only Control)

**Goal:** Prevent users from self-granting "Unsandboxed" (Root) access.

* **Database:** Verify `users` table has `role` column (defaults to `'user'`).

* **Permission Manager (`gituPermissionManager.ts`):**

  * Modify `updatePermission` and `grantPermission` to check user role.

  * **Rule:** If `allowUnsandboxed` is requested, query DB: `SELECT role FROM users WHERE id = ?`.

  * **Enforcement:** Throw `403 Forbidden` if role is not `'admin'`.

* **API Routes:** Ensure `PUT /shell/permissions` respects this check.

## 2. Core Architecture Fixes (WhatsApp & AI)

**Goal:** Stability and Configurable Deployments.

* **WhatsApp (`whatsappAdapter.ts`):**

  * **Fix Auth Path:** Change hardcoded `path.join(process.cwd(), ...)` to use `process.env.GITU_WHATSAPP_AUTH_DIR` or default to a persistent volume path.

  * **Fix Reconnection:** Remove the aggressive `fs.rmSync` on generic disconnects. Only clear session on specific `401 Unauthorized` or "Stream Errored" (conflict) events.

* **AI Router (`gituAIRouter.ts`):**

  * **Dynamic Models:** Ensure `DEFAULT_TASK_MODELS` can be overridden by database values (already partially there, but needs to be robust against missing DB entries).

  * **Error Handling:** Wrap provider calls in specific try/catch blocks to return clean errors (e.g., "Context too long" vs "Provider down") instead of generic 500s.

## 3. Knowledge Persistence (Context Awareness)

**Goal:** "NotebookLLM knowledge should persist across all platforms."

* **Context Injection:**

  * Update `gituAIRouter.route()` to accept `notebookId` or `searchQuery`.

  * Implement **Vector Retrieval**: Before sending prompt to AI, query the `chunks` table (embedding search) for relevant knowledge from the user's notebooks.

  * **Injection:** Append top 3-5 relevant chunks to the `system` prompt or `context` array.

* **Result:** WhatsApp/CLI queries will "know" about documents uploaded via the Web Dashboard.

## 4. Sub-Agent System (100 Agents)

**Goal:** "Create up to 100 autonomous sub-agents."

* **New Service:** **`gituAgentManager.ts`**

  * **Table:** Create `gitu_agents` (id, user\_id, task, status, parent\_agent\_id, memory\_context).

  * **Logic:**

    * `spawnAgent(task)`: Creates a new entry.

    * `orchestrator`: A background loop (or cron) that checks active agents, calls `gituAIRouter` for their next step, and executes it.

    * **Limit:** Enforce `COUNT(*) <= 100` per user.

## 5. MCP (Model Context Protocol) & Plugins

**Goal:** "User can add MCP on their dashboard."

* **Plugin System Extension:**

  * Add `type` column to `gitu_plugin_catalog` (value: `'script' | 'mcp'`).

  * **MCP Client:** Implement a generic MCP client in `backend/src/services/mcp/` that connects to user-provided SSE/Stdio endpoints.

  * **Integration:** Expose MCP tools to the `gituAIRouter` so the AI can call them (e.g., "read\_resource", "call\_tool").

## 6. CLI Enhancements ("Code to Source")

**Goal:** "Code through CLI and automatically send output to app as sources and notebooks."

* **CLI Authentication:**

  * Ensure `POST /terminal/link` works with QR code logic.

* **New Endpoint:** **`POST /terminal/source`**

  * **Input:** `code`, `filename`, `notebookId` (optional).

  * **Action:** Inserts the code directly into the `sources` table.

  * **Result:** The code becomes immediately available for RAG/Chat in the web app.

## 7. Execution Order

1. **Security:** Fix Permissions (Critical).
2. **Stability:** Fix WhatsApp & AI Router.
3. **Features:** Implement Knowledge Persistence & CLI "Code-to-Source".
4. **Advanced:** Implement Sub-Agents & MCP Support.

