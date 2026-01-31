import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

import { gituAIRouter } from './gituAIRouter.js';
import { gituMessageGateway } from './gituMessageGateway.js';
import { gituMCPHub } from './gituMCPHub.js';
import { gituSystemPromptBuilder } from './gituSystemPromptBuilder.js';

export interface GituAgent {
  id: string;
  userId: string;
  parentAgentId?: string;
  task: string;
  status: 'pending' | 'active' | 'completed' | 'failed' | 'paused';
  memory: Record<string, any>;
  result?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}



/**
 * Configuration for spawning a specialized agent
 */
export interface AgentConfig {
  role: 'autonomous_agent';
  focus: string; // e.g., "coding", "research"
  missionId?: string;
  parentAgentId?: string;
  systemPromptOverride?: string;
  autoLoadPlugins?: boolean;
  initialMemory?: Record<string, any>;
}

export class GituAgentManager {
  private readonly MAX_AGENTS_PER_USER = 100; // Increased limit for swarms

  /**
   * Spawn a new autonomous agent.
   */
  async spawnAgent(userId: string, task: string, config: AgentConfig): Promise<GituAgent> {
    // Check limit
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM gitu_agents WHERE user_id = $1 AND status NOT IN ('completed', 'failed')`,
      [userId]
    );
    const activeCount = parseInt(countResult.rows[0].count, 10);

    if (activeCount >= this.MAX_AGENTS_PER_USER) {
      throw new Error(`Agent limit reached (${this.MAX_AGENTS_PER_USER}). Please wait for agents to finish.`);
    }

    const id = uuidv4();

    // Initialize memory with config context
    const memory = {
      history: [],
      focus: config.focus,
      missionId: config.missionId,
      autoLoadPlugins: config.autoLoadPlugins ?? true,
      ...config.initialMemory
    };

    const result = await pool.query(
      `INSERT INTO gitu_agents (id, user_id, parent_agent_id, task, status, memory)
         VALUES ($1, $2, $3, $4, 'pending', $5)
         RETURNING *`,
      [id, userId, config.parentAgentId, task, JSON.stringify(memory)]
    );

    return this.mapRowToAgent(result.rows[0]);
  }

  /**
   * Process the queue of active/pending agents for a user.
   * This is called by the scheduler.
   */
  async processAgentQueue(userId: string): Promise<void> {
    const agentsResult = await pool.query(
      `SELECT * FROM gitu_agents 
       WHERE user_id = $1 AND status IN ('pending', 'active')
       ORDER BY updated_at ASC
       LIMIT 5`, // Process up to 5 agents per tick per user
      [userId]
    );

    const agents = agentsResult.rows.map(this.mapRowToAgent);

    for (const agent of agents) {
      try {
        // Mark as active if pending
        if (agent.status === 'pending') {
          await this.updateAgentStatus(agent.id, 'active');
        }

        // Execute "Brain" step
        await this.executeAgentStep(agent);

      } catch (error: any) {
        console.error(`Error processing agent ${agent.id}:`, error);
        await this.updateAgentStatus(agent.id, 'failed', { error: error.message });

        // Notify user of failure
        await gituMessageGateway.notifyUser(
          agent.userId,
          `❌ **Agent Task Failed**\n\n*Task:* ${agent.task}\n\n*Error:* ${error.message}`
        );
      }
    }
  }

  /**
   * Execute a single cognitive step for an agent.
   */
  /**
   * Execute a single cognitive step for an agent.
   */
  private async executeAgentStep(agent: GituAgent): Promise<void> {
    const history = (agent.memory.history as any[]) || [];

    // 1. Build System Prompt with Tools
    const promptResult = await gituSystemPromptBuilder.buildSystemPrompt({
      userId: agent.userId,
      platform: 'agent_process',
      includeTools: true,
      includeMemories: true,
    });

    // 2. Add specific agent instructions
    const agentInstructions = `
      You are an autonomous Gitu Agent working on a background task.
      
      YOUR TASK: ${agent.task}
      
      STATUS:
      - ID: ${agent.id}
      - Steps taken: ${history.length}
      
      INSTRUCTIONS:
      1. Review the history of your actions.
      2. Use available tools to make progress on the task.
      3. If the task is COMPLETED, respond with "DONE" and a summary of the result.
      4. If you cannot complete the task, respond with "FAILED" and the reason.
      5. Otherwise, act on the next step.
      
      Use the defined tool call format for any actions.
    `;

    // 3. Construct Messages
    const messages = [
      { role: 'system', content: promptResult.systemPrompt + '\n\n' + agentInstructions },
      ...history.map(h => ({ role: h.role, content: h.content })),
    ];

    // 4. Call AI
    const aiResponse = await gituAIRouter.route({
      userId: agent.userId,
      prompt: 'Execute next step', // Dummy prompt, real context is in messages
      context: messages.map(m => `${m.role}: ${m.content}`), // Legacy adapter for router, or better: use router correctly
      // Actually, gituAIRouter.route() is a bit high level. Let's use aiService directly or adapt route()
      // For now, allow route() to handle it but we need to ensure it sees the system prompt.
      // previous implementation of route() handles system prompt via includeSystemPrompt,
      // but we built our own here. Let's disable the router's auto-system-prompt.
      includeSystemPrompt: false, // We manually built it
      taskType: 'coding', // Agents usually do complex work
    });

    // We need to inject our custom messages into route() or use a lower level.
    // gituAIRouter.route takes `prompt` and `context`.
    // Let's rely on the router's built-in system prompt builder by passing includeSystemPrompt: true but customized?
    // Actually, let's just stick to the pattern: pass the task as the prompt.

    const response = await gituAIRouter.route({
      userId: agent.userId,
      prompt: `Context: ${JSON.stringify(history.slice(-5))}\n\nTask: ${agent.task}\n\nExecute the next step. If done, say DONE.`,
      taskType: 'coding',
      platform: 'agent',
      includeSystemPrompt: true, // Let router build the standard Gitu prompt + tools
      includeTools: true,
    });

    // 5. Parse and Execute Tools
    const content = response.content;
    let toolOutput = '';

    // Simple tool parsing (same as ToolExecutionService)
    const jsonMatch = content.match(/```tool\s*\n?([\s\S]*?)\n?```/) || content.match(/\{\s*"tool"\s*:\s*"([^"]+)"/);

    if (jsonMatch) {
      try {
        const jsonStr = jsonMatch[1] || jsonMatch[0];
        const toolCall = JSON.parse(jsonStr);

        if (toolCall.tool && toolCall.args) {
          console.log(`[Agent ${agent.id}] Executing tool: ${toolCall.tool}`);
          try {
            const result = await gituMCPHub.executeTool(toolCall.tool, toolCall.args, {
              userId: agent.userId,
              sessionId: agent.id
            });
            toolOutput = `\nTool '${toolCall.tool}' Result: ${JSON.stringify(result)}`;
          } catch (e: any) {
            toolOutput = `\nTool '${toolCall.tool}' Failed: ${e.message}`;
          }
        }
      } catch (e) {
        console.warn(`[Agent ${agent.id}] Failed to parse tool call`);
      }
    }

    // 6. Update Memory
    const newHistory = [...history, {
      role: 'assistant',
      content: content + toolOutput,
      timestamp: new Date().toISOString()
    }];

    // Prune history if too long to save DB space/context window
    if (newHistory.length > 20) {
      newHistory.splice(0, newHistory.length - 20);
    }

    const newMemory = { ...agent.memory, history: newHistory };

    // 7. Check for completion
    if (content.includes('DONE')) {
      await this.updateAgentStatus(agent.id, 'completed', { output: content });

      await gituMessageGateway.notifyUser(
        agent.userId,
        `🎉 **Agent Task Completed**\n\n*Task:* ${agent.task}\n\n*Result:* ${content}`
      );
    } else if (content.includes('FAILED')) {
      await this.updateAgentStatus(agent.id, 'failed', { output: content });

      await gituMessageGateway.notifyUser(
        agent.userId,
        `❌ **Agent Task Failed**\n\n*Task:* ${agent.task}\n\n*Reason:* ${content}`
      );
    } else {
      // Keep active
      await pool.query(
        `UPDATE gitu_agents SET memory = $1, updated_at = NOW() WHERE id = $2`,
        [JSON.stringify(newMemory), agent.id]
      );
    }
  }

  /**
   * Get an agent by ID.
   */
  async getAgent(agentId: string): Promise<GituAgent | null> {
    const result = await pool.query(`SELECT * FROM gitu_agents WHERE id = $1`, [agentId]);
    if (result.rows.length === 0) return null;
    return this.mapRowToAgent(result.rows[0]);
  }

  /**
   * List all agents for a user.
   */
  async listAgents(userId: string): Promise<GituAgent[]> {
    const result = await pool.query(
      `SELECT * FROM gitu_agents WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId]
    );
    return result.rows.map(this.mapRowToAgent);
  }

  /**
   * Update an agent's status and result.
   */
  async updateAgentStatus(agentId: string, status: GituAgent['status'], result?: any): Promise<void> {
    await pool.query(
      `UPDATE gitu_agents SET status = $1, result = $2, updated_at = NOW() WHERE id = $3`,
      [status, result ? JSON.stringify(result) : null, agentId]
    );
  }

  private mapRowToAgent(row: any): GituAgent {
    return {
      id: row.id,
      userId: row.user_id,
      parentAgentId: row.parent_agent_id,
      task: row.task,
      status: row.status,
      memory: row.memory || {},
      result: row.result,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

export const gituAgentManager = new GituAgentManager();
