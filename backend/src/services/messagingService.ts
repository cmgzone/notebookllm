import pool from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';
import { notificationService } from './notificationService.js';
import { ForbiddenError, NotFoundError, ValidationError } from '../types/errors.js';

export interface Message {
  id: string;
  senderId: string;
  senderUsername: string;
  senderAvatarUrl?: string;
  content: string;
  messageType: string;
  metadata?: Record<string, any>;
  createdAt: Date;
  isRead?: boolean;
}

export interface MessageReaction {
  type: string;
  count: number;
}

export interface Conversation {
  id: string;
  otherUserId: string;
  otherUsername: string;
  otherAvatarUrl?: string;
  lastMessage?: string;
  lastMessageAt?: Date;
  unreadCount: number;
}

export interface GroupMessage extends Message {
  groupId: string;
  replyToId?: string;
  replyToContent?: string;
  editedAt?: Date;
  isDeleted?: boolean;
  deletedAt?: Date;
  deletedBy?: string;
  reactions?: MessageReaction[];
  userReaction?: string;
  isPinned?: boolean;
  pinnedAt?: Date;
  pinnedBy?: string;
  replyCount?: number;
}

type GroupRole = 'owner' | 'admin' | 'moderator' | 'member';

const ROLE_RANK: Record<GroupRole, number> = {
  owner: 3,
  admin: 2,
  moderator: 1,
  member: 0,
};

const hasModerationPrivileges = (role: GroupRole) =>
  role === 'owner' || role === 'admin' || role === 'moderator';

// Helper to check if users are friends (direct query to avoid circular dependency)
async function checkAreFriends(userId1: string, userId2: string): Promise<boolean> {
  const result = await pool.query(`
    SELECT id FROM friendships
    WHERE ((user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1))
      AND status = 'accepted'
  `, [userId1, userId2]);
  return result.rows.length > 0;
}

// Helper to get or create conversation between two users
async function getOrCreateConversation(userId1: string, userId2: string): Promise<string> {
  const [user1, user2] = userId1 < userId2 ? [userId1, userId2] : [userId2, userId1];

  const existing = await pool.query(
    'SELECT id FROM conversations WHERE user1_id = $1 AND user2_id = $2',
    [user1, user2]
  );

  if (existing.rows.length > 0) {
    return existing.rows[0].id;
  }

  const id = uuidv4();
  const result = await pool.query(
    'INSERT INTO conversations (id, user1_id, user2_id) VALUES ($1, $2, $3) RETURNING id',
    [id, user1, user2]
  );
  return result.rows[0].id;
}

const normalizeRole = (role?: string): GroupRole =>
  role === 'owner' || role === 'admin' || role === 'moderator' ? role : 'member';

async function getGroupRole(groupId: string, userId: string): Promise<GroupRole | null> {
  const result = await pool.query(
    'SELECT role FROM study_group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId]
  );
  if (result.rows.length === 0) return null;
  return normalizeRole(result.rows[0].role);
}

const allowedReactionTypes = new Set([
  'like',
  'love',
  'laugh',
  'wow',
  'sad',
  'party',
]);

const groupMessageBaseSelect = `
  SELECT gm.*,
    u.display_name as sender_username,
    u.avatar_url as sender_avatar_url,
    rm.content as reply_to_content,
    rm.is_deleted as reply_to_deleted,
    COALESCE(ragg.reactions, '[]'::json) as reactions,
    ur.reaction_type as user_reaction,
    pin.pinned_at,
    pin.pinned_by,
    rc.reply_count
  FROM group_messages gm
  JOIN users u ON u.id = gm.sender_id
  LEFT JOIN group_messages rm ON rm.id = gm.reply_to_id
  LEFT JOIN LATERAL (
    SELECT json_agg(
      json_build_object('type', reaction_type, 'count', count)
      ORDER BY reaction_type
    ) as reactions
    FROM (
      SELECT reaction_type, COUNT(*)::int as count
      FROM group_message_reactions
      WHERE message_id = gm.id
      GROUP BY reaction_type
    ) reaction_counts
  ) ragg ON true
  LEFT JOIN LATERAL (
    SELECT reaction_type
    FROM group_message_reactions
    WHERE message_id = gm.id AND user_id = $2
    LIMIT 1
  ) ur ON true
  LEFT JOIN LATERAL (
    SELECT pinned_at, pinned_by
    FROM group_message_pins
    WHERE message_id = gm.id AND group_id = gm.group_id
    LIMIT 1
  ) pin ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::int as reply_count
    FROM group_messages
    WHERE reply_to_id = gm.id
  ) rc ON true
`;

