import pool from '../config/database.js';

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
      
      const result = await client.query(`
        INSERT INTO study_groups (name, description, owner_id, icon, is_public)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `, [data.name, data.description, data.ownerId, data.icon || '📚', data.isPublic || false]);
      
      const group = result.rows[0];
      
      // Add owner as member with owner role
      await client.query(`
        INSERT INTO study_group_members (group_id, user_id, role)
        VALUES ($1, $2, 'owner')
      `, [group.id, data.ownerId]);
      
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
        u.username as owner_username
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


  async updateGroup(groupId: string, userId: string, data: Partial<StudyGroup>) {
    // Check if user is owner or admin
    const memberCheck = await pool.query(`
      SELECT role FROM study_group_members 
      WHERE group_id = $1 AND user_id = $2 AND role IN ('owner', 'admin')
    `, [groupId, userId]);
    
    if (memberCheck.rows.length === 0) {
      throw new Error('Not authorized to update this group');
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
      throw new Error('Not authorized to delete this group');
    }
    return { success: true };
  },

  async inviteUser(groupId: string, invitedUserId: string, invitedBy: string) {
    // Check if inviter is member
    const memberCheck = await pool.query(`
      SELECT role FROM study_group_members WHERE group_id = $1 AND user_id = $2
    `, [groupId, invitedBy]);
    
    if (memberCheck.rows.length === 0) {
      throw new Error('Not a member of this group');
    }

    const result = await pool.query(`
      INSERT INTO group_invitations (group_id, invited_user_id, invited_by)
      VALUES ($1, $2, $3)
      ON CONFLICT (group_id, invited_user_id) DO NOTHING
      RETURNING *
    `, [groupId, invitedUserId, invitedBy]);
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
        throw new Error('Invitation not found');
      }

      await client.query(`
        INSERT INTO study_group_members (group_id, user_id, invited_by)
        VALUES ($1, $2, $3)
      `, [invitation.rows[0].group_id, userId, invitation.rows[0].invited_by]);
      
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
      throw new Error('Owner cannot leave the group. Transfer ownership or delete the group.');
    }

    await pool.query(`
      DELETE FROM study_group_members WHERE group_id = $1 AND user_id = $2
    `, [groupId, userId]);
    return { success: true };
  },

  async getMembers(groupId: string) {
    const result = await pool.query(`
      SELECT m.*, u.username, u.email, u.avatar_url
      FROM study_group_members m
      JOIN users u ON u.id = m.user_id
      WHERE m.group_id = $1
      ORDER BY m.role = 'owner' DESC, m.joined_at ASC
    `, [groupId]);
    return result.rows;
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
    const result = await pool.query(`
      INSERT INTO study_sessions (group_id, title, description, scheduled_at, duration_minutes, meeting_url, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `, [data.groupId, data.title, data.description, data.scheduledAt, data.durationMinutes || 60, data.meetingUrl, data.createdBy]);
    return result.rows[0];
  },

  async getGroupSessions(groupId: string, upcoming = true) {
    const result = await pool.query(`
      SELECT s.*, u.username as created_by_username
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
      SELECT i.*, g.name as group_name, g.icon as group_icon, u.username as invited_by_username
      FROM group_invitations i
      JOIN study_groups g ON g.id = i.group_id
      JOIN users u ON u.id = i.invited_by
      WHERE i.invited_user_id = $1 AND i.status = 'pending'
      ORDER BY i.created_at DESC
    `, [userId]);
    return result.rows;
  },

  async shareNotebookWithGroup(notebookId: string, groupId: string, sharedBy: string, permission = 'viewer') {
    const result = await pool.query(`
      INSERT INTO notebook_shares (notebook_id, shared_with_group_id, shared_by, permission)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT DO NOTHING
      RETURNING *
    `, [notebookId, groupId, sharedBy, permission]);
    return result.rows[0];
  },

  async getGroupSharedNotebooks(groupId: string) {
    const result = await pool.query(`
      SELECT n.*, ns.permission, u.username as shared_by_username
      FROM notebook_shares ns
      JOIN notebooks n ON n.id = ns.notebook_id
      JOIN users u ON u.id = ns.shared_by
      WHERE ns.shared_with_group_id = $1
      ORDER BY ns.created_at DESC
    `, [groupId]);
    return result.rows;
  }
};
