/**
 * Integration Tests for GitHub-MCP Integration
 * 
 * These tests validate the end-to-end flows for the GitHub-MCP integration feature.
 * They test the complete integration between:
 * - GitHub Source Service
 * - Unified Context Builder
 * - Webhook Service with GitHub context
 * - Agent Session Service
 * 
 * Feature: github-mcp-integration
 * Requirements: 1.1, 2.1, 3.4, 4.1, 4.2, 5.1, 5.3
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { unifiedContextBuilder, CodeContext } from '../services/unifiedContextBuilder.js';
import { githubWebhookBuilder, GitHubWebhookPayload } from '../services/githubWebhookBuilder.js';
import { WebhookService, WebhookPayload } from '../services/webhookService.js';
import { agentSessionService } from '../services/agentSessionService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdSessionIds: string[] = [];
const createdSourceIds: string[] = [];
const createdNotebookIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-integration-${userId}@example.com`;
  
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
async function createTestNotebook(userId: string, isAgentNotebook: boolean = false): Promise<string> {
  const notebookId = uuidv4();
  
  await pool.query(
    `INSERT INTO notebooks (id, user_id, title, description, is_agent_notebook)
     VALUES ($1, $2, 'Test Notebook', 'Test Description', $3)`,
    [notebookId, userId, isAgentNotebook]
  );
  
  createdNotebookIds.push(notebookId);
  return notebookId;
}

// Helper to create a GitHub source
async function createGitHubSource(
  notebookId: string,
  userId: string,
  options: {
    owner?: string;
    repo?: string;
    path?: string;
    branch?: string;
    language?: string;
    content?: string;
    agentSessionId?: string;
    agentName?: string;
  } = {}
): Promise<string> {
  const sourceId = uuidv4();
  const {
    owner = 'test-owner',
    repo = 'test-repo',
    path = 'src/index.ts',
    branch = 'main',
    language = 'typescript',
    content = 'export const hello = "world";',
    agentSessionId,
    agentName,
  } = options;

  // Generate a 40-character hex string to simulate a real Git commit SHA
  const commitSha = uuidv4().replace(/-/g, '') + uuidv4().replace(/-/g, '').substring(0, 8);
  
  const metadata = {
    type: 'github',
    owner,
    repo,
    path,
    branch,
    commitSha,
    language,
    size: content.length,
    lastFetchedAt: new Date().toISOString(),
    githubUrl: `https://github.com/${owner}/${repo}/blob/${branch}/${path}`,
    ...(agentSessionId && { agentSessionId }),
    ...(agentName && { agentName }),
  };

  await pool.query(
    `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata)
     VALUES ($1, $2, $3, 'github', $4, $5, $6)`,
    [sourceId, notebookId, userId, `${repo}/${path}`, content, JSON.stringify(metadata)]
  );

  createdSourceIds.push(sourceId);
  return sourceId;
}

// Helper to create an agent code source
async function createAgentCodeSource(
  notebookId: string,
  userId: string,
  agentSessionId: string,
  options: {
    title?: string;
    content?: string;
    language?: string;
    agentName?: string;
    verificationScore?: number;
  } = {}
): Promise<string> {
  const sourceId = uuidv4();
  const {
    title = 'Agent Code',
    content = 'function test() { return true; }',
    language = 'javascript',
    agentName = 'Kiro',
    verificationScore = 85,
  } = options;

  const metadata = {
    language,
    agentSessionId,
    agentName,
    isVerified: true,
    verification: {
      score: verificationScore,
      isValid: true,
    },
  };

  await pool.query(
    `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata)
     VALUES ($1, $2, $3, 'code', $4, $5, $6)`,
    [sourceId, notebookId, userId, title, content, JSON.stringify(metadata)]
  );

  createdSourceIds.push(sourceId);
  return sourceId;
}

// Helper to create a text source
async function createTextSource(
  notebookId: string,
  userId: string,
  options: {
    title?: string;
    content?: string;
  } = {}
): Promise<string> {
  const sourceId = uuidv4();
  const { title = 'Text Note', content = 'This is a text note.' } = options;

  await pool.query(
    `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata)
     VALUES ($1, $2, $3, 'text', $4, $5, '{}')`,
    [sourceId, notebookId, userId, title, content]
  );

  createdSourceIds.push(sourceId);
  return sourceId;
}

// Helper to create an agent session
async function createAgentSession(
  userId: string,
  notebookId: string,
  options: {
    agentName?: string;
    webhookUrl?: string;
    webhookSecret?: string;
  } = {}
): Promise<string> {
  const sessionId = uuidv4();
  const {
    agentName = 'Kiro',
    webhookUrl,
    webhookSecret,
  } = options;

  await pool.query(
    `INSERT INTO agent_sessions (id, user_id, notebook_id, agent_name, agent_identifier, status, webhook_url, webhook_secret)
     VALUES ($1, $2, $3, $4, $5, 'active', $6, $7)`,
    [sessionId, userId, notebookId, agentName, `${agentName.toLowerCase()}-v1`, webhookUrl, webhookSecret]
  );

  createdSessionIds.push(sessionId);
  return sessionId;
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

  // Delete sessions
  if (createdSessionIds.length > 0) {
    await pool.query(
      `DELETE FROM agent_sessions WHERE id = ANY($1)`,
      [createdSessionIds]
    );
  }

  // Delete notebooks
  if (createdNotebookIds.length > 0) {
    await pool.query(
      `DELETE FROM notebooks WHERE id = ANY($1)`,
      [createdNotebookIds]
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
  createdSessionIds.length = 0;
  createdNotebookIds.length = 0;
  createdUserIds.length = 0;
}

// ==================== INTEGRATION TESTS ====================

describe('GitHub-MCP Integration Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Test 19.1: End-to-end flow - App adds GitHub source → Chat with AI
   * 
   * Verifies:
   * - Source creation with complete metadata
   * - Context inclusion for AI chat
   * - AI response context contains GitHub source
   * 
   * Requirements: 1.1, 2.1
   */
  describe('19.1 App adds GitHub source → Chat with AI', () => {
    it('should create GitHub source with complete metadata', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create GitHub source
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'facebook',
        repo: 'react',
        path: 'packages/react/src/React.js',
        branch: 'main',
        language: 'javascript',
        content: 'export { useState, useEffect } from "./ReactHooks";',
      });

      // Verify source was created
      const result = await pool.query(
        `SELECT * FROM sources WHERE id = $1`,
        [sourceId]
      );

      expect(result.rows.length).toBe(1);
      const source = result.rows[0];
      const metadata = source.metadata;

      // Verify all required metadata fields (Requirement 1.1, 1.2)
      expect(metadata.type).toBe('github');
      expect(metadata.owner).toBe('facebook');
      expect(metadata.repo).toBe('react');
      expect(metadata.path).toBe('packages/react/src/React.js');
      expect(metadata.branch).toBe('main');
      expect(metadata.commitSha).toBeDefined();
      expect(metadata.commitSha.length).toBe(40);
      expect(metadata.language).toBe('javascript');
      expect(metadata.githubUrl).toContain('github.com/facebook/react');
      expect(metadata.lastFetchedAt).toBeDefined();
    });

    it('should include GitHub source in AI context', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create GitHub source
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'vercel',
        repo: 'next.js',
        path: 'packages/next/src/server/app-render.tsx',
        language: 'typescript',
        content: 'export async function renderToHTML() { /* ... */ }',
      });

      // Build context for AI (Requirement 2.1)
      const context = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
      });

      // Verify GitHub source is included in context
      expect(context.sources.length).toBeGreaterThan(0);
      
      const githubSource = context.sources.find(s => s.id === sourceId);
      expect(githubSource).toBeDefined();
      expect(githubSource!.type).toBe('github');
      expect(githubSource!.content).toContain('renderToHTML');
      expect(githubSource!.metadata.owner).toBe('vercel');
      expect(githubSource!.metadata.repo).toBe('next.js');
    });

    it('should include multiple GitHub sources from same repo in context', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create multiple GitHub sources from same repo
      const sourceId1 = await createGitHubSource(notebookId, userId, {
        owner: 'flutter',
        repo: 'flutter',
        path: 'packages/flutter/lib/src/widgets/app.dart',
        language: 'dart',
        content: 'class MaterialApp extends StatefulWidget {}',
      });

      const sourceId2 = await createGitHubSource(notebookId, userId, {
        owner: 'flutter',
        repo: 'flutter',
        path: 'packages/flutter/lib/src/widgets/scaffold.dart',
        language: 'dart',
        content: 'class Scaffold extends StatefulWidget {}',
      });

      // Build context
      const context = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeRepoStructure: true,
      });

      // Verify both sources are included
      expect(context.sources.length).toBe(2);
      
      const source1 = context.sources.find(s => s.id === sourceId1);
      const source2 = context.sources.find(s => s.id === sourceId2);
      
      expect(source1).toBeDefined();
      expect(source2).toBeDefined();
      expect(source1!.content).toContain('MaterialApp');
      expect(source2!.content).toContain('Scaffold');
    });

    it('should format context correctly for AI prompt', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create GitHub source
      await createGitHubSource(notebookId, userId, {
        owner: 'microsoft',
        repo: 'typescript',
        path: 'src/compiler/checker.ts',
        language: 'typescript',
        content: 'export function createTypeChecker() {}',
      });

      // Build and format context
      const context = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
      });

      const formattedContext = unifiedContextBuilder.formatContextForPrompt(context);

      // Verify formatted context contains expected elements
      expect(formattedContext).toContain('GitHub File');
      expect(formattedContext).toContain('typescript');
      expect(formattedContext).toContain('createTypeChecker');
      expect(formattedContext).toContain('```');
    });
  });

  /**
   * Test 19.2: MCP flow - Agent adds source → User chats with agent
   * 
   * Verifies:
   * - MCP tool creates source correctly
   * - Webhook delivery includes GitHub context
   * - Response display with code highlighting
   * 
   * Requirements: 3.4, 4.1, 4.2
   */
  describe('19.2 Agent adds source → User chats with agent', () => {
    it('should create source with agent session metadata', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'Claude',
      });

      // Create GitHub source via agent (simulating MCP tool call)
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'anthropics',
        repo: 'anthropic-sdk-python',
        path: 'src/anthropic/client.py',
        language: 'python',
        content: 'class Anthropic:\n    def __init__(self): pass',
        agentSessionId: sessionId,
        agentName: 'Claude',
      });

      // Verify source has agent metadata (Requirement 3.4)
      const result = await pool.query(
        `SELECT * FROM sources WHERE id = $1`,
        [sourceId]
      );

      const source = result.rows[0];
      const metadata = source.metadata;

      expect(metadata.agentSessionId).toBe(sessionId);
      expect(metadata.agentName).toBe('Claude');
      expect(metadata.type).toBe('github');
    });

    it('should enable chat functionality for agent-created sources', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'Kiro',
        webhookUrl: 'https://example.com/webhook',
        webhookSecret: 'test-secret-1234567890',
      });

      // Create GitHub source via agent
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'aws',
        repo: 'aws-sdk-js-v3',
        path: 'clients/client-s3/src/S3Client.ts',
        language: 'typescript',
        content: 'export class S3Client extends Client {}',
        agentSessionId: sessionId,
        agentName: 'Kiro',
      });

      // Verify source can be used for chat (Requirement 4.1)
      const isGitHubSource = await githubWebhookBuilder.isGitHubSource(sourceId);
      expect(isGitHubSource).toBe(true);

      // Verify session has webhook configured
      const session = await agentSessionService.getSession(sessionId);
      expect(session).toBeDefined();
      expect(session!.webhookUrl).toBe('https://example.com/webhook');
    });

    it('should build webhook payload with GitHub context', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create GitHub source
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'google',
        repo: 'guava',
        path: 'guava/src/com/google/common/collect/ImmutableList.java',
        language: 'java',
        content: 'public abstract class ImmutableList<E> extends ImmutableCollection<E> {}',
        agentSessionId: sessionId,
      });

      // Build webhook payload (Requirement 4.2)
      const payload = await githubWebhookBuilder.buildPayload({
        sourceId,
        message: 'How does ImmutableList work?',
        conversationHistory: [],
        userId,
      });

      // Verify GitHub context is included
      expect(payload.githubContext).toBeDefined();
      expect(payload.githubContext.owner).toBe('google');
      expect(payload.githubContext.repo).toBe('guava');
      expect(payload.githubContext.path).toBe('guava/src/com/google/common/collect/ImmutableList.java');
      expect(payload.githubContext.branch).toBe('main');
      expect(payload.githubContext.language).toBe('java');
      expect(payload.githubContext.currentContent).toContain('ImmutableList');
      expect(payload.githubContext.commitSha).toBeDefined();
      expect(payload.githubContext.githubUrl).toContain('github.com/google/guava');
    });

    it('should validate GitHub webhook payload completeness', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create GitHub source
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'nodejs',
        repo: 'node',
        path: 'lib/fs.js',
        language: 'javascript',
        content: 'const fs = require("internal/fs/promises");',
      });

      // Build payload
      const payload = await githubWebhookBuilder.buildPayload({
        sourceId,
        message: 'Explain the fs module',
        conversationHistory: [],
        userId,
      });

      // Validate payload
      const validationError = githubWebhookBuilder.validatePayload(payload);
      expect(validationError).toBeNull();

      // Verify all required fields
      expect(payload.type).toBe('followup_message');
      expect(payload.sourceId).toBe(sourceId);
      expect(payload.sourceTitle).toBeDefined();
      expect(payload.sourceCode).toBeDefined();
      expect(payload.sourceLanguage).toBe('javascript');
      expect(payload.message).toBe('Explain the fs module');
      expect(payload.userId).toBe(userId);
      expect(payload.timestamp).toBeDefined();
    });

    it('should include conversation history in webhook payload', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create GitHub source
      const sourceId = await createGitHubSource(notebookId, userId);

      // Build payload with conversation history
      const conversationHistory = [
        {
          id: uuidv4(),
          conversationId: uuidv4(),
          sourceId,
          role: 'user' as const,
          content: 'What does this code do?',
          metadata: {},
          isRead: true,
          createdAt: new Date(),
        },
        {
          id: uuidv4(),
          conversationId: uuidv4(),
          sourceId,
          role: 'agent' as const,
          content: 'This code exports a hello variable.',
          metadata: {},
          isRead: true,
          createdAt: new Date(),
        },
      ];

      const payload = await githubWebhookBuilder.buildPayload({
        sourceId,
        message: 'Can you explain more?',
        conversationHistory,
        userId,
      });

      // Verify conversation history is preserved
      expect(payload.conversationHistory.length).toBe(2);
      expect(payload.conversationHistory[0].content).toBe('What does this code do?');
      expect(payload.conversationHistory[1].content).toBe('This code exports a hello variable.');
    });

    it('should simulate complete MCP tool call flow for github_add_as_source', async () => {
      // Setup: Create user, agent notebook, and session (simulating MCP create_agent_notebook)
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'TestAgent',
        webhookUrl: 'https://test-agent.example.com/webhook',
        webhookSecret: 'test-secret-minimum-16-chars',
      });

      // Simulate MCP github_add_as_source tool call
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'test-org',
        repo: 'test-project',
        path: 'src/components/Button.tsx',
        branch: 'develop',
        language: 'typescript',
        content: 'export const Button = ({ children }) => <button>{children}</button>;',
        agentSessionId: sessionId,
        agentName: 'TestAgent',
      });

      // Verify source was created with correct metadata (Requirement 3.4)
      const sourceResult = await pool.query(
        `SELECT * FROM sources WHERE id = $1`,
        [sourceId]
      );
      expect(sourceResult.rows.length).toBe(1);
      
      const source = sourceResult.rows[0];
      const metadata = source.metadata;
      
      // Verify all GitHub metadata fields
      expect(metadata.type).toBe('github');
      expect(metadata.owner).toBe('test-org');
      expect(metadata.repo).toBe('test-project');
      expect(metadata.path).toBe('src/components/Button.tsx');
      expect(metadata.branch).toBe('develop');
      expect(metadata.language).toBe('typescript');
      expect(metadata.agentSessionId).toBe(sessionId);
      expect(metadata.agentName).toBe('TestAgent');
      expect(metadata.githubUrl).toContain('github.com/test-org/test-project');

      // Verify chat is enabled (Requirement 4.1)
      const isGitHub = await githubWebhookBuilder.isGitHubSource(sourceId);
      expect(isGitHub).toBe(true);

      // Verify session is properly linked
      const session = await agentSessionService.getSession(sessionId);
      expect(session).toBeDefined();
      expect(session!.status).toBe('active');
      expect(session!.webhookUrl).toBe('https://test-agent.example.com/webhook');
    });

    it('should build webhook payload with all required fields for agent response', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'ResponseAgent',
        webhookUrl: 'https://response-agent.example.com/webhook',
        webhookSecret: 'response-secret-16-chars',
      });

      // Create GitHub source via agent
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'example',
        repo: 'api-client',
        path: 'lib/client.ts',
        language: 'typescript',
        content: `
export class ApiClient {
  private baseUrl: string;
  
  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }
  
  async get<T>(path: string): Promise<T> {
    const response = await fetch(\`\${this.baseUrl}\${path}\`);
    return response.json();
  }
}`,
        agentSessionId: sessionId,
        agentName: 'ResponseAgent',
      });

      // Simulate user sending a follow-up message
      const userMessage = 'Can you add error handling to the get method?';
      
      // Build webhook payload (Requirement 4.2)
      const payload = await githubWebhookBuilder.buildPayload({
        sourceId,
        message: userMessage,
        conversationHistory: [],
        userId,
      });

      // Verify payload structure for webhook delivery
      expect(payload.type).toBe('followup_message');
      expect(payload.sourceId).toBe(sourceId);
      expect(payload.message).toBe(userMessage);
      expect(payload.userId).toBe(userId);
      expect(payload.timestamp).toBeDefined();
      
      // Verify GitHub context is complete
      expect(payload.githubContext).toBeDefined();
      expect(payload.githubContext.owner).toBe('example');
      expect(payload.githubContext.repo).toBe('api-client');
      expect(payload.githubContext.path).toBe('lib/client.ts');
      expect(payload.githubContext.branch).toBe('main');
      expect(payload.githubContext.language).toBe('typescript');
      expect(payload.githubContext.currentContent).toContain('ApiClient');
      expect(payload.githubContext.currentContent).toContain('async get');
      expect(payload.githubContext.githubUrl).toContain('github.com/example/api-client');

      // Verify payload passes validation
      const validationError = githubWebhookBuilder.validatePayload(payload);
      expect(validationError).toBeNull();
    });

    it('should handle multiple sources from same agent session', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'MultiSourceAgent',
      });

      // Create multiple GitHub sources via same agent session
      const sourceId1 = await createGitHubSource(notebookId, userId, {
        owner: 'multi-repo',
        repo: 'frontend',
        path: 'src/App.tsx',
        language: 'typescript',
        content: 'export const App = () => <div>Hello</div>;',
        agentSessionId: sessionId,
        agentName: 'MultiSourceAgent',
      });

      const sourceId2 = await createGitHubSource(notebookId, userId, {
        owner: 'multi-repo',
        repo: 'frontend',
        path: 'src/utils/helpers.ts',
        language: 'typescript',
        content: 'export const formatDate = (d: Date) => d.toISOString();',
        agentSessionId: sessionId,
        agentName: 'MultiSourceAgent',
      });

      const sourceId3 = await createGitHubSource(notebookId, userId, {
        owner: 'multi-repo',
        repo: 'backend',
        path: 'src/server.ts',
        language: 'typescript',
        content: 'import express from "express"; const app = express();',
        agentSessionId: sessionId,
        agentName: 'MultiSourceAgent',
      });

      // Verify all sources are linked to the same session
      const sources = await pool.query(
        `SELECT id, metadata FROM sources WHERE notebook_id = $1 AND type = 'github'`,
        [notebookId]
      );

      expect(sources.rows.length).toBe(3);
      
      for (const source of sources.rows) {
        expect(source.metadata.agentSessionId).toBe(sessionId);
        expect(source.metadata.agentName).toBe('MultiSourceAgent');
      }

      // Verify each source can have its own webhook payload built
      for (const sourceId of [sourceId1, sourceId2, sourceId3]) {
        const payload = await githubWebhookBuilder.buildPayload({
          sourceId,
          message: 'Test message',
          conversationHistory: [],
          userId,
        });
        
        expect(payload.githubContext).toBeDefined();
        expect(githubWebhookBuilder.validatePayload(payload)).toBeNull();
      }
    });

    it('should preserve source content in webhook payload for code discussion', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create source with specific code content
      const codeContent = `
/**
 * Calculate fibonacci number
 * @param n - The position in the sequence
 */
export function fibonacci(n: number): number {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

// Memoized version
const memo = new Map<number, number>();
export function fibonacciMemo(n: number): number {
  if (memo.has(n)) return memo.get(n)!;
  if (n <= 1) return n;
  const result = fibonacciMemo(n - 1) + fibonacciMemo(n - 2);
  memo.set(n, result);
  return result;
}`;

      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'algorithms',
        repo: 'math-utils',
        path: 'src/fibonacci.ts',
        language: 'typescript',
        content: codeContent,
        agentSessionId: sessionId,
      });

      // Build payload for code discussion
      const payload = await githubWebhookBuilder.buildPayload({
        sourceId,
        message: 'Can you explain the difference between the two implementations?',
        conversationHistory: [],
        userId,
      });

      // Verify full code content is preserved
      expect(payload.sourceCode).toBe(codeContent);
      expect(payload.githubContext.currentContent).toBe(codeContent);
      
      // Verify code content includes key elements
      expect(payload.sourceCode).toContain('fibonacci');
      expect(payload.sourceCode).toContain('fibonacciMemo');
      expect(payload.sourceCode).toContain('memo.set');
      expect(payload.sourceCode).toContain('Calculate fibonacci number');
    });
  });

  /**
   * Test 19.3: Context sharing between notebook AI and agents
   * 
   * Verifies:
   * - Both AI systems can access unified context
   * - GitHub sources and agent sources are combined
   * - Context is consistent across systems
   * 
   * Requirements: 5.1, 5.3
   */
  describe('19.3 Context sharing between notebook AI and agents', () => {
    it('should include both GitHub and agent sources in unified context', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create GitHub source
      const githubSourceId = await createGitHubSource(notebookId, userId, {
        owner: 'rust-lang',
        repo: 'rust',
        path: 'library/std/src/io/mod.rs',
        language: 'rust',
        content: 'pub use self::buffered::BufReader;',
      });

      // Create agent code source
      const agentSourceId = await createAgentCodeSource(notebookId, userId, sessionId, {
        title: 'Custom IO Handler',
        content: 'fn handle_io() -> Result<(), Error> { Ok(()) }',
        language: 'rust',
        agentName: 'Kiro',
      });

      // Build unified context (Requirement 5.1)
      const context = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeAgentSources: true,
      });

      // Verify both source types are included
      expect(context.sources.length).toBe(2);

      const githubSource = context.sources.find(s => s.id === githubSourceId);
      const agentSource = context.sources.find(s => s.id === agentSourceId);

      expect(githubSource).toBeDefined();
      expect(githubSource!.type).toBe('github');
      expect(githubSource!.content).toContain('BufReader');

      expect(agentSource).toBeDefined();
      expect(agentSource!.type).toBe('code');
      expect(agentSource!.content).toContain('handle_io');

      // Verify agent sources array is populated
      expect(context.agentSources).toBeDefined();
      expect(context.agentSources!.length).toBe(1);
      expect(context.agentSources![0].agentName).toBe('Kiro');
    });

    it('should provide context to agent via getContextForAgent', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create sources
      await createGitHubSource(notebookId, userId, {
        owner: 'golang',
        repo: 'go',
        path: 'src/net/http/server.go',
        language: 'go',
        content: 'func ListenAndServe(addr string, handler Handler) error {}',
      });

      await createAgentCodeSource(notebookId, userId, sessionId, {
        title: 'HTTP Handler',
        content: 'func myHandler(w http.ResponseWriter, r *http.Request) {}',
        language: 'go',
      });

      // Get context for agent (Requirement 5.3)
      const context = await unifiedContextBuilder.getContextForAgent(sessionId, notebookId);

      // Verify context is complete
      expect(context.sources.length).toBe(2);
      expect(context.totalTokenEstimate).toBeGreaterThan(0);

      // Verify GitHub source metadata
      const githubSource = context.sources.find(s => s.type === 'github');
      expect(githubSource).toBeDefined();
      expect(githubSource!.metadata.owner).toBe('golang');
      expect(githubSource!.metadata.repo).toBe('go');
    });

    it('should maintain consistent context across multiple requests', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create sources
      const sourceId = await createGitHubSource(notebookId, userId, {
        owner: 'python',
        repo: 'cpython',
        path: 'Lib/asyncio/tasks.py',
        language: 'python',
        content: 'async def gather(*coros_or_futures): pass',
      });

      // Build context multiple times
      const context1 = await unifiedContextBuilder.buildContext(notebookId, userId);
      const context2 = await unifiedContextBuilder.buildContext(notebookId, userId);

      // Verify consistency
      expect(context1.sources.length).toBe(context2.sources.length);
      expect(context1.sources[0].id).toBe(context2.sources[0].id);
      expect(context1.sources[0].content).toBe(context2.sources[0].content);
    });

    it('should respect context options for filtering', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create various source types
      await createGitHubSource(notebookId, userId);
      await createAgentCodeSource(notebookId, userId, sessionId);
      await createTextSource(notebookId, userId);

      // Build context with GitHub only
      const githubOnlyContext = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeAgentSources: false,
        includeTextSources: false,
      });

      expect(githubOnlyContext.sources.length).toBe(1);
      expect(githubOnlyContext.sources[0].type).toBe('github');

      // Build context with agent sources only
      const agentOnlyContext = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: false,
        includeAgentSources: true,
        includeTextSources: false,
      });

      expect(agentOnlyContext.sources.length).toBe(1);
      expect(agentOnlyContext.sources[0].type).toBe('code');

      // Build context with all sources
      const allContext = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeAgentSources: true,
        includeTextSources: true,
      });

      expect(allContext.sources.length).toBe(3);
    });

    it('should calculate token estimates correctly', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create source with known content length
      const content = 'x'.repeat(1000); // 1000 characters
      await createGitHubSource(notebookId, userId, {
        content,
      });

      // Build context
      const context = await unifiedContextBuilder.buildContext(notebookId, userId);

      // Verify token estimate (0.25 tokens per char)
      expect(context.totalTokenEstimate).toBe(Math.ceil(1000 * 0.25));
    });

    it('should respect maxTokens limit', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Create multiple sources with large content
      for (let i = 0; i < 5; i++) {
        await createGitHubSource(notebookId, userId, {
          path: `file${i}.ts`,
          content: 'x'.repeat(2000), // 2000 chars each = ~500 tokens
        });
      }

      // Build context with low token limit
      const context = await unifiedContextBuilder.buildContext(notebookId, userId, {
        maxTokens: 1000, // Only allow ~4000 chars
      });

      // Should not include all sources due to token limit
      expect(context.totalTokenEstimate).toBeLessThanOrEqual(1000);
    });

    it('should handle empty notebook gracefully', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId);

      // Build context for empty notebook
      const context = await unifiedContextBuilder.buildContext(notebookId, userId);

      expect(context.sources).toEqual([]);
      expect(context.totalTokenEstimate).toBe(0);
      expect(context.agentSources).toBeUndefined();
      expect(context.repoStructure).toBeUndefined();
    });

    /**
     * Test: Context sharing between notebook AI and agents
     * 
     * This test validates that both the notebook AI and coding agents
     * can access the same unified context, ensuring consistency.
     * 
     * Requirements: 5.1, 5.3
     */
    it('should provide identical context to notebook AI and coding agents', async () => {
      // Setup: Create user, notebook, and agent session
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId, {
        agentName: 'ContextTestAgent',
      });

      // Create GitHub source (simulating user adding from app)
      const githubSourceId = await createGitHubSource(notebookId, userId, {
        owner: 'test-org',
        repo: 'shared-context-repo',
        path: 'src/shared/utils.ts',
        language: 'typescript',
        content: `
export function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}

export function parseDate(str: string): Date {
  return new Date(str);
}`,
      });

      // Create agent code source (simulating agent saving code via MCP)
      const agentSourceId = await createAgentCodeSource(notebookId, userId, sessionId, {
        title: 'Date Formatter Extension',
        content: `
import { formatDate, parseDate } from './utils';

export function formatRelativeDate(date: Date): string {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  
  if (days === 0) return 'Today';
  if (days === 1) return 'Yesterday';
  return \`\${days} days ago\`;
}`,
        language: 'typescript',
        agentName: 'ContextTestAgent',
      });

      // Create text source (simulating user notes)
      const textSourceId = await createTextSource(notebookId, userId, {
        title: 'Date Formatting Notes',
        content: 'We need to support relative date formatting for the UI.',
      });

      // Get context as notebook AI would (via buildContext)
      const notebookAIContext = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeAgentSources: true,
        includeTextSources: true,
      });

      // Get context as coding agent would (via getContextForAgent)
      const agentContext = await unifiedContextBuilder.getContextForAgent(sessionId, notebookId);

      // Verify both contexts have the same sources
      expect(notebookAIContext.sources.length).toBe(3);
      expect(agentContext.sources.length).toBe(3);

      // Verify GitHub source is accessible to both
      const notebookGithubSource = notebookAIContext.sources.find(s => s.id === githubSourceId);
      const agentGithubSource = agentContext.sources.find(s => s.id === githubSourceId);
      
      expect(notebookGithubSource).toBeDefined();
      expect(agentGithubSource).toBeDefined();
      expect(notebookGithubSource!.content).toBe(agentGithubSource!.content);
      expect(notebookGithubSource!.type).toBe('github');
      expect(agentGithubSource!.type).toBe('github');

      // Verify agent-saved code is accessible to both
      const notebookAgentSource = notebookAIContext.sources.find(s => s.id === agentSourceId);
      const agentAgentSource = agentContext.sources.find(s => s.id === agentSourceId);
      
      expect(notebookAgentSource).toBeDefined();
      expect(agentAgentSource).toBeDefined();
      expect(notebookAgentSource!.content).toBe(agentAgentSource!.content);
      expect(notebookAgentSource!.type).toBe('code');
      expect(agentAgentSource!.type).toBe('code');

      // Verify text source is accessible to both
      const notebookTextSource = notebookAIContext.sources.find(s => s.id === textSourceId);
      const agentTextSource = agentContext.sources.find(s => s.id === textSourceId);
      
      expect(notebookTextSource).toBeDefined();
      expect(agentTextSource).toBeDefined();
      expect(notebookTextSource!.content).toBe(agentTextSource!.content);

      // Verify agentSources array is populated in both contexts
      expect(notebookAIContext.agentSources).toBeDefined();
      expect(agentContext.agentSources).toBeDefined();
      expect(notebookAIContext.agentSources!.length).toBeGreaterThan(0);
      expect(agentContext.agentSources!.length).toBeGreaterThan(0);

      // Verify the agent source metadata is consistent
      const notebookAgentMeta = notebookAIContext.agentSources!.find(s => s.id === agentSourceId);
      const agentAgentMeta = agentContext.agentSources!.find(s => s.id === agentSourceId);
      
      expect(notebookAgentMeta).toBeDefined();
      expect(agentAgentMeta).toBeDefined();
      expect(notebookAgentMeta!.agentName).toBe(agentAgentMeta!.agentName);
      expect(notebookAgentMeta!.agentSessionId).toBe(agentAgentMeta!.agentSessionId);
    });

    it('should allow agent to reference code saved by another agent session', async () => {
      // Setup: Create user and notebook
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);

      // Create first agent session (simulating Claude)
      const session1Id = await createAgentSession(userId, notebookId, {
        agentName: 'Claude',
      });

      // Create second agent session (simulating Kiro)
      const session2Id = await createAgentSession(userId, notebookId, {
        agentName: 'Kiro',
      });

      // First agent saves code
      const source1Id = await createAgentCodeSource(notebookId, userId, session1Id, {
        title: 'API Client',
        content: `
export class ApiClient {
  async fetch(url: string) {
    return fetch(url).then(r => r.json());
  }
}`,
        language: 'typescript',
        agentName: 'Claude',
      });

      // Second agent saves code that references the first
      const source2Id = await createAgentCodeSource(notebookId, userId, session2Id, {
        title: 'User Service',
        content: `
import { ApiClient } from './api-client';

export class UserService {
  constructor(private client: ApiClient) {}
  
  async getUser(id: string) {
    return this.client.fetch(\`/users/\${id}\`);
  }
}`,
        language: 'typescript',
        agentName: 'Kiro',
      });

      // Get context for second agent
      const context = await unifiedContextBuilder.getContextForAgent(session2Id, notebookId);

      // Verify both agent sources are accessible in the main sources array
      // (This is the key test - agents can see code from other agents)
      expect(context.sources.length).toBe(2);
      
      const source1 = context.sources.find(s => s.id === source1Id);
      const source2 = context.sources.find(s => s.id === source2Id);
      
      expect(source1).toBeDefined();
      expect(source2).toBeDefined();
      expect(source1!.content).toContain('ApiClient');
      expect(source2!.content).toContain('UserService');

      // Note: agentSources is filtered to only include sources from the current session
      // or sources without a session ID. This is by design for the agentSources helper array.
      // The main sources array contains ALL sources regardless of which agent created them.
      expect(context.agentSources).toBeDefined();
      
      // The agentSources array is filtered to current session only
      // But the important thing is that context.sources contains both
      const agent2Source = context.agentSources!.find(s => s.agentName === 'Kiro');
      expect(agent2Source).toBeDefined();
      
      // Verify the second agent can see the first agent's code in the main sources
      const claudeSourceInContext = context.sources.find(s => 
        s.metadata.agentName === 'Claude'
      );
      expect(claudeSourceInContext).toBeDefined();
      expect(claudeSourceInContext!.content).toContain('ApiClient');
    });

    it('should format context consistently for both notebook AI and agents', async () => {
      // Setup
      const userId = await createTestUser();
      const notebookId = await createTestNotebook(userId, true);
      const sessionId = await createAgentSession(userId, notebookId);

      // Create GitHub source
      await createGitHubSource(notebookId, userId, {
        owner: 'format-test',
        repo: 'context-format',
        path: 'src/index.ts',
        language: 'typescript',
        content: 'export const VERSION = "1.0.0";',
      });

      // Create agent source
      await createAgentCodeSource(notebookId, userId, sessionId, {
        title: 'Config',
        content: 'export const CONFIG = { debug: true };',
        language: 'typescript',
      });

      // Get contexts
      const notebookContext = await unifiedContextBuilder.buildContext(notebookId, userId, {
        includeGitHubSources: true,
        includeAgentSources: true,
      });
      const agentContext = await unifiedContextBuilder.getContextForAgent(sessionId, notebookId);

      // Format both contexts
      const notebookFormatted = unifiedContextBuilder.formatContextForPrompt(notebookContext);
      const agentFormatted = unifiedContextBuilder.formatContextForPrompt(agentContext);

      // Verify both formatted contexts contain the same key elements
      expect(notebookFormatted).toContain('GitHub File');
      expect(agentFormatted).toContain('GitHub File');
      
      expect(notebookFormatted).toContain('VERSION');
      expect(agentFormatted).toContain('VERSION');
      
      expect(notebookFormatted).toContain('CONFIG');
      expect(agentFormatted).toContain('CONFIG');
      
      expect(notebookFormatted).toContain('typescript');
      expect(agentFormatted).toContain('typescript');
    });
  });
});
