
import { v4 as uuidv4 } from 'uuid';
import { gituAIRouter, TaskType } from './gituAIRouter.js';
import { gituAgentManager, AgentConfig } from './gituAgentManager.js';
import { gituEvaluationService } from './gituEvaluationService.js';
import { gituMissionControl, Mission, MissionStatus } from './gituMissionControl.js';

export interface MissionPlan {
    objective: string;
    tasks: SwarmTask[];
    strategy: 'parallel' | 'sequential' | 'hierarchical';
}

export interface SwarmTask {
    id: string;
    description: string;
    role: string; // e.g. "Researcher", "Coder"
    dependencies: string[]; // IDs of tasks that must complete first
    agentId?: string;
    blockedBy?: string[]; // Failed dependency IDs
    status: 'pending' | 'in_progress' | 'completed' | 'failed';
}

class GituAgentOrchestrator {
    /**
     * Create and plan a new mission.
     * Uses AI to decompose the high-level objective into a dependency graph.
     */
    async createMission(userId: string, objective: string): Promise<Mission> {
        // 1. Create the mission container
        const mission = await gituMissionControl.createMission(userId, 'Mission: ' + objective.substring(0, 30), objective);

        // 2. AI Planning Step (Decomposition)
        console.log(`[Orchestrator] Planning mission ${mission.id}: ${objective}`);

        // We ask the AI to break it down into tasks
        const prompt = `
      OBJECTIVE: ${objective}
      
      You are the Gitu Swarm Orchestrator. 
      Break this objective down into a set of distinct, actionable tasks for a team of autonomous agents.
      
      Return a JSON object with this structure:
      {
        "strategy": "parallel" | "sequential",
        "tasks": [
          {
            "id": "task_1",
            "description": "Detailed instruction for the agent",
            "role": "coder" | "researcher" | "writer" | "reviewer",
            "dependencies": [] 
          }
        ]
      }
      
      Keep it efficient. Max 5 initial tasks.
    `;

        try {
            const response = await gituAIRouter.route({
                userId,
                prompt,
                taskType: 'analysis',
                platform: 'terminal'
            });

            // Parse AI plan
            const plan = this.parsePlan(response.content);

            // Ensure all tasks have a status of 'pending' if not provided by AI
            plan.tasks = plan.tasks.map(t => ({
                ...t,
                status: t.status || 'pending',
                dependencies: t.dependencies || []
            }));

            // Update Mission Control with the plan
            await gituMissionControl.updateMissionState(mission.id, {
                status: 'active',
                contextUpdates: {
                    plan,
                    swarmState: 'deployed'
                },
                logEntry: `Mission planned: ${plan.tasks.length} tasks generated.`
            });

            // 3. Spawns Initial Agents (Roots of dependency graph)
            await this.unleashSwarm(userId, mission.id, plan);

            return await gituMissionControl.getMission(mission.id) as Mission;

        } catch (error: any) {
            console.error('[Orchestrator] Planning failed:', error);
            await gituMissionControl.updateMissionState(mission.id, {
                status: 'failed',
                logEntry: `Planning failed: ${error.message}`
            });
            throw error;
        }
    }

    /**
     * Handle the completion of a task by an agent.
     * Triggers dependent tasks or mission synthesis.
     */
    async handleTaskCompletion(missionId: string, agentId: string): Promise<void> {
        console.log(`[Orchestrator] Handling completion for mission ${missionId}, agent ${agentId}`);
        const mission = await gituMissionControl.getMission(missionId);
        if (!mission) {
            console.error(`[Orchestrator] Mission ${missionId} not found`);
            return;
        }

        const plan = mission.context.plan as MissionPlan;
        if (!plan) {
            console.error(`[Orchestrator] Mission plan not found for ${missionId}`);
            return;
        }

        // 1. Refresh task states from current agent statuses (avoids stale/concurrent overwrites)
        const agents = await gituAgentManager.listAgentsByMission(mission.userId, missionId);
        const agentsById = new Map(agents.map(a => [a.id, a]));

        const normalizedTasks: SwarmTask[] = plan.tasks.map(t => {
            const dependencies = Array.isArray(t.dependencies) ? t.dependencies : [];
            let status: SwarmTask['status'] = t.status || 'pending';

            const agent = t.agentId ? agentsById.get(t.agentId) : undefined;
            if (agent) {
                if (agent.status === 'completed') status = 'completed';
                else if (agent.status === 'failed') status = 'failed';
                else if (agent.status === 'active') status = 'in_progress';
                else if (agent.status === 'pending') status = 'pending';
            }

            return { ...t, status, dependencies };
        });

        const completedTaskIds = new Set(normalizedTasks.filter(t => t.status === 'completed').map(t => t.id));
        const failedTaskIds = new Set(normalizedTasks.filter(t => t.status === 'failed').map(t => t.id));

        const tasksWithBlocked: SwarmTask[] = normalizedTasks.map(t => {
            if (t.status !== 'pending') return t;
            const failedDeps = t.dependencies.filter(depId => failedTaskIds.has(depId));
            if (failedDeps.length === 0) return t;
            return { ...t, status: 'failed', blockedBy: failedDeps };
        });

        const completedTaskIdsFinal = new Set(tasksWithBlocked.filter(t => t.status === 'completed').map(t => t.id));
        const pendingTasks = tasksWithBlocked.filter(t => t.status === 'pending');
        const readyTasks = pendingTasks.filter(t => t.dependencies.every(depId => completedTaskIdsFinal.has(depId)));
        const allTerminal = tasksWithBlocked.length > 0 && tasksWithBlocked.every(t => t.status === 'completed' || t.status === 'failed');

        const updatedPlan: MissionPlan = { ...plan, tasks: tasksWithBlocked };

        // 2. Persist updated plan
        await gituMissionControl.updateMissionState(missionId, {
            contextUpdates: { plan: updatedPlan }
        });

        // 3. Check for dependent tasks to launch or synthesize
        if (readyTasks.length > 0) {
            console.log(`[Orchestrator] Unlocking ${readyTasks.length} dependent tasks`);
            await this.dispatchTasks(mission.userId, missionId, updatedPlan, readyTasks);
        } else if (allTerminal) {
            console.log(`[Orchestrator] All tasks terminal. Synthesizing results.`);
            await this.synthesizeMissionResults(missionId);
        }
    }

