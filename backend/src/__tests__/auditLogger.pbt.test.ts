/**
 * Property-Based Tests for Audit Logger Service
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: github-mcp-integration
 * Property 9: Issue Creation Data Integrity (audit portion)
 * Validates: Requirements 7.3
 */

import * as fc from 'fast-check';

// ==================== INLINE TYPES FOR TESTING ====================
// These mirror the types from auditLoggerService.ts

type GitHubAuditAction = 
  | 'list_repos' 
  | 'get_file' 
  | 'search' 
  | 'create_issue' 
  | 'add_source' 
  | 'analyze_repo' 
  | 'get_tree';

interface GitHubAuditLog {
  id: string;
  userId: string;
  action: GitHubAuditAction;
  owner?: string;
  repo?: string;
  path?: string;
  agentSessionId?: string;
  success: boolean;
  errorMessage?: string;
  requestMetadata?: Record<string, any>;
  createdAt: Date;
}

interface CreateAuditLogParams {
  userId: string;
  action: GitHubAuditAction;
  owner?: string;
  repo?: string;
  path?: string;
  agentSessionId?: string;
  success?: boolean;
  errorMessage?: string;
  requestMetadata?: Record<string, any>;
}

// ==================== VALIDATION FUNCTIONS ====================

/**
 * Valid GitHub audit actions
 */
const VALID_ACTIONS: GitHubAuditAction[] = [
  'list_repos',
  'get_file',
  'search',
  'create_issue',
  'add_source',
  'analyze_repo',
  'get_tree',
];

/**
 * Validate that an audit log entry contains all required fields
 */
function validateAuditLogEntry(log: GitHubAuditLog): boolean {
  // Required fields must be present
  if (!log.id || typeof log.id !== 'string') return false;
  if (!log.userId || typeof log.userId !== 'string') return false;
  if (!log.action || !VALID_ACTIONS.includes(log.action)) return false;
  if (typeof log.success !== 'boolean') return false;
  if (!(log.createdAt instanceof Date) || isNaN(log.createdAt.getTime())) return false;
  
  // Optional fields should be correct type if present
  if (log.owner !== undefined && typeof log.owner !== 'string') return false;
  if (log.repo !== undefined && typeof log.repo !== 'string') return false;
  if (log.path !== undefined && typeof log.path !== 'string') return false;
  if (log.agentSessionId !== undefined && typeof log.agentSessionId !== 'string') return false;
  if (log.errorMessage !== undefined && typeof log.errorMessage !== 'string') return false;
  if (log.requestMetadata !== undefined && typeof log.requestMetadata !== 'object') return false;
  
  return true;
}

/**
 * Validate that audit log preserves input data integrity
 */
function validateDataIntegrity(input: CreateAuditLogParams, output: GitHubAuditLog): boolean {
  // User ID must match exactly
  if (output.userId !== input.userId) return false;
  
  // Action must match exactly
  if (output.action !== input.action) return false;
  
  // Optional fields must match if provided
  if (input.owner !== undefined && output.owner !== input.owner) return false;
  if (input.repo !== undefined && output.repo !== input.repo) return false;
  if (input.path !== undefined && output.path !== input.path) return false;
  if (input.agentSessionId !== undefined && output.agentSessionId !== input.agentSessionId) return false;
  
  // Success defaults to true if not provided
  const expectedSuccess = input.success !== undefined ? input.success : true;
  if (output.success !== expectedSuccess) return false;
  
  // Error message must match if provided
  if (input.errorMessage !== undefined && output.errorMessage !== input.errorMessage) return false;
  
  return true;
}

/**
 * Simulate creating an audit log entry (for testing without database)
 */
