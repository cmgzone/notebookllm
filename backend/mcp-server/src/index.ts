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
 * - get_quota: Get current MCP usage quota and limits
 * - list_notebooks: List all notebooks with source counts
 * - get_source: Get a specific source by ID
 * - search_sources: Search across all code sources
 * - update_source: Update existing source without quota hit
 * 
 * Agent Communication Tools (Requirements 1.1, 1.2, 2.1-2.3, 3.2, 3.3, 5.1):
 * - create_agent_notebook: Create a dedicated notebook for the agent
 * - save_code_with_context: Save code with conversation context
 * - get_followup_messages: Poll for user messages
 * - respond_to_followup: Send response to user
 * - register_webhook: Register webhook for receiving messages
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
  // ==================== AGENT COMMUNICATION TOOLS ====================
  {
    name: 'create_agent_notebook',
    description: `Create a dedicated notebook for this coding agent. This is idempotent - calling multiple times with the same agent identifier returns the existing notebook.
    
Use this tool to:
- Set up a workspace for storing verified code
- Establish a session for bidirectional communication with the user
- Configure webhook endpoints for receiving follow-up messages

Returns:
- notebook: The created/existing notebook with ID, title, description
- session: The agent session with ID, status, and configuration`,
    inputSchema: {
      type: 'object',
      properties: {
        agentName: {
          type: 'string',
          description: 'Display name of the coding agent (e.g., "Claude", "Kiro", "Cursor")',
        },
        agentIdentifier: {
          type: 'string',
          description: 'Unique identifier for this agent type (e.g., "claude-3-opus", "kiro-v1")',
        },
        title: {
          type: 'string',
          description: 'Optional custom title for the notebook (defaults to "{agentName} Code")',
        },
        description: {
          type: 'string',
          description: 'Optional description for the notebook',
        },
        webhookUrl: {
          type: 'string',
          description: 'Optional webhook URL for receiving follow-up messages',
        },
        webhookSecret: {
          type: 'string',
          description: 'Optional shared secret for webhook authentication',
        },
        metadata: {
          type: 'object',
          description: 'Optional additional metadata to store with the session',
        },
      },
      required: ['agentName', 'agentIdentifier'],
    },
  },
  {
    name: 'save_code_with_context',
    description: `Save verified code to the agent's notebook with full conversation context.
    
This tool:
- Associates the code with the agent's notebook
- Stores the conversation context that led to this code
- Links the source to the agent session for follow-up communication
- Optionally verifies the code before saving

Use this instead of verify_and_save when you want to:
- Preserve the conversation history with the code
- Enable the user to send follow-up messages about this code
- Track which agent created the code`,
    inputSchema: {
      type: 'object',
      properties: {
        code: {
          type: 'string',
          description: 'The code to save',
        },
        language: {
          type: 'string',
          description: 'Programming language (javascript, typescript, python, dart, etc.)',
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
          description: 'The agent notebook ID to save to (from create_agent_notebook)',
        },
        agentSessionId: {
          type: 'string',
          description: 'The agent session ID (from create_agent_notebook)',
        },
        conversationContext: {
          type: 'string',
          description: 'The conversation/context that led to this code being created',
        },
        verification: {
          type: 'object',
          description: 'Optional pre-computed verification result',
        },
        strictMode: {
          type: 'boolean',
          description: 'Enable strict verification mode if verifying',
          default: false,
        },
      },
      required: ['code', 'language', 'title', 'notebookId'],
    },
  },
  {
    name: 'get_followup_messages',
    description: `Poll for pending follow-up messages from the user.
    
Use this tool to:
- Check if the user has sent any questions or requests about saved code
- Retrieve messages that need responses
- Get context about which code source the message relates to

Returns messages with:
- Message ID, content, and timestamp
- Source information (title, code, language)
- Conversation history`,
    inputSchema: {
      type: 'object',
      properties: {
        agentSessionId: {
          type: 'string',
          description: 'The agent session ID to check for messages',
        },
        agentIdentifier: {
          type: 'string',
          description: 'Alternative: the agent identifier to look up the session',
        },
      },
    },
  },
  {
    name: 'respond_to_followup',
    description: `Send a response to a user's follow-up message.
    
Use this tool to:
- Answer user questions about saved code
- Provide code updates or modifications
- Continue the conversation about a specific code source

The response will be displayed to the user in the app's chat interface.`,
    inputSchema: {
      type: 'object',
      properties: {
        messageId: {
          type: 'string',
          description: 'The ID of the message being responded to',
        },
        response: {
          type: 'string',
          description: 'The response text to send to the user',
        },
        agentSessionId: {
          type: 'string',
          description: 'The agent session ID',
        },
        codeUpdate: {
          type: 'object',
          description: 'Optional code update to apply to the source',
          properties: {
            code: {
              type: 'string',
              description: 'The updated code',
            },
            description: {
              type: 'string',
              description: 'Description of what changed',
            },
          },
        },
      },
      required: ['messageId', 'response'],
    },
  },
  {
    name: 'register_webhook',
    description: `Register a webhook endpoint to receive follow-up messages in real-time.
    
Instead of polling with get_followup_messages, you can register a webhook to receive messages as they arrive.

The webhook will receive POST requests with:
- type: 'followup_message'
- sourceId, sourceTitle, sourceCode, sourceLanguage
- message: The user's message
- conversationHistory: Previous messages
- userId, timestamp

Webhook requests are signed with HMAC-SHA256 using the provided secret.`,
    inputSchema: {
      type: 'object',
      properties: {
        agentSessionId: {
          type: 'string',
          description: 'The agent session ID to configure',
        },
        agentIdentifier: {
          type: 'string',
          description: 'Alternative: the agent identifier to look up the session',
        },
        webhookUrl: {
          type: 'string',
          description: 'The HTTPS URL to receive webhook requests',
        },
        webhookSecret: {
          type: 'string',
          description: 'Shared secret for HMAC-SHA256 signature verification (min 16 characters)',
        },
      },
      required: ['webhookUrl', 'webhookSecret'],
    },
  },
  {
    name: 'get_websocket_info',
    description: `Get WebSocket connection information for real-time bidirectional communication.
    
WebSocket provides instant message delivery without polling. Connect to receive user messages in real-time and send responses immediately.

Returns:
- WebSocket URL to connect to
- Authentication method (query parameters)
- Message format for sending responses

Use this for the most responsive agent experience.`,
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'get_quota',
    description: `Get your current MCP usage quota and limits.
    
Returns quota information including:
- sourcesLimit/sourcesUsed/sourcesRemaining: Code source storage limits
- tokensLimit/tokensUsed/tokensRemaining: API token limits
- apiCallsLimit/apiCallsUsed/apiCallsRemaining: Daily API call limits
- isPremium: Whether user has premium plan
- isMcpEnabled: Whether MCP is enabled by administrator

Use this to check your remaining quota before saving sources or making API calls.`,
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'list_notebooks',
    description: `List all your notebooks with their source counts.
    
Returns a list of notebooks including:
- id, title, description, icon
- isAgentNotebook: Whether created by an agent
- sourceCount: Number of code sources in the notebook
- createdAt, updatedAt

Use this to find notebooks to save code to or to browse your previous work.`,
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'get_source',
    description: `Get a specific code source by ID.
    
Returns the full source including:
- id, title, notebookId, notebookTitle
- content: The full code
- language, verification result
- agentName: Which agent created it
- originalContext: The conversation context when created
- createdAt, updatedAt

Use this to retrieve previously saved code for reference or modification.`,
    inputSchema: {
      type: 'object',
      properties: {
        sourceId: {
          type: 'string',
          description: 'The ID of the source to retrieve',
        },
      },
      required: ['sourceId'],
    },
  },
  {
    name: 'search_sources',
    description: `Search across all your code sources.
    
Search by:
- query: Text to search in title and code content
- language: Filter by programming language
- notebookId: Filter by specific notebook

Returns matching sources with:
- id, title, notebookId, notebookTitle
- language, isVerified, agentName
- contentPreview: First 200 characters of code

Use this to find relevant code from previous sessions.`,
    inputSchema: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Text to search for in title and code content',
        },
        language: {
          type: 'string',
          description: 'Filter by programming language (e.g., typescript, python)',
        },
        notebookId: {
          type: 'string',
          description: 'Filter by specific notebook ID',
        },
        limit: {
          type: 'number',
          description: 'Maximum results to return (default: 20)',
          default: 20,
        },
      },
    },
  },
  {
    name: 'update_source',
    description: `Update an existing code source without using quota.
    
Update:
- code: The new code content
- title: New title
- description: New description
- language: Change language
- revalidate: Re-run verification on updated code

This does NOT count against your source quota - use it to iterate on existing code.

Returns the updated source and optionally new verification results.`,
    inputSchema: {
      type: 'object',
      properties: {
        sourceId: {
          type: 'string',
          description: 'The ID of the source to update',
        },
        code: {
          type: 'string',
          description: 'The updated code content',
        },
        title: {
          type: 'string',
          description: 'New title for the source',
        },
        description: {
          type: 'string',
          description: 'New description',
        },
        language: {
          type: 'string',
          description: 'Change the programming language',
        },
        revalidate: {
          type: 'boolean',
          description: 'Re-run code verification after update',
          default: false,
        },
      },
      required: ['sourceId'],
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

// ==================== AGENT COMMUNICATION SCHEMAS ====================

const CreateAgentNotebookSchema = z.object({
  agentName: z.string().min(1),
  agentIdentifier: z.string().min(1),
  title: z.string().optional(),
  description: z.string().optional(),
  webhookUrl: z.string().url().optional(),
  webhookSecret: z.string().min(16).optional(),
  metadata: z.record(z.any()).optional(),
});

const SaveCodeWithContextSchema = z.object({
  code: z.string().min(1),
  language: z.string().min(1),
  title: z.string().min(1),
  description: z.string().optional(),
  notebookId: z.string().min(1),
  agentSessionId: z.string().optional(),
  conversationContext: z.string().optional(),
  verification: z.object({
    isValid: z.boolean(),
    score: z.number(),
    errors: z.array(z.string()).optional(),
    warnings: z.array(z.string()).optional(),
    suggestions: z.array(z.string()).optional(),
  }).optional(),
  strictMode: z.boolean().optional().default(false),
});

const GetFollowupMessagesSchema = z.object({
  agentSessionId: z.string().optional(),
  agentIdentifier: z.string().optional(),
});

const RespondToFollowupSchema = z.object({
  messageId: z.string().min(1),
  response: z.string().min(1),
  agentSessionId: z.string().optional(),
  codeUpdate: z.object({
    code: z.string(),
    description: z.string().optional(),
  }).optional(),
});

const RegisterWebhookSchema = z.object({
  agentSessionId: z.string().optional(),
  agentIdentifier: z.string().optional(),
  webhookUrl: z.string().url(),
  webhookSecret: z.string().min(16),
});

// ==================== NEW TOOL SCHEMAS ====================

const GetSourceSchema = z.object({
  sourceId: z.string().min(1),
});

const SearchSourcesSchema = z.object({
  query: z.string().optional(),
  language: z.string().optional(),
  notebookId: z.string().optional(),
  limit: z.number().optional().default(20),
});

const UpdateSourceSchema = z.object({
  sourceId: z.string().min(1),
  code: z.string().optional(),
  title: z.string().optional(),
  description: z.string().optional(),
  language: z.string().optional(),
  revalidate: z.boolean().optional().default(false),
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

      // ==================== AGENT COMMUNICATION HANDLERS ====================

      case 'create_agent_notebook': {
        const input = CreateAgentNotebookSchema.parse(args);
        const response = await api.post('/notebooks', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'save_code_with_context': {
        const input = SaveCodeWithContextSchema.parse(args);
        const response = await api.post('/sources/with-context', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'get_followup_messages': {
        const input = GetFollowupMessagesSchema.parse(args);
        const params = new URLSearchParams();
        if (input.agentSessionId) params.append('agentSessionId', input.agentSessionId);
        if (input.agentIdentifier) params.append('agentIdentifier', input.agentIdentifier);
        
        const response = await api.get(`/followups?${params.toString()}`);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'respond_to_followup': {
        const input = RespondToFollowupSchema.parse(args);
        const { messageId, ...body } = input;
        const response = await api.post(`/followups/${messageId}/respond`, body);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'register_webhook': {
        const input = RegisterWebhookSchema.parse(args);
        const response = await api.post('/webhook/register', input);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'get_websocket_info': {
        const response = await api.get('/websocket/info');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'get_quota': {
        const response = await api.get('/quota');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'list_notebooks': {
        const response = await api.get('/notebooks/list');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'get_source': {
        const input = GetSourceSchema.parse(args);
        const response = await api.get(`/sources/${input.sourceId}`);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'search_sources': {
        const input = SearchSourcesSchema.parse(args);
        const params = new URLSearchParams();
        if (input.query) params.append('query', input.query);
        if (input.language) params.append('language', input.language);
        if (input.notebookId) params.append('notebookId', input.notebookId);
        if (input.limit) params.append('limit', input.limit.toString());
        
        const response = await api.get(`/sources/search?${params.toString()}`);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(response.data, null, 2),
            },
          ],
        };
      }

      case 'update_source': {
        const input = UpdateSourceSchema.parse(args);
        const { sourceId, ...body } = input;
        const response = await api.put(`/sources/${sourceId}`, body);
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
