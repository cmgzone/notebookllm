/**
 * Unified Context Builder Service
 * Builds AI context from multiple source types including GitHub sources and agent-saved code.
 * 
 * Requirements: 2.1, 5.1, 5.3
 */

import pool from '../config/database.js';
import { githubSourceService, GitHubSource, GitHubSourceMetadata } from './githubSourceService.js';

// ==================== INTERFACES ====================

/**
 * A source included in the context
 */
export interface ContextSource {
  id: string;
  type: 'github' | 'code' | 'text' | 'url' | 'youtube' | 'gdrive';
  title: string;
  content: string;
  language?: string;
  metadata: Record<string, any>;
}

/**
 * Repository structure information
 */
export interface RepoStructure {
  owner: string;
  repo: string;
  branch: string;
  files: string[];
}

/**
 * Related file from the same repository
 */
export interface RelatedFile {
  path: string;
  language: string;
  size: number;
}

/**
 * Agent-saved source information
 */
export interface AgentSource {
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
export interface CodeContext {
  sources: ContextSource[];
  repoStructure?: RepoStructure;
  relatedFiles?: RelatedFile[];
  agentSources?: AgentSource[];
  totalTokenEstimate?: number;
}

/**
 * Options for building context
 */
export interface ContextOptions {
  includeGitHubSources?: boolean;
  includeAgentSources?: boolean;
  includeRepoStructure?: boolean;
  includeTextSources?: boolean;
  maxTokens?: number;
  sourceIds?: string[];  // Specific sources to include
}

/**
 * Repository info for fetching related files
 */
export interface RepoInfo {
  owner: string;
  repo: string;
  branch: string;
}

// ==================== CONSTANTS ====================

/**
 * Approximate tokens per character (rough estimate for context sizing)
 */
const TOKENS_PER_CHAR = 0.25;

/**
 * Default max tokens for context
 */
const DEFAULT_MAX_TOKENS = 100000;

// ==================== SERVICE CLASS ====================

class UnifiedContextBuilder {

  /**
   * Build unified context for a notebook, gathering all source types.
   * 
   * Requirements: 2.1, 5.1
   * 
   * @param notebookId - The notebook ID
   * @param userId - The user ID for authorization
   * @param options - Context building options
   * @returns Complete CodeContext with all sources
   */
  async buildContext(
    notebookId: string,
    userId: string,
    options: ContextOptions = {}
  ): Promise<CodeContext> {
    const {
      includeGitHubSources = true,
      includeAgentSources = true,
      includeTextSources = true,
      includeRepoStructure = false,
      maxTokens = DEFAULT_MAX_TOKENS,
      sourceIds,
    } = options;

    // Verify notebook exists and belongs to user
    const notebookResult = await pool.query(
      'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
      [notebookId, userId]
    );

    if (notebookResult.rows.length === 0) {
      throw new Error('Notebook not found or access denied');
    }

    const context: CodeContext = {
      sources: [],
      totalTokenEstimate: 0,
    };

    let currentTokens = 0;

    // Build base query for sources
    let sourceQuery = `
      SELECT s.* FROM sources s
      WHERE s.notebook_id = $1
    `;
    const queryParams: any[] = [notebookId];

    // Filter by specific source IDs if provided
    if (sourceIds && sourceIds.length > 0) {
      sourceQuery += ` AND s.id = ANY($${queryParams.length + 1})`;
      queryParams.push(sourceIds);
    }

    sourceQuery += ' ORDER BY s.updated_at DESC';

    const sourcesResult = await pool.query(sourceQuery, queryParams);

    // Process each source
    for (const row of sourcesResult.rows) {
      const metadata = typeof row.metadata === 'string' 
        ? JSON.parse(row.metadata) 
        : (row.metadata || {});
      
      const sourceType = row.type as string;
      const content = row.content || '';
      const contentTokens = Math.ceil(content.length * TOKENS_PER_CHAR);

      // Check if we'd exceed max tokens
      if (currentTokens + contentTokens > maxTokens) {
        continue; // Skip this source to stay within limits
      }

      // Handle GitHub sources
      if (sourceType === 'github' && includeGitHubSources) {
        const contextSource: ContextSource = {
          id: row.id,
          type: 'github',
          title: row.title,
          content: content,
          language: metadata.language,
          metadata: {
            owner: metadata.owner,
            repo: metadata.repo,
            path: metadata.path,
            branch: metadata.branch,
            commitSha: metadata.commitSha,
            githubUrl: metadata.githubUrl,
          },
        };
        context.sources.push(contextSource);
        currentTokens += contentTokens;

        // Optionally add repo structure for GitHub sources
        if (includeRepoStructure && !context.repoStructure) {
          context.repoStructure = {
            owner: metadata.owner,
            repo: metadata.repo,
            branch: metadata.branch,
            files: [], // Would be populated by addRelatedFiles
          };
        }
      }
      // Handle agent-saved code sources
      else if (sourceType === 'code' && includeAgentSources && metadata.agentSessionId) {
        const contextSource: ContextSource = {
          id: row.id,
          type: 'code',
          title: row.title,
          content: content,
          language: metadata.language,
          metadata: {
            agentName: metadata.agentName,
            agentSessionId: metadata.agentSessionId,
            isVerified: metadata.isVerified,
            verificationScore: metadata.verification?.score,
          },
        };
        context.sources.push(contextSource);
        currentTokens += contentTokens;

        // Also add to agentSources array for easy access
        if (!context.agentSources) {
          context.agentSources = [];
        }
        context.agentSources.push({
          id: row.id,
          title: row.title,
          content: content,
          language: metadata.language || 'unknown',
          agentName: metadata.agentName || 'Unknown Agent',
          agentSessionId: metadata.agentSessionId,
          verificationScore: metadata.verification?.score,
        });
      }
      // Handle regular code sources (not from agents)
      else if (sourceType === 'code' && includeAgentSources && !metadata.agentSessionId) {
        const contextSource: ContextSource = {
          id: row.id,
          type: 'code',
          title: row.title,
          content: content,
          language: metadata.language,
          metadata: {
            isVerified: metadata.isVerified,
            verificationScore: metadata.verification?.score,
          },
        };
        context.sources.push(contextSource);
        currentTokens += contentTokens;
      }
      // Handle text sources
      else if (sourceType === 'text' && includeTextSources) {
        const contextSource: ContextSource = {
          id: row.id,
          type: 'text',
          title: row.title,
          content: content,
          metadata: {},
        };
        context.sources.push(contextSource);
        currentTokens += contentTokens;
      }
      // Handle URL sources
      else if (sourceType === 'url' && includeTextSources) {
        const contextSource: ContextSource = {
          id: row.id,
          type: 'url',
          title: row.title,
          content: content,
          metadata: {
            url: row.url || metadata.url,
          },
        };
        context.sources.push(contextSource);
        currentTokens += contentTokens;
      }
    }

    context.totalTokenEstimate = currentTokens;
    return context;
  }


