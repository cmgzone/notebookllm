/**
 * MCP Limits Service
 * Manages MCP usage limits and quota enforcement
 */

import pool from '../config/database.js';

export interface McpSettings {
  id: string;
  freeSourcesLimit: number;
  freeTokensLimit: number;
  freeApiCallsPerDay: number;
  premiumSourcesLimit: number;
  premiumTokensLimit: number;
  premiumApiCallsPerDay: number;
  isMcpEnabled: boolean;
  updatedAt: Date;
  updatedBy: string | null;
}

export interface UserMcpUsage {
  userId: string;
  sourcesCount: number;
  apiCallsToday: number;
  lastApiCallDate: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserQuota {
  sourcesLimit: number;
  sourcesUsed: number;
  sourcesRemaining: number;
  tokensLimit: number;
  tokensUsed: number;
  tokensRemaining: number;
  apiCallsLimit: number;
  apiCallsUsed: number;
  apiCallsRemaining: number;
  isPremium: boolean;
  isMcpEnabled: boolean;
}

class McpLimitsService {
  /**
   * Get MCP settings
   */
  async getSettings(): Promise<McpSettings> {
    const result = await pool.query(
      'SELECT * FROM mcp_settings WHERE id = $1',
      ['default']
    );

    if (result.rows.length === 0) {
      // Return defaults if not found
      return {
        id: 'default',
        freeSourcesLimit: 10,
        freeTokensLimit: 3,
        freeApiCallsPerDay: 100,
        premiumSourcesLimit: 1000,
        premiumTokensLimit: 10,
        premiumApiCallsPerDay: 10000,
        isMcpEnabled: true,
        updatedAt: new Date(),
        updatedBy: null,
      };
    }

    const row = result.rows[0];
    return {
      id: row.id,
      freeSourcesLimit: row.free_sources_limit,
      freeTokensLimit: row.free_tokens_limit,
      freeApiCallsPerDay: row.free_api_calls_per_day,
      premiumSourcesLimit: row.premium_sources_limit,
      premiumTokensLimit: row.premium_tokens_limit,
      premiumApiCallsPerDay: row.premium_api_calls_per_day,
      isMcpEnabled: row.is_mcp_enabled,
      updatedAt: row.updated_at,
      updatedBy: row.updated_by,
    };
  }

  /**
   * Update MCP settings (admin only)
   */
  async updateSettings(
    settings: Partial<Omit<McpSettings, 'id' | 'updatedAt'>>,
    adminUserId: string
  ): Promise<McpSettings> {
    const updates: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (settings.freeSourcesLimit !== undefined) {
      updates.push(`free_sources_limit = $${paramIndex++}`);
      values.push(settings.freeSourcesLimit);
    }
    if (settings.freeTokensLimit !== undefined) {
      updates.push(`free_tokens_limit = $${paramIndex++}`);
      values.push(settings.freeTokensLimit);
    }
    if (settings.freeApiCallsPerDay !== undefined) {
      updates.push(`free_api_calls_per_day = $${paramIndex++}`);
      values.push(settings.freeApiCallsPerDay);
    }
    if (settings.premiumSourcesLimit !== undefined) {
      updates.push(`premium_sources_limit = $${paramIndex++}`);
      values.push(settings.premiumSourcesLimit);
    }
    if (settings.premiumTokensLimit !== undefined) {
      updates.push(`premium_tokens_limit = $${paramIndex++}`);
      values.push(settings.premiumTokensLimit);
    }
    if (settings.premiumApiCallsPerDay !== undefined) {
      updates.push(`premium_api_calls_per_day = $${paramIndex++}`);
      values.push(settings.premiumApiCallsPerDay);
    }
    if (settings.isMcpEnabled !== undefined) {
      updates.push(`is_mcp_enabled = $${paramIndex++}`);
      values.push(settings.isMcpEnabled);
    }

    updates.push(`updated_at = NOW()`);
    updates.push(`updated_by = $${paramIndex++}`);
    values.push(adminUserId);
    values.push('default');

    await pool.query(
      `UPDATE mcp_settings SET ${updates.join(', ')} WHERE id = $${paramIndex}`,
      values
    );

    return this.getSettings();
  }

