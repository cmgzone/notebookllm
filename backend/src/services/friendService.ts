import { pool } from '../config/database';

export interface Friend {
  id: string;
  friendId: string;
  username: string;
  email: string;
  avatarUrl?: string;
  status: 'pending' | 'accepted' | 'blocked';
  createdAt: Date;
  acceptedAt?: Date;
}

export interface FriendRequest {
  id: string;
  fromUserId: string;
  fromUsername: string;
  fromEmail: string;
  fromAvatarUrl?: string;
  createdAt: Date;
}

export const friendService = {
  async searchUsers(query: string, currentUserId: string, limit = 20) {
    const result = await pool.query(`
      SELECT id, username, email, avatar_url
      FROM users
      WHERE id != $1
        AND (username ILIKE $2 OR email ILIKE $2)
        AND id NOT IN (
          SELECT friend_id FROM friendships WHERE user_id = $1
          UNION
          SELECT user_id FROM friendships WHERE friend_id = $1
        )
      LIMIT $3
    `, [currentUserId, `%${query}%`, limit]);
    return result.rows;
  },

  async sendFriendRequest(userId: string, friendId: string) {
    // Check if request already exists
    const existing = await pool.query(`
      SELECT id, status FROM friendships 
      WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
    `, [userId, friendId]);

    if (existing.rows.length > 0) {
      throw new Error('Friend request already exists');
    }

    const result = await pool.query(`
      INSERT INTO friendships (user_id, friend_id, status)
      VALUES ($1, $2, 'pending')
      RETURNING *
    `, [userId, friendId]);
    return result.rows[0];
  },

  async acceptFriendRequest(requestId: string, userId: string) {
    const result = await pool.query(`
      UPDATE friendships
      SET status = 'accepted', accepted_at = NOW()
      WHERE id = $1 AND friend_id = $2 AND status = 'pending'
      RETURNING *
    `, [requestId, userId]);

    if (result.rows.length === 0) {
      throw new Error('Friend request not found');
    }
    return result.rows[0];
  },

  async declineFriendRequest(requestId: string, userId: string) {
    const result = await pool.query(`
      DELETE FROM friendships
      WHERE id = $1 AND friend_id = $2 AND status = 'pending'
      RETURNING *
    `, [requestId, userId]);

    if (result.rows.length === 0) {
      throw new Error('Friend request not found');
    }
    return { success: true };
  },


  async removeFriend(friendshipId: string, userId: string) {
    const result = await pool.query(`
      DELETE FROM friendships
      WHERE id = $1 AND (user_id = $2 OR friend_id = $2)
      RETURNING *
    `, [friendshipId, userId]);

    if (result.rows.length === 0) {
      throw new Error('Friendship not found');
    }
    return { success: true };
  },

  async getFriends(userId: string) {
    const result = await pool.query(`
      SELECT 
        f.id,
        CASE WHEN f.user_id = $1 THEN f.friend_id ELSE f.user_id END as friend_id,
        u.username,
        u.email,
        u.avatar_url,
        f.status,
        f.created_at,
        f.accepted_at
      FROM friendships f
      JOIN users u ON u.id = CASE WHEN f.user_id = $1 THEN f.friend_id ELSE f.user_id END
      WHERE (f.user_id = $1 OR f.friend_id = $1) AND f.status = 'accepted'
      ORDER BY f.accepted_at DESC
    `, [userId]);
    return result.rows;
  },

  async getPendingRequests(userId: string) {
    const result = await pool.query(`
      SELECT 
        f.id,
        f.user_id as from_user_id,
        u.username as from_username,
        u.email as from_email,
        u.avatar_url as from_avatar_url,
        f.created_at
      FROM friendships f
      JOIN users u ON u.id = f.user_id
      WHERE f.friend_id = $1 AND f.status = 'pending'
      ORDER BY f.created_at DESC
    `, [userId]);
    return result.rows;
  },

  async getSentRequests(userId: string) {
    const result = await pool.query(`
      SELECT 
        f.id,
        f.friend_id as to_user_id,
        u.username as to_username,
        u.email as to_email,
        u.avatar_url as to_avatar_url,
        f.created_at
      FROM friendships f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = $1 AND f.status = 'pending'
      ORDER BY f.created_at DESC
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
