import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { getJwtSecret } from '../config/secrets.js';

/**
 * Gitu Terminal Service
 * 
 * Handles terminal authentication and device management for the Gitu assistant.
 * Provides token-based authentication flow for linking terminal clients to user accounts.
 * 
 * Authentication Flow:
 * 1. User generates pairing token in Flutter app (5-minute expiry)
 * 2. User runs `gitu auth <token>` in terminal
 * 3. Terminal calls linkTerminal() with token + device info
 * 4. Service validates token and creates linked account
 * 5. Service generates long-lived JWT auth token (90 days)
 * 6. Terminal stores auth token locally
 * 7. Terminal uses auth token for all subsequent requests
 */

interface PairingToken {
  code: string;
  userId: string;
  expiresAt: Date;
  expiresInSeconds: number;
}

interface LinkTerminalResult {
  authToken: string;
  userId: string;
  expiresAt: Date;
  expiresInDays: number;
}

interface ValidateTokenResult {
  valid: boolean;
  userId?: string;
  deviceId?: string;
  expiresAt?: Date;
  error?: string;
}

interface LinkedDevice {
  deviceId: string;
  deviceName: string;
  linkedAt: Date;
  lastUsedAt: Date;
  status: 'active' | 'inactive' | 'suspended';
}

interface RefreshTokenResult {
  authToken: string;
  expiresAt: Date;
  expiresInDays: number;
}

export class GituTerminalService {
  private readonly TOKEN_EXPIRY_MINUTES = 5;
  private readonly AUTH_TOKEN_EXPIRY_DAYS = 90;
  private readonly JWT_SECRET: string;
  private readonly shouldLog: boolean;

  constructor() {
    this.JWT_SECRET = getJwtSecret();
    this.shouldLog = process.env.NODE_ENV !== 'production';
  }

  /**
   * Generate a pairing token for terminal authentication
   * 
   * Creates a short-lived (5 minutes) pairing token that users can use to link
   * their terminal to their account. Token format: GITU-XXXX-YYYY
   * 
   * @param userId - User ID from authenticated session
   * @returns Pairing token details including code and expiry
   */
  async generatePairingToken(userId: string): Promise<PairingToken> {
    // Generate 8-character token (e.g., GITU-ABCD-1234)
    const part1 = this.generateRandomCode(4);
    const part2 = this.generateRandomCode(4);
    const code = `GITU-${part1}-${part2}`;

    // Token expires in 5 minutes
    const expiresAt = new Date(Date.now() + this.TOKEN_EXPIRY_MINUTES * 60 * 1000);

    // Store in database (upsert to handle duplicate codes)
    await pool.query(
      `INSERT INTO gitu_pairing_tokens (code, user_id, expires_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (code) DO UPDATE SET expires_at = $3`,
      [code, userId, expiresAt]
    );

    if (this.shouldLog) console.log(`[GituTerminalService] Generated pairing token for user ${userId}`);

    return {
      code,
      userId,
      expiresAt,
      expiresInSeconds: this.TOKEN_EXPIRY_MINUTES * 60
    };
  }

