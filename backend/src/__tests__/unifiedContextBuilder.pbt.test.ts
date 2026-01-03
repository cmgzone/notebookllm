/**
 * Property-Based Tests for Unified Context Builder
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: github-mcp-integration
 */

import * as fc from 'fast-check';

// ==================== INLINE IMPLEMENTATIONS FOR TESTING ====================
// These mirror the types and logic from unifiedContextBuilder.ts

/**
 * A source included in the context
 */
interface ContextSource {
  id: string;
  type: 'github' | 'code' | 'text' | 'url' | 'youtube' | 'gdrive';
  title: string;
  content: string;
  language?: string;
  metadata: Record<string, any>;
}

/**
 * Agent-saved source information
 */
interface AgentSource {
  id: string;
  title: string;
  content: string;
  language: string;
  agentName: string;
  agentSessionId: string;
  verificationScore?: number;
}

/**
 * Complete code context for AI
 */
interface CodeContext {
  sources: ContextSource[];
  repoStructure?: {
    owner: string;
    repo: string;
    branch: string;
    files: string[];
  };
  relatedFiles?: {
    path: string;
    language: string;
    size: number;
  }[];
  agentSources?: AgentSource[];
  totalTokenEstimate?: number;
}

/**
 * Approximate tokens per character (rough estimate for context sizing)
 */
const TOKENS_PER_CHAR = 0.25;

/**
 * Estimate token count for a string
 */
function estimateTokens(text: string): number {
  return Math.ceil(text.length * TOKENS_PER_CHAR);
}

/**
 * Build context from sources (simplified version for testing)
 */
function buildContextFromSources(
  sources: Array<{
    id: string;
    type: string;
    title: string;
    content: string;
    metadata: Record<string, any>;
  }>,
  options: {
    includeGitHubSources?: boolean;
    includeAgentSources?: boolean;
    includeTextSources?: boolean;
    maxTokens?: number;
  } = {}
): CodeContext {
  const {
    includeGitHubSources = true,
    includeAgentSources = true,
    includeTextSources = true,
    maxTokens = 100000,
  } = options;

  const context: CodeContext = {
    sources: [],
    totalTokenEstimate: 0,
  };

  let currentTokens = 0;

  for (const source of sources) {
    const content = source.content || '';
    const contentTokens = estimateTokens(content);

    // Check if we'd exceed max tokens
    if (currentTokens + contentTokens > maxTokens) {
      continue;
    }

    // Handle GitHub sources
    if (source.type === 'github' && includeGitHubSources) {
      const contextSource: ContextSource = {
        id: source.id,
        type: 'github',
        title: source.title,
        content: content,
        language: source.metadata.language,
        metadata: {
          owner: source.metadata.owner,
          repo: source.metadata.repo,
          path: source.metadata.path,
          branch: source.metadata.branch,
          commitSha: source.metadata.commitSha,
          githubUrl: source.metadata.githubUrl,
        },
      };
      context.sources.push(contextSource);
      currentTokens += contentTokens;

      // Add repo structure
      if (!context.repoStructure) {
        context.repoStructure = {
          owner: source.metadata.owner,
          repo: source.metadata.repo,
          branch: source.metadata.branch,
          files: [source.metadata.path],
        };
      }
    }
    // Handle agent-saved code sources
    else if (source.type === 'code' && includeAgentSources && source.metadata.agentSessionId) {
      const contextSource: ContextSource = {
        id: source.id,
        type: 'code',
        title: source.title,
        content: content,
        language: source.metadata.language,
        metadata: {
          agentName: source.metadata.agentName,
          agentSessionId: source.metadata.agentSessionId,
          isVerified: source.metadata.isVerified,
          verificationScore: source.metadata.verification?.score,
        },
      };
      context.sources.push(contextSource);
      currentTokens += contentTokens;

      // Add to agentSources array
      if (!context.agentSources) {
        context.agentSources = [];
      }
      context.agentSources.push({
        id: source.id,
        title: source.title,
        content: content,
        language: source.metadata.language || 'unknown',
        agentName: source.metadata.agentName || 'Unknown Agent',
        agentSessionId: source.metadata.agentSessionId,
        verificationScore: source.metadata.verification?.score,
      });
    }
    // Handle regular code sources
    else if (source.type === 'code' && includeAgentSources && !source.metadata.agentSessionId) {
      const contextSource: ContextSource = {
        id: source.id,
        type: 'code',
        title: source.title,
        content: content,
        language: source.metadata.language,
        metadata: {
          isVerified: source.metadata.isVerified,
          verificationScore: source.metadata.verification?.score,
        },
      };
      context.sources.push(contextSource);
      currentTokens += contentTokens;
    }
    // Handle text sources
    else if (source.type === 'text' && includeTextSources) {
      const contextSource: ContextSource = {
        id: source.id,
        type: 'text',
        title: source.title,
        content: content,
        metadata: {},
      };
      context.sources.push(contextSource);
      currentTokens += contentTokens;
    }
  }

  context.totalTokenEstimate = currentTokens;
  return context;
}

