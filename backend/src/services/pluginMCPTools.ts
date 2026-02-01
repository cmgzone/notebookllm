/**
 * Plugin MCP Tools
 * Allows the AI to discover and execute user-defined plugins
 */

import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituPluginSystem } from './gituPluginSystem.js';

/**
 * Tool: List User Plugins
 * Lets the AI discover what custom plugins/skills the user has created
 */
const listUserPluginsTool: MCPTool = {
    name: 'list_user_plugins',
    description: 'List all custom plugins/skills the user has created. Use this to discover what custom capabilities are available.',
    schema: {
        type: 'object',
        properties: {
            enabledOnly: {
                type: 'boolean',
                description: 'Only show enabled plugins',
                default: true
            }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { enabledOnly = true } = args;

        const plugins = await gituPluginSystem.listPlugins(context.userId, {
            enabled: enabledOnly ? true : undefined
        });

        if (plugins.length === 0) {
            return {
                plugins: [],
                message: 'No custom plugins found. The user can create plugins to extend your capabilities!'
            };
        }

        return {
            plugins: plugins.map(p => ({
                id: p.id,
                name: p.name,
                description: p.description || 'No description provided',
                enabled: p.enabled,
                entrypoint: p.entrypoint
            })),
            message: `Found ${plugins.length} custom plugin(s). You can run them using the run_user_plugin tool.`
        };
    }
};

/**
 * Tool: Run User Plugin
 * Executes a user-defined plugin by name or ID
 */
const runUserPluginTool: MCPTool = {
    name: 'run_user_plugin',
    description: 'Execute a custom plugin/skill that the user has created. Use list_user_plugins first to see available plugins.',
    schema: {
        type: 'object',
        properties: {
            pluginId: {
                type: 'string',
                description: 'The ID of the plugin to run (from list_user_plugins)'
            },
            pluginName: {
                type: 'string',
                description: 'The name of the plugin to run (alternative to pluginId, will search by name)'
            },
            input: {
                type: 'object',
                description: 'Input data to pass to the plugin'
            }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { pluginId, pluginName, input } = args;

        if (!pluginId && !pluginName) {
            throw new Error('Please provide either pluginId or pluginName');
        }

        let targetPluginId = pluginId;

        // If name provided, search for matching plugin
        if (!targetPluginId && pluginName) {
            const plugins = await gituPluginSystem.listPlugins(context.userId, { enabled: true });
            const match = plugins.find(p =>
                p.name.toLowerCase().includes(pluginName.toLowerCase())
            );

            if (!match) {
                throw new Error(`No enabled plugin found matching "${pluginName}". Use list_user_plugins to see available plugins.`);
            }

            targetPluginId = match.id;
        }

        // Execute the plugin
        const result = await gituPluginSystem.executePlugin(
            context.userId,
            targetPluginId,
            input,
            {
                sessionId: context.sessionId,
                notebookId: context.notebookId,
                invokedBy: 'ai'
            }
        );

        if (!result.success) {
            return {
                success: false,
                error: result.error,
                logs: result.logs,
                message: `Plugin execution failed: ${result.error}`
            };
        }

        return {
            success: true,
            result: result.result,
            logs: result.logs,
            durationMs: result.durationMs,
            message: 'Plugin executed successfully'
        };
    }
};

/**
 * Tool: Create User Plugin
 * Allows the AI to help users create new plugins
 */
const createUserPluginTool: MCPTool = {
    name: 'create_user_plugin',
    description: 'Create a new custom plugin/skill for the user. The plugin code runs in a sandboxed environment with access to gitu.files and gitu.shell APIs.',
    schema: {
        type: 'object',
        properties: {
            name: {
                type: 'string',
                description: 'Name of the plugin (e.g., "Daily Report Generator")'
            },
            description: {
                type: 'string',
                description: 'What the plugin does'
            },
            code: {
                type: 'string',
                description: 'JavaScript code for the plugin. Must export a function named "run" that receives { input, config, gitu }'
            },
            enabled: {
                type: 'boolean',
                description: 'Whether the plugin is enabled immediately',
                default: true
            }
        },
        required: ['name', 'code']
    },
    handler: async (args: any, context: MCPContext) => {
        const { name, description, code, enabled = true } = args;

        // Validate first
        const validation = gituPluginSystem.validatePlugin({
            name,
            code,
            entrypoint: 'run',
            enabled
        });

        if (!validation.valid) {
            return {
                success: false,
                errors: validation.errors,
                message: `Plugin validation failed: ${validation.errors.join(', ')}`
            };
        }

        // Create the plugin
        const plugin = await gituPluginSystem.createPlugin(context.userId, {
            name,
            description,
            code,
            entrypoint: 'run',
            enabled
        });

        return {
            success: true,
            pluginId: plugin.id,
            name: plugin.name,
            message: `Plugin "${name}" created successfully! You can now run it using run_user_plugin.`
        };
    }
};

/**
 * Tool: Delete User Plugin
 */
const deleteUserPluginTool: MCPTool = {
    name: 'delete_user_plugin',
    description: 'Delete a custom plugin by ID or name',
    schema: {
        type: 'object',
        properties: {
            pluginId: { type: 'string', description: 'The ID of the plugin to delete' },
            pluginName: { type: 'string', description: 'The name of the plugin to delete (if ID not known)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { pluginId, pluginName } = args;

        if (!pluginId && !pluginName) {
            throw new Error('Please provide either pluginId or pluginName');
        }

        let targetPluginId = pluginId;

        if (!targetPluginId && pluginName) {
            const plugins = await gituPluginSystem.listPlugins(context.userId);
            const match = plugins.find(p =>
                p.name.toLowerCase().includes(pluginName.toLowerCase())
            );

            if (!match) {
                throw new Error(`No plugin found matching "${pluginName}"`);
            }

            targetPluginId = match.id;
        }

        const deleted = await gituPluginSystem.deletePlugin(context.userId, targetPluginId);

        if (!deleted) {
            throw new Error('Plugin not found or could not be deleted');
        }

        return {
            success: true,
            message: 'Plugin deleted successfully'
        };
    }
};

/**
 * Register Plugin MCP Tools
 */
export function registerPluginMCPTools() {
    gituMCPHub.registerTool(listUserPluginsTool);
    gituMCPHub.registerTool(runUserPluginTool);
    gituMCPHub.registerTool(createUserPluginTool);
    gituMCPHub.registerTool(deleteUserPluginTool);
    console.log('[PluginMCPTools] Registered user plugin tools (list, run, create, delete)');
}
