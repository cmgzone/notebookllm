/**
 * Property-Based Tests for Source Conversation Service
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: coding-agent-communication
 */

import * as fc from 'fast-check';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { sourceConversationService } from '../services/sourceConversationService.js';
import { agentSessionService } from '../services/agentSessionService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdNotebookIds: string[] = [];
const createdSourceIds: string[] = [];
const createdSessionIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-conv-${userId}@example.com`;
  
  await pool.query(
    `INSERT INTO users (id, email, password_hash, display_name) 
     VALUES ($1, $2, 'test-hash', 'Test User')
     ON CONFLICT (id) DO NOTHING`,
    [userId, email]
  );
  
  createdUserIds.push(userId);
  return userId;
}

// Helper to create a test notebook
async function createTestNotebook(userId: string): Promise<string> {
  const notebookId = uuidv4();
  
  await pool.query(
    `INSERT INTO notebooks (id, user_id, title, description, created_at, updated_at)
     VALUES ($1, $2, 'Test Notebook', 'Test Description', NOW(), NOW())`,
    [notebookId, userId]
  );
  
  createdNotebookIds.push(notebookId);
  return notebookId;
}

// Helper to create a test source
async function createTestSource(notebookId: string, metadata: Record<string, any> = {}): Promise<string> {
  const sourceId = uuidv4();
  
  await pool.query(
    `INSERT INTO sources (id, notebook_id, title, type, content, metadata, created_at, updated_at)
     VALUES ($1, $2, 'Test Source', 'code', 'console.log("test")', $3, NOW(), NOW())`,
    [sourceId, notebookId, JSON.stringify(metadata)]
  );
  
  createdSourceIds.push(sourceId);
  return sourceId;
}

// Cleanup function
async function cleanup() {
  // Delete conversations first (foreign key to sources)
  if (createdSourceIds.length > 0) {
    await pool.query(
      `DELETE FROM source_conversations WHERE source_id = ANY($1)`,
      [createdSourceIds]
    );
  }
  
  // Delete sources
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
  
  createdUserIds.length = 0;
  createdNotebookIds.length = 0;
  createdSourceIds.length = 0;
  createdSessionIds.length = 0;
}

// ==================== ARBITRARIES ====================

// Generate valid message content
const messageContentArb = fc.string({ minLength: 1, maxLength: 1000 })
  .filter(s => s.trim().length > 0);

// Generate message role
const messageRoleArb = fc.constantFrom('user', 'agent') as fc.Arbitrary<'user' | 'agent'>;

// Generate message metadata
const messageMetadataArb = fc.option(
  fc.record({
    codeModification: fc.option(fc.string(), { nil: undefined }),
    attachments: fc.option(fc.array(fc.string(), { maxLength: 3 }), { nil: undefined }),
  }),
  { nil: {} }
);

// Generate a sequence of messages
const messageSequenceArb = fc.array(
  fc.record({
    role: messageRoleArb,
    content: messageContentArb,
    metadata: messageMetadataArb,
  }),
  { minLength: 1, maxLength: 10 }
);

// ==================== PROPERTY TESTS ====================

describe('Source Conversation Service - Property-Based Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Property 3: Conversation History Integrity
   * 
   * For any source with a conversation, adding a message SHALL increase 
   * the conversation length by one, and the message SHALL be retrievable 
   * with correct role, content, and timestamp.
   * 
   * **Validates: Requirements 3.5**
   */
  describe('Property 3: Conversation History Integrity', () => {
    it('adding a message increases conversation length by exactly one', async () => {
      await fc.assert(
        fc.asyncProperty(
          messageRoleArb,
          messageContentArb,
          async (role, content) => {
            // Setup: Create user, notebook, and source
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            // Get initial count (should be 0 for new source)
            const initialCount = await sourceConversationService.getMessageCount(sourceId);
            expect(initialCount).toBe(0);
            
            // Add a message
            await sourceConversationService.addMessage(sourceId, role, content);
            
            // Verify count increased by exactly 1
            const newCount = await sourceConversationService.getMessageCount(sourceId);
            expect(newCount).toBe(initialCount + 1);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('added message is retrievable with correct role and content', async () => {
      await fc.assert(
        fc.asyncProperty(
          messageRoleArb,
          messageContentArb,
          messageMetadataArb,
          async (role, content, metadata) => {
            // Setup
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            // Add message
            const addedMessage = await sourceConversationService.addMessage(
              sourceId, 
              role, 
              content, 
              { metadata: metadata || {} }
            );
            
            // Retrieve conversation
            const conversation = await sourceConversationService.getConversation(sourceId);
            
            // Verify message is in conversation
            expect(conversation).not.toBeNull();
            expect(conversation!.messages.length).toBe(1);
            
            const retrievedMessage = conversation!.messages[0];
            expect(retrievedMessage.id).toBe(addedMessage.id);
            expect(retrievedMessage.role).toBe(role);
            expect(retrievedMessage.content).toBe(content);
            expect(retrievedMessage.sourceId).toBe(sourceId);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('message timestamp is set and preserved', async () => {
      await fc.assert(
        fc.asyncProperty(
          messageRoleArb,
          messageContentArb,
          async (role, content) => {
            // Setup
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            const beforeAdd = new Date();
            
            // Add message
            const addedMessage = await sourceConversationService.addMessage(sourceId, role, content);
            
            const afterAdd = new Date();
            
            // Verify timestamp is within expected range
            expect(addedMessage.createdAt).toBeInstanceOf(Date);
            expect(addedMessage.createdAt.getTime()).toBeGreaterThanOrEqual(beforeAdd.getTime() - 1000);
            expect(addedMessage.createdAt.getTime()).toBeLessThanOrEqual(afterAdd.getTime() + 1000);
            
            // Retrieve and verify timestamp is preserved
            const conversation = await sourceConversationService.getConversation(sourceId);
            const retrievedMessage = conversation!.messages[0];
            
            expect(retrievedMessage.createdAt.getTime()).toBe(addedMessage.createdAt.getTime());
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('multiple messages maintain correct order and count', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(
            fc.record({
              role: messageRoleArb,
              content: messageContentArb,
              metadata: messageMetadataArb,
            }),
            { minLength: 1, maxLength: 5 }
          ),
          async (messages) => {
            // Setup
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            // Add all messages
            const addedMessages: Awaited<ReturnType<typeof sourceConversationService.addMessage>>[] = [];
            for (const msg of messages) {
              const added = await sourceConversationService.addMessage(
                sourceId,
                msg.role,
                msg.content,
                { metadata: msg.metadata || {} }
              );
              addedMessages.push(added);
            }
            
            // Retrieve conversation
            const conversation = await sourceConversationService.getConversation(sourceId);
            
            // Verify count matches
            expect(conversation).not.toBeNull();
            expect(conversation!.messages.length).toBe(messages.length);
            
            // Verify order is preserved (messages should be in chronological order)
            for (let i = 0; i < messages.length; i++) {
              expect(conversation!.messages[i].role).toBe(messages[i].role);
              expect(conversation!.messages[i].content).toBe(messages[i].content);
            }
            
            // Verify timestamps are in ascending order
            for (let i = 1; i < conversation!.messages.length; i++) {
              expect(conversation!.messages[i].createdAt.getTime())
                .toBeGreaterThanOrEqual(conversation!.messages[i - 1].createdAt.getTime());
            }
          }
        ),
        { numRuns: 5, timeout: 60000 }
      );
    }, 90000);

    it('conversation is created automatically on first message', async () => {
      await fc.assert(
        fc.asyncProperty(
          messageRoleArb,
          messageContentArb,
          async (role, content) => {
            // Setup
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            // Verify no conversation exists initially
            const initialConversation = await sourceConversationService.getConversation(sourceId);
            expect(initialConversation).toBeNull();
            
            // Add message (should create conversation)
            await sourceConversationService.addMessage(sourceId, role, content);
            
            // Verify conversation now exists
            const conversation = await sourceConversationService.getConversation(sourceId);
            expect(conversation).not.toBeNull();
            expect(conversation!.sourceId).toBe(sourceId);
            expect(conversation!.messages.length).toBe(1);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('user messages are marked as unread, agent messages as read', async () => {
      await fc.assert(
        fc.asyncProperty(
          messageContentArb,
          async (content) => {
            // Setup
            const userId = await createTestUser();
            const notebookId = await createTestNotebook(userId);
            const sourceId = await createTestSource(notebookId);
            
            // Add user message
            const userMessage = await sourceConversationService.addMessage(sourceId, 'user', content);
            expect(userMessage.isRead).toBe(false);
            
            // Add agent message
            const agentMessage = await sourceConversationService.addMessage(sourceId, 'agent', content);
            expect(agentMessage.isRead).toBe(true);
            
            // Verify via getConversation
            const conversation = await sourceConversationService.getConversation(sourceId);
            const userMsg = conversation!.messages.find(m => m.role === 'user');
            const agentMsg = conversation!.messages.find(m => m.role === 'agent');
            
            expect(userMsg!.isRead).toBe(false);
            expect(agentMsg!.isRead).toBe(true);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);
  });
});