  /**
   * Add GitHub source content to an existing context.
   * 
   * Requirements: 2.1
   * 
   * @param context - Existing CodeContext to enhance
   * @param sourceId - GitHub source ID to add
   * @param userId - User ID for authorization
   * @returns Enhanced CodeContext with GitHub source
   */
  async addGitHubContext(
    context: CodeContext,
    sourceId: string,
    userId: string
  ): Promise<CodeContext> {
    // Get the GitHub source with fresh content
    const source = await githubSourceService.getSourceWithContent(sourceId, userId);

    // Check if source already exists in context
    const existingIndex = context.sources.findIndex(s => s.id === sourceId);
    
    const contextSource: ContextSource = {
      id: source.id,
      type: 'github',
      title: source.title,
      content: source.content,
      language: source.metadata.language,
      metadata: {
        owner: source.metadata.owner,
        repo: source.metadata.repo,
        path: source.metadata.path,
        branch: source.metadata.branch,
        commitSha: source.metadata.commitSha,
        githubUrl: source.metadata.githubUrl,
        hasUpdates: source.hasUpdates,
        newSha: source.newSha,
      },
    };

    if (existingIndex >= 0) {
      // Replace existing source with updated content
      context.sources[existingIndex] = contextSource;
    } else {
      // Add new source
      context.sources.push(contextSource);
    }

    // Update token estimate
    const contentTokens = Math.ceil(source.content.length * TOKENS_PER_CHAR);
    context.totalTokenEstimate = (context.totalTokenEstimate || 0) + contentTokens;

    // Update repo structure if not already set
    if (!context.repoStructure) {
      context.repoStructure = {
        owner: source.metadata.owner,
        repo: source.metadata.repo,
        branch: source.metadata.branch,
        files: [source.metadata.path],
      };
    } else if (
      context.repoStructure.owner === source.metadata.owner &&
      context.repoStructure.repo === source.metadata.repo
    ) {
      // Add file to existing repo structure
      if (!context.repoStructure.files.includes(source.metadata.path)) {
        context.repoStructure.files.push(source.metadata.path);
      }
    }

    return context;
  }

