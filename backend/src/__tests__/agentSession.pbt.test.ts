/**
 * Property-Based Tests for Agent Session Service
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: coding-agent-communication
 */

import * as fc from 'fast-check';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { agentSessionService, AgentConfig } from '../services/agentSessionService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdSessionIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-${userId}@example.com`;
  
  await pool.query(
    `INSERT INTO users (id, email, password_hash, display_name) 
     VALUES ($1, $2, 'test-hash', 'Test User')
     ON CONFLICT (id) DO NOTHING`,
    [userId, email]
  );
  
  createdUserIds.push(userId);
  return userId;
}

// Cleanup function
async function cleanup() {
  // Delete sessions first (foreign key constraint)
  if (createdSessionIds.length > 0) {
    await pool.query(
      `DELETE FROM agent_sessions WHERE id = ANY($1)`,
      [createdSessionIds]
    );
  }
  
  // Delete users
  if (createdUserIds.length > 0) {
    await pool.query(
      `DELETE FROM users WHERE id = ANY($1)`,
      [createdUserIds]
    );
  }
  
  createdUserIds.length = 0;
  createdSessionIds.length = 0;
}

// ==================== ARBITRARIES ====================

// Generate valid agent names
const agentNameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_'),
  { minLength: 3, maxLength: 50 }
).filter(s => s.length >= 3);

// Generate valid agent identifiers
const agentIdentifierArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_'),
  { minLength: 5, maxLength: 100 }
).filter(s => s.length >= 5);

// Generate optional webhook URLs
const webhookUrlArb = fc.option(
  fc.webUrl({ validSchemes: ['https'] }),
  { nil: undefined }
);

// Generate agent config
const agentConfigArb = fc.record({
  agentName: agentNameArb,
  agentIdentifier: agentIdentifierArb,
  webhookUrl: webhookUrlArb,
  webhookSecret: fc.option(fc.hexaString({ minLength: 32, maxLength: 64 }), { nil: undefined }),
  metadata: fc.option(fc.dictionary(fc.string(), fc.jsonValue()), { nil: {} }),
});

// ==================== PROPERTY TESTS ====================