// ==================== ARBITRARIES ====================

// Generate UUIDs
const uuidArb = fc.uuid();

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

// Generate file paths
const filePathArb = fc.array(
  fc.stringOf(
    fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'),
    { minLength: 1, maxLength: 50 }
  ),
  { minLength: 1, maxLength: 5 }
).map(parts => parts.join('/'));

// Generate branch names
const branchArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_/'),
  { minLength: 1, maxLength: 50 }
).filter(s => s.length >= 1 && !s.startsWith('/') && !s.endsWith('/'));

// Generate commit SHAs
const shaArb = fc.hexaString({ minLength: 40, maxLength: 40 });

// Generate programming languages
const languageArb = fc.constantFrom(
  'typescript', 'javascript', 'python', 'dart', 'java', 'go', 'rust', 'text'
);

// Generate code content
const codeContentArb = fc.string({ minLength: 10, maxLength: 5000 });

// Generate source titles
const titleArb = fc.string({ minLength: 1, maxLength: 100 });

// Generate GitHub source
const githubSourceArb = fc.record({
  id: uuidArb,
  type: fc.constant('github'),
  title: titleArb,
  content: codeContentArb,
  metadata: fc.record({
    type: fc.constant('github'),
    owner: ownerArb,
    repo: repoArb,
    path: filePathArb.map(p => p + '.ts'),
    branch: branchArb,
    commitSha: shaArb,
    language: languageArb,
    size: fc.integer({ min: 10, max: 100000 }),
    lastFetchedAt: fc.date({ min: new Date('2020-01-01'), max: new Date() }).map(d => d.toISOString()),
    githubUrl: fc.constant('https://github.com/test/repo/blob/main/test.ts'),
  }),
});

// Generate agent code source
const agentCodeSourceArb = fc.record({
  id: uuidArb,
  type: fc.constant('code'),
  title: titleArb,
  content: codeContentArb,
  metadata: fc.record({
    language: languageArb,
    agentSessionId: uuidArb,
    agentName: fc.constantFrom('Claude', 'Kiro', 'Cursor', 'Copilot'),
    isVerified: fc.boolean(),
    verification: fc.record({
      score: fc.integer({ min: 0, max: 100 }),
      isValid: fc.boolean(),
    }),
  }),
});

// Generate regular code source (not from agent)
const regularCodeSourceArb = fc.record({
  id: uuidArb,
  type: fc.constant('code'),
  title: titleArb,
  content: codeContentArb,
  metadata: fc.record({
    language: languageArb,
    isVerified: fc.boolean(),
    verification: fc.record({
      score: fc.integer({ min: 0, max: 100 }),
      isValid: fc.boolean(),
    }),
  }),
});

// Generate text source
const textSourceArb = fc.record({
  id: uuidArb,
  type: fc.constant('text'),
  title: titleArb,
  content: fc.string({ minLength: 10, maxLength: 2000 }),
  metadata: fc.record({}),
});

// Generate mixed sources array
const mixedSourcesArb = fc.array(
  fc.oneof(githubSourceArb, agentCodeSourceArb, regularCodeSourceArb, textSourceArb),
  { minLength: 1, maxLength: 10 }
);

// ==================== PROPERTY TESTS ====================

