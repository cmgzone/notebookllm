import pool from '../config/database.js';
import { notificationService } from './notificationService.js';
import { NotFoundError, ValidationError } from '../types/errors.js';

export class ConflictError extends Error {
  code = 'CONFLICT';
  status = 409;
  constructor(message: string) {
    super(message);
    this.name = 'ConflictError';
  }
}

// Re-export error classes for backward compatibility
export { NotFoundError, ValidationError };

// Response interfaces (no email for privacy)
export interface FriendResponse {
  id: string;
  friendId: string;
  username: string;
  avatarUrl?: string;
  status: 'pending' | 'accepted' | 'blocked';
  createdAt: Date;
  acceptedAt?: Date;
}

export interface FriendRequestResponse {
  id: string;
  fromUserId: string;
  fromUsername: string;
  fromAvatarUrl?: string;
  createdAt: Date;
}

export interface UserSearchResponse {
  id: string;
  username: string;
  avatarUrl?: string;
}

// UUID validation helper
const isValidUUID = (id: string): boolean => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
};

export const friendService = {
  // Search users - returns limited info for privacy
  async searchUsers(query: string, currentUserId: string, limit = 20): Promise<UserSearchResponse[]> {
    // Validate inputs
    if (!query || query.length < 2) {
      throw new ValidationError('Search query must be at least 2 characters');
    }
    // Sanitize and limit
    const sanitizedQuery = query.replace(/[%_]/g, '\\$&'); // Escape SQL wildcards
    const safeLimit = Math.min(Math.max(1, limit), 50); // Clamp between 1-50
    
    const result = await pool.query(`
      SELECT id, display_name as username, avatar_url
      FROM users
      WHERE id != $1
        AND (display_name ILIKE $2 OR email ILIKE $2)
        AND id NOT IN (
          SELECT friend_id FROM friendships WHERE user_id = $1
          UNION
          SELECT user_id FROM friendships WHERE friend_id = $1
        )
      LIMIT $3
    `, [currentUserId, `%${sanitizedQuery}%`, safeLimit]);
    return result.rows;
  },

  // Send friend request with transaction for atomicity
  async sendFriendRequest(userId: string, friendId: string) {
    // Validate inputs
    if (!userId || !friendId) {
      throw new ValidationError('User ID and Friend ID are required');
    }
    if (userId === friendId) {
      throw new ValidationError('Cannot send friend request to yourself');
    }
    
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // Check if request already exists (with lock)
      const existing = await client.query(`
        SELECT id, status FROM friendships 
        WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
        FOR UPDATE
      `, [userId, friendId]);

      if (existing.rows.length > 0) {
        await client.query('ROLLBACK');
        throw new ConflictError('Friend request already exists');
      }

      // Verify target user exists
      const userExists = await client.query('SELECT id FROM users WHERE id = $1', [friendId]);
      if (userExists.rows.length === 0) {
        await client.query('ROLLBACK');
        throw new NotFoundError('User not found');
      }

      const result = await client.query(`
        INSERT INTO friendships (user_id, friend_id, status)
        VALUES ($1, $2, 'pending')
        RETURNING *
      `, [userId, friendId]);
      
      await client.query('COMMIT');
      
      // Send notification to the recipient (async)
      pool.query('SELECT display_name FROM users WHERE id = $1', [userId])
        .then(sender => {
          const senderName = sender.rows[0]?.display_name || 'Someone';
          notificationService.notifyFriendRequest(friendId, userId, senderName)
            .catch(err => console.error('Failed to send friend request notification:', err));
        })
        .catch(err => console.error('Failed to get sender name for notification:', err));
      
      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  // Accept friend request - validates recipient
  async acceptFriendRequest(requestId: string, userId: string) {
    if (!requestId || !userId) {
      throw new ValidationError('Request ID and User ID are required');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // First verify the request exists and user is the recipient
      const check = await client.query(`
        SELECT id, user_id, friend_id, status FROM friendships 
        WHERE id = $1 FOR UPDATE
      `, [requestId]);
      
      if (check.rows.length === 0) {
        await client.query('ROLLBACK');
        throw new NotFoundError('Friend request not found');
      }
      
      const request = check.rows[0];
      if (request.friend_id !== userId) {
        await client.query('ROLLBACK');
        throw new ValidationError('You can only accept requests sent to you');
      }
      
      if (request.status !== 'pending') {
        await client.query('ROLLBACK');
        throw new ConflictError('Friend request is not pending');
      }

      const result = await client.query(`
        UPDATE friendships
        SET status = 'accepted', accepted_at = NOW()
        WHERE id = $1
        RETURNING *
      `, [requestId]);
      
      await client.query('COMMIT');
      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  // Decline/reject friend request
  async declineFriendRequest(requestId: string, userId: string) {
    if (!requestId || !userId) {
      throw new ValidationError('Request ID and User ID are required');
    }

    const result = await pool.query(`
      DELETE FROM friendships
      WHERE id = $1 AND friend_id = $2 AND status = 'pending'
      RETURNING *
    `, [requestId, userId]);

    if (result.rows.length === 0) {
      throw new NotFoundError('Friend request not found or you are not the recipient');
    }
    return { success: true };
  },

  // Remove friendship
  async removeFriend(friendshipId: string, userId: string) {
    if (!friendshipId || !userId) {
      throw new ValidationError('Friendship ID and User ID are required');
    }

    const result = await pool.query(`
      DELETE FROM friendships
      WHERE id = $1 AND (user_id = $2 OR friend_id = $2) AND status = 'accepted'
      RETURNING *
    `, [friendshipId, userId]);

    if (result.rows.length === 0) {
      throw new NotFoundError('Friendship not found');
    }
    return { success: true };
  },

  // Get friends list with pagination (no email for privacy)
  async getFriends(userId: string, options?: { limit?: number; offset?: number }): Promise<FriendResponse[]> {
    const limit = Math.min(options?.limit || 50, 100);
    const offset = options?.offset || 0;
    
    // Using UNION ALL for better performance instead of CASE in JOIN
    const result = await pool.query(`
      SELECT f.id, f.friend_id, u.display_name as username, u.avatar_url, f.status, f.created_at, f.accepted_at
      FROM friendships f 
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1 AND f.status = 'accepted'
      UNION ALL
      SELECT f.id, f.user_id as friend_id, u.display_name as username, u.avatar_url, f.status, f.created_at, f.accepted_at
      FROM friendships f 
      JOIN users u ON u.id = f.user_id
      WHERE f.friend_id = $1 AND f.status = 'accepted'
      ORDER BY accepted_at DESC
      LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);
    return result.rows;
  },

  // Get pending requests (no email for privacy)
  async getPendingRequests(userId: string): Promise<FriendRequestResponse[]> {
    const result = await pool.query(`
      SELECT 
        f.id,
        f.user_id as from_user_id,
        u.display_name as from_username,
        u.avatar_url as from_avatar_url,
        f.created_at
      FROM friendships f
      JOIN users u ON u.id = f.user_id
      WHERE f.friend_id = $1 AND f.status = 'pending'
      ORDER BY f.created_at DESC
      LIMIT 100
    `, [userId]);
    return result.rows;
  },

  // Get sent requests (no email for privacy)
  async getSentRequests(userId: string) {
    const result = await pool.query(`
      SELECT 
        f.id,
        f.friend_id as to_user_id,
        u.display_name as to_username,
        u.avatar_url as to_avatar_url,
        f.created_at
      FROM friendships f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1 AND f.status = 'pending'
      ORDER BY f.created_at DESC
      LIMIT 100
    `, [userId]);
    return result.rows;
  },

  async areFriends(userId1: string, userId2: string): Promise<boolean> {
    const result = await pool.query(`
      SELECT id FROM friendships
      WHERE ((user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1))
        AND status = 'accepted'
    `, [userId1, userId2]);
    return result.rows.length > 0;
  },

  async getFriendIds(userId: string): Promise<string[]> {
    const result = await pool.query(`
      SELECT CASE WHEN user_id = $1 THEN friend_id ELSE user_id END as friend_id
      FROM friendships
      WHERE (user_id = $1 OR friend_id = $1) AND status = 'accepted'
    `, [userId]);
    return result.rows.map(r => r.friend_id);
  }
};
