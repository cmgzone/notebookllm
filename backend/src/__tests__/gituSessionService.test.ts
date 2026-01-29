/**
 * Unit tests for Gitu Session Service
 */

import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import pool from '../config/database.js';
import gituSessionService, { Session, Message, Task } from '../services/gituSessionService.js';

describe('GituSessionService', () => {
  const testUserId = 'test-user-gitu-' + Date.now();
  const testPlatform = 'telegram';
  let createdSessionIds: string[] = [];

  // Create test user before all tests
  beforeEach(async () => {
    try {
      await pool.query(
        `INSERT INTO users (id, email, display_name, password_hash) 
         VALUES ($1, $2, $3, $4) 
         ON CONFLICT (id) DO NOTHING`,
        [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
      );
    } catch (error) {
      // Ignore if user already exists
    }
  });

  // Clean up after each test
  afterEach(async () => {
    for (const sessionId of createdSessionIds) {
      try {
        await gituSessionService.deleteSession(sessionId);
      } catch (error) {
        // Ignore errors if session already deleted
      }
    }
    createdSessionIds = [];
    
    // Clean up test user
    try {
      await pool.query(`DELETE FROM users WHERE id = $1`, [testUserId]);
    } catch (error) {
      // Ignore errors
    }
  });

  describe('getOrCreateSession', () => {
    it('should create a new session if none exists', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      expect(session).toBeDefined();
      expect(session.userId).toBe(testUserId);
      expect(session.platform).toBe(testPlatform);
      expect(session.status).toBe('active');
      expect(session.context.conversationHistory).toEqual([]);
      expect(session.context.activeNotebooks).toEqual([]);
      expect(session.context.activeIntegrations).toEqual([]);
      expect(session.context.variables).toEqual({});
    });

    it('should return existing active session instead of creating new one', async () => {
      const session1 = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session1.id);

      const session2 = await gituSessionService.getOrCreateSession(testUserId, testPlatform);

      expect(session2.id).toBe(session1.id);
      expect(createdSessionIds.length).toBe(1);
    });

    it('should create separate sessions for different platforms', async () => {
      const telegramSession = await gituSessionService.getOrCreateSession(testUserId, 'telegram');
      createdSessionIds.push(telegramSession.id);

      const whatsappSession = await gituSessionService.getOrCreateSession(testUserId, 'whatsapp');
      createdSessionIds.push(whatsappSession.id);

      expect(telegramSession.id).not.toBe(whatsappSession.id);
      expect(telegramSession.platform).toBe('telegram');
      expect(whatsappSession.platform).toBe('whatsapp');
    });
  });

  describe('getSession', () => {
    it('should retrieve a session by ID', async () => {
      const created = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(created.id);

      const retrieved = await gituSessionService.getSession(created.id);

      expect(retrieved).toBeDefined();
      expect(retrieved!.id).toBe(created.id);
      expect(retrieved!.userId).toBe(testUserId);
    });

    it('should return null for non-existent session', async () => {
      const session = await gituSessionService.getSession('00000000-0000-0000-0000-000000000000');
      expect(session).toBeNull();
    });
  });

  describe('updateSession', () => {
    it('should update session status', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const updated = await gituSessionService.updateSession(session.id, { status: 'paused' });

      expect(updated.status).toBe('paused');
    });

    it('should update session context', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const newContext = {
        ...session.context,
        activeNotebooks: ['notebook-1', 'notebook-2'],
      };

      const updated = await gituSessionService.updateSession(session.id, { context: newContext });

      expect(updated.context.activeNotebooks).toEqual(['notebook-1', 'notebook-2']);
    });

    it('should throw error for non-existent session', async () => {
      await expect(
        gituSessionService.updateSession('00000000-0000-0000-0000-000000000000', { status: 'paused' })
      ).rejects.toThrow('Session 00000000-0000-0000-0000-000000000000 not found');
    });
  });

  describe('addMessage', () => {
    it('should add a message to conversation history', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addMessage(session.id, {
        role: 'user',
        content: 'Hello Gitu',
        platform: 'telegram',
      });

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.conversationHistory).toHaveLength(1);
      expect(updated!.context.conversationHistory[0].role).toBe('user');
      expect(updated!.context.conversationHistory[0].content).toBe('Hello Gitu');
      expect(updated!.context.conversationHistory[0].timestamp).toBeInstanceOf(Date);
    });

    it('should maintain message order', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addMessage(session.id, {
        role: 'user',
        content: 'First message',
        platform: 'telegram',
      });

      await gituSessionService.addMessage(session.id, {
        role: 'assistant',
        content: 'Second message',
        platform: 'telegram',
      });

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.conversationHistory).toHaveLength(2);
      expect(updated!.context.conversationHistory[0].content).toBe('First message');
      expect(updated!.context.conversationHistory[1].content).toBe('Second message');
    });
  });

  describe('notebook management', () => {
    it('should add notebook to active notebooks', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addNotebook(session.id, 'notebook-1');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeNotebooks).toContain('notebook-1');
    });

    it('should not add duplicate notebooks', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addNotebook(session.id, 'notebook-1');
      await gituSessionService.addNotebook(session.id, 'notebook-1');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeNotebooks).toHaveLength(1);
    });

    it('should remove notebook from active notebooks', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addNotebook(session.id, 'notebook-1');
      await gituSessionService.addNotebook(session.id, 'notebook-2');
      await gituSessionService.removeNotebook(session.id, 'notebook-1');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeNotebooks).not.toContain('notebook-1');
      expect(updated!.context.activeNotebooks).toContain('notebook-2');
    });
  });

  describe('integration management', () => {
    it('should add integration to active integrations', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addIntegration(session.id, 'gmail');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeIntegrations).toContain('gmail');
    });

    it('should not add duplicate integrations', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addIntegration(session.id, 'gmail');
      await gituSessionService.addIntegration(session.id, 'gmail');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeIntegrations).toHaveLength(1);
    });

    it('should remove integration from active integrations', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.addIntegration(session.id, 'gmail');
      await gituSessionService.addIntegration(session.id, 'shopify');
      await gituSessionService.removeIntegration(session.id, 'gmail');

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.activeIntegrations).not.toContain('gmail');
      expect(updated!.context.activeIntegrations).toContain('shopify');
    });
  });

  describe('variable management', () => {
    it('should set and get session variables', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.setVariable(session.id, 'userPreference', 'dark-mode');
      const value = await gituSessionService.getVariable(session.id, 'userPreference');

      expect(value).toBe('dark-mode');
    });

    it('should handle complex variable types', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const complexValue = { nested: { data: [1, 2, 3] } };
      await gituSessionService.setVariable(session.id, 'complexVar', complexValue);
      const value = await gituSessionService.getVariable(session.id, 'complexVar');

      expect(value).toEqual(complexValue);
    });

    it('should return undefined for non-existent variable', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const value = await gituSessionService.getVariable(session.id, 'nonExistent');
      expect(value).toBeUndefined();
    });
  });

  describe('task management', () => {
    it('should set current task', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const task: Task = {
        id: 'task-1',
        description: 'Summarize emails',
        status: 'in_progress',
        startedAt: new Date(),
      };

      await gituSessionService.setCurrentTask(session.id, task);

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.currentTask).toBeDefined();
      expect(updated!.context.currentTask!.id).toBe('task-1');
      expect(updated!.context.currentTask!.status).toBe('in_progress');
    });

    it('should clear current task', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      const task: Task = {
        id: 'task-1',
        description: 'Summarize emails',
        status: 'completed',
        startedAt: new Date(),
        completedAt: new Date(),
      };

      await gituSessionService.setCurrentTask(session.id, task);
      await gituSessionService.clearCurrentTask(session.id);

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.context.currentTask).toBeUndefined();
    });
  });

  describe('session lifecycle', () => {
    it('should pause and resume session', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.pauseSession(session.id);
      let updated = await gituSessionService.getSession(session.id);
      expect(updated!.status).toBe('paused');

      await gituSessionService.resumeSession(session.id);
      updated = await gituSessionService.getSession(session.id);
      expect(updated!.status).toBe('active');
    });

    it('should end session with timestamp', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.endSession(session.id);

      const updated = await gituSessionService.getSession(session.id);
      expect(updated!.status).toBe('ended');
      expect(updated!.endedAt).toBeInstanceOf(Date);
    });

    it('should delete session completely', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      const sessionId = session.id;

      await gituSessionService.deleteSession(sessionId);

      const retrieved = await gituSessionService.getSession(sessionId);
      expect(retrieved).toBeNull();
    });
  });

  describe('listUserSessions', () => {
    it('should list all active sessions for a user', async () => {
      const session1 = await gituSessionService.getOrCreateSession(testUserId, 'telegram');
      createdSessionIds.push(session1.id);

      const session2 = await gituSessionService.getOrCreateSession(testUserId, 'whatsapp');
      createdSessionIds.push(session2.id);

      const sessions = await gituSessionService.listUserSessions(testUserId);

      expect(sessions.length).toBeGreaterThanOrEqual(2);
      expect(sessions.some(s => s.id === session1.id)).toBe(true);
      expect(sessions.some(s => s.id === session2.id)).toBe(true);
    });

    it('should exclude ended sessions by default', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.endSession(session.id);

      const sessions = await gituSessionService.listUserSessions(testUserId, false);
      expect(sessions.some(s => s.id === session.id)).toBe(false);
    });

    it('should include ended sessions when requested', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.endSession(session.id);

      const sessions = await gituSessionService.listUserSessions(testUserId, true);
      expect(sessions.some(s => s.id === session.id)).toBe(true);
    });
  });

  describe('getSessionStats', () => {
    it('should calculate session statistics', async () => {
      const session1 = await gituSessionService.getOrCreateSession(testUserId, 'telegram');
      createdSessionIds.push(session1.id);

      await gituSessionService.addMessage(session1.id, {
        role: 'user',
        content: 'Test message',
        platform: 'telegram',
      });

      const session2 = await gituSessionService.getOrCreateSession(testUserId, 'whatsapp');
      createdSessionIds.push(session2.id);

      await gituSessionService.pauseSession(session2.id);

      const stats = await gituSessionService.getSessionStats(testUserId);

      expect(stats.totalSessions).toBeGreaterThanOrEqual(2);
      expect(stats.activeSessions).toBeGreaterThanOrEqual(1);
      expect(stats.pausedSessions).toBeGreaterThanOrEqual(1);
      expect(stats.messageCount).toBeGreaterThanOrEqual(1);
    });
  });

  describe('cleanupOldSessions', () => {
    it('should not delete recent ended sessions', async () => {
      const session = await gituSessionService.getOrCreateSession(testUserId, testPlatform);
      createdSessionIds.push(session.id);

      await gituSessionService.endSession(session.id);

      const deletedCount = await gituSessionService.cleanupOldSessions(30);

      const retrieved = await gituSessionService.getSession(session.id);
      expect(retrieved).not.toBeNull();
    });
  });
});
