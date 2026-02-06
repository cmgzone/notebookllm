/**
 * Gitu Task Scheduler Service
 * Background service that processes scheduled tasks at their designated times.
 * 
 * Requirements: US-11 (Autonomous Wake-Up), US-17 (Task Execution)
 * Design: Section 5 (Task Scheduler)
 */

import pool from '../config/database.js';
import { gituTaskExecutor } from './gituTaskExecutor.js';
import { gituMessageGateway } from './gituMessageGateway.js';

// ==================== INTERFACES ====================

export interface ScheduledTask {
  id: string;
  userId: string;
  name: string;
  description?: string;
  trigger: TaskTrigger;
  action: TaskAction;
  enabled: boolean;
  lastRunAt?: Date;
  nextRunAt?: Date;
  runCount: number;
  failureCount: number;
  createdAt: Date;
}

export interface TaskTrigger {
  type: 'cron' | 'once' | 'interval' | 'event';
  cron?: string;  // Cron expression (e.g., "0 9 * * *" for 9am daily)
  timestamp?: string;  // ISO timestamp for one-time tasks
  intervalMinutes?: number;  // Interval in minutes
  event?: string;  // Event name (e.g., "new_email", "message_received")
}

export interface TaskAction {
  type: 'send_message' | 'run_command' | 'ai_request' | 'webhook' | 'custom';
  platform?: string;  // Target platform for messages
  message?: string;  // Message content
  command?: string;  // Command to execute
  prompt?: string;  // AI prompt
  webhookUrl?: string;  // Webhook URL
  customCode?: string;  // Custom JavaScript code
  metadata?: Record<string, any>;
}

export interface TaskExecution {
  id: string;
  taskId: string;
  success: boolean;
  output?: any;
  error?: string;
  duration: number;  // milliseconds
  executedAt: Date;
}

// ==================== SERVICE CLASS ====================

class GituTaskScheduler {
  private isRunning: boolean = false;
  private intervalId?: NodeJS.Timeout;
  private readonly CHECK_INTERVAL_MS = 30000;  // Check every 30 seconds

  /**
   * Start the task scheduler background service.
   */
  start(): void {
    if (this.isRunning) {
      console.log('[Gitu Task Scheduler] Already running');
      return;
    }

    console.log('[Gitu Task Scheduler] Starting...');
    this.isRunning = true;

    // Run immediately on start
    this.processScheduledTasks().catch(err => {
      console.error('[Gitu Task Scheduler] Error in initial run:', err);
    });

    // Then run periodically
    this.intervalId = setInterval(() => {
      this.processScheduledTasks().catch(err => {
        console.error('[Gitu Task Scheduler] Error in periodic run:', err);
      });
    }, this.CHECK_INTERVAL_MS);

    console.log('[Gitu Task Scheduler] Started successfully');
  }

  /**
   * Stop the task scheduler.
   */
  stop(): void {
    if (!this.isRunning) {
      console.log('[Gitu Task Scheduler] Not running');
      return;
    }

    console.log('[Gitu Task Scheduler] Stopping...');

    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = undefined;
    }

