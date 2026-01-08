import pool from '../config/database.js';
import { friendService, ValidationError, NotFoundError } from './friendService.js';

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
}

// Helper to get or create conversation between two users
async function getOrCreateConversation(userId1: string, userId2: string): Promise<string> {
  // Always store with smaller ID first for consistency
  const [user1, user2] = userId1 < userId2 ? [userId1, userId2] : [userId2, userId1];
  
  const existing = await pool.query(
    'SELECT id FROM conversations WHERE user1_id = $1 AND user2_id = $2',
    [user1, user2]
  );
  
  if (existing.rows.length > 0) {
    return existing.rows[0].id;
  }
  
  const result = await pool.query(
    'INSERT INTO conversations (user1_id, user2_id) VALUES ($1, $2) RETURNING id',
    [user1, user2]
  );
  return result.rows[0].id;
}

export const messagingService = {
  // ============================================
  // DIRECT MESSAGES (1-on-1)
  // ============================================
  
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
    
    // Check if they are friends
    const areFriends = await friendService.areFriends(senderId, recipientId);
    if (!areFriends) {
      throw new ValidationError('You can only message friends');
    }
    
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const conversationId = await getOrCreateConversation(senderId, recipientId);
      
      // Insert message
      const result = await client.query(`
        INSERT INTO direct_messages (conversation_id, sender_id, recipient_id, content, message_type, metadata)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
      `, [conversationId, senderId, recipientId, content.trim(), messageType, metadata || {}]);
      
      const message = result.rows[0];
      
      // Update conversation
      const [user1, user2] = senderId < recipientId ? [senderId, recipientId] : [recipientId, senderId];
      const unreadColumn = senderId === user1 ? 'user2_unread_count' : 'user1_unread_count';
      
      await client.query(`
        UPDATE conversations 
        SET last_message_id = $1, last_message_at = NOW(), ${unreadColumn} = ${unreadColumn} + 1, updated_at = NOW()
        WHERE id = $2
      `, [message.id, conversationId]);
      
      await client.query('COMMIT');
      
      // Get sender info
      const sender = await pool.query(
        'SELECT display_name, avatar_url FROM users WHERE id = $1',
        [senderId]
      );
      
      return {
        id: message.id,
        senderId: message.sender_id,
        senderUsername: sender.rows[0]?.display_name || 'Unknown',
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
    })).reverse(); // Return in chronological order
  },

  async markConversationRead(userId: string, otherUserId: string): Promise<void> {
    const [user1, user2] = userId < otherUserId ? [userId, otherUserId] : [otherUserId, userId];
    const unreadColumn = userId === user1 ? 'user1_unread_count' : 'user2_unread_count';
    
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // Get conversation
      const conv = await client.query(
        'SELECT id FROM conversations WHERE user1_id = $1 AND user2_id = $2',
        [user1, user2]
      );
      
      if (conv.rows.length > 0) {
        // Mark messages as read
        await client.query(`
          UPDATE direct_messages 
          SET is_read = TRUE, read_at = NOW()
          WHERE conversation_id = $1 AND recipient_id = $2 AND is_read = FALSE
        `, [conv.rows[0].id, userId]);
        
        // Reset unread count
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

  // ============================================
  // GROUP MESSAGES
  // ============================================
  
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
    
    // Check if user is member of group
    const membership = await pool.query(
      'SELECT id FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, senderId]
    );
    
    if (membership.rows.length === 0) {
      throw new ValidationError('You are not a member of this group');
    }
    
    const result = await pool.query(`
      INSERT INTO group_messages (group_id, sender_id, content, message_type, metadata, reply_to_id)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [groupId, senderId, content.trim(), messageType, metadata || {}, replyToId]);
    
    const message = result.rows[0];
    
    // Get sender info and reply content
    const [sender, reply] = await Promise.all([
      pool.query('SELECT display_name, avatar_url FROM users WHERE id = $1', [senderId]),
      replyToId ? pool.query('SELECT content FROM group_messages WHERE id = $1', [replyToId]) : null
    ]);
    
    return {
      id: message.id,
      groupId: message.group_id,
      senderId: message.sender_id,
      senderUsername: sender.rows[0]?.display_name || 'Unknown',
      senderAvatarUrl: sender.rows[0]?.avatar_url,
      content: message.content,
      messageType: message.message_type,
      metadata: message.metadata,
      replyToId: message.reply_to_id,
      replyToContent: reply?.rows[0]?.content,
      createdAt: message.created_at
    };
  },

  async getGroupMessages(
    groupId: string,
    userId: string,
    options?: { limit?: number; before?: string }
  ): Promise<GroupMessage[]> {
    // Check membership
    const membership = await pool.query(
      'SELECT id FROM study_group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
    
    if (membership.rows.length === 0) {
      throw new ValidationError('You are not a member of this group');
    }
    
    const limit = Math.min(options?.limit || 50, 100);
    
    let query = `
      SELECT gm.*, 
        u.display_name as sender_username, 
        u.avatar_url as sender_avatar_url,
        rm.content as reply_to_content
      FROM group_messages gm
      JOIN users u ON u.id = gm.sender_id
      LEFT JOIN group_messages rm ON rm.id = gm.reply_to_id
      WHERE gm.group_id = $1
    `;
    const params: any[] = [groupId];
    
    if (options?.before) {
      query += ` AND gm.created_at < (SELECT created_at FROM group_messages WHERE id = $${params.length + 1})`;
      params.push(options.before);
    }
    
    query += ` ORDER BY gm.created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);
    
    const result = await pool.query(query, params);
    
    return result.rows.map(r => ({
      id: r.id,
      groupId: r.group_id,
      senderId: r.sender_id,
      senderUsername: r.sender_username,
      senderAvatarUrl: r.sender_avatar_url,
      content: r.content,
      messageType: r.message_type,
      metadata: r.metadata,
      replyToId: r.reply_to_id,
      replyToContent: r.reply_to_content,
      createdAt: r.created_at
    })).reverse();
  },

  async markGroupMessagesRead(groupId: string, userId: string, lastMessageId: string): Promise<void> {
    await pool.query(`
      INSERT INTO group_message_reads (group_id, user_id, last_read_message_id, last_read_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (group_id, user_id) 
      DO UPDATE SET last_read_message_id = $3, last_read_at = NOW()
    `, [groupId, userId, lastMessageId]);
  },

  async getGroupUnreadCount(groupId: string, userId: string): Promise<number> {
    const lastRead = await pool.query(
      'SELECT last_read_message_id FROM group_message_reads WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
    
    if (lastRead.rows.length === 0) {
      // Never read - count all messages
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
    // Direct message unread count
    const directResult = await pool.query(`
      SELECT COALESCE(SUM(
        CASE WHEN user1_id = $1 THEN user1_unread_count ELSE user2_unread_count END
      ), 0) as count
      FROM conversations
      WHERE user1_id = $1 OR user2_id = $1
    `, [userId]);
    
    // Group unread count (simplified - counts groups with unread)
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