  /**
   * Add related files from the same repository to the context.
   * 
   * @param context - Existing CodeContext to enhance
   * @param repoInfo - Repository information
   * @param userId - User ID for authorization
   * @returns Enhanced CodeContext with related files
   */
  async addRelatedFiles(
    context: CodeContext,
    repoInfo: RepoInfo,
    userId: string
  ): Promise<CodeContext> {
    // Find other GitHub sources from the same repo
    const relatedResult = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE n.user_id = $1 
         AND s.type = 'github'
         AND s.metadata->>'owner' = $2
         AND s.metadata->>'repo' = $3
       ORDER BY s.updated_at DESC
       LIMIT 10`,
      [userId, repoInfo.owner, repoInfo.repo]
    );

    if (!context.relatedFiles) {
      context.relatedFiles = [];
    }

    for (const row of relatedResult.rows) {
      const metadata = typeof row.metadata === 'string' 
        ? JSON.parse(row.metadata) 
        : (row.metadata || {});

      // Don't add if already in main sources
      if (context.sources.some(s => s.id === row.id)) {
        continue;
      }

      context.relatedFiles.push({
        path: metadata.path,
        language: metadata.language || 'unknown',
        size: metadata.size || 0,
      });
    }

    // Update repo structure
    if (!context.repoStructure) {
      context.repoStructure = {
        owner: repoInfo.owner,
        repo: repoInfo.repo,
        branch: repoInfo.branch,
        files: context.relatedFiles.map(f => f.path),
      };
    } else {
      // Merge files
      for (const file of context.relatedFiles) {
        if (!context.repoStructure.files.includes(file.path)) {
          context.repoStructure.files.push(file.path);
        }
      }
    }

    return context;
  }

  /**
   * Get context for an MCP-connected coding agent.
   * Includes both GitHub sources and agent-saved code from the notebook.
   * 
   * Requirements: 5.3
   * 
   * @param sessionId - Agent session ID
   * @param notebookId - Notebook ID to get context from
   * @returns CodeContext for the agent
   */
  async getContextForAgent(
    sessionId: string,
    notebookId: string
  ): Promise<CodeContext> {
    // Get the agent session to verify it exists and get user ID
    const sessionResult = await pool.query(
      'SELECT user_id FROM agent_sessions WHERE id = $1',
      [sessionId]
    );

    if (sessionResult.rows.length === 0) {
      throw new Error('Agent session not found');
    }

    const userId = sessionResult.rows[0].user_id;

    // Build context with all source types
    const context = await this.buildContext(notebookId, userId, {
      includeGitHubSources: true,
      includeAgentSources: true,
      includeTextSources: true,
      includeRepoStructure: true,
    });

    // Add session-specific metadata
    return {
      ...context,
      agentSources: context.agentSources?.filter(
        s => s.agentSessionId === sessionId || !s.agentSessionId
      ),
    };
  }

  /**
   * Get context for a specific source (for follow-up messages).
   * 
   * @param sourceId - Source ID
   * @param userId - User ID for authorization
   * @returns CodeContext focused on the specific source
   */
  async getContextForSource(
    sourceId: string,
    userId: string
  ): Promise<CodeContext> {
    // Get the source
    const sourceResult = await pool.query(
      `SELECT s.*, n.id as notebook_id FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2`,
      [sourceId, userId]
    );

    if (sourceResult.rows.length === 0) {
      throw new Error('Source not found or access denied');
    }

    const source = sourceResult.rows[0];
    const notebookId = source.notebook_id;

    // Build context for the notebook, but prioritize the specific source
    const context = await this.buildContext(notebookId, userId, {
      includeGitHubSources: true,
      includeAgentSources: true,
      includeTextSources: false, // Focus on code sources
    });

    // Move the target source to the front
    const targetIndex = context.sources.findIndex(s => s.id === sourceId);
    if (targetIndex > 0) {
      const [targetSource] = context.sources.splice(targetIndex, 1);
      context.sources.unshift(targetSource);
    }

    return context;
  }

  /**
   * Estimate token count for a string.
   * 
   * @param text - Text to estimate
   * @returns Estimated token count
   */
  estimateTokens(text: string): number {
    return Math.ceil(text.length * TOKENS_PER_CHAR);
  }

  /**
   * Format context as a string for AI prompts.
   * 
   * @param context - CodeContext to format
   * @returns Formatted string representation
   */
  formatContextForPrompt(context: CodeContext): string {
    const parts: string[] = [];

    // Add repo structure if available
    if (context.repoStructure) {
      parts.push(`## Repository: ${context.repoStructure.owner}/${context.repoStructure.repo}`);
      parts.push(`Branch: ${context.repoStructure.branch}`);
      if (context.repoStructure.files.length > 0) {
        parts.push(`Files in context: ${context.repoStructure.files.join(', ')}`);
      }
      parts.push('');
    }

    // Add each source
    for (const source of context.sources) {
      parts.push(`## ${source.title}`);
      if (source.type === 'github') {
        parts.push(`Type: GitHub File`);
        parts.push(`Path: ${source.metadata.path}`);
        parts.push(`URL: ${source.metadata.githubUrl}`);
      } else if (source.type === 'code') {
        parts.push(`Type: Code (${source.metadata.agentName || 'User'})`);
        if (source.metadata.verificationScore) {
          parts.push(`Verification Score: ${source.metadata.verificationScore}`);
        }
      }
      if (source.language) {
        parts.push(`Language: ${source.language}`);
      }
      parts.push('```' + (source.language || ''));
      parts.push(source.content);
      parts.push('```');
      parts.push('');
    }

    // Add related files summary
    if (context.relatedFiles && context.relatedFiles.length > 0) {
      parts.push('## Related Files in Repository');
      for (const file of context.relatedFiles) {
        parts.push(`- ${file.path} (${file.language}, ${file.size} bytes)`);
      }
      parts.push('');
    }

    return parts.join('\n');
  }
}

// Export singleton instance
export const unifiedContextBuilder = new UnifiedContextBuilder();
export default unifiedContextBuilder;