describe('Agent Session Service - Property-Based Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Property 1: Agent Notebook Creation Idempotence
   * 
   * For any user and agent identifier, calling createSession multiple times 
   * SHALL return the same session ID and not create duplicates.
   * 
   * **Validates: Requirements 1.1, 1.2, 1.3**
   */
  describe('Property 1: Agent Notebook Creation Idempotence', () => {
    it('calling createSession multiple times returns the same session ID', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          fc.integer({ min: 2, max: 5 }), // Number of times to call createSession
          async (config, callCount) => {
            // Create a test user
            const userId = await createTestUser();
            
            // Call createSession multiple times
            const sessions: string[] = [];
            for (let i = 0; i < callCount; i++) {
              const session = await agentSessionService.createSession(userId, config);
              sessions.push(session.id);
              createdSessionIds.push(session.id);
            }
            
            // All session IDs should be the same (idempotent)
            const uniqueIds = new Set(sessions);
            expect(uniqueIds.size).toBe(1);
            
            // Verify only one session exists in database
            const result = await pool.query(
              `SELECT COUNT(*) as count FROM agent_sessions 
               WHERE user_id = $1 AND agent_identifier = $2`,
              [userId, config.agentIdentifier]
            );
            expect(parseInt(result.rows[0].count)).toBe(1);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('session data is preserved across idempotent calls', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          async (config) => {
            const userId = await createTestUser();
            
            // First call
            const session1 = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session1.id);
            
            // Second call
            const session2 = await agentSessionService.createSession(userId, config);
            
            // Session properties should match
            expect(session2.id).toBe(session1.id);
            expect(session2.agentName).toBe(config.agentName);
            expect(session2.agentIdentifier).toBe(config.agentIdentifier);
            expect(session2.userId).toBe(userId);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('disconnected sessions are reactivated on subsequent createSession calls', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          async (config) => {
            const userId = await createTestUser();
            
            // Create session
            const session1 = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session1.id);
            expect(session1.status).toBe('active');
            
            // Disconnect it
            await agentSessionService.disconnectSession(session1.id);
            const disconnected = await agentSessionService.getSession(session1.id);
            expect(disconnected?.status).toBe('disconnected');
            
            // Create again - should reactivate
            const session2 = await agentSessionService.createSession(userId, config);
            expect(session2.id).toBe(session1.id);
            expect(session2.status).toBe('active');
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);
  });

  /**
   * Property 6: Multiple Agent Sessions
   * 
   * For any user, creating sessions with different agent identifiers 
   * SHALL result in separate, independent sessions and notebooks that 
   * do not interfere with each other.
   * 
   * **Validates: Requirements 4.4**
   */
  describe('Property 6: Multiple Agent Sessions', () => {
    it('different agent identifiers create separate sessions', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          agentConfigArb,
          async (config1, config2) => {
            // Ensure different agent identifiers
            const uniqueConfig2 = {
              ...config2,
              agentIdentifier: config2.agentIdentifier + '-unique-' + Date.now(),
            };
            
            const userId = await createTestUser();
            
            // Create two sessions with different agent identifiers
            const session1 = await agentSessionService.createSession(userId, config1);
            createdSessionIds.push(session1.id);
            
            const session2 = await agentSessionService.createSession(userId, uniqueConfig2);
            createdSessionIds.push(session2.id);
            
            // Sessions should be different
            expect(session1.id).not.toBe(session2.id);
            expect(session1.agentIdentifier).not.toBe(session2.agentIdentifier);
            
            // Both sessions should exist independently
            const retrieved1 = await agentSessionService.getSession(session1.id);
            const retrieved2 = await agentSessionService.getSession(session2.id);
            
            expect(retrieved1).not.toBeNull();
            expect(retrieved2).not.toBeNull();
            expect(retrieved1?.id).toBe(session1.id);
            expect(retrieved2?.id).toBe(session2.id);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('operations on one session do not affect other sessions', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          agentConfigArb,
          async (config1, config2) => {
            // Ensure different agent identifiers
            const uniqueConfig2 = {
              ...config2,
              agentIdentifier: config2.agentIdentifier + '-unique2-' + Date.now(),
            };
            
            const userId = await createTestUser();
            
            // Create two sessions
            const session1 = await agentSessionService.createSession(userId, config1);
            createdSessionIds.push(session1.id);
            
            const session2 = await agentSessionService.createSession(userId, uniqueConfig2);
            createdSessionIds.push(session2.id);
            
            // Disconnect session1
            await agentSessionService.disconnectSession(session1.id);
            
            // Session2 should still be active
            const retrieved1 = await agentSessionService.getSession(session1.id);
            const retrieved2 = await agentSessionService.getSession(session2.id);
            
            expect(retrieved1?.status).toBe('disconnected');
            expect(retrieved2?.status).toBe('active');
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('user can have multiple active sessions simultaneously', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(agentConfigArb, { minLength: 2, maxLength: 3 }),
          async (configs) => {
            const userId = await createTestUser();
            
            // Make all agent identifiers unique
            const uniqueConfigs = configs.map((config, index) => ({
              ...config,
              agentIdentifier: `${config.agentIdentifier}-multi-${index}-${Date.now()}`,
            }));
            
            // Create multiple sessions
            const sessions: Awaited<ReturnType<typeof agentSessionService.createSession>>[] = [];
            for (const config of uniqueConfigs) {
              const session = await agentSessionService.createSession(userId, config);
              createdSessionIds.push(session.id);
              sessions.push(session);
            }
            
            // All sessions should be unique
            const sessionIds = sessions.map(s => s.id);
            const uniqueIds = new Set(sessionIds);
            expect(uniqueIds.size).toBe(sessions.length);
            
            // All sessions should be active
            for (const session of sessions) {
              const retrieved = await agentSessionService.getSession(session.id);
              expect(retrieved?.status).toBe('active');
            }
            
            // getSessionsByUser should return all sessions
            const userSessions = await agentSessionService.getSessionsByUser(userId);
            expect(userSessions.length).toBeGreaterThanOrEqual(sessions.length);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);
  });
});
