import { mcpLimitsService } from './mcpLimitsService.js';
import { mcpUserSettingsService } from './mcpUserSettingsService.js';
import { gituAgentOrchestrator } from './gituAgentOrchestrator.js';
import { hydrateExternalMcpToolsForUser } from './externalMcpRegistry.js';

export interface MCPToolParameter {
  type: string;
  description?: string;
  enum?: string[];
  default?: any;
  items?: any; // For array types
  properties?: Record<string, MCPToolParameter>; // For nested object types
  required?: string[]; // For required properties in nested objects
}

export interface MCPToolSchema {
  type: 'object';
  properties: Record<string, MCPToolParameter>;
  required?: string[];
}

export interface MCPTool {
  name: string;
  description: string;
  schema: MCPToolSchema;
  handler: (args: any, context: MCPContext) => Promise<any>;
  requiresPremium?: boolean;
  cost?: number; // Cost in credits
}

export interface MCPContext {
  userId: string;
  sessionId?: string;
  notebookId?: string;
}

export interface MCPToolDefinition {
  name: string;
  description: string;
  inputSchema: MCPToolSchema;
}

class GituMCPHub {
  private tools: Map<string, MCPTool> = new Map();
  private userTools: Map<string, Map<string, MCPTool>> = new Map();
  private hydratedUsers: Set<string> = new Set();
  private hydrationPromises: Map<string, Promise<void>> = new Map();

  constructor() {
    // Register built-in tools
    this.registerTool({
      name: 'deploy_swarm',
      description: 'Deploys a multi-agent swarm to execute a complex objective (e.g. comprehensive research, multi-step analysis). Use this when the user asks to "start a swarm", "research deep", or "agent team".',
      schema: {
        type: 'object',
        properties: {
          objective: {
            type: 'string',
            description: 'The complex goal for the swarm to achieve'
          }
        },
        required: ['objective']
      },
      handler: async (args, context) => {
        const mission = await gituAgentOrchestrator.createMission(context.userId, args.objective);
        return {
          success: true,
          missionId: mission.id,
          message: `Swarm deployed for objective: "${args.objective}". Status: ${mission.status}`
        };
      }
    });
  }

  /**
   * Register a new tool
   */
  registerTool(tool: MCPTool) {
    if (this.tools.has(tool.name)) {
      console.warn(`[GituMCPHub] Overwriting tool: ${tool.name}`);
    }
    this.tools.set(tool.name, tool);
  }

  registerUserTool(userId: string, tool: MCPTool) {
    const map = this.userTools.get(userId) ?? new Map<string, MCPTool>();
    map.set(tool.name, tool);
    this.userTools.set(userId, map);
  }

  unregisterUserToolsByPrefix(userId: string, prefix: string) {
    const map = this.userTools.get(userId);
    if (!map) return;
    for (const name of Array.from(map.keys())) {
      if (name.startsWith(prefix)) {
        map.delete(name);
      }
    }
    if (map.size === 0) {
      this.userTools.delete(userId);
    }
  }

  private async hydrateUserTools(userId: string): Promise<void> {
    if (this.hydratedUsers.has(userId)) return;
    const existing = this.hydrationPromises.get(userId);
    if (existing) {
      await existing;
      return;
    }
    const p = (async () => {
      try {
        await hydrateExternalMcpToolsForUser(userId, tool => this.registerUserTool(userId, tool));
      } catch { }
      this.hydratedUsers.add(userId);
    })();
    this.hydrationPromises.set(userId, p);
    await p;
    this.hydrationPromises.delete(userId);
  }

  /**
   * List available tools for a user
   */
  async listTools(userId: string): Promise<MCPToolDefinition[]> {
    const definitions: MCPToolDefinition[] = [];

    await this.hydrateUserTools(userId);

    for (const tool of this.tools.values()) {
      definitions.push({
        name: tool.name,
        description: tool.description,
        inputSchema: tool.schema
      });
    }

    const userMap = this.userTools.get(userId);
    if (userMap) {
      for (const tool of userMap.values()) {
        definitions.push({
          name: tool.name,
          description: tool.description,
          inputSchema: tool.schema
        });
      }
    }

    return definitions;
  }

  /**
   * Execute a tool
   */
  async executeTool(name: string, args: any, context: MCPContext): Promise<any> {
    const tool = this.userTools.get(context.userId)?.get(name) ?? this.tools.get(name);
    if (!tool) {
      throw new Error(`Tool not found: ${name}`);
    }

    // 1. Quota/Limit Check
    await this.checkLimits(tool, context.userId);

    try {
      // 2. Execution
      const result = await tool.handler(args, context);

      // 3. Post-execution tracking (if needed, e.g. logging usage)
      await this.trackUsage(tool, context.userId);

      return result;
    } catch (error: any) {
      console.error(`[GituMCPHub] Error executing tool ${name}:`, error);
      throw new Error(`Tool execution failed: ${error.message}`);
    }
  }

  /**
   * Check if user is allowed to execute the tool
   */
  private async checkLimits(tool: MCPTool, userId: string): Promise<void> {
    const usage = await mcpLimitsService.getUserUsage(userId);
    const quota = await mcpLimitsService.getUserQuota(userId);

    if (!quota.isMcpEnabled) {
      throw new Error('MCP is currently disabled');
    }

    if (quota.apiCallsRemaining <= 0) {
      throw new Error('Daily API call limit reached');
    }

    if (tool.requiresPremium && !quota.isPremium) {
      throw new Error('This tool requires a premium subscription');
    }
  }

  /**
   * Track tool usage
   */
  private async trackUsage(tool: MCPTool, userId: string): Promise<void> {
    await mcpLimitsService.incrementApiUsage(userId);
  }
}

export const gituMCPHub = new GituMCPHub();
export default gituMCPHub;
