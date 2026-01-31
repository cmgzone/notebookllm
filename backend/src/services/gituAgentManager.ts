import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

import { gituAIRouter } from './gituAIRouter.js';
import { gituMessageGateway } from './gituMessageGateway.js';
import { gituShellManager } from './gituShellManager.js';

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

export class GituAgentManager {
  private readonly MAX_AGENTS_PER_USER = 100;

  /**
   * Spawn a new autonomous agent.
   */
  async spawnAgent(userId: string, task: string, parentAgentId?: string, memory: Record<string, any> = {}): Promise<GituAgent> {
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
    const result = await pool.query(
      `INSERT INTO gitu_agents (id, user_id, parent_agent_id, task, status, memory)
       VALUES ($1, $2, $3, $4, 'pending', $5)
       RETURNING *`,
      [id, userId, parentAgentId, task, JSON.stringify(memory)]
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
  private async executeAgentStep(agent: GituAgent): Promise<void> {
    // 1. Construct prompt from task and memory
    const history = (agent.memory.history as any[]) || [];
    const prompt = `
      You are an autonomous AI agent with access to a sandboxed shell.
      Your Task: ${agent.task}
      
      Current Memory/Context:
      ${JSON.stringify(agent.memory.data || {})}
      
      Available Tools:
      - Execute Shell Command: ACTION: SHELL "command_here"
      
      Instructions:
      1. Analyze the task and history.
      2. If you need to run a command (e.g., list files, read file, check network), use the SHELL action.
      3. If the task is done, output "DONE" and the final result.
      4. Otherwise, describe your next thought or action.
      
      Example:
      Thought: I need to check the files.
      ACTION: SHELL "ls -la"
    `;

    // 2. Call AI Router
    const aiResponse = await gituAIRouter.route({
      userId: agent.userId,
      prompt: prompt,
      taskType: 'analysis', // or 'coding' depending on task
      context: history.map(h => JSON.stringify(h)),
      useRetrieval: true, // Enable RAG
    });

    const content = aiResponse.content;
    let toolOutput = '';

    // Check for tool execution
    const shellMatch = content.match(/ACTION: SHELL "(.*)"/);
    if (shellMatch) {
      const command = shellMatch[1];
      try {
        const result = await gituShellManager.execute(
          agent.userId,
          {
            command: command,
            args: [],
            sandboxed: true
          }
        );
        toolOutput = `\nTool Output: ${result.stdout || result.stderr}`;
      } catch (e: any) {
        toolOutput = `\nTool Error: ${e.message}`;
      }
    }

    // 3. Update Memory
    const newHistory = [...history, { 
      role: 'assistant', 
      content: content + toolOutput, 
      timestamp: new Date().toISOString() 
    }];
    const newMemory = { ...agent.memory, history: newHistory };

    // 4. Check for completion
    if (content.includes('DONE')) {
      await this.updateAgentStatus(agent.id, 'completed', { output: content });
      
      // Notify user via connected platforms
      await gituMessageGateway.notifyUser(
        agent.userId, 
        `🎉 **Agent Task Completed**\n\n*Task:* ${agent.task}\n\n*Result:* ${content}`
      );
    } else {
      // Update memory and keep active
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
