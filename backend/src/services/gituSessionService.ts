/**
 * Gitu Session Service
 * Manages persistent sessions across platforms and conversations for the Gitu universal AI assistant.
 * 
 * Requirements: US-3 (Session Management), TR-1 (Architecture)
 * Design: Section 2 (Session Manager)
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

/**
 * Message in a conversation
 */
export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  platform: string;
}

/**
 * Task being executed in a session
 */
export interface Task {
  id: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  startedAt?: Date;
  completedAt?: Date;
}

/**
 * Session context containing conversation history and state
 */
export interface SessionContext {
  conversationHistory: Message[];
  activeNotebooks: string[];  // Notebook IDs in context
  activeIntegrations: string[];  // Integration names (gmail, shopify, etc.)
  currentTask?: Task;
  variables: Record<string, any>;  // Session variables
}

/**
 * Gitu session
 */
export interface Session {
  id: string;
  userId: string;
  platform: 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal' | 'web' | 'universal';
  status: 'active' | 'paused' | 'ended';
  context: SessionContext;
  startedAt: Date;
  lastActivityAt: Date;
  endedAt?: Date;
}

/**
 * Options for creating or updating a session
 */
export interface SessionOptions {
  platform: 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal' | 'web' | 'universal';
  initialContext?: Partial<SessionContext>;
}

// ==================== SERVICE CLASS ====================

class GituSessionService {
  /**
   * Get an existing session or create a new one for the user on the specified platform.
   * Implements idempotent behavior - returns active session if one exists.
   * 
   * @param userId - The user's ID
   * @param platform - The platform the user is connecting from
   * @returns The active or newly created Session
   */
  async getOrCreateSession(userId: string, platform: SessionOptions['platform']): Promise<Session> {
    // Check for existing active session on this platform
    const existingSession = await this.getActiveSession(userId, platform);
    if (existingSession) {
      // Update activity timestamp
      await this.updateActivity(existingSession.id);
      return existingSession;
    }

    // Create new session
    const sessionId = uuidv4();
    const defaultContext: SessionContext = {
      conversationHistory: [],
      activeNotebooks: [],
      activeIntegrations: [],
      variables: {},
    };

    const result = await pool.query(
      `INSERT INTO gitu_sessions 
       (id, user_id, platform, status, context, started_at, last_activity_at)
       VALUES ($1, $2, $3, 'active', $4, NOW(), NOW())
       RETURNING *`,
      [sessionId, userId, platform, JSON.stringify(defaultContext)]
    );

    return this.mapRowToSession(result.rows[0]);
  }

