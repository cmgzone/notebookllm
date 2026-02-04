import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

import { gituAIRouter } from './gituAIRouter.js';
import { gituEvaluationService } from './gituEvaluationService.js';
import { gituMessageGateway } from './gituMessageGateway.js';
import { gituMCPHub } from './gituMCPHub.js';

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

    await this.ensureAgentProcessingTask(userId);

    // Trigger processing immediately (fire-and-forget)
    this.processAgentQueue(userId).catch(e => console.error(`[AgentManager] Failed to trigger immediate processing for user ${userId}`, e));

    return this.mapRowToAgent(result.rows[0]);
  }

  private async ensureAgentProcessingTask(userId: string): Promise<void> {
    await pool.query(
      `INSERT INTO gitu_scheduled_tasks (
         id,
         user_id,
         name,
         description,
         trigger,
         action,
         cron,
         enabled,
         max_retries,
         retry_count,
         created_at,
         updated_at
       )
       SELECT
         gen_random_uuid(),
         $1,
         'Process Autonomous Agents',
         'Auto-run agents.processQueue',
         jsonb_build_object('type','cron'),
         jsonb_build_object('type','agents.processQueue'),
         '* * * * *',
         true,
         3,
         0,
         NOW(),
         NOW()
       WHERE NOT EXISTS (
         SELECT 1 FROM gitu_scheduled_tasks t
         WHERE t.user_id = $1 AND (
           t.action = to_jsonb('agents.processQueue'::text)
           OR t.action->>'type' = 'agents.processQueue'
           OR t.action->>'action' = 'agents.processQueue'
         )
       )`,
      [userId]
    );
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

    // Process in parallel with error handling and timeout
    const promises = agents.map(agent => this.processSingleAgentSafe(agent));
    await Promise.allSettled(promises);
  }

  private async processSingleAgentSafe(agent: GituAgent): Promise<void> {
    try {
      // Mark as active if pending
      if (agent.status === 'pending') {
        await this.updateAgentStatus(agent.id, 'active');
      }

      // Execute with timeout
      await Promise.race([
        this.executeAgentStep(agent),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Agent execution timed out (30s)')), 30000))
      ]);

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

  /**
   * Execute a single cognitive step for an agent.
   */
  /**
   * Execute a single cognitive step for an agent.
   */
  private async executeAgentStep(agent: GituAgent): Promise<void> {
    const history = (agent.memory.history as any[]) || [];

    const response = await gituAIRouter.route({
      userId: agent.userId,
      prompt: `Recent Context: ${JSON.stringify(history.slice(-5))}\n\nTask: ${agent.task}\n\nRespond with a single JSON object in a \`\`\`json\`\`\` code block:\n{\n  \"status\": \"continue\" | \"done\" | \"failed\",\n  \"message\": \"what you did / what you will do next\",\n  \"toolCall\": { \"tool\": \"tool_name\", \"args\": { } }\n}\n\nOmit toolCall if no tool is needed.`,
      taskType: 'chat',
      platform: 'terminal',
      includeSystemPrompt: true, // Let router build the standard Gitu prompt + tools
      includeTools: true,
    });

    const rawContent = response.content;
    const envelope = this.tryParseAgentEnvelope(rawContent);
    let toolOutput = '';

    const toolCall = envelope?.toolCall || this.tryParseLegacyToolCall(rawContent);
    if (toolCall?.tool && toolCall?.args) {
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

    const legacyStatus = this.detectLegacyCompletionStatus(rawContent);
    const previousNonEnvelopeCount = typeof (agent.memory as any)?.nonEnvelopeCount === 'number'
      ? (agent.memory as any).nonEnvelopeCount
      : 0;
    const nonEnvelopeCount = envelope ? 0 : previousNonEnvelopeCount + 1;
    const forcedCompletion = !envelope && !legacyStatus && !toolCall && nonEnvelopeCount >= 2;

    const baseContent = envelope?.message ?? rawContent;
    const finalContent = forcedCompletion
      ? `${baseContent}\n\n[Auto-completed: missing JSON envelope]`
      : baseContent;
    const content = finalContent;

    const newHistory = [...history, {
      role: 'assistant',
      content: finalContent + toolOutput,
      timestamp: new Date().toISOString()
    }];

    // Prune history if too long to save DB space/context window
    if (newHistory.length > 20) {
      newHistory.splice(0, newHistory.length - 20);
    }

    const newMemory = { ...agent.memory, history: newHistory, nonEnvelopeCount };

    const completionStatus = envelope?.status === 'done'
      ? 'done'
      : envelope?.status === 'failed'
        ? 'failed'
        : legacyStatus
          ? legacyStatus
          : forcedCompletion
            ? 'done'
            : null;

    if (completionStatus === 'done') {
      await this.updateAgentStatus(agent.id, 'completed', { output: content + toolOutput });

      await gituMessageGateway.notifyUser(
        agent.userId,
        `🎉 **Agent Task Completed**\n\n*Task:* ${agent.task}\n\n*Result:* ${content}`
      );

      if (agent.memory.missionId) {
        try {
          await gituEvaluationService.createAgentCompletionEvaluation({
            userId: agent.userId,
            missionId: agent.memory.missionId,
            agentId: agent.id,
            status: 'completed',
            toolCallsAttempted: toolCall ? 1 : 0
          });
        } catch (e) {
          console.error(`[AgentManager] Failed to store evaluation for agent ${agent.id}`, e);
        }
      }

      // Notify Orchestrator if this agent is part of a swarm mission
      if (agent.memory.missionId) {
        try {
          // Dynamic import to avoid circular dependency
          const { gituAgentOrchestrator } = await import('./gituAgentOrchestrator.js');
          await gituAgentOrchestrator.handleTaskCompletion(agent.memory.missionId, agent.id);
        } catch (e) {
          console.error(`[AgentManager] Failed to notify orchestrator for agent ${agent.id}`, e);
        }
      }
    } else if (completionStatus === 'failed') {
      await this.updateAgentStatus(agent.id, 'failed', { output: content + toolOutput });

      await gituMessageGateway.notifyUser(
        agent.userId,
        `❌ **Agent Task Failed**\n\n*Task:* ${agent.task}\n\n*Reason:* ${content}`
      );

      if (agent.memory.missionId) {
        try {
          await gituEvaluationService.createAgentCompletionEvaluation({
            userId: agent.userId,
            missionId: agent.memory.missionId,
            agentId: agent.id,
            status: 'failed',
            toolCallsAttempted: toolCall ? 1 : 0
          });
        } catch (e) {
          console.error(`[AgentManager] Failed to store evaluation for agent ${agent.id}`, e);
        }
      }

      // Notify Orchestrator if this agent is part of a swarm mission
      if (agent.memory.missionId) {
        try {
          // Dynamic import to avoid circular dependency
          const { gituAgentOrchestrator } = await import('./gituAgentOrchestrator.js');
          await gituAgentOrchestrator.handleTaskCompletion(agent.memory.missionId, agent.id);
        } catch (e) {
          console.error(`[AgentManager] Failed to notify orchestrator for agent ${agent.id}`, e);
        }
      }
    } else {
      // Keep active
      await pool.query(
        `UPDATE gitu_agents SET memory = $1, updated_at = NOW() WHERE id = $2`,
        [JSON.stringify(newMemory), agent.id]
      );
    }
  }

  private tryParseAgentEnvelope(content: string): { status: 'continue' | 'done' | 'failed'; message: string; toolCall?: { tool: string; args: any } } | null {
    const jsonCandidate = this.extractEnvelopeJson(content);
    if (!jsonCandidate) return null;
    try {
      const parsed = JSON.parse(jsonCandidate);
      const status = typeof parsed?.status === 'string' ? parsed.status.toLowerCase() : '';
      const message = typeof parsed?.message === 'string'
        ? parsed.message
        : typeof parsed?.content === 'string'
          ? parsed.content
          : '';
      if (status !== 'continue' && status !== 'done' && status !== 'failed') return null;
      if (!message) return null;
      const toolCall = parsed?.toolCall || parsed?.tool_call;
      if (toolCall && typeof toolCall?.tool === 'string' && toolCall?.args && typeof toolCall?.args === 'object') {
        return { status, message, toolCall: { tool: toolCall.tool, args: toolCall.args } };
      }
      return { status, message };
    } catch {
      return null;
    }
  }

  private extractEnvelopeJson(content: string): string | null {
    const fencedMatch = content.match(/```(?:json)?\s*\n?([\s\S]*?)\n?```/i);
    const fencedCandidate = (fencedMatch?.[1] || '').trim();
    if (fencedCandidate) return fencedCandidate;

    const inlineMatch = content.match(/\{[\s\S]*\}/);
    const inlineCandidate = (inlineMatch?.[0] || '').trim();
    if (inlineCandidate) return inlineCandidate;

    return null;
  }

  private tryParseLegacyToolCall(content: string): { tool: string; args: any } | null {
    const toolBlockMatch = content.match(/```tool\s*\n?([\s\S]*?)\n?```/i);
    if (toolBlockMatch?.[1]) {
      try {
        const parsed = JSON.parse(toolBlockMatch[1]);
        if (parsed?.tool && parsed?.args) return { tool: parsed.tool, args: parsed.args };
      } catch { }
    }
    const inlineJsonMatch = content.match(/\{\s*"tool"\s*:\s*"[^"]+"\s*,[\s\S]*?\}/);
    if (inlineJsonMatch?.[0]) {
      try {
        const parsed = JSON.parse(inlineJsonMatch[0]);
        if (parsed?.tool && parsed?.args) return { tool: parsed.tool, args: parsed.args };
      } catch { }
    }
    return null;
  }

  private detectLegacyCompletionStatus(content: string): 'done' | 'failed' | null {
    if (/^\s*(DONE|COMPLETED|FINISHED|FINAL)\b/m.test(content)) return 'done';
    if (/^\s*(FAILED|ERROR|FAILURE)\b/m.test(content)) return 'failed';
    return null;
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

  async listAgentsByMission(userId: string, missionId: string): Promise<GituAgent[]> {
    const result = await pool.query(
      `SELECT * FROM gitu_agents
       WHERE user_id = $1 AND (memory->>'missionId') = $2
       ORDER BY created_at DESC`,
      [userId, missionId]
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
