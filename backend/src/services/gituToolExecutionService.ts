/**
 * Gitu Tool Execution Service
 * Orchestrates the execution of MCP tools during AI conversations.
 * 
 * This service handles the tool execution loop:
 * 1. AI receives user message + available tools
 * 2. AI may request to call a tool
 * 3. Service executes the tool and returns result to AI
 * 4. AI generates final response
 */

import { gituMCPHub, MCPContext } from './gituMCPHub.js';
import { gituAIRouter, AIRequest, AIResponse } from './gituAIRouter.js';
import { gituSystemPromptBuilder } from './gituSystemPromptBuilder.js';

const MAX_TOOL_CALLS = 5; // Prevent infinite loops

export interface ToolCall {
    name: string;
    arguments: Record<string, any>;
}

export interface ToolResult {
    name: string;
    result: any;
    error?: string;
}

export interface ConversationTurn {
    role: 'user' | 'assistant' | 'system' | 'tool';
    content: string;
    toolCalls?: ToolCall[];
    toolResults?: ToolResult[];
}

export interface ToolExecutionResult {
    response: string;
    toolsUsed: ToolResult[];
    model: string;
    tokensUsed: number;
}

class GituToolExecutionService {
    /**
     * Process a user message with tool execution capability.
     * This handles the full conversation loop including tool calls.
     */
    async processWithTools(
        userId: string,
        userMessage: string,
        conversationHistory: ConversationTurn[] = [],
        options: {
            platform?: string;
            sessionId?: string;
            notebookId?: string;
        } = {}
    ): Promise<ToolExecutionResult> {
        const { platform = 'web', sessionId, notebookId } = options;
        const toolsUsed: ToolResult[] = [];

        // Get available tools
        const tools = await gituMCPHub.listTools(userId);

        // Build tool instructions if tools are available
        let toolInstructions = '';
        if (tools.length > 0) {
            toolInstructions = this.buildToolInstructions(tools);
        }

        // Build context from conversation history
        const contextMessages = conversationHistory.map(turn => turn.content);

        // Combine user message with tool instructions
        const fullPrompt = toolInstructions
            ? `${userMessage}\n\n${toolInstructions}`
            : userMessage;

        let currentPrompt = fullPrompt;
        let toolCallCount = 0;
        let finalResponse = '';
        let tokensUsed = 0;
        let selectedModel = '';

        // Tool execution loop
        while (toolCallCount < MAX_TOOL_CALLS) {
            // Use gituAIRouter to select and call the appropriate model
            const aiRequest: AIRequest = {
                userId,
                sessionId,
                prompt: currentPrompt,
                context: contextMessages,
                taskType: 'chat',
                platform,
                includeSystemPrompt: true,
                includeTools: true,
            };

            const aiResponse = await gituAIRouter.route(aiRequest);
            selectedModel = aiResponse.model;
            tokensUsed += aiResponse.tokensUsed;

            // Check if AI wants to call a tool
            const toolCall = this.parseToolCall(aiResponse.content);

            if (toolCall) {
                toolCallCount++;
                console.log(`[ToolExecution] Tool call ${toolCallCount}: ${toolCall.name} (using model: ${selectedModel})`);

                // Execute the tool
                const result = await this.executeTool(toolCall, { userId, sessionId, notebookId });
                toolsUsed.push(result);

                // Update context with tool result for next iteration
                contextMessages.push(`I'll use the ${toolCall.name} tool to help with that.`);
                contextMessages.push(`Tool result for ${toolCall.name}:\n${JSON.stringify(result.result, null, 2)}${result.error ? `\nError: ${result.error}` : ''}`);

                // Update prompt for next iteration
                currentPrompt = `Based on the tool result above, please provide your response to the user's original request: ${userMessage}`;

                // Continue the loop to let AI process the result
                continue;
            }

            // No tool call, this is the final response
            finalResponse = aiResponse.content;
            break;
        }

        if (toolCallCount >= MAX_TOOL_CALLS) {
            console.warn(`[ToolExecution] Max tool calls reached for user ${userId}`);
            finalResponse = finalResponse || "I've reached the limit of actions I can take. Here's what I found so far.";
        }

        return {
            response: finalResponse,
            toolsUsed,
            model: selectedModel || 'unknown',
            tokensUsed,
        };
    }

    /**
     * Build tool instructions for the AI.
     */
    private buildToolInstructions(tools: Array<{ name: string; description: string; inputSchema?: any }>): string {
        const toolDocs = tools.map(t => {
            const params = t.inputSchema?.properties
                ? Object.entries(t.inputSchema.properties)
                    .map(([key, val]: [string, any]) => `  - ${key}: ${val.description || val.type}`)
                    .join('\n')
                : '  (no parameters)';
            return `### ${t.name}\n${t.description}\nParameters:\n${params}`;
        }).join('\n\n');

        return `# How to Use Tools

When you need to use a tool, respond with ONLY a JSON block in this exact format:
\`\`\`tool
{
  "tool": "tool_name",
  "args": { "param1": "value1" }
}
\`\`\`

Available tools:

${toolDocs}

After I execute the tool, I'll give you the result. Then provide your final answer to the user.
If you don't need a tool, just respond normally without the tool block.`;
    }

    /**
     * Parse AI response for tool calls.
     */
    private parseToolCall(response: string): ToolCall | null {
        // Look for tool call block
        const toolMatch = response.match(/```tool\s*\n?([\s\S]*?)\n?```/);

        if (!toolMatch) {
            // Also try JSON-only format
            const jsonMatch = response.match(/\{\s*"tool"\s*:\s*"([^"]+)"/);
            if (jsonMatch) {
                try {
                    const parsed = JSON.parse(response.trim());
                    if (parsed.tool) {
                        return {
                            name: parsed.tool,
                            arguments: parsed.args || {},
                        };
                    }
                } catch {
                    // Not valid JSON
                }
            }
            return null;
        }

        try {
            const parsed = JSON.parse(toolMatch[1].trim());
            if (parsed.tool) {
                return {
                    name: parsed.tool,
                    arguments: parsed.args || {},
                };
            }
        } catch (e) {
            console.warn('[ToolExecution] Failed to parse tool call:', e);
        }

        return null;
    }

    /**
     * Execute a tool call.
     */
    private async executeTool(toolCall: ToolCall, context: MCPContext): Promise<ToolResult> {
        try {
            const result = await gituMCPHub.executeTool(
                toolCall.name,
                toolCall.arguments,
                context
            );

            return {
                name: toolCall.name,
                result,
            };
        } catch (error: any) {
            console.error(`[ToolExecution] Error executing ${toolCall.name}:`, error);
            return {
                name: toolCall.name,
                result: null,
                error: error.message || 'Tool execution failed',
            };
        }
    }
}

export const gituToolExecutionService = new GituToolExecutionService();
export default gituToolExecutionService;