  /**
   * Get a session by its ID.
   * 
   * @param sessionId - The session ID
   * @returns The Session or null if not found
   */
  async getSession(sessionId: string): Promise<Session | null> {
    const result = await pool.query(
      `SELECT * FROM gitu_sessions WHERE id = $1`,
      [sessionId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToSession(result.rows[0]);
  }

  /**
   * Get the active session for a user on a specific platform.
   * 
   * @param userId - The user's ID
   * @param platform - The platform
   * @returns The active Session or null if not found
   */
  async getActiveSession(userId: string, platform: SessionOptions['platform']): Promise<Session | null> {
    const result = await pool.query(
      `SELECT * FROM gitu_sessions 
       WHERE user_id = $1 AND platform = $2 AND status = 'active'
       ORDER BY last_activity_at DESC
       LIMIT 1`,
      [userId, platform]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return this.mapRowToSession(result.rows[0]);
  }

  /**
   * Get all sessions for a user across all platforms.
   * 
   * @param userId - The user's ID
   * @param includeEnded - Whether to include ended sessions (default: false)
   * @returns Array of Sessions
   */
  async listUserSessions(userId: string, includeEnded: boolean = false): Promise<Session[]> {
    const query = includeEnded
      ? `SELECT * FROM gitu_sessions WHERE user_id = $1 ORDER BY last_activity_at DESC`
      : `SELECT * FROM gitu_sessions WHERE user_id = $1 AND status != 'ended' ORDER BY last_activity_at DESC`;

    const result = await pool.query(query, [userId]);
    return result.rows.map(row => this.mapRowToSession(row));
  }

  /**
   * Update a session with partial updates.
   * 
   * @param sessionId - The session ID
   * @param updates - Partial session updates
   * @returns The updated Session
   */
  async updateSession(sessionId: string, updates: Partial<Session>): Promise<Session> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    // Build update query dynamically based on provided fields
    const updateFields: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (updates.status !== undefined) {
      updateFields.push(`status = $${paramIndex++}`);
      values.push(updates.status);
    }

    if (updates.context !== undefined) {
      updateFields.push(`context = $${paramIndex++}`);
      values.push(JSON.stringify(updates.context));
    }

    if (updates.endedAt !== undefined) {
      updateFields.push(`ended_at = $${paramIndex++}`);
      values.push(updates.endedAt);
    }

    // Always update last_activity_at
    updateFields.push(`last_activity_at = NOW()`);

    // Add session ID as last parameter
    values.push(sessionId);

    const query = `
      UPDATE gitu_sessions 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    return this.mapRowToSession(result.rows[0]);
  }

  /**
   * Update the last activity timestamp for a session.
   * 
   * @param sessionId - The session ID
   */
  async updateActivity(sessionId: string): Promise<void> {
    await pool.query(
      `UPDATE gitu_sessions SET last_activity_at = NOW() WHERE id = $1`,
      [sessionId]
    );
  }

  /**
   * Add a message to the session's conversation history.
   * 
   * @param sessionId - The session ID
   * @param message - The message to add
   */
  async addMessage(sessionId: string, message: Omit<Message, 'timestamp'>): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    const fullMessage: Message = {
      ...message,
      timestamp: new Date(),
    };

    session.context.conversationHistory.push(fullMessage);

    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Add a notebook to the session's active notebooks.
   * 
   * @param sessionId - The session ID
   * @param notebookId - The notebook ID to add
   */
  async addNotebook(sessionId: string, notebookId: string): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    if (!session.context.activeNotebooks.includes(notebookId)) {
      session.context.activeNotebooks.push(notebookId);
      await this.updateSession(sessionId, { context: session.context });
    }
  }

  /**
   * Remove a notebook from the session's active notebooks.
   * 
   * @param sessionId - The session ID
   * @param notebookId - The notebook ID to remove
   */
  async removeNotebook(sessionId: string, notebookId: string): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.context.activeNotebooks = session.context.activeNotebooks.filter(
      id => id !== notebookId
    );
    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Add an integration to the session's active integrations.
   * 
   * @param sessionId - The session ID
   * @param integration - The integration name (e.g., 'gmail', 'shopify')
   */
  async addIntegration(sessionId: string, integration: string): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    if (!session.context.activeIntegrations.includes(integration)) {
      session.context.activeIntegrations.push(integration);
      await this.updateSession(sessionId, { context: session.context });
    }
  }

  /**
   * Remove an integration from the session's active integrations.
   * 
   * @param sessionId - The session ID
   * @param integration - The integration name to remove
   */
  async removeIntegration(sessionId: string, integration: string): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.context.activeIntegrations = session.context.activeIntegrations.filter(
      name => name !== integration
    );
    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Set a session variable.
   * 
   * @param sessionId - The session ID
   * @param key - The variable key
   * @param value - The variable value
   */
  async setVariable(sessionId: string, key: string, value: any): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.context.variables[key] = value;
    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Get a session variable.
   * 
   * @param sessionId - The session ID
   * @param key - The variable key
   * @returns The variable value or undefined if not found
   */
  async getVariable(sessionId: string, key: string): Promise<any> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    return session.context.variables[key];
  }

  /**
   * Set the current task for a session.
   * 
   * @param sessionId - The session ID
   * @param task - The task to set
   */
  async setCurrentTask(sessionId: string, task: Task): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.context.currentTask = task;
    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Clear the current task from a session.
   * 
   * @param sessionId - The session ID
   */
  async clearCurrentTask(sessionId: string): Promise<void> {
    const session = await this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.context.currentTask = undefined;
    await this.updateSession(sessionId, { context: session.context });
  }

  /**
   * Pause a session (user can resume later).
   * 
   * @param sessionId - The session ID
   */
  async pauseSession(sessionId: string): Promise<void> {
    await this.updateSession(sessionId, { status: 'paused' });
  }

  /**
   * Resume a paused session.
   * 
   * @param sessionId - The session ID
   */
  async resumeSession(sessionId: string): Promise<void> {
    await this.updateSession(sessionId, { status: 'active' });
  }

  /**
   * End a session permanently.
   * 
   * @param sessionId - The session ID
   */
  async endSession(sessionId: string): Promise<void> {
    await this.updateSession(sessionId, {
      status: 'ended',
      endedAt: new Date(),
    });
  }

  /**
   * Delete a session completely (removes from database).
   * 
   * @param sessionId - The session ID
   */
  async deleteSession(sessionId: string): Promise<void> {
    await pool.query(
      `DELETE FROM gitu_sessions WHERE id = $1`,
      [sessionId]
    );
  }

  /**
   * Clean up old ended sessions (older than specified days).
   * This should be run as a cron job.
   * 
   * @param daysOld - Number of days old (default: 30)
   * @returns Number of sessions deleted
   */
  async cleanupOldSessions(daysOld: number = 30): Promise<number> {
    const result = await pool.query(
      `DELETE FROM gitu_sessions 
       WHERE status = 'ended' 
       AND ended_at < NOW() - INTERVAL '${daysOld} days'
       RETURNING id`,
    );

    return result.rowCount || 0;
  }

  /**
   * Get session statistics for a user.
   * 
   * @param userId - The user's ID
   * @returns Session statistics
   */
  async getSessionStats(userId: string): Promise<{
    totalSessions: number;
    activeSessions: number;
    pausedSessions: number;
    endedSessions: number;
    messageCount: number;
    averageSessionDuration: number;  // in minutes
  }> {
    const sessions = await this.listUserSessions(userId, true);

    const stats = {
      totalSessions: sessions.length,
      activeSessions: sessions.filter(s => s.status === 'active').length,
      pausedSessions: sessions.filter(s => s.status === 'paused').length,
      endedSessions: sessions.filter(s => s.status === 'ended').length,
      messageCount: sessions.reduce((sum, s) => sum + s.context.conversationHistory.length, 0),
      averageSessionDuration: 0,
    };

    // Calculate average session duration for ended sessions
    const endedSessions = sessions.filter(s => s.status === 'ended' && s.endedAt);
    if (endedSessions.length > 0) {
      const totalDuration = endedSessions.reduce((sum, s) => {
        const duration = s.endedAt!.getTime() - s.startedAt.getTime();
        return sum + duration;
      }, 0);
      stats.averageSessionDuration = Math.round(totalDuration / endedSessions.length / 60000); // Convert to minutes
    }

    return stats;
  }

  /**
   * Map a database row to a Session object.
   */
  private mapRowToSession(row: any): Session {
    const context = typeof row.context === 'string' ? JSON.parse(row.context) : row.context;
    
    // Convert timestamp strings back to Date objects in conversation history
    if (context.conversationHistory) {
      context.conversationHistory = context.conversationHistory.map((msg: any) => ({
        ...msg,
        timestamp: typeof msg.timestamp === 'string' ? new Date(msg.timestamp) : msg.timestamp,
      }));
    }
    
    // Convert task timestamps if present
    if (context.currentTask) {
      if (context.currentTask.startedAt && typeof context.currentTask.startedAt === 'string') {
        context.currentTask.startedAt = new Date(context.currentTask.startedAt);
      }
      if (context.currentTask.completedAt && typeof context.currentTask.completedAt === 'string') {
        context.currentTask.completedAt = new Date(context.currentTask.completedAt);
      }
    }
    
    return {
      id: row.id,
      userId: row.user_id,
      platform: row.platform,
      status: row.status,
      context,
      startedAt: new Date(row.started_at),
      lastActivityAt: new Date(row.last_activity_at),
      endedAt: row.ended_at ? new Date(row.ended_at) : undefined,
    };
  }
}

// Export singleton instance
export const gituSessionService = new GituSessionService();
export default gituSessionService;
