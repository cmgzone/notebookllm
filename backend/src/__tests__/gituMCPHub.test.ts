import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { gituMCPHub, MCPTool, MCPContext } from '../services/gituMCPHub.js';
import { mcpLimitsService } from '../services/mcpLimitsService.js';

describe('GituMCPHub', () => {
  const mockUserId = 'user-123';
  const mockContext: MCPContext = { userId: mockUserId };
  
  const mockTool: MCPTool = {
    name: 'test_tool',
    description: 'A test tool',
    schema: {
      type: 'object',
      properties: {
        arg1: { type: 'string' }
      }
    },
    handler: jest.fn(async (args: any) => {
      return { result: `Executed with ${args.arg1}` };
    })
  };

  beforeEach(() => {
    jest.restoreAllMocks();
    // Reset hub tools (if possible, or just register unique ones)
    // Since gituMCPHub is a singleton, we might need to be careful.
    // For this test, we register a tool.
    gituMCPHub.registerTool(mockTool);
  });

  it('should list registered tools', async () => {
    const tools = await gituMCPHub.listTools(mockUserId);
    expect(tools).toContainEqual({
      name: mockTool.name,
      description: mockTool.description,
      inputSchema: mockTool.schema
    });
  });

  it('should execute a tool successfully when limits are not exceeded', async () => {
    // Mock quota check to pass
    jest.spyOn(mcpLimitsService, 'getUserQuota').mockResolvedValue({
      isMcpEnabled: true,
      apiCallsRemaining: 100,
      isPremium: true
    } as any);
    jest.spyOn(mcpLimitsService, 'getUserUsage').mockResolvedValue({} as any);
    jest.spyOn(mcpLimitsService, 'incrementApiUsage').mockResolvedValue();

    const result = await gituMCPHub.executeTool('test_tool', { arg1: 'foo' }, mockContext);
    
    expect(result).toEqual({ result: 'Executed with foo' });
    expect(mockTool.handler).toHaveBeenCalledWith({ arg1: 'foo' }, mockContext);
    expect(mcpLimitsService.incrementApiUsage).toHaveBeenCalledWith(mockUserId);
  });

  it('should throw error when tool not found', async () => {
    await expect(gituMCPHub.executeTool('non_existent', {}, mockContext))
      .rejects.toThrow('Tool not found');
  });

  it('should throw error when MCP is disabled', async () => {
    jest.spyOn(mcpLimitsService, 'getUserQuota').mockResolvedValue({
      isMcpEnabled: false
    } as any);
    jest.spyOn(mcpLimitsService, 'getUserUsage').mockResolvedValue({} as any);

    await expect(gituMCPHub.executeTool('test_tool', {}, mockContext))
      .rejects.toThrow('MCP is currently disabled');
  });

  it('should throw error when API limit reached', async () => {
    jest.spyOn(mcpLimitsService, 'getUserQuota').mockResolvedValue({
      isMcpEnabled: true,
      apiCallsRemaining: 0
    } as any);
    jest.spyOn(mcpLimitsService, 'getUserUsage').mockResolvedValue({} as any);

    await expect(gituMCPHub.executeTool('test_tool', {}, mockContext))
      .rejects.toThrow('Daily API call limit reached');
  });

  it('should throw error for premium tool on free plan', async () => {
    const premiumTool: MCPTool = {
      ...mockTool,
      name: 'premium_tool',
      requiresPremium: true
    };
    gituMCPHub.registerTool(premiumTool);

    jest.spyOn(mcpLimitsService, 'getUserQuota').mockResolvedValue({
      isMcpEnabled: true,
      apiCallsRemaining: 100,
      isPremium: false
    } as any);
    jest.spyOn(mcpLimitsService, 'getUserUsage').mockResolvedValue({} as any);

    await expect(gituMCPHub.executeTool('premium_tool', {}, mockContext))
      .rejects.toThrow('requires a premium subscription');
  });
});
