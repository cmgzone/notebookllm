
import { v4 as uuidv4 } from 'uuid';
import { gituAIRouter, TaskType } from './gituAIRouter.js';
import { gituAgentManager, AgentConfig } from './gituAgentManager.js';
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
                platform: 'orchestrator'
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
     * Activate the swarm based on the plan.
     * Spawns agents for all tasks that have satisfied dependencies.
     */
    async unleashSwarm(userId: string, missionId: string, plan: MissionPlan): Promise<void> {
        // Find tasks ready to execute (no incomplete dependencies)
        // For simplicity in this v1, we just launch all "root" tasks (no dependencies)

        const readyTasks = plan.tasks.filter(t => t.status === 'pending' && t.dependencies.length === 0);

        for (const task of readyTasks) {
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

                // Update task status in plan (this needs to be persisted in Mission Context really)
                // For now we just log it. A robust system would update the plan in DB.
                task.agentId = agent.id;
                task.status = 'in_progress';

            } catch (e) {
                console.error(`[Orchestrator] Failed to spawn agent for task ${task.id}`, e);
            }
        }

        // Persist updated plan to Mission Control
        await gituMissionControl.updateMissionState(missionId, {
            contextUpdates: { plan }
        });

        // Trigger immediate processing of the agent queue so the user doesn't wait for scheduler
        // using the scheduler logic but manually triggered
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

        const agents = await gituAgentManager.listAgents(mission.userId);
        const missionAgents = agents.filter(a => a.memory.missionId === missionId && a.status === 'completed');

        if (missionAgents.length === 0) {
            return "No agents have completed their tasks yet.";
        }

        const agentOutputs = missionAgents.map(a => `Task: ${a.task}\nResult: ${a.result?.output || 'No output'}`).join('\n\n---\n\n');

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
                platform: 'orchestrator'
            });

            // Update Mission Control
            await gituMissionControl.updateMissionState(missionId, {
                status: 'completed',
                completedAt: new Date(),
                artifacts: { finalReport: response.content }
            });

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
