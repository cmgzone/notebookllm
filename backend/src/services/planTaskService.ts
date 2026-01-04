/**
 * Plan Task Service
 * Manages tasks within plans in Planning Mode.
 * Provides CRUD operations and status management with audit trail.
 * 
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.6
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

export type TaskStatus = 'not_started' | 'in_progress' | 'paused' | 'blocked' | 'completed';
export type TaskPriority = 'low' | 'medium' | 'high' | 'critical';

export interface CreateTaskInput {
  planId: string;
  parentTaskId?: string;
  title: string;
  description?: string;
  requirementIds?: string[];
  priority?: TaskPriority;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  requirementIds?: string[];
  priority?: TaskPriority;
  assignedAgentId?: string | null;
  timeSpentMinutes?: number;
}

export interface UpdateStatusInput {
  status: TaskStatus;
  changedBy: string;
  reason?: string;
}

export interface StatusHistoryEntry {
  id: string;
  taskId: string;
  status: TaskStatus;
  changedBy: string;
  reason?: string;
  changedAt: Date;
}

export interface AgentOutput {
  id: string;
  taskId: string;
  agentSessionId?: string;
  agentName?: string;
  outputType: 'comment' | 'code' | 'file' | 'completion';
  content: string;
  metadata?: Record<string, any>;
  createdAt: Date;
}

export interface Task {
  id: string;
  planId: string;
  parentTaskId?: string;
  requirementIds: string[];
  title: string;
  description?: string;
  status: TaskStatus;
  priority: TaskPriority;
  assignedAgentId?: string;
  timeSpentMinutes: number;
  blockingReason?: string;
  createdAt: Date;
  updatedAt: Date;
  completedAt?: Date;
  // Optional loaded relations
  subTasks?: Task[];
  statusHistory?: StatusHistoryEntry[];
  agentOutputs?: AgentOutput[];
}

export interface ListTasksOptions {
  status?: TaskStatus;
  parentTaskId?: string | null;
  includeSubTasks?: boolean;
  limit?: number;
  offset?: number;
}

// ==================== SERVICE CLASS ====================

class PlanTaskService {
  /**
   * Create a new task within a plan.
   * Implements Requirement 3.1: Task creation with required fields.
   * Records initial status in history (Requirement 3.2).
   * 
   * @param input - Task creation input
   * @param changedBy - User or agent ID creating the task
   * @returns The created Task
   */
  async createTask(input: CreateTaskInput, changedBy: string): Promise<Task> {
    const {
      planId,
      parentTaskId,
      title,
      description,
      requirementIds = [],
      priority = 'medium',
    } = input;

    const taskId = uuidv4();
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Insert the task
      const result = await client.query(
        `INSERT INTO plan_tasks 
         (id, plan_id, parent_task_id, requirement_ids, title, description, status, priority, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, 'not_started', $7, NOW(), NOW())
         RETURNING *`,
        [taskId, planId, parentTaskId || null, requirementIds, title, description || null, priority]
      );

      // Record initial status in history (Requirement 3.2)
      await client.query(
        `INSERT INTO task_status_history (id, task_id, status, changed_by, changed_at)
         VALUES ($1, $2, 'not_started', $3, NOW())`,
        [uuidv4(), taskId, changedBy]
      );

      await client.query('COMMIT');
      return this.mapRowToTask(result.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get a task by ID with optional relations.
   * 
   * @param taskId - The task ID
   * @param includeRelations - Whether to include sub-tasks, history, and outputs
   * @returns The Task or null if not found
   */
  async getTask(taskId: string, includeRelations: boolean = false): Promise<Task | null> {
    const result = await pool.query(
      `SELECT * FROM plan_tasks WHERE id = $1`,
      [taskId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const task = this.mapRowToTask(result.rows[0]);

    if (includeRelations) {
      task.subTasks = await this.getSubTasks(taskId);
      task.statusHistory = await this.getStatusHistory(taskId);
      task.agentOutputs = await this.getAgentOutputs(taskId);
    }

    return task;
  }

  /**
   * List tasks for a plan with optional filtering.
   * 
   * @param planId - The plan ID
   * @param options - List options (status filter, parent filter, pagination)
   * @returns Array of Tasks
   */
  async listTasks(planId: string, options: ListTasksOptions = {}): Promise<Task[]> {
    const { status, parentTaskId, includeSubTasks = false, limit = 100, offset = 0 } = options;

    let query = `SELECT * FROM plan_tasks WHERE plan_id = $1`;
    const params: any[] = [planId];
    let paramIndex = 2;

    // Filter by parent task
    if (parentTaskId === null) {
      // Only top-level tasks
      query += ` AND parent_task_id IS NULL`;
    } else if (parentTaskId !== undefined) {
      query += ` AND parent_task_id = $${paramIndex}`;
      params.push(parentTaskId);
      paramIndex++;
    }

    // Filter by status
    if (status) {
      query += ` AND status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    query += ` ORDER BY created_at ASC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    const tasks = result.rows.map(row => this.mapRowToTask(row));

    // Optionally load sub-tasks for each task
    if (includeSubTasks) {
      for (const task of tasks) {
        task.subTasks = await this.getSubTasks(task.id);
      }
    }

    return tasks;
  }

  /**
   * Update a task's properties (not status).
   * 
   * @param taskId - The task ID
   * @param input - Update input
   * @returns The updated Task or null if not found
   */
  async updateTask(taskId: string, input: UpdateTaskInput): Promise<Task | null> {
    const existing = await this.getTask(taskId);
    if (!existing) {
      return null;
    }

    const updates: string[] = [];
    const params: any[] = [];
    let paramIndex = 1;

    if (input.title !== undefined) {
      updates.push(`title = $${paramIndex}`);
      params.push(input.title);
      paramIndex++;
    }

    if (input.description !== undefined) {
      updates.push(`description = $${paramIndex}`);
      params.push(input.description);
      paramIndex++;
    }

    if (input.requirementIds !== undefined) {
      updates.push(`requirement_ids = $${paramIndex}`);
      params.push(input.requirementIds);
      paramIndex++;
    }

    if (input.priority !== undefined) {
      updates.push(`priority = $${paramIndex}`);
      params.push(input.priority);
      paramIndex++;
    }

    if (input.assignedAgentId !== undefined) {
      updates.push(`assigned_agent_id = $${paramIndex}`);
      params.push(input.assignedAgentId);
      paramIndex++;
    }

    if (input.timeSpentMinutes !== undefined) {
      updates.push(`time_spent_minutes = $${paramIndex}`);
      params.push(input.timeSpentMinutes);
      paramIndex++;
    }

    if (updates.length === 0) {
      return existing;
    }

    params.push(taskId);
    const result = await pool.query(
      `UPDATE plan_tasks SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex}
       RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToTask(result.rows[0]);
  }

  /**
   * Delete a task and all sub-tasks (cascade).
   * 
   * @param taskId - The task ID
   * @returns True if deleted, false if not found
   */
  async deleteTask(taskId: string): Promise<boolean> {
    // CASCADE delete is handled by database foreign keys
    const result = await pool.query(
      `DELETE FROM plan_tasks WHERE id = $1 RETURNING id`,
      [taskId]
    );

    return result.rows.length > 0;
  }

  /**
   * Update a task's status with audit trail.
   * Implements Requirement 3.2: Record status change with timestamp.
   * 
   * @param taskId - The task ID
   * @param input - Status update input
   * @returns The updated Task or null if not found
   */
  async updateStatus(taskId: string, input: UpdateStatusInput): Promise<Task | null> {
    const { status, changedBy, reason } = input;

    const existing = await this.getTask(taskId);
    if (!existing) {
      return null;
    }

    // Validate blocked status requires reason (Requirement 3.6)
    if (status === 'blocked' && !reason) {
      throw new Error('Blocking reason is required when setting status to blocked');
    }

    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Update task status
      const updateFields: string[] = [`status = $1`];
      const updateParams: any[] = [status];
      let paramIndex = 2;

      // Set blocking_reason for blocked status
      if (status === 'blocked') {
        updateFields.push(`blocking_reason = $${paramIndex}`);
        updateParams.push(reason);
        paramIndex++;
      } else if (existing.status === 'blocked') {
        // Clear blocking reason when moving away from blocked
        updateFields.push(`blocking_reason = NULL`);
      }

      // Set completed_at for completed status
      if (status === 'completed') {
        updateFields.push(`completed_at = NOW()`);
      } else if (existing.completedAt) {
        updateFields.push(`completed_at = NULL`);
      }

      updateParams.push(taskId);
      const result = await client.query(
        `UPDATE plan_tasks SET ${updateFields.join(', ')}, updated_at = NOW()
         WHERE id = $${paramIndex}
         RETURNING *`,
        updateParams
      );

      // Record status change in history (Requirement 3.2)
      await client.query(
        `INSERT INTO task_status_history (id, task_id, status, changed_by, reason, changed_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [uuidv4(), taskId, status, changedBy, reason || null]
      );

      await client.query('COMMIT');

      if (result.rows.length === 0) {
        return null;
      }

      return this.mapRowToTask(result.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Pause a task, preserving its current state.
   * Implements Requirement 3.3: Mark as paused and preserve state.
   * 
   * @param taskId - The task ID
   * @param changedBy - User or agent ID pausing the task
   * @param reason - Optional reason for pausing
   * @returns The paused Task or null if not found
   */
  async pauseTask(taskId: string, changedBy: string, reason?: string): Promise<Task | null> {
    const existing = await this.getTask(taskId);
    if (!existing) {
      return null;
    }

    // Can only pause tasks that are in_progress
    if (existing.status !== 'in_progress') {
      throw new Error(`Cannot pause task with status '${existing.status}'. Only in_progress tasks can be paused.`);
    }

    return this.updateStatus(taskId, {
      status: 'paused',
      changedBy,
      reason,
    });
  }

  /**
   * Resume a paused task, restoring it to in_progress status.
   * Implements Requirement 3.4: Restore to in_progress status.
   * 
   * @param taskId - The task ID
   * @param changedBy - User or agent ID resuming the task
   * @returns The resumed Task or null if not found
   */
  async resumeTask(taskId: string, changedBy: string): Promise<Task | null> {
    const existing = await this.getTask(taskId);
    if (!existing) {
      return null;
    }

    // Can only resume tasks that are paused
    if (existing.status !== 'paused') {
      throw new Error(`Cannot resume task with status '${existing.status}'. Only paused tasks can be resumed.`);
    }

    return this.updateStatus(taskId, {
      status: 'in_progress',
      changedBy,
    });
  }

  /**
   * Block a task with a reason.
   * Implements Requirement 3.6: Allow blocking with reason.
   * 
   * @param taskId - The task ID
   * @param changedBy - User or agent ID blocking the task
   * @param reason - Required reason for blocking
   * @returns The blocked Task or null if not found
   */
  async blockTask(taskId: string, changedBy: string, reason: string): Promise<Task | null> {
    if (!reason || reason.trim() === '') {
      throw new Error('Blocking reason is required');
    }

    return this.updateStatus(taskId, {
      status: 'blocked',
      changedBy,
      reason,
    });
  }

  /**
   * Start a task, setting it to in_progress.
   * 
   * @param taskId - The task ID
   * @param changedBy - User or agent ID starting the task
   * @returns The started Task or null if not found
   */
  async startTask(taskId: string, changedBy: string): Promise<Task | null> {
    const existing = await this.getTask(taskId);
    if (!existing) {
      return null;
    }

    // Can only start tasks that are not_started or blocked
    if (existing.status !== 'not_started' && existing.status !== 'blocked') {
      throw new Error(`Cannot start task with status '${existing.status}'. Only not_started or blocked tasks can be started.`);
    }

    return this.updateStatus(taskId, {
      status: 'in_progress',
      changedBy,
    });
  }

  /**
   * Complete a task.
   * 
   * @param taskId - The task ID
   * @param changedBy - User or agent ID completing the task
   * @param summary - Optional completion summary
   * @returns The completed Task or null if not found
   */
  async completeTask(taskId: string, changedBy: string, summary?: string): Promise<Task | null> {
    return this.updateStatus(taskId, {
      status: 'completed',
      changedBy,
      reason: summary,
    });
  }

  /**
   * Add an agent output to a task.
   * 
   * @param taskId - The task ID
   * @param output - Output data
   * @returns The created AgentOutput
   */
  async addAgentOutput(
    taskId: string,
    output: {
      agentSessionId?: string;
      agentName?: string;
      outputType: 'comment' | 'code' | 'file' | 'completion';
      content: string;
      metadata?: Record<string, any>;
    }
  ): Promise<AgentOutput> {
    const outputId = uuidv4();

    const result = await pool.query(
      `INSERT INTO task_agent_outputs 
       (id, task_id, agent_session_id, agent_name, output_type, content, metadata, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [
        outputId,
        taskId,
        output.agentSessionId || null,
        output.agentName || null,
        output.outputType,
        output.content,
        output.metadata ? JSON.stringify(output.metadata) : null,
      ]
    );

    return this.mapRowToAgentOutput(result.rows[0]);
  }

  // ==================== HELPER METHODS ====================

  /**
   * Get sub-tasks for a task.
   */
  private async getSubTasks(taskId: string): Promise<Task[]> {
    const result = await pool.query(
      `SELECT * FROM plan_tasks WHERE parent_task_id = $1 ORDER BY created_at ASC`,
      [taskId]
    );

    return result.rows.map(row => this.mapRowToTask(row));
  }

  /**
   * Get status history for a task.
   */
  async getStatusHistory(taskId: string): Promise<StatusHistoryEntry[]> {
    const result = await pool.query(
      `SELECT * FROM task_status_history WHERE task_id = $1 ORDER BY changed_at ASC`,
      [taskId]
    );

    return result.rows.map(row => this.mapRowToStatusHistory(row));
  }

  /**
   * Get agent outputs for a task.
   */
  private async getAgentOutputs(taskId: string): Promise<AgentOutput[]> {
    const result = await pool.query(
      `SELECT * FROM task_agent_outputs WHERE task_id = $1 ORDER BY created_at ASC`,
      [taskId]
    );

    return result.rows.map(row => this.mapRowToAgentOutput(row));
  }

  /**
   * Check if all sub-tasks of a parent task are completed.
   * Useful for Requirement 3.5: Prompt user when all sub-tasks complete.
   */
  async areAllSubTasksCompleted(parentTaskId: string): Promise<boolean> {
    const result = await pool.query(
      `SELECT COUNT(*) as total, 
              COUNT(*) FILTER (WHERE status = 'completed') as completed
       FROM plan_tasks WHERE parent_task_id = $1`,
      [parentTaskId]
    );

    const { total, completed } = result.rows[0];
    return parseInt(total) > 0 && parseInt(total) === parseInt(completed);
  }

  /**
   * Get tasks by plan ID with their completion status.
   */
  async getTasksByPlanId(planId: string): Promise<Task[]> {
    const result = await pool.query(
      `SELECT * FROM plan_tasks WHERE plan_id = $1 ORDER BY created_at ASC`,
      [planId]
    );

    return result.rows.map(row => this.mapRowToTask(row));
  }

  /**
   * Map a database row to a Task object.
   */
  private mapRowToTask(row: any): Task {
    return {
      id: row.id,
      planId: row.plan_id,
      parentTaskId: row.parent_task_id || undefined,
      requirementIds: row.requirement_ids || [],
      title: row.title,
      description: row.description || undefined,
      status: row.status as TaskStatus,
      priority: row.priority as TaskPriority,
      assignedAgentId: row.assigned_agent_id || undefined,
      timeSpentMinutes: row.time_spent_minutes || 0,
      blockingReason: row.blocking_reason || undefined,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
      completedAt: row.completed_at ? new Date(row.completed_at) : undefined,
    };
  }

  /**
   * Map a database row to a StatusHistoryEntry object.
   */
  private mapRowToStatusHistory(row: any): StatusHistoryEntry {
    return {
      id: row.id,
      taskId: row.task_id,
      status: row.status as TaskStatus,
      changedBy: row.changed_by,
      reason: row.reason || undefined,
      changedAt: new Date(row.changed_at),
    };
  }

  /**
   * Map a database row to an AgentOutput object.
   */
  private mapRowToAgentOutput(row: any): AgentOutput {
    return {
      id: row.id,
      taskId: row.task_id,
      agentSessionId: row.agent_session_id || undefined,
      agentName: row.agent_name || undefined,
      outputType: row.output_type,
      content: row.content,
      metadata: row.metadata || undefined,
      createdAt: new Date(row.created_at),
    };
  }
}

// Export singleton instance
export const planTaskService = new PlanTaskService();
export default planTaskService;
