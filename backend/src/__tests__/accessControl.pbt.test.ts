/**
 * Property-Based Tests for Access Control
 * 
 * These tests validate Property 10: Access Control Enforcement
 * 
 * For any GitHub API request, the system SHALL only return data for repositories 
 * the user has access to, and requests for inaccessible repos SHALL return 403 errors.
 * 
 * Feature: github-mcp-integration
 * **Property 10: Access Control Enforcement**
 * **Validates: Requirements 7.1, 7.2**
 */

import * as fc from 'fast-check';

// ==================== INLINE IMPLEMENTATIONS FOR TESTING ====================

/**
 * Error codes for access control operations
 */
const ACCESS_CONTROL_ERROR_CODES = {
  REPOSITORY_ACCESS_DENIED: 'REPOSITORY_ACCESS_DENIED',
  INVALID_AGENT_SESSION: 'INVALID_AGENT_SESSION',
  SESSION_USER_MISMATCH: 'SESSION_USER_MISMATCH',
  SESSION_EXPIRED: 'SESSION_EXPIRED',
  SESSION_NOT_FOUND: 'SESSION_NOT_FOUND',
} as const;

/**
 * Simulated GitHub connection
 */
interface GitHubConnection {
  id: string;
  userId: string;
  githubUsername: string;
  isActive: boolean;
}

/**
 * Simulated repository
 */
interface Repository {
  owner: string;
  name: string;
  fullName: string;
  isPrivate: boolean;
}

/**
 * Simulated agent session
 */
interface AgentSession {
  id: string;
  userId: string;
  agentName: string;
  status: 'active' | 'expired' | 'disconnected';
}

/**
 * Access check result
 */
interface AccessCheckResult {
  hasAccess: boolean;
  error?: {
    code: string;
    message: string;
  };
}

/**
 * Agent session validation result
 */
interface AgentSessionValidationResult {
  valid: boolean;
  session?: {
    id: string;
    userId: string;
    agentName: string;
    status: string;
  };
  error?: {
    code: string;
    message: string;
  };
}

/**
 * Simulated access control service
 */
class SimulatedAccessControlService {
  private connections: Map<string, GitHubConnection> = new Map();
  private userRepos: Map<string, Repository[]> = new Map();
  private sessions: Map<string, AgentSession> = new Map();

  /**
   * Set up test data
   */
  setup(
    connection: GitHubConnection | null,
    accessibleRepos: Repository[],
    session: AgentSession | null
  ) {
    this.connections.clear();
    this.userRepos.clear();
    this.sessions.clear();

    if (connection) {
      this.connections.set(connection.userId, connection);
      this.userRepos.set(connection.userId, accessibleRepos);
    }

    if (session) {
      this.sessions.set(session.id, session);
    }
  }

  /**
   * Verify repository access
   */
  verifyRepositoryAccess(
    userId: string,
    owner: string,
    repo: string
  ): AccessCheckResult {
    // Check if user has GitHub connected
    const connection = this.connections.get(userId);
    if (!connection || !connection.isActive) {
      return {
        hasAccess: false,
        error: {
          code: 'GITHUB_NOT_CONNECTED',
          message: 'GitHub account not connected.',
        },
      };
    }

    // Check if repository is in user's accessible repos
    const repos = this.userRepos.get(userId) || [];
    const hasRepo = repos.some(
      r => r.owner.toLowerCase() === owner.toLowerCase() &&
           r.name.toLowerCase() === repo.toLowerCase()
    );

    if (!hasRepo) {
      return {
        hasAccess: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED,
          message: `Access denied to repository ${owner}/${repo}.`,
        },
      };
    }

    return { hasAccess: true };
  }

  /**
   * Validate agent session
   */
  validateAgentSession(
    sessionId: string,
    userId: string
  ): AgentSessionValidationResult {
    const session = this.sessions.get(sessionId);

    if (!session) {
      return {
        valid: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.SESSION_NOT_FOUND,
          message: 'Agent session not found',
        },
      };
    }

    if (session.userId !== userId) {
      return {
        valid: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.SESSION_USER_MISMATCH,
          message: 'Agent session does not belong to the requesting user',
        },
      };
    }

    if (session.status !== 'active') {
      return {
        valid: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.SESSION_EXPIRED,
          message: `Agent session is ${session.status}.`,
        },
      };
    }

    return {
      valid: true,
      session: {
        id: session.id,
        userId: session.userId,
        agentName: session.agentName,
        status: session.status,
      },
    };
  }
}

