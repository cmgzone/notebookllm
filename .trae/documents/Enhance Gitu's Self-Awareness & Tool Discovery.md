Based on the codebase analysis, I have identified the root cause of why Gitu claims it needs shell permissions for GitHub tools, even though it shouldn't.

### **Root Cause Analysis**
1.  **Tool Existence:** The GitHub tools (`github_list_repos`, `github_get_tree`, etc.) **are defined** in `backend/src/services/githubMCPTools.ts`.
2.  **Tool Registration:** They are **correctly registered** in `backend/src/index.ts` via `registerGitHubTools()`.
3.  **The "Shell Permission" Confusion:**
    *   The user asked "gitu list github repo".
    *   The AI likely **hallucinated** that it needs to run a shell command (e.g., `git ls-remote` or `curl`) because it might not have "seen" or "selected" the `github_list_repos` tool in its context for that specific turn, or it has a strong bias towards CLI commands when hearing "list repo".
    *   There is **no code** in the GitHub tools that checks for shell permissions. They purely use `githubService` (API based).
    *   However, if the AI *tries* to use a shell tool (like `run_command` from `shellMCPTools.ts`), *that* tool definitely checks for permissions/safety.

### **Why Gitu is "Unaware"**
*   **Prompt Context:** If the list of tools is too long, the LLM context might be truncating them, or the `gituAIRouter` might not be injecting them if the intent isn't clear.
*   **System Prompt:** The system prompt might not be emphasizing these tools enough.

### **Plan to "Improve" Gitu's Awareness**
To fix this, we need to ensure the AI prioritizes the MCP tools over shell commands for GitHub tasks.

1.  **Clarify Tool Descriptions:** Update `githubMCPTools.ts` descriptions to be more explicit (e.g., "Use this tool to list repositories. Do NOT use shell commands.").
2.  **Verify Injection:** Ensure `gituAIRouter.ts` is actually passing these tools to the model. (Already verified in `index.ts` -> `gituMCPHub`).
3.  **Address "How many agents" query:** The user also asked "how many ai agent are working".
    *   There is **no tool** currently exposed to the AI to check the status of the `GituAgentManager` queue.
    *   **Action:** I will create a new MCP tool `gitu_get_agent_status` in `backend/src/services/agentMCPTools.ts` (new file) or add it to `backend/src/services/gituMCPHub.ts` that exposes `gituAgentManager.getQueueStatus()`.

### **Implementation Steps**
1.  **Create `gitu_get_agent_status` Tool:**
    *   Allow the AI to inspect its own swarm state (active agents, pending tasks).
    *   Register this tool in `index.ts`.
2.  **Refine GitHub Tool Descriptions:**
    *   Modify `backend/src/services/githubMCPTools.ts` to explicitly guide the AI to use these tools instead of shell commands.

This will directly address the user's complaint that "some tools gitu is not aware of" and fix the "shell permission" hallucination.