  /**
   * Get user's MCP usage
   */
  async getUserUsage(userId: string): Promise<UserMcpUsage> {
    // Ensure user has a usage record
    await pool.query(
      `INSERT INTO user_mcp_usage (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );

    // Reset daily counter if it's a new day
    await pool.query(
      `UPDATE user_mcp_usage 
       SET api_calls_today = 0, last_api_call_date = CURRENT_DATE, updated_at = NOW()
       WHERE user_id = $1 AND last_api_call_date < CURRENT_DATE`,
      [userId]
    );

    const result = await pool.query(
      'SELECT * FROM user_mcp_usage WHERE user_id = $1',
      [userId]
    );

    const row = result.rows[0];
    return {
      userId: row.user_id,
      sourcesCount: row.sources_count,
      apiCallsToday: row.api_calls_today,
      lastApiCallDate: row.last_api_call_date,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Increment API call usage for a user
   */
  async incrementApiUsage(userId: string): Promise<void> {
    await pool.query(
      `UPDATE user_mcp_usage 
       SET api_calls_today = api_calls_today + 1,
           last_api_call_date = CURRENT_DATE,
           updated_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
  }

  /**
   * Check if user is on premium plan
   */
  async isUserPremium(userId: string): Promise<boolean> {
    const result = await pool.query(
      `SELECT sp.is_free_plan 
       FROM user_subscriptions us
       JOIN subscription_plans sp ON us.plan_id = sp.id
       WHERE us.user_id = $1`,
      [userId]
    );

    if (result.rows.length === 0) return false;
    return !result.rows[0].is_free_plan;
  }

  /**
   * Get user's quota information
   */
  async getUserQuota(userId: string): Promise<UserQuota> {
    const [settings, usage, isPremium] = await Promise.all([
      this.getSettings(),
      this.getUserUsage(userId),
      this.isUserPremium(userId),
    ]);

    // Get actual token count (active = not revoked)
    const tokensResult = await pool.query(
      'SELECT COUNT(*) FROM api_tokens WHERE user_id = $1 AND revoked_at IS NULL',
      [userId]
    );
    const tokensUsed = parseInt(tokensResult.rows[0].count) || 0;

    const sourcesLimit = isPremium ? settings.premiumSourcesLimit : settings.freeSourcesLimit;
    const tokensLimit = isPremium ? settings.premiumTokensLimit : settings.freeTokensLimit;
    const apiCallsLimit = isPremium ? settings.premiumApiCallsPerDay : settings.freeApiCallsPerDay;

    return {
      sourcesLimit,
      sourcesUsed: usage.sourcesCount,
      sourcesRemaining: Math.max(0, sourcesLimit - usage.sourcesCount),
      tokensLimit,
      tokensUsed,
      tokensRemaining: Math.max(0, tokensLimit - tokensUsed),
      apiCallsLimit,
      apiCallsUsed: usage.apiCallsToday,
      apiCallsRemaining: Math.max(0, apiCallsLimit - usage.apiCallsToday),
      isPremium,
      isMcpEnabled: settings.isMcpEnabled,
    };
  }

  /**
   * Check if user can create a new source
   */
  async canCreateSource(userId: string): Promise<{ allowed: boolean; reason?: string }> {
    const quota = await this.getUserQuota(userId);

    if (!quota.isMcpEnabled) {
      return { allowed: false, reason: 'MCP is currently disabled by administrator' };
    }

    if (quota.sourcesRemaining <= 0) {
      return {
        allowed: false,
        reason: `Source limit reached (${quota.sourcesLimit}). ${quota.isPremium ? 'Contact support for higher limits.' : 'Upgrade to premium for more sources.'}`,
      };
    }

    return { allowed: true };
  }

  /**
   * Check if user can create a new API token
   */
  async canCreateToken(userId: string): Promise<{ allowed: boolean; reason?: string }> {
    const quota = await this.getUserQuota(userId);

    if (!quota.isMcpEnabled) {
      return { allowed: false, reason: 'MCP is currently disabled by administrator' };
    }

    if (quota.tokensRemaining <= 0) {
      return {
        allowed: false,
        reason: `Token limit reached (${quota.tokensLimit}). ${quota.isPremium ? 'Contact support for higher limits.' : 'Upgrade to premium for more tokens.'}`,
      };
    }

    return { allowed: true };
  }

  /**
   * Check if user can make an API call
   */
  async canMakeApiCall(userId: string): Promise<{ allowed: boolean; reason?: string }> {
    const quota = await this.getUserQuota(userId);

    if (!quota.isMcpEnabled) {
      return { allowed: false, reason: 'MCP is currently disabled by administrator' };
    }

    if (quota.apiCallsRemaining <= 0) {
      return {
        allowed: false,
        reason: `Daily API call limit reached (${quota.apiCallsLimit}). ${quota.isPremium ? 'Limit resets at midnight.' : 'Upgrade to premium for more API calls.'}`,
      };
    }

    return { allowed: true };
  }

  /**
   * Increment source count for user
   */
  async incrementSourceCount(userId: string): Promise<void> {
    await pool.query(
      `INSERT INTO user_mcp_usage (user_id, sources_count) VALUES ($1, 1)
       ON CONFLICT (user_id) DO UPDATE SET sources_count = user_mcp_usage.sources_count + 1, updated_at = NOW()`,
      [userId]
    );
  }

  /**
   * Decrement source count for user
   */
  async decrementSourceCount(userId: string): Promise<void> {
    await pool.query(
      `UPDATE user_mcp_usage SET sources_count = GREATEST(0, sources_count - 1), updated_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
  }

  /**
   * Increment API call count for user
   */
  async incrementApiCallCount(userId: string): Promise<void> {
    await pool.query(
      `INSERT INTO user_mcp_usage (user_id, api_calls_today, last_api_call_date) 
       VALUES ($1, 1, CURRENT_DATE)
       ON CONFLICT (user_id) DO UPDATE SET 
         api_calls_today = CASE 
           WHEN user_mcp_usage.last_api_call_date < CURRENT_DATE THEN 1 
           ELSE user_mcp_usage.api_calls_today + 1 
         END,
         last_api_call_date = CURRENT_DATE,
         updated_at = NOW()`,
      [userId]
    );
  }

  /**
   * Sync user's source count from actual database
   */
  async syncSourceCount(userId: string): Promise<number> {
    const result = await pool.query(
      `SELECT COUNT(*) FROM sources WHERE user_id = $1 AND type = 'code' AND (metadata->>'isVerified')::boolean = true`,
      [userId]
    );
    const count = parseInt(result.rows[0].count) || 0;

    await pool.query(
      `INSERT INTO user_mcp_usage (user_id, sources_count) VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE SET sources_count = $2, updated_at = NOW()`,
      [userId, count]
    );

    return count;
  }
}

export const mcpLimitsService = new McpLimitsService();
export default mcpLimitsService;
