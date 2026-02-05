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

const MAX_TOOL_CALLS = 10; // Prevent infinite loops while allowing more complex workflows

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
    private readonly verboseLogs =
        process.env.GITU_LOG_LEVEL === 'debug' || process.env.GITU_LOG_VERBOSE === 'true';
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
        const toolNames = tools.map(t => t.name);

        // IMPORTANT: Detect common patterns and force tool execution
        // This prevents AI from hallucinating when it should use tools
        const forcedTool = this.detectForcedTool(userMessage, toolNames);
        if (forcedTool) {
            if (this.verboseLogs) {
                console.log(`[ToolExecution] Forcing tool call: ${forcedTool.name} for user request`);
            }

            // Execute the tool directly
            const result = await this.executeTool(forcedTool, { userId, sessionId, notebookId, platform });
            toolsUsed.push(result);

            if (result.error) {
                return {
                    response: this.formatToolResultFallback(forcedTool.name, result, userId),
                    toolsUsed,
                    model: 'fallback',
                    tokensUsed: 0,
                };
            }

            // Now ask AI to format the result nicely
            const formatPrompt = this.buildResultFormattingPrompt(userMessage, forcedTool.name, result);

            const aiRequest: AIRequest = {
                userId,
                sessionId,
                prompt: formatPrompt,
                context: conversationHistory.map(turn => turn.content),
                taskType: 'chat',
                platform,
                includeSystemPrompt: true,
                includeTools: false, // Don't include tools for formatting step
            };

            try {
            const aiResponse = await gituAIRouter.route(aiRequest);
            return {
                response: aiResponse.content,
                toolsUsed,
                model: aiResponse.model,
                    tokensUsed: aiResponse.tokensUsed,
                };
            } catch (error) {
                // If AI fails, format the result ourselves
                console.warn('[ToolExecution] AI formatting failed, using raw result');
                return {
                    response: this.formatToolResultFallback(forcedTool.name, result, userId),
                    toolsUsed,
                    model: 'fallback',
                    tokensUsed: 0,
                };
            }
        }

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
                if (this.verboseLogs) {
                    console.log(`[ToolExecution] Tool call ${toolCallCount}: ${toolCall.name} (using model: ${selectedModel})`);
                }

                if (toolCall.name === 'send_voice_note' && !this.isExplicitVoiceRequest(userMessage)) {
                    const wantsEnglish = /\b(english|in english|use english)\b/i.test(userMessage);
                    const textOnlyPrompt = `The user did not explicitly request a voice note. Respond in text only${wantsEnglish ? ' and in English' : ''}.\n\nUser request: ${userMessage}`;
                    const textOnlyResponse = await gituAIRouter.route({
                        userId,
                        sessionId,
                        prompt: textOnlyPrompt,
                        context: contextMessages,
                        taskType: 'chat',
                        platform,
                        includeSystemPrompt: true,
                        includeTools: false,
                    });
                    finalResponse = textOnlyResponse.content;
                    selectedModel = textOnlyResponse.model;
                    tokensUsed += textOnlyResponse.tokensUsed;
                    break;
                }

                if (!this.isToolAllowed(toolCall.name, userMessage)) {
                    finalResponse = this.buildConfirmationPrompt(toolCall.name, userMessage);
                    break;
                }

                // Execute the tool
                const result = await this.executeTool(toolCall, { userId, sessionId, notebookId, platform });
                toolsUsed.push(result);

                if (result.error) {
                    finalResponse = this.formatToolResultFallback(toolCall.name, result, userId);
                    break;
                }

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
     * Detect if we should force a specific tool call based on user message.
     * This bypasses AI tool selection which can fail or hallucinate.
     */
    private detectForcedTool(userMessage: string, availableTools: string[]): ToolCall | null {
        const msg = userMessage.toLowerCase();

        // Notebook-related queries → force list_notebooks
        if (availableTools.includes('list_notebooks')) {
            const notebookPatterns = [
                /\b(list|show|what|tell me|get|my)\b.*(notebook|notebooks)/i,
                /\bnotebook(s)?\b.*\b(have|list|show|access)/i,
                /how many notebooks/i,
                /^notebooks?$/i,
            ];
            for (const pattern of notebookPatterns) {
                if (pattern.test(msg)) {
                    return { name: 'list_notebooks', arguments: { limit: 20, offset: 0 } };
                }
            }
        }

        // Reminder-related queries → force list_reminders
        if (availableTools.includes('list_reminders')) {
            const reminderPatterns = [
                /\b(list|show|what|my)\b.*(reminder|reminders)/i,
                /^reminders?$/i,
            ];
            for (const pattern of reminderPatterns) {
                if (pattern.test(msg)) {
                    return { name: 'list_reminders', arguments: {} };
                }
            }
        }

        // Memory/fact-related queries → force recall_facts
        if (availableTools.includes('recall_facts')) {
            const factPatterns = [
                /what (do you|did you) (know|remember) about me/i,
                /\b(recall|remember|what).*(facts?|about me)/i,
            ];
            for (const pattern of factPatterns) {
                if (pattern.test(msg)) {
                    return { name: 'recall_facts', arguments: { limit: 10 } };
                }
            }
        }

        // Swarm/Research-related queries → force deploy_swarm
        if (availableTools.includes('deploy_swarm') && this.isExplicitSwarmRequest(userMessage)) {
            return { name: 'deploy_swarm', arguments: { objective: userMessage } };
        }

        return null;
    }

    private isExplicitSwarmRequest(userMessage: string): boolean {
        const msg = userMessage.toLowerCase();
        return (
            /\b(swarm|agent swarm|agent team|team of agents|agent group|multi-agent)\b/i.test(msg) ||
            /\b(deploy|start|create|spin up)\s+(a\s+)?swarm\b/i.test(msg)
        );
    }

    private isExplicitAgentRequest(userMessage: string): boolean {
        const msg = userMessage.toLowerCase();
        return (
            this.isExplicitSwarmRequest(userMessage) ||
            /\b(spawn|create|start)\s+(an?\s+)?agent\b/i.test(msg) ||
            /\buse\s+an?\s+agent\b/i.test(msg)
        );
    }

    private isExplicitVoiceRequest(userMessage: string): boolean {
        const msg = userMessage.toLowerCase();
        if (/\b(stop|disable|no|dont|don't|do not)\b.*\b(voice|audio)\b/i.test(msg)) {
            return false;
        }
        return (
            /\b(voice note|voice message|audio note)\b/i.test(msg) ||
            /\b(send|record)\b.*\b(voice|audio)\b/i.test(msg) ||
            /\b(read it out|say it out loud|speak it)\b/i.test(msg)
        );
    }

    private isToolAllowed(toolName: string, userMessage: string): boolean {
        if (toolName === 'deploy_swarm') return this.isExplicitSwarmRequest(userMessage);
        if (toolName === 'spawn_agent') return this.isExplicitAgentRequest(userMessage);
        return true;
    }

    private buildConfirmationPrompt(toolName: string, userMessage: string): string {
        const objective = this.clampText(userMessage.trim(), 160);
        if (toolName === 'deploy_swarm') {
            return [
                '**Confirmation Required**',
                'I can deploy a swarm of agents, but I need explicit confirmation.',
                '',
                `Action: Deploy swarm`,
                `Goal: "${objective}"`,
                '',
                'Reply with one of:',
                `1. "Deploy swarm: ${objective}" to proceed`,
                '2. "No" to cancel',
            ].join('\n');
        }
        if (toolName === 'spawn_agent') {
            return [
                '**Confirmation Required**',
                'I can spawn a dedicated agent, but I need explicit confirmation.',
                '',
                `Action: Spawn agent`,
                `Task: "${objective}"`,
                '',
                'Reply with one of:',
                `1. "Spawn agent: ${objective}" to proceed`,
                '2. "No" to cancel',
            ].join('\n');
        }
        return `I can do that, but I need explicit confirmation.`;
    }

    private clampText(text: string, max: number): string {
        if (text.length <= max) return text;
        return `${text.slice(0, max - 1).trim()}…`;
    }

    /**
     * Build a prompt to have AI format tool results nicely.
     */
    private buildResultFormattingPrompt(originalRequest: string, toolName: string, result: ToolResult): string {
        const resultJson = JSON.stringify(result.result, null, 2);
        return `The user asked: "${originalRequest}"

I executed the ${toolName} tool and got this result:
${resultJson}
${result.error ? `Error: ${result.error}` : ''}

Please provide a friendly, well-formatted response to the user based on this ACTUAL data. Do NOT make up or hallucinate any information - only use what is in the result above.`;
    }

    /**
     * Format tool result as fallback when AI is unavailable.
     */
    private formatToolResultFallback(toolName: string, result: ToolResult, userId?: string): string {
        if (result.error) {
            if (toolName === 'execute_command') {
                const raw = String(result.error);
                const marker = 'LOCAL_ACCESS_NOT_GRANTED';
                if (raw.includes(marker)) {
                    const message = raw.split(marker)[1]?.replace(/^[:\s-]+/, '').trim();
                    return message && message.length > 0
                        ? message
                        : 'Local access not yet granted. Connect the Gitu CLI remote terminal and approve shell access, then try again.';
                }
            }
            return `❌ Error executing ${toolName}: ${result.error}`;
        }

        if (toolName === 'list_notebooks' && result.result?.notebooks) {
            const notebooks = result.result.notebooks;
            if (notebooks.length === 0) {
                return `**No notebooks found.** 😕\n\nI can see your account is linked, but I didn't find any notebooks in the database.\n\n**Troubleshooting:**\n1. Ensure you have created notebooks in the app.\n2. Check if your app is connected to the same server/database.\n3. Your User ID is: \`${userId || 'unknown'}\``;
            }
            const lines = notebooks.map((nb: any, i: number) =>
                `${i + 1}. **${nb.title}**${nb.is_agent_notebook ? ' [agent]' : ''} - ${nb.source_count || 0} sources`
            );
            return `📚 **Your Notebooks (${notebooks.length}):**\n\n${lines.join('\n')}`;
        }

        if (toolName === 'list_reminders' && result.result?.reminders) {
            const reminders = result.result.reminders;
            if (reminders.length === 0) {
                return "You don't have any active reminders.";
            }
            const lines = reminders.map((r: any, i: number) =>
                `${i + 1}. ${r.name} (${r.enabled ? '✅ active' : '❌ disabled'})`
            );
            return `⏰ **Your Reminders:**\n\n${lines.join('\n')}`;
        }

        // Generic fallback
        return `Here's what I found:\n\`\`\`json\n${JSON.stringify(result.result, null, 2)}\n\`\`\``;
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
     * Returns the tool call if found, or null if no tool call.
     * IMPORTANT: If a tool call is found, any text after the tool block should be ignored
     * because the AI may have "hallucinated" continuation text.
     */
    private parseToolCall(response: string): ToolCall | null {
        // Look for tool call block with backticks
        const toolMatch = response.match(/```tool\s*\n?([\s\S]*?)\n?```/);

        if (toolMatch) {
            try {
                const parsed = JSON.parse(toolMatch[1].trim());
                if (parsed.tool) {
                    if (this.verboseLogs) {
                        console.log(`[ToolExecution] Detected tool call: ${parsed.tool}`);
                    }
                    return {
                        name: parsed.tool,
                        arguments: parsed.args || {},
                    };
                }
            } catch (e) {
                console.warn('[ToolExecution] Failed to parse tool call from block:', e);
            }
        }

        // Also try to find JSON directly (without backticks) - more lenient parsing
        // Look for patterns like: {"tool": "...", "args": {...}}
        const jsonPatterns = [
            /\{\s*"tool"\s*:\s*"([^"]+)"\s*,\s*"args"\s*:\s*(\{[^}]*\})\s*\}/,
            /\{\s*['"]tool['"]\s*:\s*['"]([^'"]+)['"]/
        ];

        for (const pattern of jsonPatterns) {
            const match = response.match(pattern);
            if (match) {
                try {
                    // Try to extract the full JSON object
                    const startIdx = response.indexOf('{', match.index);
                    let braceCount = 0;
                    let endIdx = startIdx;

                    for (let i = startIdx; i < response.length; i++) {
                        if (response[i] === '{') braceCount++;
                        if (response[i] === '}') braceCount--;
                        if (braceCount === 0) {
                            endIdx = i + 1;
                            break;
                        }
                    }

                    const jsonStr = response.substring(startIdx, endIdx);
                    const parsed = JSON.parse(jsonStr);

                    if (parsed.tool) {
                        if (this.verboseLogs) {
                            console.log(`[ToolExecution] Detected tool call (JSON format): ${parsed.tool}`);
                        }
                        return {
                            name: parsed.tool,
                            arguments: parsed.args || {},
                        };
                    }
                } catch {
                    // Continue to next pattern
                }
            }
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
