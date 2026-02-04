/**
 * Gitu System Prompt Builder
 * Builds context-aware system prompts for Gitu AI interactions.
 * 
 * This service aggregates:
 * - User identity and preferences
 * - Recent memories and facts
 * - Available MCP tools
 * - Platform-specific context
 */

import { gituIdentityManager } from './gituIdentityManager.js';
import { gituMemoryService } from './gituMemoryService.js';
import { gituMCPHub } from './gituMCPHub.js';
import { gituPluginSystem } from './gituPluginSystem.js';
import { gituRuleEngine } from './gituRuleEngine.js';
import { gituRemoteTerminalService } from './gituRemoteTerminalService.js';
import pool from '../config/database.js';
import { SOUL_DOCUMENT } from '../config/soul.js';

export interface SystemPromptContext {
    userId: string;
    platform?: string;
    sessionId?: string;
    notebookId?: string;
    includeTools?: boolean;
    includeMemories?: boolean;
}

export interface SystemPromptResult {
    systemPrompt: string;
    toolDefinitions?: any[];
    userDisplayName?: string;
}

class GituSystemPromptBuilder {
    /**
     * Build a complete system prompt for Gitu
     */
    async buildSystemPrompt(context: SystemPromptContext): Promise<SystemPromptResult> {
        const { userId, platform = 'web', includeTools = true, includeMemories = true } = context;

        // Gather all context in parallel
        const [userInfo, linkedAccounts, memories, tools, userPlugins, activeRules] = await Promise.all([
            this.getUserInfo(userId),
            this.getLinkedAccounts(userId),
            includeMemories ? this.getRecentMemories(userId) : Promise.resolve([]),
            includeTools ? this.getAvailableTools(userId) : Promise.resolve([]),
            includeTools ? this.getUserPlugins(userId) : Promise.resolve([]),
            includeTools ? this.getActiveRules(userId) : Promise.resolve([]),
        ]);
        const localTerminal = gituRemoteTerminalService.getConnectionSummary(userId);

        // Build the system prompt sections
        const sections: string[] = [];

        // Core identity
        sections.push(this.buildIdentitySection());

        // Soul Document
        sections.push(SOUL_DOCUMENT);

        // User context
        sections.push(this.buildUserSection(userInfo, linkedAccounts, platform));
        sections.push(this.buildLocalTerminalSection(localTerminal));

        // Memories (facts about the user)
        if (memories.length > 0) {
            sections.push(this.buildMemoriesSection(memories));
        }

        // Custom Skills (Plugins & Rules)
        if (userPlugins.length > 0 || activeRules.length > 0) {
            sections.push(this.buildCustomSkillsSection(userPlugins, activeRules));
        }

        // Available tools
        if (tools.length > 0) {
            sections.push(this.buildToolsSection(tools));
        }

        // Behavioral guidelines
        sections.push(this.buildGuidelinesSection());

        const systemPrompt = sections.join('\n\n');

        return {
            systemPrompt,
            toolDefinitions: tools.length > 0 ? this.formatToolsForAI(tools) : undefined,
            userDisplayName: userInfo?.displayName,
        };
    }

    /**
     * Build a minimal system prompt (for quick/cheap calls)
     */
    async buildMinimalPrompt(userId: string): Promise<string> {
        const userInfo = await this.getUserInfo(userId);
        const userName = userInfo?.displayName || 'there';

        return `You are Gitu, a helpful AI assistant for NotebookLLM.

${SOUL_DOCUMENT}

You are talking to ${userName}.
Be helpful, concise, and friendly.`;
    }

    private buildIdentitySection(): string {
        return `# About You

You are **Gitu**, the AI assistant for NotebookLLM. NotebookLLM is a knowledge management platform that helps users organize research, take notes, and learn from their documents.

## Your Personality
- You are helpful, knowledgeable, and friendly
- You speak conversationally but professionally
- You remember things the user tells you
- You can access the user's notebooks and documents when asked
- You proactively offer to help with related tasks

## Platform Persona
- **WhatsApp**: When replying on WhatsApp (unless it's a "Note to Self"), you act as the user's personal AI agent or secretary. You represent the user ("I am replying on behalf of [User]"). Adopt a professional yet helpful tone suitable for the user's contacts. If the user asks you to "reply like me", try to match their likely tone based on context.`;
    }

