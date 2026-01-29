/**
 * Gitu Permission Manager Service
 * Controls access to integrations and resources with granular permissions.
 * Implements permission CRUD, permission checking, and permission scopes.
 * 
 * Requirements: US-12 (Permission System), TR-1 (Architecture)
 * Design: Section 5 (Permission Manager)
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

/**
 * Permission scope for fine-grained access control
 */
export interface PermissionScope {
  // For files
  allowedPaths?: string[];
  
  // For email
  emailLabels?: string[];
  
  // For notebooks
  notebookIds?: string[];
  
  // For VPS
  vpsConfigIds?: string[];
  allowedCommands?: string[];
  
  // For custom integrations
  customScope?: Record<string, any>;
}

/**
 * Permission grant for a user
 */
export interface Permission {
  id: string;
  userId: string;
  resource: string;  // 'gmail', 'shopify', 'files', 'notebooks', 'vps', etc.
  actions: ('read' | 'write' | 'execute' | 'delete')[];
  scope?: PermissionScope;
  grantedAt: Date;
  expiresAt?: Date;
  revokedAt?: Date;
}

/**
 * Permission request from Gitu
 */
export interface PermissionRequest {
  id: string;
  userId: string;
  permission: Omit<Permission, 'id' | 'userId' | 'grantedAt' | 'revokedAt'>;
  reason: string;
  status: 'pending' | 'approved' | 'denied';
  requestedAt: Date;
  respondedAt?: Date;
  grantedPermissionId?: string;
}

/**
 * Options for creating a permission
 */
export interface CreatePermissionOptions {
  resource: string;
  actions: ('read' | 'write' | 'execute' | 'delete')[];
  scope?: PermissionScope;
  expiresAt?: Date;
}

/**
 * Options for checking a permission
 */
export interface CheckPermissionOptions {
  resource: string;
  action: 'read' | 'write' | 'execute' | 'delete';
  scope?: {
    path?: string;
    notebookId?: string;
    emailLabel?: string;
    vpsConfigId?: string;
    command?: string;
  };
}

// ==================== CONSTANTS ====================

/**
 * Valid resource types
 */
const VALID_RESOURCES = [
  'gmail',
  'shopify',
  'files',
  'notebooks',
  'vps',
  'shell',
  'github',
  'calendar',
  'slack',
  'custom',
] as const;

/**
 * Valid actions
 */
const VALID_ACTIONS = ['read', 'write', 'execute', 'delete'] as const;

/**
 * Default permission expiry (30 days)
 */
const DEFAULT_EXPIRY_DAYS = 30;

// ==================== SERVICE CLASS ====================

