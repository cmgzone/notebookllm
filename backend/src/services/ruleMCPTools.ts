import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituRuleEngine, RuleTrigger, RuleCondition, RuleAction } from './gituRuleEngine.js';

/**
 * Tool: List Automation Rules
 */
const listRulesTool: MCPTool = {
    name: 'list_rules',
    description: 'List all automation rules defined by the user.',
    schema: {
        type: 'object',
        properties: {
            enabledOnly: {
                type: 'boolean',
                description: 'Filter to show only enabled rules',
                default: false
            }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { enabledOnly } = args;
        const rules = await gituRuleEngine.listRules(context.userId, { enabled: enabledOnly });
        
        if (rules.length === 0) {
            return {
                rules: [],
                message: 'No automation rules found.'
            };
        }

        return {
            rules: rules.map(r => ({
                id: r.id,
                name: r.name,
                description: r.description,
                enabled: r.enabled,
                trigger: r.trigger.type,
                actions: r.actions.length
            })),
            message: `Found ${rules.length} rule(s).`
        };
    }
};

/**
 * Tool: Create Automation Rule
 */
const createRuleTool: MCPTool = {
    name: 'create_rule',
    description: 'Create a new automation rule with triggers, conditions, and actions.',
    schema: {
        type: 'object',
        properties: {
            name: { type: 'string', description: 'Name of the rule' },
            description: { type: 'string', description: 'Description of what the rule does' },
            trigger: {
                type: 'object',
                description: 'Trigger configuration (e.g., { type: "manual" } or { type: "event", eventType: "user_login" })',
                properties: {
                    type: { type: 'string', enum: ['manual', 'event'] },
                    eventType: { type: 'string' }
                },
                required: ['type']
            },
            conditions: {
                type: 'array',
                description: 'List of conditions (e.g., [{ type: "equals", path: "user.role", value: "admin" }])',
                items: {
                    type: 'object',
                    properties: {
                        type: { type: 'string', enum: ['equals', 'contains', 'exists'] },
                        path: { type: 'string' },
                        value: { type: ['string', 'number', 'boolean'] }
                    },
                    required: ['type', 'path']
                }
            },
            actions: {
                type: 'array',
                description: 'List of actions to perform (e.g., [{ type: "shell.execute", command: "echo hello" }])',
                items: {
                    type: 'object',
                    properties: {
                        type: { type: 'string', enum: ['shell.execute', 'files.write', 'files.read', 'files.list'] },
                        command: { type: 'string' },
                        args: { type: 'array', items: { type: 'string' } },
                        path: { type: 'string' },
                        content: { type: 'string' },
                        cwd: { type: 'string' },
                        timeoutMs: { type: 'number' },
                        sandboxed: { type: 'boolean' }
                    },
                    required: ['type']
                }
            },
            enabled: { type: 'boolean', default: true }
        },
        required: ['name', 'trigger', 'actions']
    },
    handler: async (args: any, context: MCPContext) => {
        try {
            const rule = await gituRuleEngine.createRule(context.userId, args);
            return {
                success: true,
                ruleId: rule.id,
                name: rule.name,
                message: `Rule "${rule.name}" created successfully.`
            };
        } catch (e: any) {
            return {
                success: false,
                error: e.message
            };
        }
    }
};

/**
 * Tool: Delete Automation Rule
 */
const deleteRuleTool: MCPTool = {
    name: 'delete_rule',
    description: 'Delete an automation rule by ID or name.',
    schema: {
        type: 'object',
        properties: {
            ruleId: { type: 'string', description: 'ID of the rule to delete' },
            ruleName: { type: 'string', description: 'Name of the rule to delete (if ID unknown)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { ruleId, ruleName } = args;
        
        if (!ruleId && !ruleName) {
            throw new Error('Please provide either ruleId or ruleName');
        }

        let targetId = ruleId;

        if (!targetId && ruleName) {
            const rules = await gituRuleEngine.listRules(context.userId);
            const match = rules.find(r => r.name.toLowerCase() === ruleName.toLowerCase());
            if (!match) throw new Error(`Rule "${ruleName}" not found.`);
            targetId = match.id;
        }

        const deleted = await gituRuleEngine.deleteRule(context.userId, targetId);
        
        if (!deleted) {
            throw new Error('Rule not found or could not be deleted');
        }

        return {
            success: true,
            message: 'Rule deleted successfully'
        };
    }
};

/**
 * Register Rule MCP Tools
 */
export function registerRuleMCPTools() {
    gituMCPHub.registerTool(listRulesTool);
    gituMCPHub.registerTool(createRuleTool);
    gituMCPHub.registerTool(deleteRuleTool);
    console.log('[RuleMCPTools] Registered automation rule tools');
}