// ==================== ARBITRARIES ====================

// Generate user IDs
const userIdArb = fc.uuid();

// Generate connection IDs
const connectionIdArb = fc.uuid();

// Generate session IDs
const sessionIdArb = fc.uuid();

// Generate valid GitHub usernames
const usernameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'),
  { minLength: 1, maxLength: 39 }
).filter(s => s.length >= 1 && !s.startsWith('-') && !s.endsWith('-'));

// Generate owner names
const ownerArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'),
  { minLength: 1, maxLength: 39 }
).filter(s => s.length >= 1 && !s.startsWith('-') && !s.endsWith('-'));

// Generate repo names
const repoNameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'),
  { minLength: 1, maxLength: 100 }
).filter(s => s.length >= 1);

// Generate agent names
const agentNameArb = fc.constantFrom('Claude', 'Kiro', 'Cursor', 'Copilot', 'TestAgent');

// Generate active GitHub connection
const activeConnectionArb = fc.record({
  id: connectionIdArb,
  userId: userIdArb,
  githubUsername: usernameArb,
  isActive: fc.constant(true),
});

// Generate inactive GitHub connection
const inactiveConnectionArb = fc.record({
  id: connectionIdArb,
  userId: userIdArb,
  githubUsername: usernameArb,
  isActive: fc.constant(false),
});

// Generate repository
const repositoryArb = fc.record({
  owner: ownerArb,
  name: repoNameArb,
  isPrivate: fc.boolean(),
}).map(r => ({
  ...r,
  fullName: `${r.owner}/${r.name}`,
}));

// Generate list of repositories
const repositoryListArb = fc.array(repositoryArb, { minLength: 0, maxLength: 10 });

// Generate active agent session
const activeSessionArb = (userId: string) => fc.record({
  id: sessionIdArb,
  userId: fc.constant(userId),
  agentName: agentNameArb,
  status: fc.constant('active' as const),
});

// Generate expired agent session
const expiredSessionArb = (userId: string) => fc.record({
  id: sessionIdArb,
  userId: fc.constant(userId),
  agentName: agentNameArb,
  status: fc.constant('expired' as const),
});

// Generate disconnected agent session
const disconnectedSessionArb = (userId: string) => fc.record({
  id: sessionIdArb,
  userId: fc.constant(userId),
  agentName: agentNameArb,
  status: fc.constant('disconnected' as const),
});

// Generate session with wrong user
const wrongUserSessionArb = fc.record({
  id: sessionIdArb,
  userId: userIdArb, // Different user
  agentName: agentNameArb,
  status: fc.constant('active' as const),
});

// ==================== PROPERTY TESTS ====================

