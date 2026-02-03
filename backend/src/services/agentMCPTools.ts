import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import pool from '../config/database.js';

/**
 * Tool: Get Agent Status
 */
const getAgentStatusTool: MCPTool = {
    name: 'gitu_get_agent_status',
    description: 'Get the current status of the AI agent swarm. Use this when the user asks "how many agents are working" or "check agent status". Returns counts of active, pending, and completed agents.',
    schema: {
        type: 'object',
        properties: {},
        required: []
    },
    handler: async (args: any, context: MCPContext) => {
        const result = await pool.query(
            `SELECT status, COUNT(*) as count 
             FROM gitu_agents 
             WHERE user_id = $1 
             GROUP BY status`,
            [context.userId]
        );

        const stats = result.rows.reduce((acc: any, row: any) => {
            acc[row.status] = parseInt(row.count, 10);
            return acc;
        }, {
            pending: 0,
            active: 0,
            completed: 0,
            failed: 0
        });

        // Get details of active agents
        const activeAgentsResult = await pool.query(
            `SELECT id, task, created_at, updated_at 
             FROM gitu_agents 
             WHERE user_id = $1 AND status = 'active'
             ORDER BY updated_at DESC
             LIMIT 5`,
            [context.userId]
        );

        return {
            summary: stats,
            activeAgents: activeAgentsResult.rows,
            totalActive: stats.active + stats.pending
        };
    }
};

/**
 * Register Agent Tools
 */
export function registerAgentTools() {
    gituMCPHub.registerTool(getAgentStatusTool);
    console.log('[AgentMCPTools] Registered Agent Introspection tools');
}
