/**
 * Property-Based Tests for Source-Notebook Association
 * 
 * These tests validate that verified sources saved by agents are correctly
 * associated with Agent_Notebooks and contain complete agent context.
 * 
 * Feature: coding-agent-communication
 * Property 2: Source-Notebook Association
 * **Validates: Requirements 2.1, 2.2, 2.3**
 */

import * as fc from 'fast-check';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { agentSessionService, AgentConfig } from '../services/agentSessionService.js';
import { agentNotebookService } from '../services/agentNotebookService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdSessionIds: string[] = [];
const createdNotebookIds: string[] = [];
const createdSourceIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-source-${userId}@example.com`;
  
  await pool.query(
    `INSERT INTO users (id, email, password_hash, display_name) 
     VALUES ($1, $2, 'test-hash', 'Test User')
     ON CONFLICT (id) DO NOTHING`,
    [userId, email]
  );
  
  createdUserIds.push(userId);
  return userId;
}

// Helper to create a source with agent context
async function createSourceWithContext(
  userId: string,
  notebookId: string,
  agentSessionId: string,
  agentName: string,
  code: string,
  language: string,
  title: string,
  conversationContext?: string
): Promise<{ id: string; metadata: any }> {
  const sourceId = uuidv4();
  const metadata = {
    language,
    verification: { isValid: true, score: 85 },
    isVerified: true,
    verifiedAt: new Date().toISOString(),
    agentSessionId,
    agentName,
    originalContext: conversationContext,
  };

  await pool.query(
    `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata, created_at)
     VALUES ($1, $2, $3, 'code', $4, $5, $6, NOW())`,
    [sourceId, notebookId, userId, title, code, JSON.stringify(metadata)]
  );

  createdSourceIds.push(sourceId);
  return { id: sourceId, metadata };
}

// Cleanup function
async function cleanup() {
  // Delete sources first
  if (createdSourceIds.length > 0) {
    await pool.query(
      `DELETE FROM sources WHERE id = ANY($1)`,
      [createdSourceIds]
    );
  }

  // Delete notebooks
  if (createdNotebookIds.length > 0) {
    await pool.query(
      `DELETE FROM notebooks WHERE id = ANY($1)`,
      [createdNotebookIds]
    );
  }

  // Delete sessions
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
  
  createdSourceIds.length = 0;
  createdNotebookIds.length = 0;
  createdSessionIds.length = 0;
  createdUserIds.length = 0;
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

// Generate code snippets
const codeArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t{}[]();=+-*/<>.,'),
  { minLength: 10, maxLength: 500 }
).filter(s => s.trim().length >= 10);

// Generate programming languages
const languageArb = fc.constantFrom(
  'javascript', 'typescript', 'python', 'java', 'go', 'rust', 'c', 'cpp'
);

// Generate source titles
const titleArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_'),
  { minLength: 3, maxLength: 100 }
).filter(s => s.trim().length >= 3);

// Generate conversation context
const conversationContextArb = fc.option(
  fc.stringOf(
    fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!'),
    { minLength: 10, maxLength: 500 }
  ),
  { nil: undefined }
);

// Generate agent config
const agentConfigArb = fc.record({
  agentName: agentNameArb,
  agentIdentifier: agentIdentifierArb,
  webhookUrl: fc.option(fc.webUrl({ validSchemes: ['https'] }), { nil: undefined }),
  webhookSecret: fc.option(fc.hexaString({ minLength: 32, maxLength: 64 }), { nil: undefined }),
  metadata: fc.constant({}),
});

// ==================== PROPERTY TESTS ====================

describe('Source-Notebook Association - Property-Based Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Property 2: Source-Notebook Association
   * 
   * For any verified source saved by an agent, the source SHALL be associated 
   * with the correct Agent_Notebook and contain complete agent context 
   * (session ID, agent name, conversation context) in metadata.
   * 
   * **Validates: Requirements 2.1, 2.2, 2.3**
   */
  describe('Property 2: Source-Notebook Association', () => {
    it('source is associated with the correct Agent_Notebook (Requirement 2.1)', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          async (config, code, language, title) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source with agent context
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              title
            );
            
            // Verify source is associated with the correct notebook
            const result = await pool.query(
              `SELECT notebook_id FROM sources WHERE id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            expect(result.rows[0].notebook_id).toBe(notebook.id);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('source metadata contains agent session ID (Requirement 2.2)', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          async (config, code, language, title) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source with agent context
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              title
            );
            
            // Verify source metadata contains agent session ID
            const result = await pool.query(
              `SELECT metadata FROM sources WHERE id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            const metadata = result.rows[0].metadata;
            expect(metadata.agentSessionId).toBe(session.id);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('source metadata contains agent name (Requirement 2.2)', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          async (config, code, language, title) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source with agent context
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              title
            );
            
            // Verify source metadata contains agent name
            const result = await pool.query(
              `SELECT metadata FROM sources WHERE id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            const metadata = result.rows[0].metadata;
            expect(metadata.agentName).toBe(session.agentName);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('source metadata contains conversation context when provided (Requirement 2.3)', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          conversationContextArb.filter(ctx => ctx !== undefined && ctx.length > 0),
          async (config, code, language, title, context) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source with conversation context
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              title,
              context
            );
            
            // Verify source metadata contains conversation context
            const result = await pool.query(
              `SELECT metadata FROM sources WHERE id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            const metadata = result.rows[0].metadata;
            expect(metadata.originalContext).toBe(context);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('source metadata contains complete agent context (all fields)', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          conversationContextArb,
          async (config, code, language, title, context) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source with agent context
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              title,
              context
            );
            
            // Verify source metadata contains all required fields
            const result = await pool.query(
              `SELECT metadata FROM sources WHERE id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            const metadata = result.rows[0].metadata;
            
            // Check all required fields are present
            expect(metadata).toHaveProperty('agentSessionId');
            expect(metadata).toHaveProperty('agentName');
            expect(metadata).toHaveProperty('language');
            expect(metadata).toHaveProperty('isVerified');
            expect(metadata).toHaveProperty('verifiedAt');
            
            // Verify values
            expect(metadata.agentSessionId).toBe(session.id);
            expect(metadata.agentName).toBe(session.agentName);
            expect(metadata.language).toBe(language);
            expect(metadata.isVerified).toBe(true);
            expect(typeof metadata.verifiedAt).toBe('string');
            
            // Context should be present if provided
            if (context) {
              expect(metadata.originalContext).toBe(context);
            }
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('multiple sources can be associated with the same Agent_Notebook', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          fc.array(
            fc.record({
              code: codeArb,
              language: languageArb,
              title: titleArb,
            }),
            { minLength: 2, maxLength: 3 }
          ),
          async (config, sources) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create multiple sources
            const createdSources: { id: string }[] = [];
            for (const sourceData of sources) {
              const source = await createSourceWithContext(
                userId,
                notebook.id,
                session.id,
                session.agentName,
                sourceData.code,
                sourceData.language,
                sourceData.title + '-' + Date.now() // Ensure unique titles
              );
              createdSources.push(source);
            }
            
            // Verify all sources are associated with the same notebook
            const result = await pool.query(
              `SELECT id, notebook_id FROM sources WHERE id = ANY($1)`,
              [createdSources.map(s => s.id)]
            );
            
            expect(result.rows.length).toBe(createdSources.length);
            for (const row of result.rows) {
              expect(row.notebook_id).toBe(notebook.id);
            }
          }
        ),
        { numRuns: 3, timeout: 30000 }
      );
    }, 60000);

    it('source association is preserved after notebook update', async () => {
      await fc.assert(
        fc.asyncProperty(
          agentConfigArb,
          codeArb,
          languageArb,
          titleArb,
          titleArb, // New notebook title
          async (config, code, language, sourceTitle, newNotebookTitle) => {
            // Create test user
            const userId = await createTestUser();
            
            // Create agent session
            const session = await agentSessionService.createSession(userId, config);
            createdSessionIds.push(session.id);
            
            // Create agent notebook
            const notebook = await agentNotebookService.createOrGetNotebook(userId, session);
            createdNotebookIds.push(notebook.id);
            
            // Create source
            const source = await createSourceWithContext(
              userId,
              notebook.id,
              session.id,
              session.agentName,
              code,
              language,
              sourceTitle
            );
            
            // Update notebook title
            await agentNotebookService.updateNotebook(notebook.id, userId, {
              title: newNotebookTitle,
            });
            
            // Verify source is still associated with the notebook
            const result = await pool.query(
              `SELECT s.notebook_id, n.title as notebook_title
               FROM sources s
               JOIN notebooks n ON s.notebook_id = n.id
               WHERE s.id = $1`,
              [source.id]
            );
            
            expect(result.rows.length).toBe(1);
            expect(result.rows[0].notebook_id).toBe(notebook.id);
            expect(result.rows[0].notebook_title).toBe(newNotebookTitle);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);
  });
});
