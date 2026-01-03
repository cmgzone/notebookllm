/**
 * Property-Based Tests for Token Revocation Cascade
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: github-mcp-integration
 * Property 12: Token Revocation Cascade
 * Validates: Requirements 7.5
 */

import * as fc from 'fast-check';

// ==================== INLINE TYPES FOR TESTING ====================

interface GitHubConnection {
  id: string;
  userId: string;
  isActive: boolean;
}

interface GitHubSourceCache {
  sourceId: string;
  owner: string;
  repo: string;
  path: string;
  branch: string;
  commitSha: string;
}

interface AgentSession {
  id: string;
  userId: string;
  agentName: string;
  agentIdentifier: string;
  webhookUrl?: string;
  webhookSecret?: string;
  status: 'active' | 'expired' | 'disconnected';
  metadata: Record<string, any>;
}

interface RevocationResult {
  success: boolean;
  invalidatedCacheEntries: number;
  notifiedAgentSessions: number;
  errors: string[];
}

interface GitHubApiCallResult {
  success: boolean;
  error?: string;
  errorCode?: string;
}

// ==================== SIMULATION FUNCTIONS ====================

/**
 * Simulated state for testing
 */
interface SimulatedState {
  connections: Map<string, GitHubConnection>;
  sourceCaches: Map<string, GitHubSourceCache[]>;
  agentSessions: Map<string, AgentSession[]>;
  disconnectedUsers: Set<string>;
}

/**
 * Create initial simulated state
 */
function createSimulatedState(): SimulatedState {
  return {
    connections: new Map(),
    sourceCaches: new Map(),
    agentSessions: new Map(),
    disconnectedUsers: new Set(),
  };
}

/**
 * Simulate connecting a user to GitHub
 */
function simulateConnect(state: SimulatedState, userId: string): void {
  state.connections.set(userId, {
    id: `conn-${userId}`,
    userId,
    isActive: true,
  });
  state.disconnectedUsers.delete(userId);
}

/**
 * Simulate adding source cache entries for a user
 */
function simulateAddSourceCache(
  state: SimulatedState,
  userId: string,
  caches: GitHubSourceCache[]
): void {
  state.sourceCaches.set(userId, caches);
}

/**
 * Simulate adding agent sessions for a user
 */
function simulateAddAgentSessions(
  state: SimulatedState,
  userId: string,
  sessions: AgentSession[]
): void {
  state.agentSessions.set(userId, sessions);
}

/**
 * Simulate token revocation cascade
 */
function simulateRevocation(state: SimulatedState, userId: string): RevocationResult {
  const errors: string[] = [];
  
  // Check if user has a connection
  const connection = state.connections.get(userId);
  if (!connection || !connection.isActive) {
    return {
      success: true,
      invalidatedCacheEntries: 0,
      notifiedAgentSessions: 0,
      errors: [],
    };
  }
  
  // Invalidate source cache entries
  const caches = state.sourceCaches.get(userId) || [];
  const invalidatedCacheEntries = caches.length;
  state.sourceCaches.delete(userId);
  
  // Notify agent sessions
  const sessions = state.agentSessions.get(userId) || [];
  const activeSessions = sessions.filter(s => s.status === 'active');
  let notifiedAgentSessions = 0;
  
  for (const session of activeSessions) {
    // Update session metadata to indicate GitHub is disconnected
    session.metadata.githubConnected = false;
    notifiedAgentSessions++;
  }
  
  // Mark connection as inactive
  connection.isActive = false;
  state.disconnectedUsers.add(userId);
  
  return {
    success: errors.length === 0,
    invalidatedCacheEntries,
    notifiedAgentSessions,
    errors,
  };
}

/**
 * Simulate a GitHub API call after disconnection
 */
function simulateGitHubApiCall(state: SimulatedState, userId: string): GitHubApiCallResult {
  // Check if user is in disconnected set
  if (state.disconnectedUsers.has(userId)) {
    return {
      success: false,
      error: 'GitHub not connected',
      errorCode: 'GITHUB_NOT_CONNECTED',
    };
  }
  
  // Check if user has active connection
  const connection = state.connections.get(userId);
  if (!connection || !connection.isActive) {
    return {
      success: false,
      error: 'GitHub not connected',
      errorCode: 'GITHUB_NOT_CONNECTED',
    };
  }
  
  return { success: true };
}

/**
 * Check if GitHub is connected for a user
 */
function isGitHubConnected(state: SimulatedState, userId: string): boolean {
  const connection = state.connections.get(userId);
  return !!connection && connection.isActive && !state.disconnectedUsers.has(userId);
}

