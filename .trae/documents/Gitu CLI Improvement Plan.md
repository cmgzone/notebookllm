Based on the current state of `gitu-cli` (which focuses on configuration and session management), I have designed a comprehensive improvement plan to transform it into a full-featured **AI Command Center**.

### **Phase 1: Core AI Capabilities (High Priority)**

* **`gitu chat`** **(Interactive Mode):**

  * Launch a real-time chat session with Gitu directly in the terminal.

  * Support Markdown rendering (bold, code blocks) in the terminal output.

  * Maintain conversation history context.

* **`gitu agent`** **(Autonomous Agents):**

  * `gitu agent spawn "<task>"`: Create a new background agent (e.g., "Research React 19 features").

  * `gitu agent list`: View all active/completed agents.

  * `gitu agent logs <id>`: Watch the "thought process" of a running agent in real-time.

### **Phase 2: Developer Productivity**

* **`gitu run "<command>"`:**

  * Execute a single natural language instruction without entering chat mode.

  * *Example:* `gitu run "Explain the error in ./app.log"`

* **`gitu notebook`:**

  * `gitu notebook list`: Show your available NotebookLLM notebooks.

  * `gitu notebook query <id> "<question>"`: Ask a question to a specific notebook.

* **Shell Integration:**

  * Add a `??` alias (or similar) to quickly ask Gitu for shell command suggestions (e.g., `?? how to undo git commit`).

### **Phase 3: Visual & UX Enhancements**

* **Rich Output:** Use `cli-table3` for formatted lists (sessions, agents).

* **Spinners:** Add `ora` spinners for all async operations (currently partially implemented).

* **Interactive Config:** Use `inquirer` for a guided `gitu init` setup process instead of manual `set-token` commands.

## **Implementation Plan**

I propose we start by implementing the **`gitu agent`** suite of commands immediately, as this extends the work we just finished on the backend.

### **Step 1: Create** **`src/commands/agent.ts`**

* **`list`**: Fetch agents from `GET /api/gitu/agents`. Display in a table.

* **`spawn`**: Post to `POST /api/gitu/agents`. Show the new Agent ID.

* **`watch`**: Poll `GET /api/gitu/agents/<id>` and stream the "memory/thoughts" to the console.

### **Step 2: Register Commands in** **`src/cli.ts`**

* Wire up the new `agent` command group to the main program.

### **Step 3: Verification**

* Run `gitu agent spawn "Test CLI agent"` and verify it appears in the list.

**Shall I proceed with implementing the** **`gitu agent`** **commands? **