class GituPermissionManager {
  /**
   * Grant a permission to a user.
   * 
   * @param userId - The user's ID
   * @param options - Permission options
   * @returns The created Permission
   */
  async grantPermission(userId: string, options: CreatePermissionOptions): Promise<Permission> {
    // Validate resource
    if (!VALID_RESOURCES.includes(options.resource as any)) {
      throw new Error(`Invalid resource: ${options.resource}. Must be one of: ${VALID_RESOURCES.join(', ')}`);
    }
    
    // Validate actions
    for (const action of options.actions) {
      if (!VALID_ACTIONS.includes(action as any)) {
        throw new Error(`Invalid action: ${action}. Must be one of: ${VALID_ACTIONS.join(', ')}`);
      }
    }
    
    const permissionId = uuidv4();
    const expiresAt = options.expiresAt || new Date(Date.now() + DEFAULT_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    
    const result = await pool.query(
      `INSERT INTO gitu_permissions 
       (id, user_id, resource, actions, scope, granted_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), $6)
       RETURNING *`,
      [
        permissionId,
        userId,
        options.resource,
        options.actions,
        options.scope ? JSON.stringify(options.scope) : null,
        expiresAt,
      ]
    );
    
    console.log(`[Permission Manager] Granted ${options.resource} permission to user ${userId}`);
    
    return this.mapRowToPermission(result.rows[0]);
  }

  /**
   * Revoke a permission.
   * 
   * @param userId - The user's ID
   * @param permissionId - The permission ID to revoke
   */
  async revokePermission(userId: string, permissionId: string): Promise<void> {
    const result = await pool.query(
      `UPDATE gitu_permissions 
       SET revoked_at = NOW()
       WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
       RETURNING *`,
      [permissionId, userId]
    );
    
    if (result.rows.length === 0) {
      throw new Error(`Permission ${permissionId} not found or already revoked`);
    }
    
    console.log(`[Permission Manager] Revoked permission ${permissionId} for user ${userId}`);
  }

  /**
   * Revoke all permissions for a resource.
   * 
   * @param userId - The user's ID
   * @param resource - The resource name
   */
  async revokeAllPermissions(userId: string, resource: string): Promise<number> {
    const result = await pool.query(
      `UPDATE gitu_permissions 
       SET revoked_at = NOW()
       WHERE user_id = $1 AND resource = $2 AND revoked_at IS NULL
       RETURNING id`,
      [userId, resource]
    );
    
    const count = result.rowCount || 0;
    console.log(`[Permission Manager] Revoked ${count} permissions for ${resource} for user ${userId}`);
    
    return count;
  }

  /**
   * Check if a user has permission to perform an action on a resource.
   * 
   * @param userId - The user's ID
   * @param options - Permission check options
   * @returns True if permission is granted, false otherwise
   */
  async checkPermission(userId: string, options: CheckPermissionOptions): Promise<boolean> {
    try {
      // Get all active permissions for this resource
      const permissions = await this.listPermissions(userId, options.resource);
      
      // Filter to only active, non-expired, non-revoked permissions
      const activePermissions = permissions.filter(p => 
        !p.revokedAt &&
        (!p.expiresAt || p.expiresAt > new Date())
      );
      
      if (activePermissions.length === 0) {
        return false;
      }
      
      // Check if any permission grants the requested action
      for (const permission of activePermissions) {
        if (!permission.actions.includes(options.action)) {
          continue;
        }
        
        // Check scope if specified
        if (options.scope && permission.scope) {
          if (!this.checkScope(permission.scope, options.scope)) {
            continue;
          }
        }
        
        // Permission found and scope matches
        return true;
      }
      
      return false;
    } catch (error) {
      console.error('[Permission Manager] Error checking permission:', error);
      // Fail closed - deny permission on error
      return false;
    }
  }

  /**
   * Check if a scope matches the requested scope.
   * 
   * @param permissionScope - The granted permission scope
   * @param requestedScope - The requested scope
   * @returns True if scope matches, false otherwise
   */
  private checkScope(
    permissionScope: PermissionScope,
    requestedScope: {
      path?: string;
      notebookId?: string;
      emailLabel?: string;
      vpsConfigId?: string;
      command?: string;
    }
  ): boolean {
    // Check file path
    if (requestedScope.path && permissionScope.allowedPaths) {
      const normalizePath = (p: string) =>
        p
          .trim()
          .replace(/^(\.\/|\.\\)+/, '')
          .replace(/\\/g, '/')
          .replace(/\/+/g, '/')
          .replace(/\/$/, '');

      const requestedPath = normalizePath(requestedScope.path);
      const pathAllowed = permissionScope.allowedPaths.some(allowedPath => {
        const allowed = normalizePath(allowedPath);
        if (allowed === '*') return true;
        if (!allowed) return false;
        return requestedPath === allowed || requestedPath.startsWith(`${allowed}/`);
      });
      if (!pathAllowed) {
        return false;
      }
    }
    
    // Check notebook ID
    if (requestedScope.notebookId && permissionScope.notebookIds) {
      if (!permissionScope.notebookIds.includes(requestedScope.notebookId)) {
        return false;
      }
    }
    
    // Check email label
    if (requestedScope.emailLabel && permissionScope.emailLabels) {
      if (!permissionScope.emailLabels.includes(requestedScope.emailLabel)) {
        return false;
      }
    }
    
    // Check VPS config ID
    if (requestedScope.vpsConfigId && permissionScope.vpsConfigIds) {
      if (!permissionScope.vpsConfigIds.includes(requestedScope.vpsConfigId)) {
        return false;
      }
    }
    
    // Check command
    if (requestedScope.command && permissionScope.allowedCommands) {
      const commandAllowed = permissionScope.allowedCommands.some(allowedCmd => {
        if (allowedCmd === '*') return true;
        // Check if command starts with allowed command
        return requestedScope.command!.startsWith(allowedCmd);
      });
      if (!commandAllowed) {
        return false;
      }
    }
    
    // All scope checks passed
    return true;
  }

  /**
   * List all permissions for a user.
   * 
   * @param userId - The user's ID
   * @param resource - Optional resource filter
   * @returns Array of Permissions
   */
  async listPermissions(userId: string, resource?: string): Promise<Permission[]> {
    const query = resource
      ? `SELECT * FROM gitu_permissions WHERE user_id = $1 AND resource = $2 ORDER BY granted_at DESC`
      : `SELECT * FROM gitu_permissions WHERE user_id = $1 ORDER BY granted_at DESC`;
    
    const params = resource ? [userId, resource] : [userId];
    
    const result = await pool.query(query, params);
    return result.rows.map(row => this.mapRowToPermission(row));
  }

  /**
   * Get a specific permission by ID.
   * 
   * @param permissionId - The permission ID
   * @returns The Permission or null if not found
   */
  async getPermission(permissionId: string): Promise<Permission | null> {
    const result = await pool.query(
      `SELECT * FROM gitu_permissions WHERE id = $1`,
      [permissionId]
    );
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return this.mapRowToPermission(result.rows[0]);
  }

  /**
   * Update a permission's scope or expiry.
   * 
   * @param permissionId - The permission ID
   * @param updates - Partial permission updates
   * @returns The updated Permission
   */
  async updatePermission(
    permissionId: string,
    updates: { scope?: PermissionScope; expiresAt?: Date }
  ): Promise<Permission> {
    const permission = await this.getPermission(permissionId);
    if (!permission) {
      throw new Error(`Permission ${permissionId} not found`);
    }
    
    const updateFields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;
    
    if (updates.scope !== undefined) {
      updateFields.push(`scope = $${paramIndex++}`);
      values.push(JSON.stringify(updates.scope));
    }
    
    if (updates.expiresAt !== undefined) {
      updateFields.push(`expires_at = $${paramIndex++}`);
      values.push(updates.expiresAt);
    }
    
    if (updateFields.length === 0) {
      return permission;
    }
    
    values.push(permissionId);
    
    const query = `
      UPDATE gitu_permissions 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING *
    `;
    
    const result = await pool.query(query, values);
    return this.mapRowToPermission(result.rows[0]);
  }

  /**
   * Request a permission (for user approval).
   * 
   * @param userId - The user's ID
   * @param permission - The permission being requested
   * @param reason - Reason for the request
   * @returns The created PermissionRequest
   */
  async requestPermission(
    userId: string,
    permission: Omit<Permission, 'id' | 'userId' | 'grantedAt' | 'revokedAt'>,
    reason: string
  ): Promise<PermissionRequest> {
    const requestId = uuidv4();

    const result = await pool.query(
      `INSERT INTO gitu_permission_requests
       (id, user_id, resource, actions, scope, expires_at, reason, status, requested_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', NOW())
       RETURNING *`,
      [
        requestId,
        userId,
        permission.resource,
        permission.actions,
        permission.scope ? JSON.stringify(permission.scope) : null,
        permission.expiresAt ?? null,
        reason,
      ]
    );

    console.log(`[Permission Manager] Permission request created: ${requestId} for ${permission.resource}`);

    return this.mapRowToPermissionRequest(result.rows[0]);
  }

  /**
   * Approve a permission request.
   * 
   * @param requestId - The request ID
   * @returns The granted Permission
   */
  async approveRequest(userId: string, requestId: string, overrides?: { expiresAt?: Date }): Promise<Permission> {
    const found = await pool.query(
      `SELECT * FROM gitu_permission_requests WHERE id = $1 AND user_id = $2`,
      [requestId, userId]
    );
    if (found.rows.length === 0) throw new Error('Permission request not found');
    const request = this.mapRowToPermissionRequest(found.rows[0]);
    if (request.status !== 'pending') throw new Error('Permission request already resolved');

    const granted = await this.grantPermission(userId, {
      resource: request.permission.resource,
      actions: request.permission.actions,
      scope: request.permission.scope,
      expiresAt: overrides?.expiresAt ?? request.permission.expiresAt,
    });

    await pool.query(
      `UPDATE gitu_permission_requests
       SET status = 'approved', responded_at = NOW(), granted_permission_id = $1
       WHERE id = $2 AND user_id = $3`,
      [granted.id, requestId, userId]
    );

    return granted;
  }

  /**
   * Deny a permission request.
   * 
   * @param requestId - The request ID
   */
  async denyRequest(userId: string, requestId: string): Promise<void> {
    const result = await pool.query(
      `UPDATE gitu_permission_requests
       SET status = 'denied', responded_at = NOW()
       WHERE id = $1 AND user_id = $2 AND status = 'pending'
       RETURNING id`,
      [requestId, userId]
    );
    if (result.rows.length === 0) throw new Error('Permission request not found or already resolved');
  }

  async listPermissionRequests(
    userId: string,
    status?: PermissionRequest['status']
  ): Promise<PermissionRequest[]> {
    const params: any[] = [userId];
    let query = `SELECT * FROM gitu_permission_requests WHERE user_id = $1`;
    if (status) {
      params.push(status);
      query += ` AND status = $2`;
    }
    query += ` ORDER BY requested_at DESC`;
    const result = await pool.query(query, params);
    return result.rows.map(row => this.mapRowToPermissionRequest(row));
  }

  /**
   * Clean up expired permissions.
   * This should be run as a cron job.
   * 
   * @returns Number of permissions cleaned up
   */
  async cleanupExpiredPermissions(): Promise<number> {
    const result = await pool.query(
      `UPDATE gitu_permissions 
       SET revoked_at = NOW()
       WHERE expires_at < NOW() AND revoked_at IS NULL
       RETURNING id`
    );
    
    const count = result.rowCount || 0;
    if (count > 0) {
      console.log(`[Permission Manager] Cleaned up ${count} expired permissions`);
    }
    
    return count;
  }

  /**
   * Get permission statistics for a user.
   * 
   * @param userId - The user's ID
   * @returns Permission statistics
   */
  async getPermissionStats(userId: string): Promise<{
    totalPermissions: number;
    activePermissions: number;
    expiredPermissions: number;
    revokedPermissions: number;
    byResource: Record<string, number>;
  }> {
    const permissions = await this.listPermissions(userId);
    
    const now = new Date();
    const stats = {
      totalPermissions: permissions.length,
      activePermissions: permissions.filter(p => 
        !p.revokedAt && (!p.expiresAt || p.expiresAt > now)
      ).length,
      expiredPermissions: permissions.filter(p => 
        !p.revokedAt && p.expiresAt && p.expiresAt <= now
      ).length,
      revokedPermissions: permissions.filter(p => p.revokedAt).length,
      byResource: {} as Record<string, number>,
    };
    
    // Count by resource
    for (const permission of permissions) {
      if (!permission.revokedAt && (!permission.expiresAt || permission.expiresAt > now)) {
        stats.byResource[permission.resource] = (stats.byResource[permission.resource] || 0) + 1;
      }
    }
    
    return stats;
  }

  /**
   * Check if user has any active permissions for a resource.
   * 
   * @param userId - The user's ID
   * @param resource - The resource name
   * @returns True if user has any active permissions
   */
  async hasAnyPermission(userId: string, resource: string): Promise<boolean> {
    const permissions = await this.listPermissions(userId, resource);
    
    const now = new Date();
    return permissions.some(p => 
      !p.revokedAt && (!p.expiresAt || p.expiresAt > now)
    );
  }

  /**
   * Get all resources a user has permissions for.
   * 
   * @param userId - The user's ID
   * @returns Array of resource names
   */
  async getAuthorizedResources(userId: string): Promise<string[]> {
    const permissions = await this.listPermissions(userId);
    
    const now = new Date();
    const resources = new Set<string>();
    
    for (const permission of permissions) {
      if (!permission.revokedAt && (!permission.expiresAt || permission.expiresAt > now)) {
        resources.add(permission.resource);
      }
    }
    
    return Array.from(resources);
  }

  /**
   * Extend permission expiry.
   * 
   * @param permissionId - The permission ID
   * @param additionalDays - Number of days to extend
   * @returns The updated Permission
   */
  async extendPermission(permissionId: string, additionalDays: number): Promise<Permission> {
    const permission = await this.getPermission(permissionId);
    if (!permission) {
      throw new Error(`Permission ${permissionId} not found`);
    }
    
    const currentExpiry = permission.expiresAt || new Date();
    const newExpiry = new Date(currentExpiry.getTime() + additionalDays * 24 * 60 * 60 * 1000);
    
    return this.updatePermission(permissionId, { expiresAt: newExpiry });
  }

  /**
   * Map a database row to a Permission object.
   */
  private mapRowToPermission(row: any): Permission {
    return {
      id: row.id,
      userId: row.user_id,
      resource: row.resource,
      actions: row.actions,
      scope: row.scope ? (typeof row.scope === 'string' ? JSON.parse(row.scope) : row.scope) : undefined,
      grantedAt: new Date(row.granted_at),
      expiresAt: row.expires_at ? new Date(row.expires_at) : undefined,
      revokedAt: row.revoked_at ? new Date(row.revoked_at) : undefined,
    };
  }

  private mapRowToPermissionRequest(row: any): PermissionRequest {
    const permission = {
      resource: row.resource,
      actions: row.actions,
      scope: row.scope ? (typeof row.scope === 'string' ? JSON.parse(row.scope) : row.scope) : undefined,
      expiresAt: row.expires_at ? new Date(row.expires_at) : undefined,
    } satisfies Omit<Permission, 'id' | 'userId' | 'grantedAt' | 'revokedAt'>;

    return {
      id: row.id,
      userId: row.user_id,
      permission,
      reason: row.reason,
      status: row.status,
      requestedAt: new Date(row.requested_at),
      respondedAt: row.responded_at ? new Date(row.responded_at) : undefined,
      grantedPermissionId: row.granted_permission_id ?? undefined,
    };
  }
}

// Export singleton instance
export const gituPermissionManager = new GituPermissionManager();
export default gituPermissionManager;