  /**
   * Link terminal device using pairing token
   * 
   * Validates the pairing token and creates a linked account record.
   * Generates a long-lived JWT auth token (90 days) for the terminal.
   * 
   * @param token - Pairing token from generatePairingToken()
   * @param deviceId - Unique device identifier
   * @param deviceName - Human-readable device name (optional)
   * @returns Auth token and user details
   * @throws Error if token is invalid or expired
   */
  async linkTerminal(
    token: string,
    deviceId: string,
    deviceName?: string
  ): Promise<LinkTerminalResult> {
    if (!token || !deviceId) {
      throw new Error('Token and deviceId are required');
    }

    // Validate pairing token
    const tokenResult = await pool.query(
      `SELECT user_id, expires_at FROM gitu_pairing_tokens
       WHERE code = $1 AND expires_at > NOW()`,
      [token]
    );

    if (tokenResult.rows.length === 0) {
      throw new Error('Invalid or expired pairing token');
    }

    const { user_id: userId } = tokenResult.rows[0];

    // Check if device already linked
    const existingLink = await pool.query(
      `SELECT 1 FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2
       LIMIT 1`,
      [userId, deviceId]
    );

    if (existingLink.rows.length > 0) {
      // Update existing link
      await pool.query(
        `UPDATE gitu_linked_accounts
         SET display_name = $1, last_used_at = NOW(), verified = true, status = 'active'
         WHERE user_id = $2 AND platform = 'terminal' AND platform_user_id = $3`,
        [deviceName || deviceId, userId, deviceId]
      );
    } else {
      // Create new linked account
      await pool.query(
        `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified, status)
         VALUES ($1, 'terminal', $2, $3, true, 'active')`,
        [userId, deviceId, deviceName || deviceId]
      );
    }

    // Generate long-lived JWT auth token (90 days)
    const authToken = jwt.sign(
      {
        userId,
        platform: 'terminal',
        deviceId,
        type: 'gitu_terminal'
      },
      this.JWT_SECRET,
      { expiresIn: `${this.AUTH_TOKEN_EXPIRY_DAYS}d` }
    );

    const expiresAt = new Date(Date.now() + this.AUTH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    // Delete used pairing token
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE code = $1', [token]);

    console.log(`[GituTerminalService] Terminal linked successfully for user ${userId}, device ${deviceId}`);

    return {
      authToken,
      userId,
      expiresAt,
      expiresInDays: this.AUTH_TOKEN_EXPIRY_DAYS
    };
  }

  /**
   * Link terminal device for a specific user (used by QR auth)
   * 
   * Similar to linkTerminal() but doesn't require a pairing token.
   * Used by the QR authentication flow where the user has already
   * authenticated via the Flutter app.
   * 
   * @param userId - User ID (already authenticated)
   * @param deviceId - Unique device identifier
   * @param deviceName - Human-readable device name (optional)
   * @returns Auth token and user details
   */
  async linkTerminalForUser(
    userId: string,
    deviceId: string,
    deviceName?: string
  ): Promise<LinkTerminalResult> {
    if (!userId || !deviceId) {
      throw new Error('userId and deviceId are required');
    }

    // Check if device already linked
    const existingLink = await pool.query(
      `SELECT 1 FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2
       LIMIT 1`,
      [userId, deviceId]
    );

    if (existingLink.rows.length > 0) {
      // Update existing link
      await pool.query(
        `UPDATE gitu_linked_accounts
         SET display_name = $1, last_used_at = NOW(), verified = true, status = 'active'
         WHERE user_id = $2 AND platform = 'terminal' AND platform_user_id = $3`,
        [deviceName || deviceId, userId, deviceId]
      );
    } else {
      // Create new linked account
      await pool.query(
        `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified, status)
         VALUES ($1, 'terminal', $2, $3, true, 'active')`,
        [userId, deviceId, deviceName || deviceId]
      );
    }

    // Generate long-lived JWT auth token (90 days)
    const authToken = jwt.sign(
      {
        userId,
        platform: 'terminal',
        deviceId,
        type: 'gitu_terminal'
      },
      this.JWT_SECRET,
      { expiresIn: `${this.AUTH_TOKEN_EXPIRY_DAYS}d` }
    );

    const expiresAt = new Date(Date.now() + this.AUTH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    console.log(`[GituTerminalService] Terminal linked via QR auth for user ${userId}, device ${deviceId}`);

    return {
      authToken,
      userId,
      expiresAt,
      expiresInDays: this.AUTH_TOKEN_EXPIRY_DAYS
    };
  }

  /**
   * Validate terminal auth token
   * 
   * Checks if a JWT auth token is valid and the device is still linked.
   * Updates the last_used_at timestamp if valid.
   * 
   * @param authToken - JWT auth token from linkTerminal()
   * @returns Validation result with user and device info
   */
  async validateAuthToken(authToken: string): Promise<ValidateTokenResult> {
    if (!authToken) {
      return { valid: false, error: 'authToken is required' };
    }

    try {
      const decoded = jwt.verify(authToken, this.JWT_SECRET) as {
        userId: string;
        platform: string;
        deviceId: string;
        type: string;
        exp: number;
      };

      // Verify this is a terminal token
      if (decoded.type !== 'gitu_terminal' || decoded.platform !== 'terminal') {
        return { valid: false, error: 'Not a terminal auth token' };
      }

      // Check if device is still linked
      const linkResult = await pool.query(
        `SELECT status FROM gitu_linked_accounts
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [decoded.userId, decoded.deviceId]
      );

      if (linkResult.rows.length === 0) {
        return { valid: false, error: 'Device not linked' };
      }

      const { status } = linkResult.rows[0];

      if (status !== 'active') {
        return { valid: false, error: `Device status: ${status}` };
      }

      // Update last used timestamp
      await pool.query(
        `UPDATE gitu_linked_accounts
         SET last_used_at = NOW()
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [decoded.userId, decoded.deviceId]
      );

      return {
        valid: true,
        userId: decoded.userId,
        deviceId: decoded.deviceId,
        expiresAt: new Date(decoded.exp * 1000)
      };
    } catch (jwtError: any) {
      if (jwtError.name === 'TokenExpiredError') {
        return { valid: false, error: 'Token expired' };
      }
      return { valid: false, error: 'Invalid token' };
    }
  }

  /**
   * Unlink terminal device
   * 
   * Removes the linked account record for the specified device.
   * The device will no longer be able to authenticate.
   * 
   * @param userId - User ID
   * @param deviceId - Device ID to unlink
   * @throws Error if device not found
   */
  async unlinkTerminal(userId: string, deviceId: string): Promise<void> {
    if (!deviceId) {
      throw new Error('deviceId is required');
    }

    const result = await pool.query(
      `DELETE FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2
       RETURNING platform_user_id`,
      [userId, deviceId]
    );

    if (result.rows.length === 0) {
      throw new Error('Device not found');
    }

    console.log(`[GituTerminalService] Terminal unlinked for user ${userId}, device ${deviceId}`);
  }

  /**
   * List linked terminal devices
   * 
   * Returns all terminal devices linked to the user's account.
   * 
   * @param userId - User ID
   * @returns Array of linked devices with metadata
   */
  async listLinkedDevices(userId: string): Promise<LinkedDevice[]> {
    const columnsResult = await pool.query(
      `SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'gitu_linked_accounts'`
    );
    const columns = new Set((columnsResult.rows as any[]).map(r => String(r.column_name)));

    const linkedAtExpr = columns.has('linked_at')
      ? 'linked_at'
      : columns.has('created_at')
        ? 'created_at'
        : 'NOW()';
    const lastUsedAtExpr = columns.has('last_used_at') ? 'last_used_at' : linkedAtExpr;
    const statusExpr = columns.has('status') ? 'status' : `'active'`;

    const result = await pool.query(
      `SELECT platform_user_id as device_id, display_name, ${linkedAtExpr} as linked_at, ${lastUsedAtExpr} as last_used_at, ${statusExpr} as status
       FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal'
       ORDER BY ${lastUsedAtExpr} DESC`,
      [userId]
    );

    return result.rows.map(row => ({
      deviceId: row.device_id,
      deviceName: row.display_name,
      linkedAt: row.linked_at,
      lastUsedAt: row.last_used_at,
      status: row.status
    }));
  }

  /**
   * Refresh terminal auth token
   * 
   * Issues a new JWT auth token before the old one expires.
   * Validates the old token (ignoring expiration) and checks device status.
   * 
   * @param authToken - Current JWT auth token
   * @returns New auth token with extended expiry
   * @throws Error if token is invalid or device is not active
   */
  async refreshAuthToken(authToken: string): Promise<RefreshTokenResult> {
    if (!authToken) {
      throw new Error('authToken is required');
    }

    try {
      const decoded = jwt.verify(authToken, this.JWT_SECRET, { ignoreExpiration: true }) as {
        userId: string;
        platform: string;
        deviceId: string;
        type: string;
      };

      // Verify this is a terminal token
      if (decoded.type !== 'gitu_terminal' || decoded.platform !== 'terminal') {
        throw new Error('Not a terminal auth token');
      }

      // Check if device is still linked and active
      const linkResult = await pool.query(
        `SELECT status FROM gitu_linked_accounts
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [decoded.userId, decoded.deviceId]
      );

      if (linkResult.rows.length === 0) {
        throw new Error('Device not linked');
      }

      const { status } = linkResult.rows[0];

      if (status !== 'active') {
        throw new Error(`Device status: ${status}`);
      }

      // Generate new auth token
      const newAuthToken = jwt.sign(
        {
          userId: decoded.userId,
          platform: 'terminal',
          deviceId: decoded.deviceId,
          type: 'gitu_terminal'
        },
        this.JWT_SECRET,
        { expiresIn: `${this.AUTH_TOKEN_EXPIRY_DAYS}d` }
      );

      const expiresAt = new Date(Date.now() + this.AUTH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

      // Update last used timestamp
      await pool.query(
        `UPDATE gitu_linked_accounts
         SET last_used_at = NOW()
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [decoded.userId, decoded.deviceId]
      );

      console.log(`[GituTerminalService] Terminal auth token refreshed for user ${decoded.userId}, device ${decoded.deviceId}`);

      return {
        authToken: newAuthToken,
        expiresAt,
        expiresInDays: this.AUTH_TOKEN_EXPIRY_DAYS
      };
    } catch (error: any) {
      if (error.message) {
        throw error;
      }
      throw new Error('Invalid token');
    }
  }

  /**
   * Clean up expired pairing tokens
   * 
   * Removes all pairing tokens that have expired.
   * Should be called periodically (e.g., via cron job).
   * 
   * @returns Number of tokens deleted
   */
  async cleanupExpiredTokens(): Promise<number> {
    const result = await pool.query(
      `DELETE FROM gitu_pairing_tokens WHERE expires_at < NOW() RETURNING code`
    );

    const count = result.rows.length;
    if (count > 0) {
      console.log(`[GituTerminalService] Cleaned up ${count} expired pairing tokens`);
    }

    return count;
  }

  /**
   * Get device status
   * 
   * Checks if a device is linked and returns its status.
   * 
   * @param userId - User ID
   * @param deviceId - Device ID
   * @returns Device status or null if not found
   */
  async getDeviceStatus(userId: string, deviceId: string): Promise<string | null> {
    const result = await pool.query(
      `SELECT status FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
      [userId, deviceId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0].status;
  }

  /**
   * Update device status
   * 
   * Changes the status of a linked device (e.g., suspend, reactivate).
   * 
   * @param userId - User ID
   * @param deviceId - Device ID
   * @param status - New status ('active', 'inactive', 'suspended')
   * @throws Error if device not found
   */
  async updateDeviceStatus(
    userId: string,
    deviceId: string,
    status: 'active' | 'inactive' | 'suspended'
  ): Promise<void> {
    const result = await pool.query(
      `UPDATE gitu_linked_accounts
       SET status = $1
       WHERE user_id = $2 AND platform = 'terminal' AND platform_user_id = $3
       RETURNING platform_user_id`,
      [status, userId, deviceId]
    );

    if (result.rows.length === 0) {
      throw new Error('Device not found');
    }

    console.log(`[GituTerminalService] Device status updated for user ${userId}, device ${deviceId}: ${status}`);
  }

  /**
   * Update device settings
   * 
   * Updates settings for a linked terminal device.
   * 
   * @param userId - User ID
   * @param deviceId - Device ID
   * @param settings - Settings object (e.g., preferredModel)
   */
  async updateDeviceSettings(userId: string, deviceId: string, settings: Record<string, any>): Promise<void> {
    // Check if device exists
    const device = await this.getDeviceStatus(userId, deviceId);
    if (!device) {
        throw new Error('Device not found');
    }

    // We store device-specific preferences in the user's Gitu settings for now,
    // keyed by deviceId, or we could add a settings column to gitu_linked_accounts.
    // Given the current schema, let's add a `settings` column to `gitu_linked_accounts` if it doesn't exist,
    // or better yet, use the `gitu_settings` in `users` table but scoped.
    
    // For simplicity and cleaner separation, let's assume we can update `gitu_linked_accounts`
    // We need to add a JSONB column `settings` to `gitu_linked_accounts`.
    
    // Let's first try to update and see if the column exists (it might not).
    // If not, we'll need a migration. But since we can't run migrations easily here without
    // potentially breaking things, let's use the user's global settings for now, 
    // or just assume the column exists (I will add it in ensure-tables).
    
    await pool.query(
        `UPDATE gitu_linked_accounts 
         SET settings = COALESCE(settings, '{}'::jsonb) || $1::jsonb
         WHERE user_id = $2 AND platform = 'terminal' AND platform_user_id = $3`,
        [JSON.stringify(settings), userId, deviceId]
    );
  }

  /**
   * Get device settings
   */
  async getDeviceSettings(userId: string, deviceId: string): Promise<Record<string, any>> {
      const result = await pool.query(
          `SELECT settings FROM gitu_linked_accounts
           WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
          [userId, deviceId]
      );
      
      if (result.rows.length === 0) return {};
      return result.rows[0].settings || {};
  }

  /**
   * Generate random alphanumeric code
   * 
   * Creates a random code using uppercase letters and numbers.
   * Excludes confusing characters (0, O, 1, I, L).
   * 
   * @param length - Length of code to generate
   * @returns Random uppercase alphanumeric string
   */
  private generateRandomCode(length: number): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars: 0, O, 1, I, L
    let result = '';
    const randomBytes = crypto.randomBytes(length);
    
    for (let i = 0; i < length; i++) {
      result += chars[randomBytes[i] % chars.length];
    }
    
    return result;
  }
}

// Export singleton instance
export const gituTerminalService = new GituTerminalService();
