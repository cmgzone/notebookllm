/**
 * Token Revocation Service
 * Handles cascading effects when a user disconnects their GitHub account.
 * 
 * Requirements: 7.5 - Token Revocation Cascade
 * 
 * When a user revokes GitHub access:
 * 1. All cached tokens are invalidated
 * 2. GitHub source cache entries are invalidated
 * 3. Connected agent sessions are notified
 */

import pool from '../config/database.js';
import { agentSessionService, AgentSession } from './agentSessionService.js';
import { webhookService } from './webhookService.js';
import { auditLoggerService } from './auditLoggerService.js';

// ==================== INTERFACES ====================

export interface RevocationResult {
  success: boolean;
  invalidatedCacheEntries: number;
  notifiedAgentSessions: number;
  errors: string[];
}

export interface GitHubDisconnectNotification {
  type: 'github_disconnected';
  userId: string;
  timestamp: string;
  message: string;
}

// ==================== SERVICE CLASS ====================

class TokenRevocationService {
  /**
   * Handle GitHub disconnection for a user.
   * Implements the full cascade: invalidate cache, notify agents, log audit.
   * 
   * @param userId - The user's ID
   * @returns RevocationResult with details of what was invalidated
   */
  async handleDisconnect(userId: string): Promise<RevocationResult> {
    const errors: string[] = [];
    let invalidatedCacheEntries = 0;
    let notifiedAgentSessions = 0;

    try {
      // Step 1: Invalidate GitHub source cache entries
      invalidatedCacheEntries = await this.invalidateSourceCache(userId);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      errors.push(`Failed to invalidate source cache: ${message}`);
    }

    try {
      // Step 2: Notify connected agent sessions
      notifiedAgentSessions = await this.notifyAgentSessions(userId);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      errors.push(`Failed to notify agent sessions: ${message}`);
    }

    try {
      // Step 3: Log the disconnection in audit log
      await auditLoggerService.log({
        userId,
        action: 'github_disconnect',
        success: errors.length === 0,
        errorMessage: errors.length > 0 ? errors.join('; ') : undefined,
        requestMetadata: {
          invalidatedCacheEntries,
          notifiedAgentSessions,
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      errors.push(`Failed to log audit: ${message}`);
    }

    return {
      success: errors.length === 0,
      invalidatedCacheEntries,
      notifiedAgentSessions,
      errors,
    };
  }

  /**
   * Invalidate all GitHub source cache entries for a user.
   * This ensures subsequent API calls will fail with GITHUB_NOT_CONNECTED.
   * 
   * @param userId - The user's ID
   * @returns Number of cache entries invalidated
   */
  async invalidateSourceCache(userId: string): Promise<number> {
    // Get all GitHub sources for this user
    const sourcesResult = await pool.query(
      `SELECT s.id FROM sources s
       JOIN notebooks n ON s.notebook_id = n.id
       WHERE n.user_id = $1 AND s.type = 'github'`,
      [userId]
    );

    if (sourcesResult.rows.length === 0) {
      return 0;
    }

    const sourceIds = sourcesResult.rows.map(row => row.id);

    // Delete cache entries for these sources
    const deleteResult = await pool.query(
      `DELETE FROM github_source_cache WHERE source_id = ANY($1)`,
      [sourceIds]
    );

    return deleteResult.rowCount || 0;
  }

  /**
   * Notify all connected agent sessions about GitHub disconnection.
   * Updates session status and sends webhook notification if configured.
   * 
   * @param userId - The user's ID
   * @returns Number of sessions notified
   */
  async notifyAgentSessions(userId: string): Promise<number> {
    // Get all active sessions for this user
    const sessions = await agentSessionService.getSessionsByUser(userId);
    const activeSessions = sessions.filter(s => s.status === 'active');

    let notifiedCount = 0;

    for (const session of activeSessions) {
      try {
        // Send webhook notification if configured
        if (session.webhookUrl && session.webhookSecret) {
          await this.sendDisconnectNotification(session, userId);
        }

        // Update session metadata to indicate GitHub is disconnected
        await this.updateSessionGitHubStatus(session.id, false);
        
        notifiedCount++;
      } catch (error) {
        // Log error but continue with other sessions
        console.error(`Failed to notify session ${session.id}:`, error);
      }
    }

    return notifiedCount;
  }

  /**
   * Send a disconnect notification to an agent's webhook.
   * 
   * @param session - The agent session
   * @param userId - The user's ID
   */
  private async sendDisconnectNotification(session: AgentSession, userId: string): Promise<void> {
    if (!session.webhookUrl || !session.webhookSecret) {
      return;
    }

    const notification: GitHubDisconnectNotification = {
      type: 'github_disconnected',
      userId,
      timestamp: new Date().toISOString(),
      message: 'User has disconnected their GitHub account. GitHub-related operations will fail.',
    };

    const payload = JSON.stringify(notification);
    const signature = webhookService.generateSignature(payload, session.webhookSecret);

    try {
      await fetch(session.webhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Signature': signature,
          'X-Webhook-Timestamp': new Date().toISOString(),
          'X-Webhook-Event': 'github_disconnected',
        },
        body: payload,
        signal: AbortSignal.timeout(10000), // 10 second timeout
      });
    } catch (error) {
      // Notification is best-effort, don't throw
      console.error(`Failed to send disconnect notification to ${session.webhookUrl}:`, error);
    }
  }

  /**
   * Update session metadata to reflect GitHub connection status.
   * 
   * @param sessionId - The session ID
   * @param isConnected - Whether GitHub is connected
   */
  private async updateSessionGitHubStatus(sessionId: string, isConnected: boolean): Promise<void> {
    await pool.query(
      `UPDATE agent_sessions 
       SET metadata = jsonb_set(
         COALESCE(metadata::jsonb, '{}'::jsonb),
         '{githubConnected}',
         $1::jsonb
       ),
       last_activity = NOW()
       WHERE id = $2`,
      [JSON.stringify(isConnected), sessionId]
    );
  }

  /**
   * Check if a user has an active GitHub connection.
   * Used by other services to verify before making GitHub API calls.
   * 
   * @param userId - The user's ID
   * @returns true if connected, false otherwise
   */
  async isGitHubConnected(userId: string): Promise<boolean> {
    const result = await pool.query(
      `SELECT id FROM github_connections WHERE user_id = $1 AND is_active = true`,
      [userId]
    );
    return result.rows.length > 0;
  }

  /**
   * Verify GitHub connection and throw if not connected.
   * Convenience method for use in route handlers.
   * 
   * @param userId - The user's ID
   * @throws Error with code GITHUB_NOT_CONNECTED if not connected
   */
  async requireGitHubConnection(userId: string): Promise<void> {
    const isConnected = await this.isGitHubConnected(userId);
    if (!isConnected) {
      const error = new Error('GitHub not connected');
      (error as any).code = 'GITHUB_NOT_CONNECTED';
      throw error;
    }
  }
}

// Export singleton instance
export const tokenRevocationService = new TokenRevocationService();
export default tokenRevocationService;
