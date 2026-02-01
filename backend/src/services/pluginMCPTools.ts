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
    description: 'Create a new custom plugin/skill for the user. Supports sandboxed JS plugins and container plugins (plugin.yaml + files).',
    schema: {
        type: 'object',
        properties: {
            type: {
                type: 'string',
                description: 'Plugin type: "js" (sandboxed) or "container" (plugin.yaml + files)',
                enum: ['js', 'container'],
                default: 'js'
            },
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
                description: 'For type="js": JavaScript code. For type="container": plugin.yaml content'
            },
            files: {
                type: 'object',
                description: 'For type="container": map of filename -> content (must include the manifest entry file)'
            },
            config: {
                type: 'object',
                description: 'Optional config object stored with the plugin'
            },
            enabled: {
                type: 'boolean',
                description: 'Whether the plugin is enabled immediately',
                default: true
            }
        },
        required: ['code']
    },
    handler: async (args: any, context: MCPContext) => {
        const { type = 'js', name, description, code, files, config, enabled = true } = args;

        const payload: any = {
            name,
            description,
            code,
            enabled,
        };
        if (type === 'container' || files) {
            payload.config = { ...(typeof config === 'object' && config !== null ? config : {}), files: files || {} };
        } else {
            payload.entrypoint = 'run';
            if (typeof config === 'object' && config !== null) payload.config = config;
        }

        const validation = gituPluginSystem.validatePlugin(payload);

        if (!validation.valid) {
            return {
                success: false,
                errors: validation.errors,
                message: `Plugin validation failed: ${validation.errors.join(', ')}`
            };
        }

        // Create the plugin
        const plugin = await gituPluginSystem.createPlugin(context.userId, payload);

        return {
            success: true,
            pluginId: plugin.id,
            name: plugin.name,
            message: `Plugin "${plugin.name}" created successfully! You can now run it using run_user_plugin.`
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
 * Tool: Learn Plugin
 * Allows the AI to read and understand a plugin's code to learn how to use it
 */
const learnPluginTool: MCPTool = {
    name: 'learn_plugin',
    description: "Read a plugin's code and configuration to understand how to use it. Use this to learn what inputs a plugin expects and what it returns.",
    schema: {
        type: 'object',
        properties: {
            pluginId: { type: 'string', description: 'The ID of the plugin to learn about' },
            pluginName: { type: 'string', description: 'The name of the plugin to learn about (alternative to pluginId)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { pluginId, pluginName } = args;

        if (!pluginId && !pluginName) {
            throw new Error('Please provide either pluginId or pluginName');
        }

        let targetPlugin: Awaited<ReturnType<typeof gituPluginSystem.getPlugin>> = null;

        if (pluginId) {
            targetPlugin = await gituPluginSystem.getPlugin(context.userId, pluginId);
        } else if (pluginName) {
            const plugins = await gituPluginSystem.listPlugins(context.userId);
            targetPlugin = plugins.find(p =>
                p.name.toLowerCase().includes(pluginName.toLowerCase())
            ) || null;
        }

        if (!targetPlugin) {
            throw new Error('Plugin not found');
        }

        // Analyze the code to extract useful information
        const codeAnalysis = analyzePluginCode(targetPlugin.code);

        return {
            id: targetPlugin.id,
            name: targetPlugin.name,
            description: targetPlugin.description || 'No description provided',
            enabled: targetPlugin.enabled,
            entrypoint: targetPlugin.entrypoint,
            code: targetPlugin.code,
            config: targetPlugin.config,
            analysis: codeAnalysis,
            usageHint: `To run this plugin, use run_user_plugin with pluginName="${targetPlugin.name}" and provide the expected input as described in the analysis.`
        };
    }
};

/**
 * Analyze plugin code to extract useful information for the AI
 */
function analyzePluginCode(code: string): {
    usesFiles: boolean;
    usesShell: boolean;
    expectedInputFields: string[];
    returnType: string;
} {
    const usesFiles = code.includes('gitu.files');
    const usesShell = code.includes('gitu.shell');

    // Try to extract input field names from destructuring patterns
    const inputMatch = code.match(/const\s*\{([^}]+)\}\s*=\s*(?:ctx\.)?input/);
    const expectedInputFields = inputMatch
        ? inputMatch[1].split(',').map(s => s.trim().split(':')[0].trim()).filter(Boolean)
        : [];

    // Try to detect return type
    let returnType = 'unknown';
    if (code.includes('return {')) returnType = 'object';
    else if (code.includes('return [')) returnType = 'array';
    else if (code.includes('return "') || code.includes("return '")) returnType = 'string';

    return { usesFiles, usesShell, expectedInputFields, returnType };
}

/**
 * Tool: Create Container Plugin
 * Allows the AI to help users create new secure containerized plugins
 */
const createContainerPluginTool: MCPTool = {
    name: 'create_container_plugin',
    description: 'Create a new secure containerized plugin. This is the preferred method for creating robust tools with dependencies.',
    schema: {
        type: 'object',
        properties: {
            name: {
                type: 'string',
                description: 'Name of the plugin (e.g., "Web Scraper")'
            },
            description: {
                type: 'string',
                description: 'What the plugin does'
            },
            manifest: {
                type: 'string',
                description: 'The plugin.yaml content describing runtime and permissions'
            },
            files: {
                type: 'object',
                description: 'Map of filenames to content (e.g., {"index.py": "print(1)", "requirements.txt": "requests"})'
            },
            enabled: {
                type: 'boolean',
                default: true
            }
        },
        required: ['name', 'manifest', 'files']
    },
    handler: async (args: any, context: MCPContext) => {
        const { name, description, manifest, files, enabled = true } = args;

        // 1. Validate Manifest
        try {
            // Import dynamically to avoid top-level cyclic deps if any
            const { PluginManifestParser } = await import('./plugins/pluginManifest.js');
            PluginManifestParser.parse(manifest);
        } catch (e: any) {
            return {
                success: false,
                message: `Invalid plugin.yaml: ${e.message}`
            };
        }

        // 2. Store Plugin
        // We use the same `gitu_plugins` table but store files in `config.files`
        const plugin = await gituPluginSystem.createPlugin(context.userId, {
            name,
            description,
            code: manifest, // Store manifest as the main "code"
            entrypoint: 'container', // Marker for container plugin
            config: { files }, // Store actual code files here
            enabled
        });

        return {
            success: true,
            pluginId: plugin.id,
            name: plugin.name,
            message: `Container plugin "${name}" created successfully! It runs in a secure Docker sandbox.`
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
    gituMCPHub.registerTool(createContainerPluginTool); // New tool
    gituMCPHub.registerTool(deleteUserPluginTool);
    gituMCPHub.registerTool(learnPluginTool);
    console.log('[PluginMCPTools] Registered user plugin tools (list, run, create, create_container, delete, learn)');
}