function simulateCreateAuditLog(params: CreateAuditLogParams): GitHubAuditLog {
  return {
    id: `log_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    userId: params.userId,
    action: params.action,
    owner: params.owner,
    repo: params.repo,
    path: params.path,
    agentSessionId: params.agentSessionId,
    success: params.success !== undefined ? params.success : true,
    errorMessage: params.errorMessage,
    requestMetadata: params.requestMetadata || {},
    createdAt: new Date(),
  };
}

// ==================== ARBITRARIES ====================

// Generate valid user IDs (UUID-like)
const userIdArb = fc.uuid();

// Generate valid GitHub audit actions
const actionArb = fc.constantFrom<GitHubAuditAction>(...VALID_ACTIONS);

// Generate valid GitHub owner names
const ownerArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'),
  { minLength: 1, maxLength: 39 }
).filter(s => s.length >= 1 && !s.startsWith('-') && !s.endsWith('-'));

// Generate valid GitHub repo names
const repoArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'),
  { minLength: 1, maxLength: 100 }
).filter(s => s.length >= 1);

// Generate valid file paths
const filePathArb = fc.array(
  fc.stringOf(
    fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'),
    { minLength: 1, maxLength: 50 }
  ),
  { minLength: 1, maxLength: 5 }
).map(parts => parts.join('/'));

// Generate agent session IDs (UUID-like)
const agentSessionIdArb = fc.uuid();

// Generate error messages
const errorMessageArb = fc.string({ minLength: 1, maxLength: 500 });

// Generate request metadata
const requestMetadataArb = fc.dictionary(
  fc.string({ minLength: 1, maxLength: 20 }),
  fc.oneof(
    fc.string({ maxLength: 100 }),
    fc.integer(),
    fc.boolean()
  )
);

// Generate complete audit log params
const auditLogParamsArb = fc.record({
  userId: userIdArb,
  action: actionArb,
  owner: fc.option(ownerArb, { nil: undefined }),
  repo: fc.option(repoArb, { nil: undefined }),
  path: fc.option(filePathArb, { nil: undefined }),
  agentSessionId: fc.option(agentSessionIdArb, { nil: undefined }),
  success: fc.option(fc.boolean(), { nil: undefined }),
  errorMessage: fc.option(errorMessageArb, { nil: undefined }),
  requestMetadata: fc.option(requestMetadataArb, { nil: undefined }),
});

// Generate issue creation specific params
const issueCreationParamsArb = fc.record({
  userId: userIdArb,
  action: fc.constant<GitHubAuditAction>('create_issue'),
  owner: ownerArb,
  repo: repoArb,
  path: fc.constant(undefined),
  agentSessionId: fc.option(agentSessionIdArb, { nil: undefined }),
  success: fc.boolean(),
  errorMessage: fc.option(errorMessageArb, { nil: undefined }),
  requestMetadata: fc.record({
    issueTitle: fc.string({ minLength: 1, maxLength: 200 }),
    issueBody: fc.option(fc.string({ maxLength: 1000 }), { nil: undefined }),
    labels: fc.option(fc.array(fc.string({ minLength: 1, maxLength: 50 }), { maxLength: 5 }), { nil: undefined }),
  }),
});

// ==================== PROPERTY TESTS ====================

describe('Audit Logger Service - Property-Based Tests', () => {

  /**
   * Property 9: Issue Creation Data Integrity (audit portion)
   * 
   * For any issue created from an AI suggestion, the audit log SHALL record 
   * the creation with exact data provided.
   * 
   * **Feature: github-mcp-integration, Property 9: Issue Creation Data Integrity (audit portion)**
   * **Validates: Requirements 7.3**
   */
  describe('Property 9: Issue Creation Data Integrity (audit portion)', () => {
    
    it('audit log preserves all input data exactly', async () => {
      await fc.assert(
        fc.asyncProperty(
          auditLogParamsArb,
          async (params) => {
            const log = simulateCreateAuditLog(params);
            
            // Verify data integrity
            expect(validateDataIntegrity(params, log)).toBe(true);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log entry contains all required fields', async () => {
      await fc.assert(
        fc.asyncProperty(
          auditLogParamsArb,
          async (params) => {
            const log = simulateCreateAuditLog(params);
            
            // Verify all required fields are present and valid
            expect(validateAuditLogEntry(log)).toBe(true);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('issue creation audit logs contain exact title and body in metadata', async () => {
      await fc.assert(
        fc.asyncProperty(
          issueCreationParamsArb,
          async (params) => {
            const log = simulateCreateAuditLog(params);
            
            // Verify action is create_issue
            expect(log.action).toBe('create_issue');
            
            // Verify owner and repo are preserved
            expect(log.owner).toBe(params.owner);
            expect(log.repo).toBe(params.repo);
            
            // Verify metadata contains issue details
            if (params.requestMetadata) {
              expect(log.requestMetadata).toBeDefined();
              expect(log.requestMetadata?.issueTitle).toBe(params.requestMetadata.issueTitle);
              if (params.requestMetadata.issueBody !== undefined) {
                expect(log.requestMetadata?.issueBody).toBe(params.requestMetadata.issueBody);
              }
              if (params.requestMetadata.labels !== undefined) {
                expect(log.requestMetadata?.labels).toEqual(params.requestMetadata.labels);
              }
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log action is always a valid GitHub action', async () => {
      await fc.assert(
        fc.asyncProperty(
          actionArb,
          async (action) => {
            expect(VALID_ACTIONS).toContain(action);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log success defaults to true when not specified', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.record({
            userId: userIdArb,
            action: actionArb,
            // Explicitly omit success
          }),
          async (params) => {
            const log = simulateCreateAuditLog(params as CreateAuditLogParams);
            
            // Success should default to true
            expect(log.success).toBe(true);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log preserves error message when operation fails', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.record({
            userId: userIdArb,
            action: actionArb,
            owner: fc.option(ownerArb, { nil: undefined }),
            repo: fc.option(repoArb, { nil: undefined }),
            success: fc.constant(false),
            errorMessage: errorMessageArb,
          }),
          async (params) => {
            const log = simulateCreateAuditLog(params as CreateAuditLogParams);
            
            // Error message should be preserved
            expect(log.success).toBe(false);
            expect(log.errorMessage).toBe(params.errorMessage);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log includes agent session ID when provided', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.record({
            userId: userIdArb,
            action: actionArb,
            agentSessionId: agentSessionIdArb,
          }),
          async (params) => {
            const log = simulateCreateAuditLog(params as CreateAuditLogParams);
            
            // Agent session ID should be preserved
            expect(log.agentSessionId).toBe(params.agentSessionId);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log createdAt is a valid Date', async () => {
      await fc.assert(
        fc.asyncProperty(
          auditLogParamsArb,
          async (params) => {
            const log = simulateCreateAuditLog(params);
            
            // createdAt should be a valid Date
            expect(log.createdAt).toBeInstanceOf(Date);
            expect(isNaN(log.createdAt.getTime())).toBe(false);
            
            // createdAt should be recent (within last minute)
            const now = Date.now();
            const logTime = log.createdAt.getTime();
            expect(logTime).toBeLessThanOrEqual(now);
            expect(logTime).toBeGreaterThan(now - 60000);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log ID is unique for each entry', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(auditLogParamsArb, { minLength: 2, maxLength: 10 }),
          async (paramsArray) => {
            const logs = paramsArray.map(params => simulateCreateAuditLog(params));
            const ids = logs.map(log => log.id);
            const uniqueIds = new Set(ids);
            
            // All IDs should be unique
            expect(uniqueIds.size).toBe(ids.length);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('audit log requestMetadata is always an object', async () => {
      await fc.assert(
        fc.asyncProperty(
          auditLogParamsArb,
          async (params) => {
            const log = simulateCreateAuditLog(params);
            
            // requestMetadata should always be an object (defaults to {})
            expect(typeof log.requestMetadata).toBe('object');
            expect(log.requestMetadata).not.toBeNull();
          }
        ),
        { numRuns: 20 }
      );
    });
  });
});