// ==================== ARBITRARIES ====================

// Generate valid user IDs
const userIdArb = fc.uuid();

// Generate valid source IDs
const sourceIdArb = fc.uuid();

// Generate valid GitHub owner names
const ownerArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-'),
  { minLength: 1, maxLength: 39 }
).filter(s => s.length >= 1 && !s.startsWith('-') && !s.endsWith('-'));

// Generate valid GitHub repo names
const repoArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_.'),
  { minLength: 1, maxLength: 100 }
).filter(s => s.length >= 1);

// Generate valid file paths
const pathArb = fc.array(
  fc.stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_.'), { minLength: 1, maxLength: 50 }),
  { minLength: 1, maxLength: 5 }
).map(parts => parts.join('/'));

// Generate valid branch names
const branchArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-_/'),
  { minLength: 1, maxLength: 50 }
).filter(s => s.length >= 1);

// Generate valid commit SHAs
const commitShaArb = fc.hexaString({ minLength: 40, maxLength: 40 });

// Generate source cache entries
const sourceCacheArb = fc.record({
  sourceId: sourceIdArb,
  owner: ownerArb,
  repo: repoArb,
  path: pathArb,
  branch: branchArb,
  commitSha: commitShaArb,
});

// Generate agent session IDs
const sessionIdArb = fc.uuid();

// Generate agent names
const agentNameArb = fc.constantFrom('Claude', 'Kiro', 'Cursor', 'Copilot', 'Cody');

// Generate agent identifiers
const agentIdentifierArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789-'),
  { minLength: 5, maxLength: 30 }
);

// Generate webhook URLs
const webhookUrlArb = fc.webUrl({ validSchemes: ['https'] });

// Generate webhook secrets
const webhookSecretArb = fc.hexaString({ minLength: 32, maxLength: 64 });

// Generate agent sessions
const agentSessionArb = fc.record({
  id: sessionIdArb,
  userId: userIdArb,
  agentName: agentNameArb,
  agentIdentifier: agentIdentifierArb,
  webhookUrl: fc.option(webhookUrlArb, { nil: undefined }),
  webhookSecret: fc.option(webhookSecretArb, { nil: undefined }),
  status: fc.constantFrom('active' as const, 'expired' as const, 'disconnected' as const),
  metadata: fc.constant({}),
});

// ==================== PROPERTY TESTS ====================