    private buildUserSection(
        userInfo: { displayName?: string; email?: string } | null,
        linkedAccounts: Array<{ platform: string; displayName?: string }>,
        currentPlatform: string
    ): string {
        const userName = userInfo?.displayName || 'there';
        const platformsConnected = linkedAccounts.map(a => a.platform).join(', ') || 'web';

        return `# About This User

- **Name**: ${userName}
- **Current Platform**: ${currentPlatform}
- **Connected Platforms**: ${platformsConnected}

Address the user by their name when appropriate. Remember details they share about themselves.`;
    }

    private buildLocalTerminalSection(localTerminal: { connected: boolean; devices: Array<{ deviceId: string; deviceName: string; capabilities: string[] }> }): string {
        if (!localTerminal.connected) {
            return `# Local Computer Access

- **Local Terminal**: not connected

If the user asks you to use their local computer, you must ask them to connect the Gitu CLI remote terminal. Once connected, you can run local commands using execute_command with sandboxed=false.`;
        }

        const deviceLines = localTerminal.devices
            .map(d => `- ${d.deviceName} (${d.deviceId})${d.capabilities.length ? ` [${d.capabilities.join(', ')}]` : ''}`)
            .join('\n');

        return `# Local Computer Access

- **Local Terminal**: connected
- **Devices**:
${deviceLines}

When the user asks to use their local computer or files, use execute_command with sandboxed=false to run commands on their machine. Use shell commands like ls/dir, rg, find, or PowerShell equivalents to search local files. If execution is denied, ask the user to grant shell permission and allow unsandboxed execution.`;
    }

    private buildMemoriesSection(memories: Array<{ content: string; category?: string; confidence?: number }>): string {
        const memoryLines = memories
            .filter(m => m.confidence === undefined || m.confidence >= 0.5)
            .slice(0, 20)
            .map(m => `- ${m.content}`)
            .join('\n');

        return `# What You Know About This User

These are facts and preferences you've learned about the user from past conversations:

${memoryLines}

Use this knowledge to personalize your responses, but don't mention that you "remember" things unless the user asks.`;
    }

    private buildCustomSkillsSection(
        plugins: Array<{ name: string; description: string }>,
        rules: Array<{ name: string; trigger: string }>
    ): string {
        let section = `# Your Custom Capabilities\n\n`;
        section += `You have access to the following user-defined skills and automation rules. You should proactively use them when relevant to the user's request.\n\n`;

        if (plugins.length > 0) {
            section += `### User Plugins (Custom Tools)\n`;
            section += plugins.map(p => `- **${p.name}**: ${p.description}`).join('\n');
            section += `\nTo use a plugin, call 'run_user_plugin' with the plugin name. If you need to know more about it, call 'learn_plugin' first.\n\n`;
        }

        if (rules.length > 0) {
            section += `### Active Automation Rules\n`;
            section += rules.map(r => `- **${r.name}** (Trigger: ${r.trigger})`).join('\n');
            section += `\nThese rules run automatically based on their triggers. You can manage them using 'list_rules', 'create_rule', or 'delete_rule'.\n`;
        }

        return section;
    }

    private buildToolsSection(tools: Array<{ name: string; description: string }>): string {
        const toolLines = tools
            .map(t => `- **${t.name}**: ${t.description}`)
            .join('\n');

        return `# Available Tools

You have access to the following tools to help the user:

${toolLines}

When the user asks you to do something that requires a tool, use the appropriate tool. For example:
- "List my notebooks" → use list_notebooks
- "Search for documents about AI" → use search_sources
- "Show me this source" → use get_source
- "Check my WhatsApp messages" → use list_messages with platform="whatsapp"
- "Read my last 5 messages" → use list_messages with limit=5
- "Post a status on WhatsApp saying 'Busy coding'" → use post_whatsapp_status with content="Busy coding"
- "Remind me to drink water tomorrow at 9am" → use schedule_reminder with datetime="tomorrow at 9am"
- "Send me 'hi' every 2 minutes" → use schedule_reminder with cron="*/2 * * * *" and message="hi". DO NOT ask for a specific time.
- "Remind me every Monday at 10am" → use schedule_reminder with cron="0 10 * * 1"

**Important for Scheduling:**
When the user says "every X minutes/hours/days" or any repeating interval, use the 'cron' parameter directly. Do NOT ask them for a specific datetime or "how many times". Generate the CRON expression yourself.
Common CRON patterns:
- "every 5 minutes": */5 * * * *
- "every hour": 0 * * * *
- "every day at 9am": 0 9 * * *
- "every Monday at 10am": 0 10 * * 1

**Canceling Reminders:**
- "Stop the hi reminder" → use cancel_reminder with name="hi"
- "Cancel all my reminders" → use cancel_reminder with name="" and cancelAll=true (or list_reminders first then cancel)
- "Stop sending me messages" → use cancel_reminder with cancelAll=true to stop all active reminders
You do NOT need to know the reminder ID. Just use the 'name' parameter with the keyword from the user's message.

**User Plugins (Custom Skills):**
Users can create custom plugins/skills that extend your capabilities. Use these tools:
- list_user_plugins → Discover what custom plugins the user has created
- learn_plugin → Read the plugin's code to understand how to use it (expected inputs, what it returns)
- run_user_plugin → Execute a plugin by name or ID
- create_user_plugin → Help users create new plugins (JavaScript code)
- delete_user_plugin → Remove a plugin

**Self-Learning Process:**
When you encounter a plugin you haven't used before, use learn_plugin FIRST to:
1. Read the plugin's code
2. Understand what inputs it expects
3. See what it returns
Then you can call run_user_plugin with the correct input.

When a user asks you to do something you can't do natively, check if they have a custom plugin for it!
Example: "Run my daily report plugin" → use learn_plugin first, then run_user_plugin with correct input
`;
    }