    /**
     * Activate the swarm based on the plan.
     * Spawns agents for all tasks that have satisfied dependencies.
     */
    async unleashSwarm(userId: string, missionId: string, plan: MissionPlan): Promise<void> {
        // Find tasks ready to execute (no incomplete dependencies)
        // For simplicity in this v1, we just launch all "root" tasks (no dependencies)
        const readyTasks = plan.tasks.filter(t => t.status === 'pending' && t.dependencies.length === 0);
        await this.dispatchTasks(userId, missionId, plan, readyTasks);
    }

    /**
     * Internal helper to dispatch specific tasks
     */
    private async dispatchTasks(userId: string, missionId: string, plan: MissionPlan, tasks: SwarmTask[]): Promise<void> {
        for (const task of tasks) {
            console.log(`[Orchestrator] Spawning agent for task: ${task.description}`);

            const config: AgentConfig = {
                role: 'autonomous_agent',
                focus: task.role,
                missionId: missionId,
                autoLoadPlugins: true,
                initialMemory: {
                    taskDescription: task.description,
                    taskId: task.id
                }
            };

            try {
                const agent = await gituAgentManager.spawnAgent(userId, task.description, config);

                // Register agent with Mission Control
                await gituMissionControl.registerAgent(missionId);

                // Update task status and persist IMMEDIATELY
                task.agentId = agent.id;
                task.status = 'in_progress';
                
                await gituMissionControl.updateMissionState(missionId, {
                    contextUpdates: { plan }
                });

            } catch (e) {
                console.error(`[Orchestrator] Failed to spawn agent for task ${task.id}`, e);
            }
        }

        // Trigger immediate processing of the agent queue
        try {
            await gituAgentManager.processAgentQueue(userId);
        } catch (e) {
            console.error('[Orchestrator] Failed to trigger immediate agent processing', e);
        }
    }

    /*
   * Aggregate results from all agents into a final report.
   */
    async synthesizeMissionResults(missionId: string): Promise<string> {
        const mission = await gituMissionControl.getMission(missionId);
        if (!mission) throw new Error('Mission not found');

        const agents = await gituAgentManager.listAgentsByMission(mission.userId, missionId);
        const completedAgents = agents.filter(a => a.status === 'completed');
        const failedAgents = agents.filter(a => a.status === 'failed');
        const missionAgents = [...completedAgents, ...failedAgents];

        if (missionAgents.length === 0) {
            return "No agent outputs available yet.";
        }

        const agentOutputs = missionAgents.map(a => {
            const output = a.result?.output || a.result?.error || 'No output';
            return `Task: ${a.task}\nStatus: ${a.status}\nResult: ${output}`;
        }).join('\n\n---\n\n');

        // Use AI to synthesize
        try {
            const response = await gituAIRouter.route({
                userId: mission.userId,
                prompt: `
           MISSION: ${mission.objective}
           
           BELOW ARE THE RESULTS FROM THE SWARM AGENTS:
           
           ${agentOutputs}
           
           SYNTHESIZE THESE RESULTS INTO A FINAL PROFESSIONAL REPORT.
           Focus on the outcome and actionable next steps.
         `,
                taskType: 'chat',
                platform: 'terminal'
            });

            // Update Mission Control
            await gituMissionControl.updateMissionState(missionId, {
                status: 'completed',
                completedAt: new Date(),
                artifacts: { finalReport: response.content }
            });

            const plan = mission.context.plan as MissionPlan | undefined;
            const allTasksCompleted = Boolean(plan?.tasks?.length) && plan!.tasks.every(t => t.status === 'completed');
            const finalReportPresent = typeof response.content === 'string' && response.content.trim().length > 0;

            try {
                await gituEvaluationService.createMissionCompletionEvaluation({
                    userId: mission.userId,
                    missionId: mission.id,
                    agentCount: mission.agentCount,
                    allTasksCompleted,
                    finalReportPresent
                });
            } catch (e) {
                console.error(`[Orchestrator] Failed to store mission evaluation for ${missionId}`, e);
            }

            return response.content;
        } catch (e: any) {
            console.error('Synthesis failed:', e);
            return "Failed to synthesize results.";
        }
    }

    /*
     * Helper to parse AI JSON response
     */
    private parsePlan(content: string): MissionPlan {
        try {
            const jsonMatch = content.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]) as MissionPlan;
            }
            throw new Error('No JSON found');
        } catch (e) {
            console.warn('[Orchestrator] Failed to parse strict JSON plan. Raw content:', content.substring(0, 500));
            console.warn('[Orchestrator] Falling back to single task.');
            // Fallback: Create a single task for the whole objective
            return {
                objective: 'Execute Task',
                strategy: 'sequential',
                tasks: [
                    {
                        id: 'task_1',
                        description: 'Execute the user request to the best of your ability.',
                        role: 'generalist',
                        dependencies: [],
                        status: 'pending'
                    }
                ]
            };
        }
    }
}

export const gituAgentOrchestrator = new GituAgentOrchestrator();
