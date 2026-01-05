/**
 * Plan Service
 * Manages the lifecycle of plans in Planning Mode.
 * Provides CRUD operations for plans with spec-driven structure.
 * 
 * Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

export type PlanStatus = 'draft' | 'active' | 'completed' | 'archived';

export interface CreatePlanInput {
  title: string;
  description?: string;
  isPrivate?: boolean;
}

export interface UpdatePlanInput {
  title?: string;
  description?: string;
  status?: PlanStatus;
  isPrivate?: boolean;
}

export interface Requirement {
  id: string;
  planId: string;
  title: string;
  description?: string;
  earsPattern?: 'ubiquitous' | 'event' | 'state' | 'unwanted' | 'optional' | 'complex';
  acceptanceCriteria: string[];
  sortOrder: number;
  createdAt: Date;
}

export interface DesignNote {
  id: string;
  planId: string;
  requirementIds: string[];
  content: string;
  createdAt: Date;
}

export interface TaskSummary {
  total: number;
  notStarted: number;
  inProgress: number;
  paused: number;
  blocked: number;
  completed: number;
  completionPercentage: number;
}

export interface CompletionTrendPoint {
  date: string;
  completedCount: number;
}

export interface PlanAnalytics {
  planId: string;
  taskSummary: TaskSummary;
  completionPercentage: number;
  totalTimeSpentSeconds: number;
  completionTrend: CompletionTrendPoint[];
  createdAt: Date;
  updatedAt: Date;
  completedAt?: Date;
}

export interface Plan {
  id: string;
  userId: string;
  title: string;
  description?: string;
  status: PlanStatus;
  isPrivate: boolean;
  createdAt: Date;
  updatedAt: Date;
  completedAt?: Date;
  // Optional loaded relations
  requirements?: Requirement[];
  designNotes?: DesignNote[];
  taskSummary?: TaskSummary;
}

export interface ListPlansOptions {
  status?: PlanStatus;
  includeArchived?: boolean;
  limit?: number;
  offset?: number;
}

// ==================== SERVICE CLASS ====================

class PlanService {
  /**
   * Create a new plan with title, description, and empty task list.
   * Implements Requirement 1.1: Plan creation with required fields.
   * 
   * @param userId - The user's ID
   * @param input - Plan creation input
   * @returns The created Plan
   */
  async createPlan(userId: string, input: CreatePlanInput): Promise<Plan> {
    const { title, description, isPrivate = true } = input;
    const planId = uuidv4();

    const result = await pool.query(
      `INSERT INTO plans 
       (id, user_id, title, description, status, is_private, created_at, updated_at)
       VALUES ($1, $2, $3, $4, 'draft', $5, NOW(), NOW())
       RETURNING *`,
      [planId, userId, title, description || null, isPrivate]
    );

    return this.mapRowToPlan(result.rows[0]);
  }

  /**
   * Get a plan by ID with optional relations.
   * Implements Requirement 1.3: Display full plan details.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @param includeRelations - Whether to include requirements, design notes, and task summary
   * @returns The Plan or null if not found
   */
  async getPlan(
    planId: string, 
    userId: string, 
    includeRelations: boolean = false
  ): Promise<Plan | null> {
    const result = await pool.query(
      `SELECT * FROM plans WHERE id = $1 AND user_id = $2`,
      [planId, userId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const plan = this.mapRowToPlan(result.rows[0]);

    if (includeRelations) {
      plan.requirements = await this.getRequirements(planId);
      plan.designNotes = await this.getDesignNotes(planId);
      plan.taskSummary = await this.getTaskSummary(planId);
    }

    return plan;
  }

  /**
   * Get a plan by ID without user check (for internal/MCP use).
   * 
   * @param planId - The plan ID
   * @returns The Plan or null if not found
   */
  async getPlanById(planId: string): Promise<Plan | null> {
    const result = await pool.query(
      `SELECT * FROM plans WHERE id = $1`,
      [planId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToPlan(result.rows[0]);
  }

  /**
   * List all plans for a user with optional filtering.
   * Implements Requirement 1.2: Display all existing plans with status summary.
   * Implements Requirement 1.5: Archive filtering.
   * 
   * @param userId - The user's ID
   * @param options - List options (status filter, pagination)
   * @returns Array of Plans with task summaries
   */
  async listPlans(userId: string, options: ListPlansOptions = {}): Promise<Plan[]> {
    const { status, includeArchived = false, limit = 50, offset = 0 } = options;

    let query = `SELECT * FROM plans WHERE user_id = $1`;
    const params: any[] = [userId];
    let paramIndex = 2;

    // Filter by status if provided
    if (status) {
      query += ` AND status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    } else if (!includeArchived) {
      // Exclude archived by default (Requirement 1.5)
      query += ` AND status != 'archived'`;
    }

    query += ` ORDER BY updated_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    const plans = result.rows.map(row => this.mapRowToPlan(row));

    // Load task summaries for each plan
    for (const plan of plans) {
      plan.taskSummary = await this.getTaskSummary(plan.id);
    }

    return plans;
  }

  /**
   * Update a plan's properties.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @param input - Update input
   * @returns The updated Plan or null if not found
   */
  async updatePlan(
    planId: string, 
    userId: string, 
    input: UpdatePlanInput
  ): Promise<Plan | null> {
    // First check if plan exists and belongs to user
    const existing = await this.getPlan(planId, userId);
    if (!existing) {
      return null;
    }

    // Check if plan is archived (cannot modify archived plans)
    if (existing.status === 'archived' && input.status !== 'active') {
      throw new Error('Cannot modify archived plan');
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

    if (input.status !== undefined) {
      const newStatus = input.status;
      updates.push(`status = $${paramIndex}`);
      params.push(newStatus);
      paramIndex++;

      // Set completed_at when status changes to completed
      if (newStatus === 'completed') {
        updates.push(`completed_at = NOW()`);
      } else if (existing.completedAt) {
        // Clear completed_at if moving away from completed status
        updates.push(`completed_at = NULL`);
      }
    }

    if (input.isPrivate !== undefined) {
      updates.push(`is_private = $${paramIndex}`);
      params.push(input.isPrivate);
      paramIndex++;
    }

    if (updates.length === 0) {
      return existing;
    }

    params.push(planId, userId);
    const result = await pool.query(
      `UPDATE plans SET ${updates.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}
       RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToPlan(result.rows[0]);
  }

  /**
   * Delete a plan and all associated data (cascade).
   * Implements Requirement 1.4: Remove plan and all associated tasks.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @returns True if deleted, false if not found
   */
  async deletePlan(planId: string, userId: string): Promise<boolean> {
    // CASCADE delete is handled by database foreign keys
    const result = await pool.query(
      `DELETE FROM plans WHERE id = $1 AND user_id = $2 RETURNING id`,
      [planId, userId]
    );

    return result.rows.length > 0;
  }

  /**
   * Archive a plan, hiding it from active plans list.
   * Implements Requirement 1.5: Mark as archived and hide from active list.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @returns The archived Plan or null if not found
   */
  async archivePlan(planId: string, userId: string): Promise<Plan | null> {
    return this.updatePlan(planId, userId, { status: 'archived' });
  }

  /**
   * Unarchive a plan, restoring it to draft status.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @returns The unarchived Plan or null if not found
   */
  async unarchivePlan(planId: string, userId: string): Promise<Plan | null> {
    const result = await pool.query(
      `UPDATE plans SET status = 'draft', updated_at = NOW()
       WHERE id = $1 AND user_id = $2 AND status = 'archived'
       RETURNING *`,
      [planId, userId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToPlan(result.rows[0]);
  }

  // ==================== ANALYTICS METHODS ====================
  // Implements Requirement 8.1: Progress Tracking and Analytics

  /**
   * Get completion percentage for a plan.
   * Implements Requirement 8.1: Display completion percentage based on task status.
   * 
   * @param planId - The plan ID
   * @returns Completion percentage (0-100)
   */
  async getCompletionPercentage(planId: string): Promise<number> {
    const summary = await this.getTaskSummary(planId);
    return summary.completionPercentage;
  }

  /**
   * Get detailed analytics for a plan.
   * Implements Requirement 8.1: Progress tracking and analytics.
   * 
   * @param planId - The plan ID
   * @param userId - The user's ID (for access control)
   * @returns Plan analytics or null if not found
   */
  async getPlanAnalytics(planId: string, userId: string): Promise<PlanAnalytics | null> {
    // Verify access
    const plan = await this.getPlan(planId, userId);
    if (!plan) {
      return null;
    }

    const taskSummary = await this.getTaskSummary(planId);

    // Get time spent by agents on tasks
    const timeSpentResult = await pool.query(
      `SELECT 
        COALESCE(SUM(
          CASE 
            WHEN status = 'completed' AND started_at IS NOT NULL AND completed_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (completed_at - started_at))
            WHEN status = 'in_progress' AND started_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (NOW() - started_at))
            ELSE 0
          END
        ), 0) as total_seconds
       FROM plan_tasks WHERE plan_id = $1`,
      [planId]
    );

    const totalTimeSeconds = parseFloat(timeSpentResult.rows[0]?.total_seconds) || 0;

    // Get task completion trend (last 7 days)
    const trendResult = await pool.query(
      `SELECT 
        DATE(completed_at) as date,
        COUNT(*) as completed_count
       FROM plan_tasks 
       WHERE plan_id = $1 
         AND status = 'completed' 
         AND completed_at >= NOW() - INTERVAL '7 days'
       GROUP BY DATE(completed_at)
       ORDER BY date`,
      [planId]
    );

    const completionTrend = trendResult.rows.map(row => ({
      date: row.date,
      completedCount: parseInt(row.completed_count),
    }));

    return {
      planId,
      taskSummary,
      completionPercentage: taskSummary.completionPercentage,
      totalTimeSpentSeconds: totalTimeSeconds,
      completionTrend,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
      completedAt: plan.completedAt,
    };
  }

  // ==================== HELPER METHODS ====================

  // ==================== REQUIREMENT METHODS ====================

  /**
   * Create a new requirement for a plan.
   * Implements Requirement 4.1: Spec-driven structure with requirements.
   */
  async createRequirement(
    planId: string,
    userId: string,
    input: {
      title: string;
      description?: string;
      earsPattern?: 'ubiquitous' | 'event' | 'state' | 'unwanted' | 'optional' | 'complex';
      acceptanceCriteria?: string[];
    }
  ): Promise<Requirement> {
    // Verify user owns the plan
    const plan = await this.getPlan(planId, userId, false);
    if (!plan) {
      throw new Error('Plan not found');
    }
    if (plan.status === 'archived') {
      throw new Error('Cannot add requirements to archived plan');
    }

    // Get next sort order
    const sortResult = await pool.query(
      `SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM plan_requirements WHERE plan_id = $1`,
      [planId]
    );
    const sortOrder = sortResult.rows[0].next_order;

    const id = uuidv4();
    const acceptanceCriteriaJson = JSON.stringify(input.acceptanceCriteria || []);
    const result = await pool.query(
      `INSERT INTO plan_requirements (id, plan_id, title, description, ears_pattern, acceptance_criteria, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
       RETURNING *`,
      [id, planId, input.title, input.description || null, input.earsPattern || null, acceptanceCriteriaJson, sortOrder]
    );

    return this.mapRowToRequirement(result.rows[0]);
  }

  /**
   * Create multiple requirements at once (batch).
   */
  async createRequirementsBatch(
    planId: string,
    userId: string,
    requirements: Array<{
      title: string;
      description?: string;
      earsPattern?: 'ubiquitous' | 'event' | 'state' | 'unwanted' | 'optional' | 'complex';
      acceptanceCriteria?: string[];
    }>
  ): Promise<Requirement[]> {
    // Verify user owns the plan
    const plan = await this.getPlan(planId, userId, false);
    if (!plan) {
      throw new Error('Plan not found');
    }
    if (plan.status === 'archived') {
      throw new Error('Cannot add requirements to archived plan');
    }

    // Get next sort order
    const sortResult = await pool.query(
      `SELECT COALESCE(MAX(sort_order), 0) as max_order FROM plan_requirements WHERE plan_id = $1`,
      [planId]
    );
    let sortOrder = sortResult.rows[0].max_order + 1;

    const createdRequirements: Requirement[] = [];

    for (const req of requirements) {
      const id = uuidv4();
      const acceptanceCriteriaJson = JSON.stringify(req.acceptanceCriteria || []);
      const result = await pool.query(
        `INSERT INTO plan_requirements (id, plan_id, title, description, ears_pattern, acceptance_criteria, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
         RETURNING *`,
        [id, planId, req.title, req.description || null, req.earsPattern || null, acceptanceCriteriaJson, sortOrder++]
      );
      createdRequirements.push(this.mapRowToRequirement(result.rows[0]));
    }

    return createdRequirements;
  }

  /**
   * Delete a requirement.
   */
  async deleteRequirement(requirementId: string, userId: string): Promise<boolean> {
    // Get the requirement to find the plan
    const reqResult = await pool.query(
      `SELECT r.*, p.user_id FROM plan_requirements r 
       JOIN plans p ON r.plan_id = p.id 
       WHERE r.id = $1`,
      [requirementId]
    );

    if (reqResult.rows.length === 0) {
      return false;
    }

    if (reqResult.rows[0].user_id !== userId) {
      throw new Error('Access denied');
    }

    await pool.query(`DELETE FROM plan_requirements WHERE id = $1`, [requirementId]);
    return true;
  }

  // ==================== DESIGN NOTE METHODS ====================

  /**
   * Create a new design note for a plan.
   */
  async createDesignNote(
    planId: string,
    userId: string,
    input: {
      content: string;
      requirementIds?: string[];
    }
  ): Promise<DesignNote> {
    // Verify user owns the plan
    const plan = await this.getPlan(planId, userId, false);
    if (!plan) {
      throw new Error('Plan not found');
    }
    if (plan.status === 'archived') {
      throw new Error('Cannot add design notes to archived plan');
    }

    const id = uuidv4();
    const requirementIdsJson = JSON.stringify(input.requirementIds || []);
    const result = await pool.query(
      `INSERT INTO plan_design_notes (id, plan_id, requirement_ids, content)
       VALUES ($1, $2, $3::jsonb, $4)
       RETURNING *`,
      [id, planId, requirementIdsJson, input.content]
    );

    return this.mapRowToDesignNote(result.rows[0]);
  }

  /**
   * Delete a design note.
   */
  async deleteDesignNote(noteId: string, userId: string): Promise<boolean> {
    // Get the note to find the plan
    const noteResult = await pool.query(
      `SELECT n.*, p.user_id FROM plan_design_notes n 
       JOIN plans p ON n.plan_id = p.id 
       WHERE n.id = $1`,
      [noteId]
    );

    if (noteResult.rows.length === 0) {
      return false;
    }

    if (noteResult.rows[0].user_id !== userId) {
      throw new Error('Access denied');
    }

    await pool.query(`DELETE FROM plan_design_notes WHERE id = $1`, [noteId]);
    return true;
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /**
   * Get requirements for a plan.
   */
  private async getRequirements(planId: string): Promise<Requirement[]> {
    const result = await pool.query(
      `SELECT * FROM plan_requirements WHERE plan_id = $1 ORDER BY sort_order`,
      [planId]
    );

    return result.rows.map(row => this.mapRowToRequirement(row));
  }

  /**
   * Get design notes for a plan.
   */
  private async getDesignNotes(planId: string): Promise<DesignNote[]> {
    const result = await pool.query(
      `SELECT * FROM plan_design_notes WHERE plan_id = $1 ORDER BY created_at`,
      [planId]
    );

    return result.rows.map(row => this.mapRowToDesignNote(row));
  }

  /**
   * Get task summary for a plan.
   * Implements Requirement 8.1: Display completion percentage based on task status.
   */
  private async getTaskSummary(planId: string): Promise<TaskSummary> {
    const result = await pool.query(
      `SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'not_started') as not_started,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress,
        COUNT(*) FILTER (WHERE status = 'paused') as paused,
        COUNT(*) FILTER (WHERE status = 'blocked') as blocked,
        COUNT(*) FILTER (WHERE status = 'completed') as completed
       FROM plan_tasks WHERE plan_id = $1`,
      [planId]
    );

    const row = result.rows[0];
    const total = parseInt(row.total) || 0;
    const completed = parseInt(row.completed) || 0;
    
    // Calculate completion percentage (Requirement 8.1)
    const completionPercentage = total > 0 ? Math.round((completed / total) * 100) : 0;

    return {
      total,
      notStarted: parseInt(row.not_started) || 0,
      inProgress: parseInt(row.in_progress) || 0,
      paused: parseInt(row.paused) || 0,
      blocked: parseInt(row.blocked) || 0,
      completed,
      completionPercentage,
    };
  }

  /**
   * Map a database row to a Plan object.
   */
  private mapRowToPlan(row: any): Plan {
    return {
      id: row.id,
      userId: row.user_id,
      title: row.title,
      description: row.description || undefined,
      status: row.status as PlanStatus,
      isPrivate: row.is_private,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
      completedAt: row.completed_at ? new Date(row.completed_at) : undefined,
    };
  }

  /**
   * Map a database row to a Requirement object.
   */
  private mapRowToRequirement(row: any): Requirement {
    return {
      id: row.id,
      planId: row.plan_id,
      title: row.title,
      description: row.description || undefined,
      earsPattern: row.ears_pattern || undefined,
      acceptanceCriteria: row.acceptance_criteria || [],
      sortOrder: row.sort_order,
      createdAt: new Date(row.created_at),
    };
  }

  /**
   * Map a database row to a DesignNote object.
   */
  private mapRowToDesignNote(row: any): DesignNote {
    return {
      id: row.id,
      planId: row.plan_id,
      requirementIds: row.requirement_ids || [],
      content: row.content,
      createdAt: new Date(row.created_at),
    };
  }
}

// Export singleton instance
export const planService = new PlanService();
export default planService;