const mapGroupMessageRow = (row: any): GroupMessage => {
  const isDeleted = row.is_deleted ?? false;
  const replyToContent = row.reply_to_id
    ? row.reply_to_deleted
      ? 'Message deleted'
      : row.reply_to_content
    : undefined;
  return {
    id: row.id,
    groupId: row.group_id,
    senderId: row.sender_id,
    senderUsername: row.sender_username,
    senderAvatarUrl: row.sender_avatar_url,
    content: isDeleted ? 'Message deleted' : row.content,
    messageType: row.message_type,
    metadata: row.metadata,
    replyToId: row.reply_to_id,
    replyToContent,
    createdAt: row.created_at,
    editedAt: row.edited_at,
    isDeleted,
    deletedAt: row.deleted_at,
    deletedBy: row.deleted_by,
    reactions: row.reactions || [],
    userReaction: row.user_reaction || undefined,
    isPinned: !!row.pinned_at,
    pinnedAt: row.pinned_at,
    pinnedBy: row.pinned_by,
    replyCount: row.reply_count ?? 0,
  };
};

async function getGroupMessageById(
  groupId: string,
  messageId: string,
  userId: string
): Promise<GroupMessage> {
  const result = await pool.query(
    `${groupMessageBaseSelect} WHERE gm.group_id = $1 AND gm.id = $3`,
    [groupId, userId, messageId]
  );
  if (result.rows.length === 0) {
    throw new NotFoundError('Message not found');
  }
  return mapGroupMessageRow(result.rows[0]);
}