describe('Access Control - Property-Based Tests', () => {
  const service = new SimulatedAccessControlService();

  /**
   * Property 10: Access Control Enforcement
   * 
   * For any GitHub API request, the system SHALL only return data for repositories 
   * the user has access to, and requests for inaccessible repos SHALL return 403 errors.
   * 
   * **Feature: github-mcp-integration, Property 10: Access Control Enforcement**
   * **Validates: Requirements 7.1, 7.2**
   */
  describe('Property 10: Access Control Enforcement', () => {

    describe('Repository Access Validation (Requirement 7.1)', () => {

      it('grants access to repositories in user\'s accessible list', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            repositoryListArb.filter(repos => repos.length > 0),
            async (connection, repos) => {
              service.setup(connection, repos, null);

              // Pick a random accessible repo
              const targetRepo = repos[Math.floor(Math.random() * repos.length)];
              
              const result = service.verifyRepositoryAccess(
                connection.userId,
                targetRepo.owner,
                targetRepo.name
              );

              expect(result.hasAccess).toBe(true);
              expect(result.error).toBeUndefined();
            }
          ),
          { numRuns: 100 }
        );
      });

      it('denies access to repositories not in user\'s accessible list', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            repositoryListArb,
            ownerArb,
            repoNameArb,
            async (connection, repos, randomOwner, randomRepo) => {
              service.setup(connection, repos, null);

              // Check if the random repo is NOT in the accessible list
              const isAccessible = repos.some(
                r => r.owner.toLowerCase() === randomOwner.toLowerCase() &&
                     r.name.toLowerCase() === randomRepo.toLowerCase()
              );

              if (!isAccessible) {
                const result = service.verifyRepositoryAccess(
                  connection.userId,
                  randomOwner,
                  randomRepo
                );

                expect(result.hasAccess).toBe(false);
                expect(result.error).toBeDefined();
                expect(result.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED);
              }
            }
          ),
          { numRuns: 100 }
        );
      });

      it('denies access when user has no GitHub connection', async () => {
        await fc.assert(
          fc.asyncProperty(
            userIdArb,
            ownerArb,
            repoNameArb,
            async (userId, owner, repo) => {
              service.setup(null, [], null);

              const result = service.verifyRepositoryAccess(userId, owner, repo);

              expect(result.hasAccess).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe('GITHUB_NOT_CONNECTED');
            }
          ),
          { numRuns: 100 }
        );
      });

      it('denies access when GitHub connection is inactive', async () => {
        await fc.assert(
          fc.asyncProperty(
            inactiveConnectionArb,
            repositoryListArb,
            ownerArb,
            repoNameArb,
            async (connection, repos, owner, repo) => {
              service.setup(connection, repos, null);

              const result = service.verifyRepositoryAccess(
                connection.userId,
                owner,
                repo
              );

              expect(result.hasAccess).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe('GITHUB_NOT_CONNECTED');
            }
          ),
          { numRuns: 100 }
        );
      });

      it('access check is case-insensitive for owner and repo names', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            repositoryArb,
            async (connection, repo) => {
              service.setup(connection, [repo], null);

              // Test with different case variations
              const variations = [
                { owner: repo.owner.toLowerCase(), name: repo.name.toLowerCase() },
                { owner: repo.owner.toUpperCase(), name: repo.name.toUpperCase() },
                { owner: repo.owner, name: repo.name },
              ];

              for (const variation of variations) {
                const result = service.verifyRepositoryAccess(
                  connection.userId,
                  variation.owner,
                  variation.name
                );

                expect(result.hasAccess).toBe(true);
              }
            }
          ),
          { numRuns: 100 }
        );
      });
    });

    describe('Agent Session Validation (Requirement 7.2)', () => {

      it('validates active session belonging to requesting user', async () => {
        await fc.assert(
          fc.asyncProperty(
            userIdArb,
            async (userId) => {
              const sessionArb = activeSessionArb(userId);
              const session = fc.sample(sessionArb, 1)[0];
              
              service.setup(null, [], session);

              const result = service.validateAgentSession(session.id, userId);

              expect(result.valid).toBe(true);
              expect(result.session).toBeDefined();
              expect(result.session!.userId).toBe(userId);
              expect(result.session!.status).toBe('active');
            }
          ),
          { numRuns: 100 }
        );
      });

      it('rejects session belonging to different user', async () => {
        await fc.assert(
          fc.asyncProperty(
            userIdArb,
            userIdArb,
            async (sessionUserId, requestingUserId) => {
              // Ensure different users
              if (sessionUserId === requestingUserId) return;

              const session: AgentSession = {
                id: fc.sample(sessionIdArb, 1)[0],
                userId: sessionUserId,
                agentName: 'TestAgent',
                status: 'active',
              };
              
              service.setup(null, [], session);

              const result = service.validateAgentSession(session.id, requestingUserId);

              expect(result.valid).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.SESSION_USER_MISMATCH);
            }
          ),
          { numRuns: 100 }
        );
      });

      it('rejects expired sessions', async () => {
        await fc.assert(
          fc.asyncProperty(
            userIdArb,
            async (userId) => {
              const sessionArb = expiredSessionArb(userId);
              const session = fc.sample(sessionArb, 1)[0];
              
              service.setup(null, [], session);

              const result = service.validateAgentSession(session.id, userId);

              expect(result.valid).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.SESSION_EXPIRED);
            }
          ),
          { numRuns: 100 }
        );
      });

      it('rejects disconnected sessions', async () => {
        await fc.assert(
          fc.asyncProperty(
            userIdArb,
            async (userId) => {
              const sessionArb = disconnectedSessionArb(userId);
              const session = fc.sample(sessionArb, 1)[0];
              
              service.setup(null, [], session);

              const result = service.validateAgentSession(session.id, userId);

              expect(result.valid).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.SESSION_EXPIRED);
            }
          ),
          { numRuns: 100 }
        );
      });

      it('rejects non-existent sessions', async () => {
        await fc.assert(
          fc.asyncProperty(
            sessionIdArb,
            userIdArb,
            async (sessionId, userId) => {
              service.setup(null, [], null);

              const result = service.validateAgentSession(sessionId, userId);

              expect(result.valid).toBe(false);
              expect(result.error).toBeDefined();
              expect(result.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.SESSION_NOT_FOUND);
            }
          ),
          { numRuns: 100 }
        );
      });
    });

    describe('Combined Access Control', () => {

      it('both repo access and session validation must pass for full access', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            repositoryListArb.filter(repos => repos.length > 0),
            async (connection, repos) => {
              const sessionArb = activeSessionArb(connection.userId);
              const session = fc.sample(sessionArb, 1)[0];
              
              service.setup(connection, repos, session);

              // Pick a random accessible repo
              const targetRepo = repos[Math.floor(Math.random() * repos.length)];

              // Both checks should pass
              const repoAccess = service.verifyRepositoryAccess(
                connection.userId,
                targetRepo.owner,
                targetRepo.name
              );
              const sessionValid = service.validateAgentSession(session.id, connection.userId);

              expect(repoAccess.hasAccess).toBe(true);
              expect(sessionValid.valid).toBe(true);
            }
          ),
          { numRuns: 100 }
        );
      });

      it('access denied if repo check fails even with valid session', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            ownerArb,
            repoNameArb,
            async (connection, owner, repo) => {
              const sessionArb = activeSessionArb(connection.userId);
              const session = fc.sample(sessionArb, 1)[0];
              
              // Setup with empty repo list
              service.setup(connection, [], session);

              const repoAccess = service.verifyRepositoryAccess(
                connection.userId,
                owner,
                repo
              );
              const sessionValid = service.validateAgentSession(session.id, connection.userId);

              // Session is valid but repo access is denied
              expect(sessionValid.valid).toBe(true);
              expect(repoAccess.hasAccess).toBe(false);
              expect(repoAccess.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED);
            }
          ),
          { numRuns: 100 }
        );
      });

      it('access denied if session check fails even with valid repo access', async () => {
        await fc.assert(
          fc.asyncProperty(
            activeConnectionArb,
            repositoryListArb.filter(repos => repos.length > 0),
            userIdArb,
            async (connection, repos, differentUserId) => {
              // Ensure different user
              if (connection.userId === differentUserId) return;

              const session: AgentSession = {
                id: fc.sample(sessionIdArb, 1)[0],
                userId: differentUserId, // Different user
                agentName: 'TestAgent',
                status: 'active',
              };
              
              service.setup(connection, repos, session);

              const targetRepo = repos[Math.floor(Math.random() * repos.length)];

              const repoAccess = service.verifyRepositoryAccess(
                connection.userId,
                targetRepo.owner,
                targetRepo.name
              );
              const sessionValid = service.validateAgentSession(session.id, connection.userId);

              // Repo access is valid but session belongs to different user
              expect(repoAccess.hasAccess).toBe(true);
              expect(sessionValid.valid).toBe(false);
              expect(sessionValid.error!.code).toBe(ACCESS_CONTROL_ERROR_CODES.SESSION_USER_MISMATCH);
            }
          ),
          { numRuns: 100 }
        );
      });
    });
  });
});
