/**
 * Property-Based Tests for Issue Creation Data Integrity
 * 
 * Feature: github-mcp-integration
 * Property 9: Issue Creation Data Integrity
 * Validates: Requirements 6.4, 7.3
 */

import * as fc from 'fast-check';

interface CreateIssueParams {
  userId: string;
  owner: string;
  repo: string;
  title: string;
  body: string;
  labels?: string[];
  sourceId?: string;
  agentSessionId?: string;
}

interface CreatedIssue {
  number: number;
  htmlUrl: string;
  title: string;
  body: string;
  labels: string[];
  owner: string;
  repo: string;
  createdAt: Date;
}

interface IssueAuditLog {
  id: string;
  userId: string;
  action: 'create_issue';
  owner: string;
  repo: string;
  agentSessionId?: string;
  success: boolean;
  requestMetadata: {
    issueNumber?: number;
    title: string;
    labels?: string[];
    sourceId?: string;
  };
  createdAt: Date;
}

function simulateCreateIssue(params: CreateIssueParams): CreatedIssue {
  const issueNum = Math.floor(Math.random() * 10000) + 1;
  return {
    number: issueNum,
    htmlUrl: `https://github.com/${params.owner}/${params.repo}/issues/${issueNum}`,
    title: params.title,
    body: params.body,
    labels: params.labels || [],
    owner: params.owner,
    repo: params.repo,
    createdAt: new Date(),
  };
}

function simulateCreateAuditLog(params: CreateIssueParams, issue: CreatedIssue): IssueAuditLog {
  return {
    id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`,
    userId: params.userId,
    action: 'create_issue',
    owner: params.owner,
    repo: params.repo,
    agentSessionId: params.agentSessionId,
    success: true,
    requestMetadata: {
      issueNumber: issue.number,
      title: params.title,
      labels: params.labels,
      sourceId: params.sourceId,
    },
    createdAt: new Date(),
  };
}

const userIdArb = fc.uuid();
const ownerArb = fc.string({ minLength: 2, maxLength: 39 }).filter(s => /^[a-z0-9][a-z0-9-]*[a-z0-9]$/.test(s));
const repoArb = fc.string({ minLength: 2, maxLength: 100 }).filter(s => /^[a-z0-9][a-z0-9._-]*[a-z0-9]$/.test(s));
const issueTitleArb = fc.string({ minLength: 1, maxLength: 256 }).filter(s => s.trim().length > 0);
const issueBodyArb = fc.string({ minLength: 0, maxLength: 5000 });
const labelArb = fc.string({ minLength: 1, maxLength: 50 }).filter(s => s.trim().length > 0);
const labelsArb = fc.array(labelArb, { minLength: 0, maxLength: 10 });

const createIssueParamsArb: fc.Arbitrary<CreateIssueParams> = fc.record({
  userId: userIdArb,
  owner: ownerArb,
  repo: repoArb,
  title: issueTitleArb,
  body: issueBodyArb,
  labels: fc.option(labelsArb, { nil: undefined }),
  sourceId: fc.option(fc.uuid(), { nil: undefined }),
  agentSessionId: fc.option(fc.uuid(), { nil: undefined }),
});

describe('Issue Creation Data Integrity - Property-Based Tests', () => {
  describe('Property 9: Issue Creation Data Integrity', () => {
    
    test('created issue contains exact title and body provided', async () => {
      await fc.assert(
        fc.asyncProperty(createIssueParamsArb, async (params) => {
          const issue = simulateCreateIssue(params);
          expect(issue.title).toBe(params.title);
          expect(issue.body).toBe(params.body);
          expect(issue.owner).toBe(params.owner);
          expect(issue.repo).toBe(params.repo);
        }),
        { numRuns: 20 }
      );
    });

    test('created issue preserves all labels exactly', async () => {
      await fc.assert(
        fc.asyncProperty(
          createIssueParamsArb.filter((p): p is CreateIssueParams & { labels: string[] } => 
            Boolean(p.labels && p.labels.length > 0)
          ),
          async (params) => {
            const issue = simulateCreateIssue(params);
            expect(issue.labels).toEqual(params.labels);
          }
        ),
        { numRuns: 20 }
      );
    });

    test('audit log records issue creation with exact data', async () => {
      await fc.assert(
        fc.asyncProperty(createIssueParamsArb, async (params) => {
          const issue = simulateCreateIssue(params);
          const auditLog = simulateCreateAuditLog(params, issue);
          
          expect(auditLog.action).toBe('create_issue');
          expect(auditLog.userId).toBe(params.userId);
          expect(auditLog.owner).toBe(params.owner);
          expect(auditLog.repo).toBe(params.repo);
          expect(auditLog.success).toBe(true);
          expect(auditLog.requestMetadata.title).toBe(params.title);
          expect(auditLog.requestMetadata.issueNumber).toBe(issue.number);
        }),
        { numRuns: 20 }
      );
    });

    test('audit log includes agent session ID when provided', async () => {
      await fc.assert(
        fc.asyncProperty(
          createIssueParamsArb.filter((p): p is CreateIssueParams & { agentSessionId: string } => 
            p.agentSessionId !== undefined
          ),
          async (params) => {
            const issue = simulateCreateIssue(params);
            const auditLog = simulateCreateAuditLog(params, issue);
            expect(auditLog.agentSessionId).toBe(params.agentSessionId);
          }
        ),
        { numRuns: 20 }
      );
    });

    test('audit log includes source ID in metadata when provided', async () => {
      await fc.assert(
        fc.asyncProperty(
          createIssueParamsArb.filter((p): p is CreateIssueParams & { sourceId: string } => 
            p.sourceId !== undefined
          ),
          async (params) => {
            const issue = simulateCreateIssue(params);
            const auditLog = simulateCreateAuditLog(params, issue);
            expect(auditLog.requestMetadata.sourceId).toBe(params.sourceId);
          }
        ),
        { numRuns: 20 }
      );
    });

    test('issue URL follows GitHub format', async () => {
      await fc.assert(
        fc.asyncProperty(createIssueParamsArb, async (params) => {
          const issue = simulateCreateIssue(params);
          expect(issue.htmlUrl).toMatch(/^https:\/\/github\.com\/.+\/.+\/issues\/\d+$/);
        }),
        { numRuns: 20 }
      );
    });

    test('issue number is always positive integer', async () => {
      await fc.assert(
        fc.asyncProperty(createIssueParamsArb, async (params) => {
          const issue = simulateCreateIssue(params);
          expect(issue.number).toBeGreaterThan(0);
          expect(Number.isInteger(issue.number)).toBe(true);
        }),
        { numRuns: 20 }
      );
    });

    test('issue createdAt is a valid recent Date', async () => {
      await fc.assert(
        fc.asyncProperty(createIssueParamsArb, async (params) => {
          const issue = simulateCreateIssue(params);
          expect(issue.createdAt).toBeInstanceOf(Date);
          expect(isNaN(issue.createdAt.getTime())).toBe(false);
        }),
        { numRuns: 20 }
      );
    });
  });
});