export const messagingService = {
  async sendDirectMessage(
    senderId: string,
    recipientId: string,
    content: string,
    messageType = 'text',
    metadata?: Record<string, any>
  ): Promise<Message> {
    if (!content || content.trim().length === 0) {
      throw new ValidationError('Message content is required');
    }
    if (content.length > 5000) {
      throw new ValidationError('Message too long (max 5000 characters)');
    }
    if (senderId === recipientId) {
      throw new ValidationError('Cannot send message to yourself');
    }

    const areFriends = await checkAreFriends(senderId, recipientId);
    if (!areFriends) {
      throw new ValidationError('You can only message friends');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const conversationId = await getOrCreateConversation(senderId, recipientId);

      const messageId = uuidv4();
      const result = await client.query(`
        INSERT INTO direct_messages (id, conversation_id, sender_id, recipient_id, content, message_type, metadata)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
      `, [messageId, conversationId, senderId, recipientId, content.trim(), messageType, metadata || {}]);

      const message = result.rows[0];

      const [user1] = senderId < recipientId ? [senderId] : [recipientId];
      const unreadColumn = senderId === user1 ? 'user2_unread_count' : 'user1_unread_count';

      await client.query(`
        UPDATE conversations 
        SET last_message_id = $1, last_message_at = NOW(), ${unreadColumn} = ${unreadColumn} + 1, updated_at = NOW()
        WHERE id = $2
      `, [message.id, conversationId]);

      await client.query('COMMIT');

      const sender = await pool.query(
        'SELECT display_name, avatar_url FROM users WHERE id = $1',
        [senderId]
      );

      const senderName = sender.rows[0]?.display_name || 'Unknown';

      notificationService.notifyNewMessage(recipientId, senderId, senderName).catch(err => {
        console.error('Failed to send message notification:', err);
      });

      return {
        id: message.id,
        senderId: message.sender_id,
        senderUsername: senderName,
        senderAvatarUrl: sender.rows[0]?.avatar_url,
        content: message.content,
        messageType: message.message_type,
        metadata: message.metadata,
        createdAt: message.created_at,
        isRead: false
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  async getConversations(userId: string): Promise<Conversation[]> {
    const result = await pool.query(`
      SELECT 
        c.id,
        CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END as other_user_id,
        u.display_name as other_username,
        u.avatar_url as other_avatar_url,
        dm.content as last_message,
        c.last_message_at,
        CASE WHEN c.user1_id = $1 THEN c.user1_unread_count ELSE c.user2_unread_count END as unread_count
      FROM conversations c
      JOIN users u ON u.id = CASE WHEN c.user1_id = $1 THEN c.user2_id ELSE c.user1_id END
      LEFT JOIN direct_messages dm ON dm.id = c.last_message_id
      WHERE c.user1_id = $1 OR c.user2_id = $1
      ORDER BY c.last_message_at DESC NULLS LAST
    `, [userId]);

    return result.rows.map(r => ({
      id: r.id,
      otherUserId: r.other_user_id,
      otherUsername: r.other_username,
      otherAvatarUrl: r.other_avatar_url,
      lastMessage: r.last_message,
      lastMessageAt: r.last_message_at,
      unreadCount: r.unread_count || 0
    }));
  },

  async getDirectMessages(
    userId: string,
    otherUserId: string,
    options?: { limit?: number; before?: string }
  ): Promise<Message[]> {
    // First check if users are friends
    const areFriends = await checkAreFriends(userId, otherUserId);
    if (!areFriends) {
      throw new ValidationError('You can only view messages with friends');
    }

    const limit = Math.min(options?.limit || 50, 100);
    const conversationId = await getOrCreateConversation(userId, otherUserId);

    let query = `
      SELECT dm.*, u.display_name as sender_username, u.avatar_url as sender_avatar_url
      FROM direct_messages dm
      JOIN users u ON u.id = dm.sender_id
      WHERE dm.conversation_id = $1
    `;
    const params: any[] = [conversationId];

    if (options?.before) {
      query += ` AND dm.created_at < (SELECT created_at FROM direct_messages WHERE id = $${params.length + 1})`;
      params.push(options.before);
    }

    query += ` ORDER BY dm.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await pool.query(query, params);

    return result.rows.map(r => ({
      id: r.id,
      senderId: r.sender_id,
      senderUsername: r.sender_username,
      senderAvatarUrl: r.sender_avatar_url,
      content: r.content,
      messageType: r.message_type,
      metadata: r.metadata,
      createdAt: r.created_at,
      isRead: r.is_read
    })).reverse();
  },

  async markConversationRead(userId: string, otherUserId: string): Promise<void> {
    const [user1, user2] = userId < otherUserId ? [userId, otherUserId] : [otherUserId, userId];
    const unreadColumn = userId === user1 ? 'user1_unread_count' : 'user2_unread_count';

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const conv = await client.query(
        'SELECT id FROM conversations WHERE user1_id = $1 AND user2_id = $2',
        [user1, user2]
      );

      if (conv.rows.length > 0) {
        await client.query(`
          UPDATE direct_messages 
          SET is_read = TRUE, read_at = NOW()
          WHERE conversation_id = $1 AND recipient_id = $2 AND is_read = FALSE
        `, [conv.rows[0].id, userId]);

        await client.query(`
          UPDATE conversations SET ${unreadColumn} = 0 WHERE id = $1
        `, [conv.rows[0].id]);
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  async sendGroupMessage(
    groupId: string,
    senderId: string,
    content: string,
    messageType = 'text',
    metadata?: Record<string, any>,
    replyToId?: string
  ): Promise<GroupMessage> {
    if (!content || content.trim().length === 0) {
      throw new ValidationError('Message content is required');
    }
    if (content.length > 5000) {
      throw new ValidationError('Message too long (max 5000 characters)');
    }

    const membership = await pool.query(
      'SELECT id FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, senderId]
    );

    if (membership.rows.length === 0) {
      throw new ValidationError('You are not a member of this group');
    }

    if (replyToId) {
      const replyCheck = await pool.query(
        'SELECT id FROM group_messages WHERE id = $1 AND group_id = $2',
        [replyToId, groupId]
      );
      if (replyCheck.rows.length === 0) {
        throw new ValidationError('Reply message not found');
      }
    }

    const messageId = uuidv4();
    const result = await pool.query(`
      INSERT INTO group_messages (id, group_id, sender_id, content, message_type, metadata, reply_to_id)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `, [messageId, groupId, senderId, content.trim(), messageType, metadata || {}, replyToId]);

    const message = result.rows[0];

    const [sender, reply, group] = await Promise.all([
      pool.query('SELECT display_name, avatar_url FROM users WHERE id = $1', [senderId]),
      replyToId
        ? pool.query('SELECT content, is_deleted FROM group_messages WHERE id = $1', [replyToId])
        : null,
      pool.query('SELECT name FROM study_groups WHERE id = $1', [groupId])
    ]);

    const senderName = sender.rows[0]?.display_name || 'Unknown';
    const groupName = group.rows[0]?.name || 'Group';

    pool.query(
      'SELECT user_id FROM study_group_members WHERE group_id = $1 AND user_id != $2',
      [groupId, senderId]
    ).then(members => {
      for (const member of members.rows) {
        notificationService.notifyGroupMessage(
          member.user_id, groupId, groupName, senderId, senderName
        ).catch(err => console.error('Failed to send group notification:', err));
      }
    }).catch(err => console.error('Failed to get group members for notification:', err));

    const replyContent = reply?.rows[0]
      ? reply.rows[0].is_deleted
        ? 'Message deleted'
        : reply.rows[0].content
      : undefined;

    return {
      id: message.id,
      groupId: message.group_id,
      senderId: message.sender_id,
      senderUsername: senderName,
      senderAvatarUrl: sender.rows[0]?.avatar_url,
      content: message.content,
      messageType: message.message_type,
      metadata: message.metadata,
      replyToId: message.reply_to_id,
      replyToContent: replyContent,
      createdAt: message.created_at,
      editedAt: message.edited_at,
      isDeleted: message.is_deleted,
      deletedAt: message.deleted_at,
      deletedBy: message.deleted_by,
      reactions: [],
      userReaction: undefined,
      isPinned: false,
      pinnedAt: undefined,
      pinnedBy: undefined,
      replyCount: 0
    };
  },

  async getGroupMessages(
    groupId: string,
    userId: string,
    options?: { limit?: number; before?: string }
  ): Promise<GroupMessage[]> {
    const membership = await pool.query(
      'SELECT id FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );

    if (membership.rows.length === 0) {
      throw new ValidationError('You are not a member of this group');
    }

    const limit = Math.min(options?.limit || 50, 100);

    let query = `${groupMessageBaseSelect} WHERE gm.group_id = $1`;
    const params: any[] = [groupId, userId];

    if (options?.before) {
      query += ` AND gm.created_at < (SELECT created_at FROM group_messages WHERE id = $${params.length + 1})`;
      params.push(options.before);
    }

    query += ` ORDER BY gm.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await pool.query(query, params);

    return result.rows.map(mapGroupMessageRow).reverse();
  },

  async editGroupMessage(
    groupId: string,
    messageId: string,
    userId: string,
    content: string
  ): Promise<GroupMessage> {
    if (!content || content.trim().length === 0) {
      throw new ValidationError('Message content is required');
    }
    if (content.length > 5000) {
      throw new ValidationError('Message too long (max 5000 characters)');
    }

    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }

    const messageResult = await pool.query(
      'SELECT sender_id, is_deleted FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }
    const messageRow = messageResult.rows[0];
    if (messageRow.sender_id !== userId) {
      throw new ForbiddenError('Not authorized to edit this message');
    }
    if (messageRow.is_deleted) {
      throw new ValidationError('Cannot edit a deleted message');
    }

    await pool.query(
      `UPDATE group_messages
       SET content = $1, edited_at = NOW(), updated_at = NOW()
       WHERE id = $2 AND group_id = $3`,
      [content.trim(), messageId, groupId]
    );

    return getGroupMessageById(groupId, messageId, userId);
  },

  async deleteGroupMessage(
    groupId: string,
    messageId: string,
    userId: string
  ): Promise<GroupMessage> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }

    const messageResult = await pool.query(
      'SELECT sender_id, is_deleted FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }

    const messageRow = messageResult.rows[0];
    const canDelete =
      messageRow.sender_id === userId || hasModerationPrivileges(role);
    if (!canDelete) {
      throw new ForbiddenError('Not authorized to delete this message');
    }

    if (!messageRow.is_deleted) {
      await pool.query(
        `UPDATE group_messages
         SET is_deleted = TRUE, deleted_at = NOW(), deleted_by = $1, updated_at = NOW()
         WHERE id = $2 AND group_id = $3`,
        [userId, messageId, groupId]
      );
      await pool.query(
        'DELETE FROM group_message_pins WHERE message_id = $1',
        [messageId]
      );
    }

    return getGroupMessageById(groupId, messageId, userId);
  },

  async addGroupMessageReaction(
    groupId: string,
    messageId: string,
    userId: string,
    reactionType: string
  ): Promise<GroupMessage> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!reactionType || !allowedReactionTypes.has(reactionType)) {
      throw new ValidationError('Invalid reaction type');
    }

    const messageResult = await pool.query(
      'SELECT is_deleted FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }
    if (messageResult.rows[0].is_deleted) {
      throw new ValidationError('Cannot react to a deleted message');
    }

    await pool.query(
      `INSERT INTO group_message_reactions (id, message_id, user_id, reaction_type)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (message_id, user_id)
       DO UPDATE SET reaction_type = EXCLUDED.reaction_type, created_at = NOW()`,
      [uuidv4(), messageId, userId, reactionType]
    );

    return getGroupMessageById(groupId, messageId, userId);
  },

  async removeGroupMessageReaction(
    groupId: string,
    messageId: string,
    userId: string
  ): Promise<GroupMessage> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }

    const messageResult = await pool.query(
      'SELECT id FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }

    await pool.query(
      'DELETE FROM group_message_reactions WHERE message_id = $1 AND user_id = $2',
      [messageId, userId]
    );

    return getGroupMessageById(groupId, messageId, userId);
  },

  async pinGroupMessage(
    groupId: string,
    messageId: string,
    userId: string
  ): Promise<GroupMessage> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasModerationPrivileges(role)) {
      throw new ForbiddenError('Not authorized to pin messages');
    }

    const messageResult = await pool.query(
      'SELECT id FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }

    await pool.query(
      `INSERT INTO group_message_pins (id, group_id, message_id, pinned_by)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (group_id, message_id) DO NOTHING`,
      [uuidv4(), groupId, messageId, userId]
    );

    return getGroupMessageById(groupId, messageId, userId);
  },

  async unpinGroupMessage(
    groupId: string,
    messageId: string,
    userId: string
  ): Promise<GroupMessage> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }
    if (!hasModerationPrivileges(role)) {
      throw new ForbiddenError('Not authorized to unpin messages');
    }

    const messageResult = await pool.query(
      'SELECT id FROM group_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId]
    );
    if (messageResult.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }

    await pool.query(
      'DELETE FROM group_message_pins WHERE group_id = $1 AND message_id = $2',
      [groupId, messageId]
    );

    return getGroupMessageById(groupId, messageId, userId);
  },

  async getPinnedMessages(groupId: string, userId: string): Promise<GroupMessage[]> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }

    const result = await pool.query(
      `${groupMessageBaseSelect}
       WHERE gm.group_id = $1 AND pin.pinned_at IS NOT NULL
       ORDER BY pin.pinned_at DESC`,
      [groupId, userId]
    );

    return result.rows.map(mapGroupMessageRow);
  },

  async getThreadMessages(
    groupId: string,
    rootMessageId: string,
    userId: string,
    options?: { limit?: number; before?: string }
  ): Promise<GroupMessage[]> {
    const role = await getGroupRole(groupId, userId);
    if (!role) {
      throw new ForbiddenError('Not a member of this group');
    }

    const rootCheck = await pool.query(
      'SELECT id FROM group_messages WHERE id = $1 AND group_id = $2',
      [rootMessageId, groupId]
    );
    if (rootCheck.rows.length === 0) {
      throw new NotFoundError('Message not found');
    }

    const limit = Math.min(options?.limit || 50, 100);
    let query = `${groupMessageBaseSelect} WHERE gm.group_id = $1 AND gm.reply_to_id = $3`;
    const params: any[] = [groupId, userId, rootMessageId];

    if (options?.before) {
      query += ` AND gm.created_at < (SELECT created_at FROM group_messages WHERE id = $${params.length + 1})`;
      params.push(options.before);
    }

    query += ` ORDER BY gm.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows.map(mapGroupMessageRow).reverse();
  },

  async markGroupMessagesRead(groupId: string, userId: string, lastMessageId: string): Promise<void> {
    const id = uuidv4();
    await pool.query(`
      INSERT INTO group_message_reads (id, group_id, user_id, last_read_message_id, last_read_at)
      VALUES ($1, $2, $3, $4, NOW())
      ON CONFLICT (group_id, user_id) 
      DO UPDATE SET last_read_message_id = $4, last_read_at = NOW()
    `, [id, groupId, userId, lastMessageId]);
  },

  async getGroupUnreadCount(groupId: string, userId: string): Promise<number> {
    const lastRead = await pool.query(
      'SELECT last_read_message_id FROM group_message_reads WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );

    if (lastRead.rows.length === 0) {
      const count = await pool.query(
        'SELECT COUNT(*) FROM group_messages WHERE group_id = $1',
        [groupId]
      );
      return parseInt(count.rows[0].count);
    }

    const count = await pool.query(`
      SELECT COUNT(*) FROM group_messages 
      WHERE group_id = $1 
      AND created_at > (SELECT created_at FROM group_messages WHERE id = $2)
    `, [groupId, lastRead.rows[0].last_read_message_id]);

    return parseInt(count.rows[0].count);
  },

  async getTotalUnreadCount(userId: string): Promise<{ direct: number; groups: number }> {
    const directResult = await pool.query(`
      SELECT COALESCE(SUM(
        CASE WHEN user1_id = $1 THEN user1_unread_count ELSE user2_unread_count END
      ), 0) as count
      FROM conversations
      WHERE user1_id = $1 OR user2_id = $1
    `, [userId]);

    const groupResult = await pool.query(`
      SELECT COUNT(DISTINCT gm.group_id) as count
      FROM group_messages gm
      JOIN study_group_members sgm ON sgm.group_id = gm.group_id AND sgm.user_id = $1
      LEFT JOIN group_message_reads gmr ON gmr.group_id = gm.group_id AND gmr.user_id = $1
      WHERE gmr.last_read_message_id IS NULL 
        OR gm.created_at > (SELECT created_at FROM group_messages WHERE id = gmr.last_read_message_id)
    `, [userId]);

    return {
      direct: parseInt(directResult.rows[0].count) || 0,
      groups: parseInt(groupResult.rows[0].count) || 0
    };
  }
};