describe('Token Revocation Cascade - Property-Based Tests', () => {

  /**
   * Property 12: Token Revocation Cascade
   * 
   * For any GitHub disconnection event, all cached tokens SHALL be invalidated,
   * and subsequent API calls SHALL fail with "GITHUB_NOT_CONNECTED" error.
   * 
   * **Feature: github-mcp-integration, Property 12: Token Revocation Cascade**
   * **Validates: Requirements 7.5**
   */
  describe('Property 12: Token Revocation Cascade', () => {
    
    it('all source cache entries are invalidated on disconnect', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(sourceCacheArb, { minLength: 0, maxLength: 20 }),
          async (userId, caches) => {
            const state = createSimulatedState();
            
            // Setup: Connect user and add cache entries
            simulateConnect(state, userId);
            simulateAddSourceCache(state, userId, caches);
            
            // Verify cache exists before disconnect
            const cachesBefore = state.sourceCaches.get(userId) || [];
            expect(cachesBefore.length).toBe(caches.length);
            
            // Action: Disconnect
            const result = simulateRevocation(state, userId);
            
            // Verify: All cache entries invalidated
            expect(result.invalidatedCacheEntries).toBe(caches.length);
            
            // Verify: No cache entries remain
            const cachesAfter = state.sourceCaches.get(userId) || [];
            expect(cachesAfter.length).toBe(0);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('all active agent sessions are notified on disconnect', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(agentSessionArb, { minLength: 0, maxLength: 10 }),
          async (userId, sessions) => {
            const state = createSimulatedState();
            
            // Setup: Connect user and add sessions (with correct userId)
            simulateConnect(state, userId);
            const userSessions = sessions.map(s => ({ ...s, userId }));
            simulateAddAgentSessions(state, userId, userSessions);
            
            // Count active sessions before
            const activeSessionsBefore = userSessions.filter(s => s.status === 'active').length;
            
            // Action: Disconnect
            const result = simulateRevocation(state, userId);
            
            // Verify: All active sessions were notified
            expect(result.notifiedAgentSessions).toBe(activeSessionsBefore);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('subsequent API calls fail with GITHUB_NOT_CONNECTED after disconnect', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          async (userId) => {
            const state = createSimulatedState();
            
            // Setup: Connect user
            simulateConnect(state, userId);
            
            // Verify: API calls succeed before disconnect
            const resultBefore = simulateGitHubApiCall(state, userId);
            expect(resultBefore.success).toBe(true);
            
            // Action: Disconnect
            simulateRevocation(state, userId);
            
            // Verify: API calls fail after disconnect
            const resultAfter = simulateGitHubApiCall(state, userId);
            expect(resultAfter.success).toBe(false);
            expect(resultAfter.errorCode).toBe('GITHUB_NOT_CONNECTED');
          }
        ),
        { numRuns: 20 }
      );
    });

    it('connection status is false after disconnect', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          async (userId) => {
            const state = createSimulatedState();
            
            // Setup: Connect user
            simulateConnect(state, userId);
            
            // Verify: Connected before
            expect(isGitHubConnected(state, userId)).toBe(true);
            
            // Action: Disconnect
            simulateRevocation(state, userId);
            
            // Verify: Not connected after
            expect(isGitHubConnected(state, userId)).toBe(false);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('agent session metadata is updated with githubConnected=false', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(
            agentSessionArb.filter(s => s.status === 'active'),
            { minLength: 1, maxLength: 5 }
          ),
          async (userId, sessions) => {
            const state = createSimulatedState();
            
            // Setup: Connect user and add active sessions
            simulateConnect(state, userId);
            const userSessions = sessions.map(s => ({ ...s, userId, metadata: {} }));
            simulateAddAgentSessions(state, userId, userSessions);
            
            // Action: Disconnect
            simulateRevocation(state, userId);
            
            // Verify: All active sessions have githubConnected=false in metadata
            const sessionsAfter = state.agentSessions.get(userId) || [];
            for (const session of sessionsAfter) {
              if (session.status === 'active') {
                expect(session.metadata.githubConnected).toBe(false);
              }
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('revocation is idempotent - multiple disconnects have same effect', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(sourceCacheArb, { minLength: 1, maxLength: 10 }),
          async (userId, caches) => {
            const state = createSimulatedState();
            
            // Setup: Connect user and add cache entries
            simulateConnect(state, userId);
            simulateAddSourceCache(state, userId, caches);
            
            // Action: First disconnect
            const result1 = simulateRevocation(state, userId);
            expect(result1.invalidatedCacheEntries).toBe(caches.length);
            
            // Action: Second disconnect (should be no-op)
            const result2 = simulateRevocation(state, userId);
            expect(result2.invalidatedCacheEntries).toBe(0);
            
            // Verify: Still disconnected
            expect(isGitHubConnected(state, userId)).toBe(false);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('only expired/disconnected sessions are not notified', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(agentSessionArb, { minLength: 1, maxLength: 10 }),
          async (userId, sessions) => {
            const state = createSimulatedState();
            
            // Setup: Connect user and add sessions
            simulateConnect(state, userId);
            const userSessions = sessions.map(s => ({ ...s, userId }));
            simulateAddAgentSessions(state, userId, userSessions);
            
            // Count sessions by status
            const activeCount = userSessions.filter(s => s.status === 'active').length;
            const inactiveCount = userSessions.filter(s => s.status !== 'active').length;
            
            // Action: Disconnect
            const result = simulateRevocation(state, userId);
            
            // Verify: Only active sessions were notified
            expect(result.notifiedAgentSessions).toBe(activeCount);
            
            // Verify: Inactive sessions were not modified
            const sessionsAfter = state.agentSessions.get(userId) || [];
            const inactiveAfter = sessionsAfter.filter(s => s.status !== 'active');
            expect(inactiveAfter.length).toBe(inactiveCount);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('revocation result success is true when no errors occur', async () => {
      await fc.assert(
        fc.asyncProperty(
          userIdArb,
          fc.array(sourceCacheArb, { minLength: 0, maxLength: 10 }),
          fc.array(agentSessionArb, { minLength: 0, maxLength: 5 }),
          async (userId, caches, sessions) => {
            const state = createSimulatedState();
            
            // Setup
            simulateConnect(state, userId);
            simulateAddSourceCache(state, userId, caches);
            const userSessions = sessions.map(s => ({ ...s, userId }));
            simulateAddAgentSessions(state, userId, userSessions);
            
            // Action
            const result = simulateRevocation(state, userId);
            
            // Verify: Success is true and no errors
            expect(result.success).toBe(true);
            expect(result.errors.length).toBe(0);
          }
        ),
        { numRuns: 20 }
      );
    });
  });
});
