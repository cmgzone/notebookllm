/**
 * Plan Access Control Service
 * Manages agent access to plans in Planning Mode.
 * Provides grant, revoke, check, and list operations for access control.
 * 
 * Requirements: 7.1, 7.2, 7.3, 7.4
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

export type Permission = 'read' | 'update' | 'create_task';

export interface GrantAccessInput {
  planId: string;
  agentSessionId: string;
  agentName?: string;
  permissions?: Permission[];
}

export interface AgentAccess {
  id: string;
  planId: string;
  agentSessionId: string;
  agentName?: string;
  permissions: Permission[];
  grantedAt: Date;
  revokedAt?: Date;
}

export interface AccessCheckResult {
  hasAccess: boolean;
  permissions: Permission[];
  reason?: string;
}

export interface ListAccessiblePlansOptions {
  status?: 'draft' | 'active' | 'completed' | 'archived';
  includeArchived?: boolean;
  limit?: number;
  offset?: number;
}

// ==================== SERVICE CLASS ====================

class PlanAccessService {
  /**
   * Grant an agent access to a plan.
   * Implements Requirement 7.1: Grant read and update access to agents.
   * 
   * If access already exists and is not revoked, updates the permissions.
   * If access was previously revoked, creates a new access record.
   * 
   * @param userId - The plan owner's user ID (for authorization)
   * @param input - Grant access input
   * @returns The created or updated AgentAccess
   */
  async grantAccess(userId: string, input: GrantAccessInput): Promise<AgentAccess> {
    const { planId, agentSessionId, agentName, permissions = ['read', 'update'] } = input;

    // Verify the plan exists and belongs to the user
    const planCheck = await pool.query(
      `SELECT id, user_id FROM plans WHERE id = $1`,
      [planId]
    );

    if (planCheck.rows.length === 0) {
      throw new Error('Plan not found');
    }

    if (planCheck.rows[0].user_id !== userId) {
      throw new Error('Access denied: You do not own this plan');
    }

    // Check if there's an existing active access record
    const existingAccess = await pool.query(
      `SELECT * FROM plan_agent_access 
       WHERE plan_id = $1 AND agent_session_id = $2 AND revoked_at IS NULL`,
      [planId, agentSessionId]
    );

    if (existingAccess.rows.length > 0) {
      // Update existing access with new permissions
      const result = await pool.query(
        `UPDATE plan_agent_access 
         SET permissions = $1, agent_name = COALESCE($2, agent_name)
         WHERE plan_id = $3 AND agent_session_id = $4 AND revoked_at IS NULL
         RETURNING *`,
        [permissions, agentName, planId, agentSessionId]
      );
      return this.mapRowToAgentAccess(result.rows[0]);
    }

    // Create new access record
    const accessId = uuidv4();
    const result = await pool.query(
      `INSERT INTO plan_agent_access 
       (id, plan_id, agent_session_id, agent_name, permissions, granted_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       RETURNING *`,
      [accessId, planId, agentSessionId, agentName || null, permissions]
    );

    return this.mapRowToAgentAccess(result.rows[0]);
  }

  /**
   * Revoke an agent's access to a plan.
   * Implements Requirement 7.2: Immediately prevent further access.
   * 
   * @param userId - The plan owner's user ID (for authorization)
   * @param planId - The plan ID
   * @param agentSessionId - The agent session ID to revoke
   * @returns True if access was revoked, false if no active access found
   */
  async revokeAccess(userId: string, planId: string, agentSessionId: string): Promise<boolean> {
    // Verify the plan exists and belongs to the user
    const planCheck = await pool.query(
      `SELECT id, user_id FROM plans WHERE id = $1`,
      [planId]
    );

    if (planCheck.rows.length === 0) {
      throw new Error('Plan not found');
    }

    if (planCheck.rows[0].user_id !== userId) {
      throw new Error('Access denied: You do not own this plan');
    }

    // Revoke access by setting revoked_at timestamp
    const result = await pool.query(
      `UPDATE plan_agent_access 
       SET revoked_at = NOW()
       WHERE plan_id = $1 AND agent_session_id = $2 AND revoked_at IS NULL
       RETURNING id`,
      [planId, agentSessionId]
    );

    return result.rows.length > 0;
  }

  /**
   * Check if an agent has access to a plan.
   * Implements Requirement 7.3: Return access denied for unauthorized access.
   * Implements Requirement 7.4: Only allow owner and explicitly shared agents.
   * 
   * @param planId - The plan ID
   * @param agentSessionId - The agent session ID
   * @param userId - Optional user ID (if agent is acting on behalf of user)
   * @param requiredPermission - Optional specific permission to check
   * @returns AccessCheckResult with access status and permissions
   */
  async checkAccess(
    planId: string,
    agentSessionId: string,
    userId?: string,
    requiredPermission?: Permission
  ): Promise<AccessCheckResult> {
    // First, get the plan to check ownership
    const planResult = await pool.query(
      `SELECT id, user_id, is_private FROM plans WHERE id = $1`,
      [planId]
    );

    if (planResult.rows.length === 0) {
      return {
        hasAccess: false,
        permissions: [],
        reason: 'Plan not found',
      };
    }

    const plan = planResult.rows[0];

    // Check if the user owns the plan (full access)
    if (userId && plan.user_id === userId) {
      return {
        hasAccess: true,
        permissions: ['read', 'update', 'create_task'],
      };
    }

    // Check for explicit agent access
    const accessResult = await pool.query(
      `SELECT * FROM plan_agent_access 
       WHERE plan_id = $1 AND agent_session_id = $2 AND revoked_at IS NULL`,
      [planId, agentSessionId]
    );

    if (accessResult.rows.length === 0) {
      // No explicit access - check if plan is public (non-private)
      if (!plan.is_private) {
        return {
          hasAccess: true,
          permissions: ['read'],
          reason: 'Public plan - read-only access',
        };
      }

      return {
        hasAccess: false,
        permissions: [],
        reason: 'Access denied: No permission to access this plan',
      };
    }

    const access = this.mapRowToAgentAccess(accessResult.rows[0]);

    // Check specific permission if required
    if (requiredPermission && !access.permissions.includes(requiredPermission)) {
      return {
        hasAccess: false,
        permissions: access.permissions,
        reason: `Access denied: Missing required permission '${requiredPermission}'`,
      };
    }

    return {
      hasAccess: true,
      permissions: access.permissions,
    };
  }

  /**
   * List all plans accessible to an agent.
   * Implements Requirement 7.4: Only return plans with explicit access or owned by user.
   * 
   * @param agentSessionId - The agent session ID
   * @param userId - Optional user ID (to include owned plans)
   * @param options - List options (status filter, pagination)
   * @returns Array of accessible plan IDs with their permissions
   */
  async listAccessiblePlans(
    agentSessionId: string,
    userId?: string,
    options: ListAccessiblePlansOptions = {}
  ): Promise<Array<{ planId: string; permissions: Permission[]; isOwner: boolean }>> {
    const { status, includeArchived = false, limit = 50, offset = 0 } = options;

    // Build query to get plans with access
    let query = `
      SELECT DISTINCT 
        p.id as plan_id,
        CASE WHEN p.user_id = $2 THEN true ELSE false END as is_owner,
        COALESCE(paa.permissions, ARRAY['read', 'update', 'create_task']::varchar[]) as permissions
      FROM plans p
      LEFT JOIN plan_agent_access paa ON p.id = paa.plan_id 
        AND paa.agent_session_id = $1 
        AND paa.revoked_at IS NULL
      WHERE (
        p.user_id = $2
        OR paa.id IS NOT NULL
        OR p.is_private = false
      )
    `;

    const params: any[] = [agentSessionId, userId || ''];
    let paramIndex = 3;

    // Filter by status
    if (status) {
      query += ` AND p.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    } else if (!includeArchived) {
      query += ` AND p.status != 'archived'`;
    }

    query += ` ORDER BY p.updated_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    return result.rows.map(row => ({
      planId: row.plan_id,
      permissions: row.permissions as Permission[],
      isOwner: row.is_owner,
    }));
  }

  /**
   * Get all agents with access to a plan.
   * Useful for displaying who has access in the UI.
   * 
   * @param userId - The plan owner's user ID (for authorization)
   * @param planId - The plan ID
   * @returns Array of AgentAccess records
   */
  async getAgentsWithAccess(userId: string, planId: string): Promise<AgentAccess[]> {
    // Verify the plan exists and belongs to the user
    const planCheck = await pool.query(
      `SELECT id, user_id FROM plans WHERE id = $1`,
      [planId]
    );

    if (planCheck.rows.length === 0) {
      throw new Error('Plan not found');
    }

    if (planCheck.rows[0].user_id !== userId) {
      throw new Error('Access denied: You do not own this plan');
    }

    const result = await pool.query(
      `SELECT * FROM plan_agent_access 
       WHERE plan_id = $1 AND revoked_at IS NULL
       ORDER BY granted_at DESC`,
      [planId]
    );

    return result.rows.map(row => this.mapRowToAgentAccess(row));
  }

  /**
   * Get access history for a plan (including revoked access).
   * Useful for audit purposes.
   * 
   * @param userId - The plan owner's user ID (for authorization)
   * @param planId - The plan ID
   * @returns Array of all AgentAccess records (including revoked)
   */
  async getAccessHistory(userId: string, planId: string): Promise<AgentAccess[]> {
    // Verify the plan exists and belongs to the user
    const planCheck = await pool.query(
      `SELECT id, user_id FROM plans WHERE id = $1`,
      [planId]
    );

    if (planCheck.rows.length === 0) {
      throw new Error('Plan not found');
    }

    if (planCheck.rows[0].user_id !== userId) {
      throw new Error('Access denied: You do not own this plan');
    }

    const result = await pool.query(
      `SELECT * FROM plan_agent_access 
       WHERE plan_id = $1
       ORDER BY granted_at DESC`,
      [planId]
    );

    return result.rows.map(row => this.mapRowToAgentAccess(row));
  }

  /**
   * Revoke all agent access to a plan.
   * Useful when archiving or deleting a plan.
   * 
   * @param userId - The plan owner's user ID (for authorization)
   * @param planId - The plan ID
   * @returns Number of access records revoked
   */
  async revokeAllAccess(userId: string, planId: string): Promise<number> {
    // Verify the plan exists and belongs to the user
    const planCheck = await pool.query(
      `SELECT id, user_id FROM plans WHERE id = $1`,
      [planId]
    );

    if (planCheck.rows.length === 0) {
      throw new Error('Plan not found');
    }

    if (planCheck.rows[0].user_id !== userId) {
      throw new Error('Access denied: You do not own this plan');
    }

    const result = await pool.query(
      `UPDATE plan_agent_access 
       SET revoked_at = NOW()
       WHERE plan_id = $1 AND revoked_at IS NULL
       RETURNING id`,
      [planId]
    );

    return result.rows.length;
  }

  // ==================== HELPER METHODS ====================

  /**
   * Map a database row to an AgentAccess object.
   */
  private mapRowToAgentAccess(row: any): AgentAccess {
    return {
      id: row.id,
      planId: row.plan_id,
      agentSessionId: row.agent_session_id,
      agentName: row.agent_name || undefined,
      permissions: (row.permissions || ['read']) as Permission[],
      grantedAt: new Date(row.granted_at),
      revokedAt: row.revoked_at ? new Date(row.revoked_at) : undefined,
    };
  }
}

// Export singleton instance
export const planAccessService = new PlanAccessService();
export default planAccessService;
