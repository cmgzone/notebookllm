import pool from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';
import { ForbiddenError, ValidationError, NotFoundError } from '../types/errors.js';

type GroupRole = 'owner' | 'admin' | 'moderator' | 'member';

const ROLE_RANK: Record<GroupRole, number> = {
  owner: 3,
  admin: 2,
  moderator: 1,
  member: 0,
};

const hasRankAtLeast = (role: GroupRole, minimum: GroupRole) =>
  ROLE_RANK[role] >= ROLE_RANK[minimum];

const hasHigherRank = (actor: GroupRole, target: GroupRole) =>
  ROLE_RANK[actor] > ROLE_RANK[target];

const normalizeRole = (role?: string): GroupRole =>
  role === 'owner' || role === 'admin' || role === 'moderator'
    ? role
    : 'member';

export interface StudyGroup {
  id: string;
  name: string;
  description?: string;
  ownerId: string;
  icon: string;
  coverImageUrl?: string;
  isPublic: boolean;
  maxMembers: number;
  memberCount?: number;
  createdAt: Date;
}

export interface StudySession {
  id: string;
  groupId: string;
  title: string;
  description?: string;
  scheduledAt: Date;
  durationMinutes: number;
  meetingUrl?: string;
  createdBy: string;
}

export const studyGroupService = {
  async getMemberRole(groupId: string, userId: string): Promise<GroupRole | null> {
    const result = await pool.query(
      'SELECT role FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
    if (result.rows.length === 0) return null;
    return normalizeRole(result.rows[0].role);
  },

  async logGroupAudit(
    groupId: string,
    actorId: string,
    action: string,
    targetUserId?: string,
    metadata?: Record<string, any>
  ) {
    try {
      await pool.query(
        `INSERT INTO group_audit_logs (id, group_id, actor_id, action, target_user_id, metadata)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          uuidv4(),
          groupId,
          actorId,
          action,
          targetUserId || null,
          metadata || {},
        ]
      );
    } catch (error) {
      // Audit logging should not block main operations
      console.error('Failed to log group audit:', (error as Error).message);
    }
  },

  async isBanned(groupId: string, userId: string): Promise<boolean> {
    const result = await pool.query(
      'SELECT id FROM group_bans WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
    return result.rows.length > 0;
  },
  async createGroup(data: {
    name: string;
    description?: string;
    ownerId: string;
    icon?: string;
    isPublic?: boolean;
  }) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const groupId = uuidv4();
      const result = await client.query(`
        INSERT INTO study_groups (id, name, description, owner_id, icon, is_public)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
      `, [groupId, data.name, data.description, data.ownerId, data.icon || '📚', data.isPublic || false]);

      const group = result.rows[0];

      // Add owner as member with owner role
      const memberId = uuidv4();
      await client.query(`
        INSERT INTO study_group_members (id, group_id, user_id, role)
        VALUES ($1, $2, $3, 'owner')
      `, [memberId, group.id, data.ownerId]);

      await client.query('COMMIT');
      return group;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  async getGroup(groupId: string, userId: string) {
    const result = await pool.query(`
      SELECT g.*, 
        (SELECT COUNT(*) FROM study_group_members WHERE group_id = g.id) as member_count,
        (SELECT role FROM study_group_members WHERE group_id = g.id AND user_id = $2) as user_role,
        u.display_name as owner_username
      FROM study_groups g
      JOIN users u ON u.id = g.owner_id
      WHERE g.id = $1
    `, [groupId, userId]);
    return result.rows[0];
  },

  async getUserGroups(userId: string) {
    const result = await pool.query(`
      SELECT g.*, 
        (SELECT COUNT(*) FROM study_group_members WHERE group_id = g.id) as member_count,
        m.role as user_role
      FROM study_groups g
      JOIN study_group_members m ON m.group_id = g.id
      WHERE m.user_id = $1
      ORDER BY g.created_at DESC
    `, [userId]);
    return result.rows;
  },

  async getPublicGroups(userId: string, options?: { limit?: number; offset?: number; search?: string }) {
    const limit = Math.min(options?.limit || 20, 50);
    const offset = options?.offset || 0;

    let query = `
      SELECT g.*, 
        (SELECT COUNT(*) FROM study_group_members WHERE group_id = g.id) as member_count,
        (SELECT role FROM study_group_members WHERE group_id = g.id AND user_id = $1) as user_role,
        u.display_name as owner_username
      FROM study_groups g
      JOIN users u ON u.id = g.owner_id
      WHERE g.is_public = true
    `;
    const params: any[] = [userId];

    if (options?.search) {
      params.push(`%${options.search}%`);
      query += ` AND (g.name ILIKE $${params.length} OR g.description ILIKE $${params.length})`;
    }

    query += ` ORDER BY member_count DESC, g.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    return result.rows;
  },

  async joinPublicGroup(groupId: string, userId: string) {
    // Check if group is public
    const groupCheck = await pool.query(
      'SELECT is_public, max_members FROM study_groups WHERE id = $1',
      [groupId]
    );

    if (groupCheck.rows.length === 0) {
      throw new NotFoundError('Group not found');
    }

    if (!groupCheck.rows[0].is_public) {
      throw new ValidationError('This group is not public');
    }

    if (await this.isBanned(groupId, userId)) {
      throw new ForbiddenError('You are banned from this group');
    }

    // Check member count
    const memberCount = await pool.query(
      'SELECT COUNT(*) FROM study_group_members WHERE group_id = $1',
      [groupId]
    );

    if (parseInt(memberCount.rows[0].count) >= groupCheck.rows[0].max_members) {
      throw new ValidationError('Group is full');
    }

    // Check if already a member
    const existingMember = await pool.query(
      'SELECT id FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );

    if (existingMember.rows.length > 0) {
      throw new ValidationError('Already a member of this group');
    }

    // Join the group
    await pool.query(
      'INSERT INTO study_group_members (group_id, user_id, role) VALUES ($1, $2, $3)',
      [groupId, userId, 'member']
    );

    return { success: true };
  },


  async updateGroup(groupId: string, userId: string, data: Partial<StudyGroup>) {
    // Check if user is owner or admin
    const memberCheck = await pool.query(`
      SELECT role FROM study_group_members 
      WHERE group_id = $1 AND user_id = $2 AND role IN ('owner', 'admin')
    `, [groupId, userId]);

    if (memberCheck.rows.length === 0) {
      throw new ForbiddenError('Not authorized to update this group');
    }

    const result = await pool.query(`
      UPDATE study_groups
      SET name = COALESCE($3, name),
          description = COALESCE($4, description),
          icon = COALESCE($5, icon),
          is_public = COALESCE($6, is_public),
          updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [groupId, userId, data.name, data.description, data.icon, data.isPublic]);
    return result.rows[0];
  },

  async deleteGroup(groupId: string, userId: string) {
    const result = await pool.query(`
      DELETE FROM study_groups
      WHERE id = $1 AND owner_id = $2
      RETURNING *
    `, [groupId, userId]);

    if (result.rows.length === 0) {
      throw new ForbiddenError('Not authorized to delete this group');
    }
    return { success: true };
  },

  async inviteUser(groupId: string, invitedUserId: string, invitedBy: string) {
    // Check if inviter is member
    const memberCheck = await pool.query(`
      SELECT role FROM study_group_members WHERE group_id = $1 AND user_id = $2
    `, [groupId, invitedBy]);

    if (memberCheck.rows.length === 0) {
      throw new ForbiddenError('Not a member of this group');
    }

    if (await this.isBanned(groupId, invitedUserId)) {
      throw new ForbiddenError('User is banned from this group');
    }

    const id = uuidv4();
    const result = await pool.query(`
      INSERT INTO group_invitations (id, group_id, invited_user_id, invited_by)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (group_id, invited_user_id) DO NOTHING
      RETURNING *
    `, [id, groupId, invitedUserId, invitedBy]);
    return result.rows[0];
  },

  async acceptInvitation(invitationId: string, userId: string) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const invitation = await client.query(`
        UPDATE group_invitations
        SET status = 'accepted', responded_at = NOW()
        WHERE id = $1 AND invited_user_id = $2 AND status = 'pending'
        RETURNING *
      `, [invitationId, userId]);

      if (invitation.rows.length === 0) {
        throw new NotFoundError('Invitation not found');
      }

      const groupId = invitation.rows[0].group_id;
      if (await this.isBanned(groupId, userId)) {
        throw new ForbiddenError('You are banned from this group');
      }

      const memberId = uuidv4();
      await client.query(`
        INSERT INTO study_group_members (id, group_id, user_id, invited_by)
        VALUES ($1, $2, $3, $4)
      `, [memberId, groupId, userId, invitation.rows[0].invited_by]);

      await client.query('COMMIT');
      return { success: true };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  async leaveGroup(groupId: string, userId: string) {
    // Check if user is owner
    const ownerCheck = await pool.query(`
      SELECT owner_id FROM study_groups WHERE id = $1
    `, [groupId]);

    if (ownerCheck.rows[0]?.owner_id === userId) {
      throw new ValidationError('Owner cannot leave the group. Transfer ownership or delete the group.');
    }

    await pool.query(`
      DELETE FROM study_group_members WHERE group_id = $1 AND user_id = $2
    `, [groupId, userId]);
    return { success: true };
  },

  async getMembers(groupId: string) {
    const result = await pool.query(`
      SELECT m.*, u.display_name as username, u.email, u.avatar_url
      FROM study_group_members m
      JOIN users u ON u.id = m.user_id
      WHERE m.group_id = $1
      ORDER BY m.role = 'owner' DESC, m.joined_at ASC
    `, [groupId]);
    return result.rows;
  },

  async updateMemberRole(groupId: string, actorId: string, targetUserId: string, role: GroupRole) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (!actorRole) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasRankAtLeast(actorRole, 'admin')) {
      throw new ForbiddenError('Not authorized to update roles');
    }

    const targetRole = await this.getMemberRole(groupId, targetUserId);
    if (!targetRole) {
      throw new ValidationError('Target user is not a member');
    }
    if (targetRole === 'owner') {
      throw new ForbiddenError('Cannot change owner role');
    }

    // Admins cannot promote to admin or change other admins
    if (actorRole === 'admin' && role === 'admin') {
      throw new ForbiddenError('Admins cannot promote to admin');
    }
    if (actorRole === 'admin' && targetRole === 'admin') {
      throw new ForbiddenError('Admins cannot change another admin');
    }

    await pool.query(
      `UPDATE study_group_members SET role = $1 WHERE group_id = $2 AND user_id = $3`,
      [role, groupId, targetUserId]
    );

    await this.logGroupAudit(groupId, actorId, 'role_updated', targetUserId, {
      role,
    });

    return { success: true };
  },

  async removeMember(groupId: string, actorId: string, targetUserId: string) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (!actorRole) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasRankAtLeast(actorRole, 'moderator')) {
      throw new ForbiddenError('Not authorized to remove members');
    }

    const targetRole = await this.getMemberRole(groupId, targetUserId);
    if (!targetRole) {
      throw new ValidationError('Target user is not a member');
    }
    if (!hasHigherRank(actorRole, targetRole)) {
      throw new ForbiddenError('Not authorized to remove this member');
    }

    await pool.query(
      'DELETE FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, targetUserId]
    );

    await this.logGroupAudit(groupId, actorId, 'member_removed', targetUserId);
    return { success: true };
  },

  async banMember(groupId: string, actorId: string, targetUserId: string, reason?: string) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (!actorRole) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasRankAtLeast(actorRole, 'moderator')) {
      throw new ForbiddenError('Not authorized to ban members');
    }

    const targetRole = await this.getMemberRole(groupId, targetUserId);
    if (targetRole && !hasHigherRank(actorRole, targetRole)) {
      throw new ForbiddenError('Not authorized to ban this member');
    }
    if (targetRole === 'owner') {
      throw new ForbiddenError('Cannot ban the owner');
    }

    await pool.query(
      `INSERT INTO group_bans (id, group_id, user_id, banned_by, reason)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (group_id, user_id)
       DO UPDATE SET banned_by = $4, reason = $5, created_at = NOW()`,
      [uuidv4(), groupId, targetUserId, actorId, reason || null]
    );

    await pool.query(
      'DELETE FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, targetUserId]
    );

    await this.logGroupAudit(groupId, actorId, 'member_banned', targetUserId, {
      reason,
    });

    return { success: true };
  },

  async unbanMember(groupId: string, actorId: string, targetUserId: string) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (!actorRole) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasRankAtLeast(actorRole, 'admin')) {
      throw new ForbiddenError('Not authorized to unban members');
    }

    await pool.query(
      'DELETE FROM group_bans WHERE group_id = $1 AND user_id = $2',
      [groupId, targetUserId]
    );

    await this.logGroupAudit(groupId, actorId, 'member_unbanned', targetUserId);
    return { success: true };
  },

  async listBans(groupId: string, actorId: string) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (!actorRole) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasRankAtLeast(actorRole, 'admin')) {
      throw new ForbiddenError('Not authorized to view bans');
    }

    const result = await pool.query(
      `SELECT b.*, u.display_name as username, u.email, u.avatar_url
       FROM group_bans b
       LEFT JOIN users u ON u.id = b.user_id
       WHERE b.group_id = $1
       ORDER BY b.created_at DESC`,
      [groupId]
    );

    return result.rows;
  },

  async transferOwnership(groupId: string, actorId: string, newOwnerId: string) {
    const actorRole = await this.getMemberRole(groupId, actorId);
    if (actorRole !== 'owner') {
      throw new ForbiddenError('Only the owner can transfer ownership');
    }
    if (await this.isBanned(groupId, newOwnerId)) {
      throw new ForbiddenError('Cannot transfer ownership to a banned user');
    }

    const newOwnerRole = await this.getMemberRole(groupId, newOwnerId);
    if (!newOwnerRole) {
      throw new ValidationError('New owner must be a group member');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        'UPDATE study_groups SET owner_id = $1 WHERE id = $2',
        [newOwnerId, groupId]
      );

      await client.query(
        `UPDATE study_group_members SET role = 'admin'
         WHERE group_id = $1 AND user_id = $2`,
        [groupId, actorId]
      );

      await client.query(
        `UPDATE study_group_members SET role = 'owner'
         WHERE group_id = $1 AND user_id = $2`,
        [groupId, newOwnerId]
      );

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    await this.logGroupAudit(groupId, actorId, 'ownership_transferred', newOwnerId);
    return { success: true };
  },


  // Study Sessions
  async createSession(data: {
    groupId: string;
    title: string;
    description?: string;
    scheduledAt: Date;
    durationMinutes?: number;
    meetingUrl?: string;
    createdBy: string;
  }) {
    const id = uuidv4();
    const result = await pool.query(`
      INSERT INTO study_sessions (id, group_id, title, description, scheduled_at, duration_minutes, meeting_url, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [id, data.groupId, data.title, data.description, data.scheduledAt, data.durationMinutes || 60, data.meetingUrl, data.createdBy]);
    return result.rows[0];
  },

  async getGroupSessions(groupId: string, upcoming = true) {
    const result = await pool.query(`
      SELECT s.*, u.display_name as created_by_username
      FROM study_sessions s
      JOIN users u ON u.id = s.created_by
      WHERE s.group_id = $1
        ${upcoming ? 'AND s.scheduled_at > NOW()' : ''}
      ORDER BY s.scheduled_at ${upcoming ? 'ASC' : 'DESC'}
    `, [groupId]);
    return result.rows;
  },

  async getUserPendingInvitations(userId: string) {
    const result = await pool.query(`
      SELECT i.*, g.name as group_name, g.icon as group_icon, u.display_name as invited_by_username
      FROM group_invitations i
      JOIN study_groups g ON g.id = i.group_id
      JOIN users u ON u.id = i.invited_by
      WHERE i.invited_user_id = $1 AND i.status = 'pending'
      ORDER BY i.created_at DESC
    `, [userId]);
    return result.rows;
  },

  async shareNotebookWithGroup(notebookId: string, groupId: string, sharedBy: string, permission = 'viewer') {
    const id = uuidv4();
    const result = await pool.query(`
      INSERT INTO notebook_shares (id, notebook_id, shared_with_group_id, shared_by, permission)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT DO NOTHING
      RETURNING *
    `, [id, notebookId, groupId, sharedBy, permission]);
    return result.rows[0];
  },

  async getGroupSharedNotebooks(groupId: string) {
    const result = await pool.query(`
      SELECT n.*, ns.permission, u.display_name as shared_by_username
      FROM notebook_shares ns
      JOIN notebooks n ON n.id = ns.notebook_id
      JOIN users u ON u.id = ns.shared_by
      WHERE ns.shared_with_group_id = $1
      ORDER BY ns.created_at DESC
    `, [groupId]);
    return result.rows;
  }
};
