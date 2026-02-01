import pool from '../config/database.js';
import { gituMemoryService } from './gituMemoryService.js';
import gituSessionService from './gituSessionService.js';
import { gituAgentManager } from './gituAgentManager.js';
import { gituMCPHub } from './gituMCPHub.js';
import { gituAIRouter } from './gituAIRouter.js';
import { gituMessageGateway } from './gituMessageGateway.js';
import { gituPluginSystem } from './gituPluginSystem.js';

/**
 * Extended action types for scheduled tasks
 * System actions: Internal maintenance tasks
 * User actions: User-defined automated tasks
 */
type AllowedAction =
  // System maintenance actions
  | 'memories.detectContradictions'
  | 'memories.expireUnverified'
  | 'sessions.cleanupOldSessions'
  | 'agents.processQueue'
  // User-defined actions
  | 'mcp.executeTool'        // Execute any MCP tool
  | 'ai.generateSummary'     // Generate AI summary of notebooks
  | 'ai.sendMessage'         // Send an AI-generated message
  | 'plugin.execute'         // Execute a user plugin
  | 'notification.send';     // Send a notification to user


interface ScheduledTask {
  id: string;
  userId: string;
  name: string;
  description?: string;
  action: AllowedAction;
  payload?: any;
  cron: string;
  enabled: boolean;
  maxRetries: number;
  retryCount: number;
  lastRunAt?: Date;
  lastRunStatus?: string;
}

class GituScheduler {
  private interval: NodeJS.Timeout | null = null;
  private retryTimers: Map<string, NodeJS.Timeout> = new Map();

  start() {
    if (this.interval) return;
    this.interval = setInterval(() => this.tick(), 60_000);
    console.log('🕒 GituScheduler started (tick every 60s)');
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    for (const [, t] of this.retryTimers) clearTimeout(t);
    this.retryTimers.clear();
    console.log('🛑 GituScheduler stopped');
  }

  async tick(now: Date = new Date()) {
    const res = await pool.query(
      `SELECT * FROM gitu_scheduled_tasks WHERE enabled = true`
    );
    const tasks = res.rows.map(this.mapRowToTask);
    for (const task of tasks) {
      if (this.isDue(now, task.cron, task.lastRunAt)) {
        await this.executeTask(task);
      }
    }
  }

  async trigger(action: AllowedAction, userId: string, payload?: any) {
    const task: ScheduledTask = {
      id: 'manual-' + Date.now(),
      userId,
      name: `manual:${action}`,
      action,
      cron: '* * * * *',
      enabled: true,
      maxRetries: 0,
      retryCount: 0,
    };
    await this.runAction(task, payload);
  }

  private mapRowToTask(row: any): ScheduledTask {
    let action = row.action;
    let payload = {};

    // Handle JSONB action from DB
    if (typeof row.action === 'object' && row.action !== null) {
      // If action is stored as { type: 'action.name', ...args }
      if (row.action.type) {
        action = row.action.type;
        payload = row.action;
      }
      // If action is stored as { action: 'action.name', ...args }
      else if (row.action.action) {
        action = row.action.action;
        payload = row.action;
      }
    }

    return {
      id: row.id,
      userId: row.user_id,
      name: row.name,
      description: row.description,
      action: action as AllowedAction,
      payload,
      cron: row.cron,
      enabled: row.enabled,
      maxRetries: row.max_retries,
      retryCount: row.retry_count,
      lastRunAt: row.last_run_at ? new Date(row.last_run_at) : undefined,
      lastRunStatus: row.last_run_status ?? undefined,
    };
  }

  private isDue(now: Date, cron: string, lastRun?: Date): boolean {
    // cron format: "min hour day month weekday"
    const parts = cron.trim().split(/\s+/);
    if (parts.length !== 5) return false;
    const [min, hour, day, month, weekday] = parts;
    const matches = (val: number, expr: string) => {
      if (expr === '*') return true;
      if (expr.includes(',')) {
        return expr.split(',').some(p => matches(val, p.trim()));
      }
      if (expr.includes('/')) {
        const [base, stepStr] = expr.split('/');
        const step = Number(stepStr);
        if (base !== '*') return false;
        return val % step === 0;
      }
      const num = Number(expr);
      return Number.isFinite(num) && val === num;
    };
    const nMin = now.getMinutes();
    const nHour = now.getHours();
    const nDay = now.getDate();
    const nMonth = now.getMonth() + 1;
    const nWeekday = now.getDay(); // 0-6 (Sun=0)
    const ok =
      matches(nMin, min) &&
      matches(nHour, hour) &&
      matches(nDay, day) &&
      matches(nMonth, month) &&
      matches(nWeekday, weekday);
    if (!ok) return false;
    // prevent multiple runs within the same minute
    if (!lastRun) return true;
    return now.getTime() - lastRun.getTime() > 59_000;
  }