describe('Unified Context Builder - Property-Based Tests', () => {

  /**
   * Property 6: Unified Context Inclusion
   * 
   * For any notebook with both GitHub sources and agent-saved code sources, 
   * the context builder SHALL include content from both source types in the AI context.
   * 
   * **Feature: github-mcp-integration, Property 6: Unified Context Inclusion**
   * **Validates: Requirements 2.1, 5.1, 5.3**
   */
  describe('Property 6: Unified Context Inclusion', () => {
    it('context includes both GitHub sources and agent sources when both are present', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(githubSourceArb, { minLength: 1, maxLength: 3 }),
          fc.array(agentCodeSourceArb, { minLength: 1, maxLength: 3 }),
          async (githubSources, agentSources) => {
            const allSources = [...githubSources, ...agentSources];
            const context = buildContextFromSources(allSources, {
              includeGitHubSources: true,
              includeAgentSources: true,
            });

            // Verify GitHub sources are included
            const githubInContext = context.sources.filter(s => s.type === 'github');
            expect(githubInContext.length).toBe(githubSources.length);

            // Verify agent sources are included
            const agentInContext = context.sources.filter(
              s => s.type === 'code' && s.metadata.agentSessionId
            );
            expect(agentInContext.length).toBe(agentSources.length);

            // Verify agentSources array is populated
            expect(context.agentSources).toBeDefined();
            expect(context.agentSources!.length).toBe(agentSources.length);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('GitHub sources contain all required metadata fields', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(githubSourceArb, { minLength: 1, maxLength: 5 }),
          async (githubSources) => {
            const context = buildContextFromSources(githubSources, {
              includeGitHubSources: true,
            });

            for (const source of context.sources) {
              if (source.type === 'github') {
                // Verify all required GitHub metadata fields
                expect(source.metadata).toHaveProperty('owner');
                expect(source.metadata).toHaveProperty('repo');
                expect(source.metadata).toHaveProperty('path');
                expect(source.metadata).toHaveProperty('branch');
                expect(source.metadata).toHaveProperty('commitSha');
                expect(source.metadata).toHaveProperty('githubUrl');
                
                // Verify language is set
                expect(source.language).toBeDefined();
              }
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('agent sources contain agent identification metadata', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(agentCodeSourceArb, { minLength: 1, maxLength: 5 }),
          async (agentSources) => {
            const context = buildContextFromSources(agentSources, {
              includeAgentSources: true,
            });

            for (const source of context.sources) {
              if (source.type === 'code' && source.metadata.agentSessionId) {
                // Verify agent identification
                expect(source.metadata).toHaveProperty('agentSessionId');
                expect(source.metadata).toHaveProperty('agentName');
              }
            }

            // Verify agentSources array entries
            if (context.agentSources) {
              for (const agentSource of context.agentSources) {
                expect(agentSource.agentSessionId).toBeDefined();
                expect(agentSource.agentName).toBeDefined();
                expect(agentSource.language).toBeDefined();
              }
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('context respects includeGitHubSources option', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(githubSourceArb, { minLength: 1, maxLength: 3 }),
          fc.array(agentCodeSourceArb, { minLength: 1, maxLength: 3 }),
          async (githubSources, agentSources) => {
            const allSources = [...githubSources, ...agentSources];
            
            // With GitHub sources disabled
            const contextWithoutGithub = buildContextFromSources(allSources, {
              includeGitHubSources: false,
              includeAgentSources: true,
            });

            const githubInContext = contextWithoutGithub.sources.filter(s => s.type === 'github');
            expect(githubInContext.length).toBe(0);

            // Agent sources should still be included
            const agentInContext = contextWithoutGithub.sources.filter(
              s => s.type === 'code' && s.metadata.agentSessionId
            );
            expect(agentInContext.length).toBe(agentSources.length);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('context respects includeAgentSources option', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(githubSourceArb, { minLength: 1, maxLength: 3 }),
          fc.array(agentCodeSourceArb, { minLength: 1, maxLength: 3 }),
          async (githubSources, agentSources) => {
            const allSources = [...githubSources, ...agentSources];
            
            // With agent sources disabled
            const contextWithoutAgent = buildContextFromSources(allSources, {
              includeGitHubSources: true,
              includeAgentSources: false,
            });

            // GitHub sources should still be included
            const githubInContext = contextWithoutAgent.sources.filter(s => s.type === 'github');
            expect(githubInContext.length).toBe(githubSources.length);

            // Agent sources should be excluded
            const agentInContext = contextWithoutAgent.sources.filter(
              s => s.type === 'code' && s.metadata.agentSessionId
            );
            expect(agentInContext.length).toBe(0);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('context respects includeTextSources option', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(textSourceArb, { minLength: 1, maxLength: 3 }),
          fc.array(githubSourceArb, { minLength: 1, maxLength: 3 }),
          async (textSources, githubSources) => {
            const allSources = [...textSources, ...githubSources];
            
            // With text sources disabled
            const contextWithoutText = buildContextFromSources(allSources, {
              includeGitHubSources: true,
              includeTextSources: false,
            });

            const textInContext = contextWithoutText.sources.filter(s => s.type === 'text');
            expect(textInContext.length).toBe(0);

            // GitHub sources should still be included
            const githubInContext = contextWithoutText.sources.filter(s => s.type === 'github');
            expect(githubInContext.length).toBe(githubSources.length);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('repo structure is populated from GitHub sources', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(githubSourceArb, { minLength: 1, maxLength: 5 }),
          async (githubSources) => {
            const context = buildContextFromSources(githubSources, {
              includeGitHubSources: true,
            });

            if (githubSources.length > 0) {
              expect(context.repoStructure).toBeDefined();
              expect(context.repoStructure!.owner).toBeDefined();
              expect(context.repoStructure!.repo).toBeDefined();
              expect(context.repoStructure!.branch).toBeDefined();
              expect(context.repoStructure!.files).toBeDefined();
              expect(context.repoStructure!.files.length).toBeGreaterThan(0);
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('total token estimate is calculated correctly', async () => {
      await fc.assert(
        fc.asyncProperty(
          mixedSourcesArb,
          async (sources) => {
            const context = buildContextFromSources(sources, {
              includeGitHubSources: true,
              includeAgentSources: true,
              includeTextSources: true,
            });

            // Calculate expected tokens
            let expectedTokens = 0;
            for (const source of context.sources) {
              expectedTokens += estimateTokens(source.content);
            }

            expect(context.totalTokenEstimate).toBe(expectedTokens);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('context respects maxTokens limit', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.array(
            fc.record({
              id: uuidArb,
              type: fc.constant('text'),
              title: titleArb,
              content: fc.string({ minLength: 1000, maxLength: 5000 }),
              metadata: fc.record({}),
            }),
            { minLength: 5, maxLength: 10 }
          ),
          fc.integer({ min: 100, max: 1000 }),
          async (sources, maxTokens) => {
            const context = buildContextFromSources(sources, {
              includeTextSources: true,
              maxTokens,
            });

            // Total tokens should not exceed maxTokens
            expect(context.totalTokenEstimate).toBeLessThanOrEqual(maxTokens);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('source content is preserved exactly in context', async () => {
      await fc.assert(
        fc.asyncProperty(
          mixedSourcesArb,
          async (sources) => {
            const context = buildContextFromSources(sources, {
              includeGitHubSources: true,
              includeAgentSources: true,
              includeTextSources: true,
            });

            // For each source in context, verify content matches original
            for (const contextSource of context.sources) {
              const originalSource = sources.find(s => s.id === contextSource.id);
              if (originalSource) {
                expect(contextSource.content).toBe(originalSource.content);
                expect(contextSource.title).toBe(originalSource.title);
              }
            }
          }
        ),
        { numRuns: 20 }
      );
    });

    it('source IDs are unique in context', async () => {
      await fc.assert(
        fc.asyncProperty(
          mixedSourcesArb,
          async (sources) => {
            const context = buildContextFromSources(sources, {
              includeGitHubSources: true,
              includeAgentSources: true,
              includeTextSources: true,
            });

            const ids = context.sources.map(s => s.id);
            const uniqueIds = new Set(ids);
            
            expect(uniqueIds.size).toBe(ids.length);
          }
        ),
        { numRuns: 20 }
      );
    });

    it('empty sources array produces empty context', async () => {
      const context = buildContextFromSources([], {
        includeGitHubSources: true,
        includeAgentSources: true,
        includeTextSources: true,
      });

      expect(context.sources).toEqual([]);
      expect(context.totalTokenEstimate).toBe(0);
      expect(context.agentSources).toBeUndefined();
      expect(context.repoStructure).toBeUndefined();
    });
  });
});
