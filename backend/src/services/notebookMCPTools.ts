import pool from '../config/database.js';
import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { codeVerificationService } from './codeVerificationService.js';
import { codeReviewService } from './codeReviewService.js';

/**
 * Tool: List Notebooks
 */
const listNotebooksTool: MCPTool = {
  name: 'list_notebooks',
  description: 'List all notebooks accessible to the user',
  schema: {
    type: 'object',
    properties: {
      limit: { type: 'number', description: 'Max number of notebooks to return', default: 20 },
      offset: { type: 'number', description: 'Pagination offset', default: 0 }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const limit = Math.min(args.limit || 20, 50);
    const offset = args.offset || 0;

    const result = await pool.query(
      `SELECT id, title, description, is_agent_notebook, created_at, updated_at,
              (SELECT COUNT(*) FROM sources WHERE notebook_id = notebooks.id) as source_count
       FROM notebooks
       WHERE user_id = $1
       ORDER BY updated_at DESC
       LIMIT $2 OFFSET $3`,
      [context.userId, limit, offset]
    );

    return {
      notebooks: result.rows
    };
  }
};

/**
 * Tool: Get Source
 */
const getSourceTool: MCPTool = {
  name: 'get_source',
  description: 'Get a specific source by ID',
  schema: {
    type: 'object',
    properties: {
      sourceId: { type: 'string', description: 'The ID of the source to retrieve' }
    },
    required: ['sourceId']
  },
  handler: async (args: any, context: MCPContext) => {
    const result = await pool.query(
      `SELECT s.*, n.title as notebook_title
       FROM sources s
       JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2`,
      [args.sourceId, context.userId]
    );

    if (result.rows.length === 0) {
      throw new Error('Source not found or access denied');
    }

    return {
      source: result.rows[0]
    };
  }
};

/**
 * Tool: Search Sources
 */
const searchSourcesTool: MCPTool = {
  name: 'search_sources',
  description: 'Search for sources across all notebooks',
  schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Search query' },
      limit: { type: 'number', description: 'Max results', default: 10 },
      notebookId: { type: 'string', description: 'Filter by notebook ID' }
    },
    required: ['query']
  },
  handler: async (args: any, context: MCPContext) => {
    const { query, limit = 10, notebookId } = args;
    const params: any[] = [context.userId, `%${query}%`, limit];
    let querySql = `
      SELECT s.id, s.title, s.type, s.notebook_id, n.title as notebook_title,
             substring(s.content from 1 for 200) as snippet
      FROM sources s
      JOIN notebooks n ON s.notebook_id = n.id
      WHERE n.user_id = $1 AND (s.title ILIKE $2 OR s.content ILIKE $2)
    `;

    if (notebookId) {
      querySql += ` AND s.notebook_id = $4`;
      params.push(notebookId);
    }

    querySql += ` ORDER BY s.updated_at DESC LIMIT $3`;

    const result = await pool.query(querySql, params);

    return {
      matches: result.rows
    };
  }
};

/**
 * Tool: Verify Code
 */
const verifyCodeTool: MCPTool = {
  name: 'verify_code',
  description: 'Verify code for correctness, security, and best practices',
  schema: {
    type: 'object',
    properties: {
      code: { type: 'string', description: 'The code to verify' },
      language: { type: 'string', description: 'Programming language' },
      context: { type: 'string', description: 'Optional context about the code' },
      strictMode: { type: 'boolean', description: 'Enable strict verification', default: false }
    },
    required: ['code', 'language']
  },
  handler: async (args: any, context: MCPContext) => {
    return await codeVerificationService.verifyCode({
      code: args.code,
      language: args.language,
      context: args.context,
      strictMode: args.strictMode
    });
  }
};

/**
 * Tool: Review Code
 */
const reviewCodeTool: MCPTool = {
  name: 'review_code',
  description: 'Perform a comprehensive AI code review',
  requiresPremium: true, // Assuming review is a premium feature
  schema: {
    type: 'object',
    properties: {
      code: { type: 'string', description: 'The code to review' },
      language: { type: 'string', description: 'Programming language' },
      reviewType: { 
        type: 'string', 
        enum: ['comprehensive', 'security', 'performance', 'readability'],
        default: 'comprehensive'
      },
      context: { type: 'string', description: 'Optional context' }
    },
    required: ['code', 'language']
  },
  handler: async (args: any, context: MCPContext) => {
    return await codeReviewService.reviewCode(
      context.userId,
      args.code,
      args.language,
      args.reviewType,
      args.context,
      false // Don't save review to DB for ephemeral tool calls by default, or maybe true?
             // Let's set to false to avoid cluttering history unless explicitly asked, 
             // but `codeReviewService` returns a saved review object usually.
             // The service saves if `saveReview` is true. 
             // Let's keep it false for now as this is likely an interactive session.
    );
  }
};

// Register all tools
export function registerNotebookTools() {
  gituMCPHub.registerTool(listNotebooksTool);
  gituMCPHub.registerTool(getSourceTool);
  gituMCPHub.registerTool(searchSourcesTool);
  gituMCPHub.registerTool(verifyCodeTool);
  gituMCPHub.registerTool(reviewCodeTool);
  console.log('[NotebookMCPTools] Registered notebook tools');
}