    private buildGuidelinesSection(): string {
        return `# Guidelines

1. **Be Proactive**: If you can help with something related to what the user asked, offer to do it.
2. **Use Tools**: When the user asks for data you can retrieve, use your tools.
3. **Remember**: Store important facts the user shares for future conversations.
4. **Be Clear**: If you can't do something, explain why and suggest alternatives.
5. **Stay Focused**: Keep responses relevant and avoid unnecessary verbosity.`;
    }

    private formatToolsForAI(tools: Array<{ name: string; description: string; inputSchema?: any }>): any[] {
        return tools.map(tool => ({
            type: 'function',
            function: {
                name: tool.name,
                description: tool.description,
                parameters: tool.inputSchema || { type: 'object', properties: {} },
            },
        }));
    }

    private async getUserInfo(userId: string): Promise<{ displayName?: string; email?: string } | null> {
        try {
            const result = await pool.query(
                `SELECT display_name, email FROM users WHERE id = $1`,
                [userId]
            );
            if (result.rows.length === 0) return null;
            return {
                displayName: result.rows[0].display_name,
                email: result.rows[0].email,
            };
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching user info:', error);
            return null;
        }
    }

    private async getLinkedAccounts(userId: string): Promise<Array<{ platform: string; displayName?: string }>> {
        try {
            const accounts = await gituIdentityManager.listLinkedAccounts(userId);
            return accounts.map(a => ({
                platform: a.platform,
                displayName: a.display_name ?? undefined,
            }));
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching linked accounts:', error);
            return [];
        }
    }

    private async getRecentMemories(userId: string): Promise<Array<{ content: string; category?: string; confidence?: number }>> {
        try {
            const memories = await gituMemoryService.listMemories(userId, { limit: 30 });
            return memories.map(m => ({
                content: m.content,
                category: m.category,
                confidence: m.confidence,
            }));
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching memories:', error);
            return [];
        }
    }

    private async getUserPlugins(userId: string): Promise<Array<{ name: string; description: string }>> {
        try {
            const plugins = await gituPluginSystem.listPlugins(userId, { enabled: true });
            const eligible = plugins.filter(p => !(p.config?.disableModelInvocation === true));
            return eligible.map(p => ({
                name: p.name,
                description: p.description || 'No description',
            }));
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching plugins:', error);
            return [];
        }
    }

    private async getActiveRules(userId: string): Promise<Array<{ name: string; trigger: string }>> {
        try {
            const rules = await gituRuleEngine.listRules(userId, { enabled: true });
            return rules.map(r => ({
                name: r.name,
                trigger: r.trigger.type,
            }));
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching rules:', error);
            return [];
        }
    }

    private async getAvailableTools(userId: string): Promise<Array<{ name: string; description: string; inputSchema?: any }>> {
        try {
            const tools = await gituMCPHub.listTools(userId);
            return tools.map(t => ({
                name: t.name,
                description: t.description,
                inputSchema: t.inputSchema,
            }));
        } catch (error) {
            console.error('[SystemPromptBuilder] Error fetching tools:', error);
            return [];
        }
    }
}

export const gituSystemPromptBuilder = new GituSystemPromptBuilder();
export default gituSystemPromptBuilder;
