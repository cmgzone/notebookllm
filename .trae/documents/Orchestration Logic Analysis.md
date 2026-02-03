To address the issue of agents remaining "pending" and getting stuck, I propose the following improvements to the orchestration and scheduling logic:

### **1. Parallelize Agent Processing (`gituAgentManager.ts`)**
**Current Issue:** Agents are processed sequentially in a loop. If one agent hangs (e.g., slow tool or infinite loop), it blocks the entire batch, leaving other agents "pending".
**Fix:**
*   Refactor `processAgentQueue` to execute agents **in parallel** using `Promise.allSettled`.
*   Implement a **30-second timeout** for each agent's execution step. If an agent takes too long, it will be interrupted, preventing it from blocking the queue.

### **2. Accelerate Scheduler Frequency (`gituScheduler.ts`)**
**Current Issue:** The scheduler runs every **60 seconds**. This creates a significant delay between an agent being spawned and its first execution, and between subsequent steps.
**Fix:**
*   Reduce the scheduler tick interval from **60s to 10s**. This ensures "pending" agents are picked up almost immediately and "active" agents make progress much faster.

### **3. Instant Trigger on Spawn (`gituAgentManager.ts`)**
**Current Issue:** When a new agent is spawned, it waits for the next scheduler tick (up to 60s) unless the orchestrator manually triggers the queue.
**Fix:**
*   Modify `spawnAgent` to **immediately trigger** `processAgentQueue` (fire-and-forget). This ensures the agent starts working the moment it is created.

### **4. Stuck Agent Recovery**
**Current Issue:** If an agent crashes without updating its status, it might remain "active" forever, consuming one of the 5 concurrency slots.
**Fix:**
*   Update the queue query to prioritize "pending" agents if "active" agents haven't updated their heartbeat (timestamp) in the last 5 minutes. (Or simply rely on the timeout logic to ensure they update or fail).

### **Execution Plan**
1.  **Modify `backend/src/services/gituAgentManager.ts`**:
    *   Refactor `processAgentQueue` for concurrency and timeouts.
    *   Add immediate trigger to `spawnAgent`.
2.  **Modify `backend/src/services/gituScheduler.ts`**:
    *   Change interval to 10 seconds.
