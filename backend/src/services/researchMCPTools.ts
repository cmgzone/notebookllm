import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { performCloudResearch, ResearchDepth, ResearchTemplate } from './researchService.js';

/**
 * Tool: Deep Research
 * Performs comprehensive web research and generates a detailed report.
 */
const deepResearchTool: MCPTool = {
    name: 'deep_research',
    description: 'Perform comprehensive web research on any topic. Returns a detailed report and sources.',
    requiresPremium: true,
    schema: {
        type: 'object',
        properties: {
            query: { type: 'string', description: 'The research topic or question' },
            depth: {
                type: 'string',
                enum: ['quick', 'standard', 'deep'],
                description: 'How thorough the research should be'
            },
            template: {
                type: 'string',
                enum: ['general', 'academic', 'productComparison', 'marketAnalysis', 'howToGuide', 'prosAndCons'],
                description: 'The structure of the resulting report'
            }
        },
        required: ['query']
    },
    handler: async (args: any, context: MCPContext) => {
        const { query, depth = 'standard', template = 'general' } = args;

        console.log(`[ResearchTool] Starting research for user ${context.userId}: "${query}"`);

        const result = await performCloudResearch(context.userId, query, {
            depth: depth as ResearchDepth,
            template: template as ResearchTemplate,
            notebookId: context.notebookId
        });

        return {
            success: true,
            report: result.report,
            sourceCount: result.sources.length,
            sessionId: result.sessionId
        };
    }
};

/**
 * Tool: Web Search
 * Performs a quick web search and returns organic results.
 */
const webSearchTool: MCPTool = {
    name: 'search_web',
    description: 'Perform a web search to find current information and links.',
    schema: {
        type: 'object',
        properties: {
            query: { type: 'string', description: 'The search query' },
            limit: { type: 'number', description: 'Max results to return', default: 5 }
        },
        required: ['query']
    },
    handler: async (args: any, context: MCPContext) => {
        // Dynamically import to avoid circular dependency if any, 
        // although researchService is a standalone file.
        const { searchWeb } = await import('./researchService.js');

        const results = await searchWeb(args.query, args.limit || 5);

        return {
            results: results.map(r => ({
                title: r.title,
                url: r.link,
                snippet: r.snippet
            }))
        };
    }
};

export function registerResearchTools() {
    gituMCPHub.registerTool(deepResearchTool);
    gituMCPHub.registerTool(webSearchTool);
    console.log('[ResearchMCPTools] Registered web search and deep research tools');
}
