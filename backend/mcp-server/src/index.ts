#!/usr/bin/env node
/**
 * Coding Agent MCP Server
 * 
 * This MCP server exposes code verification tools that third-party
 * coding agents can use to verify code and save it as sources.
 * 
 * Tools provided:
 * - verify_code: Verify code for correctness, security, and best practices
 * - verify_and_save: Verify code and save as source if valid
 * - batch_verify: Verify multiple code snippets at once
 * - analyze_code: Deep analysis with suggestions
 * - get_verified_sources: Retrieve saved verified sources
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';
import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const API_KEY = process.env.CODING_AGENT_API_KEY || '';

// Axios instance for backend communication
const api = axios.create({
  baseURL: `${BACKEND_URL}/api/coding-agent`,
  headers: {
    'Content-Type': 'application/json',
    ...(API_KEY && { 'Authorization': `Bearer ${API_KEY}` }),
  },
  timeout: 30000,
});

// Tool definitions
const tools: Tool[] = [
  {
    name: 'verify_code',
    description: `Verify code for correctness, security vulnerabilities, and best practices.
Returns a verification result with:
- isValid: Whether the code passes critical checks
- score: Quality score from 0-100
- errors: Critical issues that must be fixed
- warnings: Non-critical issues to consider
- suggestions: Improvement recommendations`,
    inputSchema: {
      type: 'object',
      properties: {
        code: {
          type: 'string',
          description: 'The code to verify',
        },
        language: {
          type: 'string',
          description: 'Programming language (javascript, typescript, python, dart, json, etc.)',
        },
        context: {
          type: 'string',
          description: 'Optional context about what the code should do',
        },
        strictMode: {
          type: 'boolean',
          description: 'Enable strict verification mode for more thorough analysis',
          default: false,
        },
      },
      required: ['code', 'language'],
    },
  },
  {
    name: 'verify_and_save',
    description: `Verify code and save it as a source in the app if it passes verification (score >= 60).
The code will be stored and can be retrieved later for reference.`,
    inputSchema: {
      type: 'object',
      properties: {
        code: {
          type: 'string',
          description: 'The code to verify and save',
        },
        language: {
          type: 'string',
          description: 'Programming language',
        },
        title: {
          type: 'string',
          description: 'Title for the code source',
        },
        description: {
          type: 'string',
          description: 'Description of what the code does',
        },
        notebookId: {
          type: 'string',
          description: 'Optional notebook ID to associate the source with',
        },
        context: {
          type: 'string',
          description: 'Optional context for verification',
        },
        strictMode: {
          type: 'boolean',
          description: 'Enable strict verification mode',
          default: false,
        },
      },
      required: ['code', 'language', 'title'],
    },
  },
  {
    name: 'batch_verify',
    description: `Verify multiple code snippets at once. Returns individual results and a summary.`,
    inputSchema: {
      type: 'object',
      properties: {
        snippets: {
          type: 'array',
          description: 'Array of code snippets to verify',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string', description: 'Unique identifier for the snippet' },
              code: { type: 'string', description: 'The code to verify' },
              language: { type: 'string', description: 'Programming language' },
              context: { type: 'string', description: 'Optional context' },
              strictMode: { type: 'boolean', description: 'Strict mode' },
            },
            required: ['id', 'code', 'language'],
          },
        },
      },
      required: ['snippets'],
    },
  },
  {
    name: 'analyze_code',
    description: `Perform deep analysis of code with comprehensive suggestions for improvement.
Uses strict mode by default for thorough analysis.`,
    inputSchema: {
      type: 'object',
      properties: {
        code: {
          type: 'string',
          description: 'The code to analyze',
        },
        language: {
          type: 'string',
          description: 'Programming language',
        },
        analysisType: {
          type: 'string',
          description: 'Type of analysis: performance, security, readability, or comprehensive',
          enum: ['performance', 'security', 'readability', 'comprehensive'],
          default: 'comprehensive',
        },
      },
      required: ['code', 'language'],
    },
  },
  {
    name: 'get_verified_sources',
    description: `Retrieve previously saved verified code sources.`,
    inputSchema: {
      type: 'object',
      properties: {
        notebookId: {
          type: 'string',
          description: 'Filter by notebook ID',
        },
        language: {
          type: 'string',
          description: 'Filter by programming language',
        },
      },
    },
  },
];


// Input validation schemas
const VerifyCodeSchema = z.object({
  code: z.string().min(1),
  language: z.string().min(1),
  context: z.string().optional(),
  strictMode: z.boolean().optional().default(false),
});

const VerifyAndSaveSchema = z.object({
  code: z.string().min(1),
  language: z.string().min(1),
  title: z.string().min(1),
  description: z.string().optional(),
  notebookId: z.string().optional(),
  context: z.string().optional(),
  strictMode: z.boolean().optional().default(false),
});

const BatchVerifySchema = z.object({
  snippets: z.array(z.object({
    id: z.string(),
    code: z.string(),
    language: z.string(),
    context: z.string().optional(),
    strictMode: z.boolean().optional(),
  })),
});

const AnalyzeCodeSchema = z.object({
  code: z.string().min(1),
  language: z.string().min(1),
  analysisType: z.enum(['performance', 'security', 'readability', 'comprehensive']).optional().default('comprehensive'),
});

const GetSourcesSchema = z.object({
  notebookId: z.string().optional(),
  language: z.string().optional(),
});

// Create MCP Server
const server = new Server(
  {
    name: 'coding-agent-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Handle list tools request
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request: any) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'verify_code': {
        const input = VerifyCodeSchema.parse(args);
        const response = await api.post('/verify', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'verify_and_save': {
        const input = VerifyAndSaveSchema.parse(args);
        const response = await api.post('/verify-and-save', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'batch_verify': {
        const input = BatchVerifySchema.parse(args);
        const response = await api.post('/batch-verify', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'analyze_code': {
        const input = AnalyzeCodeSchema.parse(args);
        const response = await api.post('/analyze', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'get_verified_sources': {
        const input = GetSourcesSchema.parse(args);
        const params = new URLSearchParams();
        if (input.notebookId) params.append('notebookId', input.notebookId);
        if (input.language) params.append('language', input.language);
        
        const response = await api.get(`/sources?${params.toString()}`);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    const errorMessage = error.response?.data?.error || error.message || 'Unknown error';
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: false,
            error: errorMessage,
            details: error.response?.data || null,
          }, null, 2),
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Coding Agent MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