    this.isRunning = false;
    console.log('[Gitu Task Scheduler] Stopped');
  }

  /**
   * Process all scheduled tasks that are due for execution.
   */
  async processScheduledTasks(): Promise<void> {
    try {
      // Find tasks that are due
      const result = await pool.query(
        `SELECT * FROM gitu_scheduled_tasks
         WHERE enabled = true
         AND (next_run_at IS NULL OR next_run_at <= NOW())
         AND jsonb_typeof(action) = 'object'
         AND (action->>'type') = ANY($1::text[])
         ORDER BY next_run_at ASC NULLS FIRST
         LIMIT 100`,
        [['send_message', 'run_command', 'ai_request', 'webhook', 'custom']]
      );

      const tasks = result.rows.map(row => this.mapRowToTask(row));

      if (tasks.length > 0) {
        console.log(`[Gitu Task Scheduler] Processing ${tasks.length} tasks`);
      }

      // Execute tasks in parallel (with concurrency limit)
      const CONCURRENCY = 5;
      for (let i = 0; i < tasks.length; i += CONCURRENCY) {
        const batch = tasks.slice(i, i + CONCURRENCY);
        await Promise.all(batch.map(task => this.executeTask(task)));
      }
    } catch (error) {
      console.error('[Gitu Task Scheduler] Error processing tasks:', error);
    }
  }

  /**
   * Execute a single scheduled task.
   */
  private async executeTask(task: ScheduledTask): Promise<void> {
    const startTime = Date.now();
    let success = false;
    let output: any = null;
    let error: string | undefined;

    try {
      console.log(`[Gitu Task Scheduler] Executing task: ${task.name} (${task.id})`);

      // Execute based on action type
      output = await gituTaskExecutor.execute(task.userId, task.action);
      success = true;

      console.log(`[Gitu Task Scheduler] Task completed: ${task.name}`);
    } catch (err: any) {
      success = false;
      error = err.message || 'Unknown error';
      console.error(`[Gitu Task Scheduler] Task failed: ${task.name}`, err);
    }

    const duration = Date.now() - startTime;

    // Record execution
    await this.recordExecution(task.id, success, output, error, duration);

    // Update task status
    await this.updateTaskAfterExecution(task, success);
  }

  /**
   * Record task execution in history.
   */
  private async recordExecution(
    taskId: string,
    success: boolean,
    output: any,
    error: string | undefined,
    duration: number
  ): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO gitu_task_executions 
         (task_id, success, output, error, duration, executed_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [taskId, success, JSON.stringify(output), error, duration]
      );
    } catch (err) {
      console.error('[Gitu Task Scheduler] Error recording execution:', err);
    }
  }

  /**
   * Update task after execution (run count, next run time, etc.).
   */
  private async updateTaskAfterExecution(task: ScheduledTask, success: boolean): Promise<void> {
    try {
      const nextRunAt = this.calculateNextRunTime(task);
      const failureCount = success ? 0 : task.failureCount + 1;

      // Disable task if it has failed too many times
      const shouldDisable = failureCount >= 5;

      await pool.query(
        `UPDATE gitu_scheduled_tasks
         SET last_run_at = NOW(),
             next_run_at = $1,
             run_count = run_count + 1,
             failure_count = $2,
             enabled = $3
         WHERE id = $4`,
        [nextRunAt, failureCount, !shouldDisable, task.id]
      );

      if (shouldDisable) {
        console.warn(`[Gitu Task Scheduler] Task disabled due to repeated failures: ${task.name}`);
      }
    } catch (err) {
      console.error('[Gitu Task Scheduler] Error updating task:', err);
    }
  }

  /**
   * Calculate the next run time for a task based on its trigger.
   */
  private calculateNextRunTime(task: ScheduledTask): Date | null {
    const trigger = task.trigger;

    switch (trigger.type) {
      case 'once':
        // One-time tasks don't repeat
        return null;

      case 'interval':
        if (trigger.intervalMinutes) {
          const next = new Date();
          next.setMinutes(next.getMinutes() + trigger.intervalMinutes);
          return next;
        }
        return null;

      case 'cron':
        if (trigger.cron) {
          return this.parseCronNextRun(trigger.cron);
        }
        return null;

      case 'event':
        // Event-based tasks are triggered externally
        return null;

      default:
        return null;
    }
  }

  /**
   * Parse cron expression and calculate next run time.
   * Simplified cron parser - supports basic patterns.
   */
  private parseCronNextRun(cronExpr: string): Date | null {
    try {
      // Simple cron parser for common patterns
      // Format: "minute hour day month dayOfWeek"
      // Example: "0 9 * * *" = 9am daily
      // Example: "*/15 * * * *" = every 15 minutes

      const parts = cronExpr.trim().split(/\s+/);
      if (parts.length !== 5) {
        console.warn(`[Gitu Task Scheduler] Invalid cron expression: ${cronExpr}`);
        return null;
      }

      const [minute, hour, day, month, dayOfWeek] = parts;
      const now = new Date();
      const next = new Date(now);

      // Handle minute
      if (minute === '*') {
        next.setMinutes(now.getMinutes() + 1);
      } else if (minute.startsWith('*/')) {
        const interval = parseInt(minute.substring(2));
        const nextMinute = Math.ceil(now.getMinutes() / interval) * interval;
        next.setMinutes(nextMinute);
      } else {
        next.setMinutes(parseInt(minute));
      }

      // Handle hour
      if (hour !== '*') {
        const targetHour = parseInt(hour);
        if (targetHour <= now.getHours() && minute !== '*') {
          next.setDate(next.getDate() + 1);
        }
        next.setHours(targetHour);
      }

      // Reset seconds and milliseconds
      next.setSeconds(0);
      next.setMilliseconds(0);

      // Ensure next run is in the future
      if (next <= now) {
        next.setDate(next.getDate() + 1);
      }

      return next;
    } catch (err) {
      console.error('[Gitu Task Scheduler] Error parsing cron:', err);
      return null;
    }
  }

  /**
   * Create a new scheduled task.
   */
  async createTask(
    userId: string,
    name: string,
    trigger: TaskTrigger,
    action: TaskAction,
    description?: string
  ): Promise<ScheduledTask> {
    const nextRunAt = this.calculateNextRunTime({ trigger } as ScheduledTask);

    const result = await pool.query(
      `INSERT INTO gitu_scheduled_tasks
       (user_id, name, description, trigger, action, enabled, next_run_at, run_count, failure_count, created_at)
       VALUES ($1, $2, $3, $4, $5, true, $6, 0, 0, NOW())
       RETURNING *`,
      [userId, name, description, JSON.stringify(trigger), JSON.stringify(action), nextRunAt]
    );

    return this.mapRowToTask(result.rows[0]);
  }

  /**
   * Get a task by ID.
   */
  async getTask(taskId: string): Promise<ScheduledTask | null> {
    const result = await pool.query(
      `SELECT * FROM gitu_scheduled_tasks WHERE id = $1`,
      [taskId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToTask(result.rows[0]);
  }

  /**
   * List all tasks for a user.
   */
  async listUserTasks(userId: string, includeDisabled: boolean = false): Promise<ScheduledTask[]> {
    const query = includeDisabled
      ? `SELECT * FROM gitu_scheduled_tasks WHERE user_id = $1 ORDER BY created_at DESC`
      : `SELECT * FROM gitu_scheduled_tasks WHERE user_id = $1 AND enabled = true ORDER BY created_at DESC`;

    const result = await pool.query(query, [userId]);
    return result.rows.map(row => this.mapRowToTask(row));
  }

  /**
   * Update a task.
   */
  async updateTask(
    taskId: string,
    updates: Partial<{
      name: string;
      description: string;
      trigger: TaskTrigger;
      action: TaskAction;
      enabled: boolean;
    }>
  ): Promise<ScheduledTask> {
    const task = await this.getTask(taskId);
    if (!task) {
      throw new Error(`Task ${taskId} not found`);
    }

    const updateFields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (updates.name !== undefined) {
      updateFields.push(`name = $${paramIndex++}`);
      values.push(updates.name);
    }

    if (updates.description !== undefined) {
      updateFields.push(`description = $${paramIndex++}`);
      values.push(updates.description);
    }

    if (updates.trigger !== undefined) {
      updateFields.push(`trigger = $${paramIndex++}`);
      values.push(JSON.stringify(updates.trigger));

      // Recalculate next run time
      const nextRunAt = this.calculateNextRunTime({ ...task, trigger: updates.trigger });
      updateFields.push(`next_run_at = $${paramIndex++}`);
      values.push(nextRunAt);
    }

    if (updates.action !== undefined) {
      updateFields.push(`action = $${paramIndex++}`);
      values.push(JSON.stringify(updates.action));
    }

    if (updates.enabled !== undefined) {
      updateFields.push(`enabled = $${paramIndex++}`);
      values.push(updates.enabled);
    }

    values.push(taskId);

    const query = `
      UPDATE gitu_scheduled_tasks
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    return this.mapRowToTask(result.rows[0]);
  }

  /**
   * Delete a task.
   */
  async deleteTask(taskId: string): Promise<void> {
    await pool.query(
      `DELETE FROM gitu_scheduled_tasks WHERE id = $1`,
      [taskId]
    );
  }

  /**
   * Get task execution history.
   */
  async getTaskExecutions(taskId: string, limit: number = 50): Promise<TaskExecution[]> {
    const result = await pool.query(
      `SELECT * FROM gitu_task_executions
       WHERE task_id = $1
       ORDER BY executed_at DESC
       LIMIT $2`,
      [taskId, limit]
    );

    return result.rows.map(row => ({
      id: row.id,
      taskId: row.task_id,
      success: row.success,
      output: row.output,
      error: row.error,
      duration: row.duration,
      executedAt: new Date(row.executed_at),
    }));
  }

  /**
   * Trigger an event-based task manually.
   */
  async triggerEventTask(userId: string, eventName: string, eventData?: any): Promise<void> {
    // Find all event-based tasks for this user and event
    const result = await pool.query(
      `SELECT * FROM gitu_scheduled_tasks
       WHERE user_id = $1
       AND enabled = true
       AND trigger->>'type' = 'event'
       AND trigger->>'event' = $2`,
      [userId, eventName]
    );

    const tasks = result.rows.map(row => this.mapRowToTask(row));

    // Execute all matching tasks
    for (const task of tasks) {
      // Add event data to action metadata
      const actionWithData = {
        ...task.action,
        metadata: {
          ...task.action.metadata,
          eventData,
        },
      };

      await this.executeTask({ ...task, action: actionWithData });
    }
  }

  /**
   * Map database row to ScheduledTask object.
   */
  private mapRowToTask(row: any): ScheduledTask {
    const safeParse = (val: any) => {
      if (typeof val !== 'string') return val;
      // Only parse if it looks like a JSON object or array
      if (val.trim().startsWith('{') || val.trim().startsWith('[')) {
        try {
          return JSON.parse(val);
        } catch (e) {
          return val;
        }
      }
      return val;
    };

    return {
      id: row.id,
      userId: row.user_id,
      name: row.name,
      description: row.description,
      trigger: safeParse(row.trigger),
      action: safeParse(row.action),
      enabled: row.enabled,
      lastRunAt: row.last_run_at ? new Date(row.last_run_at) : undefined,
      nextRunAt: row.next_run_at ? new Date(row.next_run_at) : undefined,
      runCount: row.run_count,
      failureCount: row.failure_count,
      createdAt: new Date(row.created_at),
    };
  }
}

// Export singleton instance
export const gituTaskScheduler = new GituTaskScheduler();
export default gituTaskScheduler;
