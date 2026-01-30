import pool from '../config/database.js';

type Platform = 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal';

interface LinkedAccountRow {
  id: string;
  user_id: string;
  platform: Platform;
  platform_user_id: string;
  display_name: string | null;
  linked_at: string | Date | null;
  last_used_at: string | Date | null;
  verified: boolean | null;
  is_primary: boolean | null;
  status: string | null;
}

class GituIdentityManager {
  async listLinkedAccounts(userId: string): Promise<LinkedAccountRow[]> {
    const res = await pool.query(
      `SELECT id, user_id, platform, platform_user_id, display_name, linked_at, last_used_at, verified, is_primary, status
       FROM gitu_linked_accounts
       WHERE user_id = $1
       ORDER BY platform, platform_user_id`,
      [userId]
    );
    return res.rows as LinkedAccountRow[];
  }

  async linkAccount(input: {
    userId: string;
    platform: Platform;
    platformUserId: string;
    displayName?: string;
  }): Promise<LinkedAccountRow> {
    const res = await pool.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, status)
       VALUES ($1, $2, $3, $4, 'active')
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           display_name = COALESCE(EXCLUDED.display_name, gitu_linked_accounts.display_name),
           status = 'active',
           last_used_at = NOW()
       RETURNING *`,
      [input.userId, input.platform, input.platformUserId, input.displayName || null]
    );
    return res.rows[0] as LinkedAccountRow;
  }

  async unlinkAccount(userId: string, platform: Platform, platformUserId: string): Promise<boolean> {
    const res = await pool.query(
      `DELETE FROM gitu_linked_accounts WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3`,
      [userId, platform, platformUserId]
    );
    return (res.rowCount || 0) > 0;
  }

  async setPrimary(userId: string, platform: Platform, platformUserId: string): Promise<LinkedAccountRow | null> {
    try {
      await pool.query(
        `UPDATE gitu_linked_accounts SET is_primary = false WHERE user_id = $1 AND platform = $2`,
        [userId, platform]
      );
      const res = await pool.query(
        `UPDATE gitu_linked_accounts SET is_primary = true, last_used_at = NOW()
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3
         RETURNING *`,
        [userId, platform, platformUserId]
      );
      return res.rows.length ? (res.rows[0] as LinkedAccountRow) : null;
    } catch {
      const res = await pool.query(
        `SELECT id, user_id, platform, platform_user_id, display_name, linked_at, last_used_at, verified, is_primary, status
         FROM gitu_linked_accounts
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3`,
        [userId, platform, platformUserId]
      );
      return res.rows.length ? (res.rows[0] as LinkedAccountRow) : null;
    }
  }

  async verifyAccount(userId: string, platform: Platform, platformUserId: string): Promise<LinkedAccountRow | null> {
    try {
      const res = await pool.query(
        `UPDATE gitu_linked_accounts SET verified = true, last_used_at = NOW()
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3
         RETURNING *`,
        [userId, platform, platformUserId]
      );
      return res.rows.length ? (res.rows[0] as LinkedAccountRow) : null;
    } catch {
      const res = await pool.query(
        `SELECT id, user_id, platform, platform_user_id, display_name, linked_at, last_used_at, verified, is_primary, status
         FROM gitu_linked_accounts
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3`,
        [userId, platform, platformUserId]
      );
      return res.rows.length ? (res.rows[0] as LinkedAccountRow) : null;
    }
  }

  async updateLastUsed(userId: string, platform: Platform, platformUserId: string): Promise<void> {
    try {
      await pool.query(
        `UPDATE gitu_linked_accounts SET last_used_at = NOW()
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3`,
        [userId, platform, platformUserId]
      );
    } catch {
      await pool.query(
        `UPDATE gitu_linked_accounts SET display_name = COALESCE(display_name, '')
         WHERE user_id = $1 AND platform = $2 AND platform_user_id = $3`,
        [userId, platform, platformUserId]
      );
    }
  }

  async getTrustLevels(userId: string): Promise<Record<Platform, 'low' | 'medium' | 'high'>> {
    const accounts = await this.listLinkedAccounts(userId);
    const levels: Record<Platform, 'low' | 'medium' | 'high'> = {
      flutter: 'low',
      whatsapp: 'low',
      telegram: 'low',
      email: 'low',
      terminal: 'low',
    };
    for (const acc of accounts) {
      if (acc.status && acc.status !== 'active') continue;
      if (acc.platform === 'email') {
        levels.email = acc.verified ? 'high' : 'medium';
      } else if (acc.platform === 'terminal') {
        levels.terminal = acc.verified ? 'high' : 'medium';
      } else if (acc.platform === 'whatsapp' || acc.platform === 'telegram' || acc.platform === 'flutter') {
        const lvl: 'low' | 'medium' | 'high' = acc.verified ? 'medium' : 'low';
        levels[acc.platform] = lvl;
      }
    }
    return levels;
  }
}

export const gituIdentityManager = new GituIdentityManager();
export default gituIdentityManager;