  private async executeTask(task: ScheduledTask) {
    const startedAt = new Date();
    try {
      const output = await this.runAction(task);
      const durationMs = Date.now() - startedAt.getTime();
      await pool.query(
        `INSERT INTO gitu_task_executions (task_id, success, output, duration)
         VALUES ($1, true, $2, $3)`,
        [task.id, output ? JSON.stringify(output) : null, durationMs]
      );
      await pool.query(
        `UPDATE gitu_scheduled_tasks 
         SET last_run_at = NOW(), last_run_status = 'success', retry_count = 0, updated_at = NOW()
         WHERE id = $1`,
        [task.id]
      );
    } catch (error: any) {
      const durationMs = Date.now() - startedAt.getTime();
      await pool.query(
        `INSERT INTO gitu_task_executions (task_id, success, error, duration)
         VALUES ($1, false, $2, $3)`,
        [task.id, error?.message || String(error), durationMs]
      );
      await pool.query(
        `UPDATE gitu_scheduled_tasks 
         SET last_run_at = NOW(), last_run_status = 'failed', retry_count = retry_count + 1, updated_at = NOW()
         WHERE id = $1`,
        [task.id]
      );
      const needRetry = task.retryCount + 1 <= task.maxRetries;
      if (needRetry) {
        const t = setTimeout(async () => {
          try {
            await this.runAction({ ...task, retryCount: task.retryCount + 1 });
            await pool.query(
              `UPDATE gitu_scheduled_tasks 
               SET last_run_status = 'success', retry_count = 0, updated_at = NOW()
               WHERE id = $1`,
              [task.id]
            );
          } catch (e: any) {
            await pool.query(
              `UPDATE gitu_scheduled_tasks 
               SET last_run_status = 'failed', updated_at = NOW()
               WHERE id = $1`,
              [task.id]
            );
          } finally {
            this.retryTimers.delete(task.id);
          }
        }, 60_000);
        this.retryTimers.set(task.id, t);
      }
    }
  }

  private async runAction(task: ScheduledTask, overloadPayload?: any): Promise<any> {
    const payload = overloadPayload || task.payload || {};

    switch (task.action) {
      // System maintenance actions
      case 'memories.detectContradictions':
        await gituMemoryService.detectContradictions(task.userId, payload?.category);
        return null;
      case 'memories.expireUnverified':
        await gituMemoryService.expireUnverifiedMemories(payload?.days ?? 30);
        return null;
      case 'sessions.cleanupOldSessions':
        await gituSessionService.cleanupOldSessions(payload?.days ?? 30);
        return null;
      case 'agents.processQueue':
        await gituAgentManager.processAgentQueue(task.userId);
        return null;

      // User-defined actions
      case 'mcp.executeTool': {
        // Execute an MCP tool
        const { toolName, args } = payload || {};
        if (!toolName) throw new Error('toolName is required for mcp.executeTool');
        const result = await gituMCPHub.executeTool(toolName, args || {}, {
          userId: task.userId,
        });
        return result ?? null;
      }

      case 'ai.generateSummary': {
        // Generate AI summary and optionally send to user
        const { prompt, notebookId, sendToUser } = payload || {};
        const summaryPrompt = prompt || 'Generate a brief summary of my recent activity and notebooks.';
        const response = await gituAIRouter.route({
          userId: task.userId,
          prompt: summaryPrompt,
          taskType: 'summarization',
          platform: 'scheduler',
          includeSystemPrompt: false, // Don't need full context for scheduled tasks
        });
        // Optionally send to user via their connected platforms
        if (sendToUser) {
          await gituMessageGateway.notifyUser(task.userId, response.content);
        }
        return { content: response.content, notebookId: notebookId ?? null, sent: Boolean(sendToUser) };
      }

      case 'ai.sendMessage': {
        // Generate and send an AI message to the user
        const { prompt, message } = payload || {};
        const content = message || (prompt ? (await gituAIRouter.route({
          userId: task.userId,
          prompt,
          taskType: 'chat',
          platform: 'scheduler',
          includeSystemPrompt: false,
        })).content : 'This is a scheduled reminder from Gitu.');
        await gituMessageGateway.notifyUser(task.userId, content);
        return { content, generated: Boolean(prompt && !message) };
      }

      case 'plugin.execute': {
        const { pluginId, input, context, timeoutMs } = payload || {};
        if (!pluginId || typeof pluginId !== 'string') throw new Error('pluginId is required for plugin.execute');
        const result = await gituPluginSystem.executePlugin(task.userId, pluginId, input, context, {
          timeoutMs: typeof timeoutMs === 'number' ? timeoutMs : undefined,
        });
        if (!result.success) throw new Error(result.error || 'PLUGIN_EXECUTION_FAILED');
        return result;
      }

      case 'notification.send': {
        // Send a notification to the user
        const { message } = payload || {};
        // Fallback to task description or name if message logic is strict
        const content = message || task.description || task.name || 'Notification';
        await gituMessageGateway.notifyUser(task.userId, content);
        return { content };
      }

      default:
        throw new Error(`Unknown action: ${task.action}`);
    }
  }
}

export const gituScheduler = new GituScheduler();
export default gituScheduler;
