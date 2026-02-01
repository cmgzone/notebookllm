Based on my analysis of `gituAgentOrchestrator.ts`, I identified **two technical issues** (besides the "swam" typo):

1.  **Incomplete Dependency Orchestration**: 
    The code currently launches "root" tasks (tasks with no dependencies) but lacks the logic to **trigger subsequent tasks** once the initial ones complete. There is no visible event handler that checks for completed tasks and unlocks dependent ones (e.g., "Task B can start now that Task A is done").

2.  **State Persistence Debt**:
    Lines 130-131 explicitly state: `// Update task status in plan (this needs to be persisted in Mission Context really) // For now we just log it.`
    While there is a batch save at the end of the function, the comment suggests the author intended for more robust, immediate persistence.

I propose the following plan to fix these issues:

## 1. Implement Task Completion Trigger
- Create a method `handleTaskCompletion(missionId, taskId)` in `GituAgentOrchestrator`.
- This method will:
    - Mark the specific task as `completed` in the mission plan.
    - Check for any `pending` tasks whose dependencies are now fully met.
    - Call `unleashSwarm` (or a new `dispatchPendingTasks` method) to launch the newly ready agents.

## 2. Improve State Persistence
- Modify `unleashSwarm` to persist task status changes (`in_progress`, `agentId`) immediately when an agent is successfully spawned, rather than waiting for the loop to finish. This prevents state inconsistency if an error occurs mid-loop.

## 3. Verify Flow
- Create a test case (or manual verification plan) where a mission has dependent tasks (Task A -> Task B) to ensure Task B only starts after Task A finishes.
