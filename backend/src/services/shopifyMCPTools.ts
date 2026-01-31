import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituShopifyManager } from './gituShopifyManager.js';

/**
 * Tool: List Shopify Products
 */
const listShopifyProductsTool: MCPTool = {
    name: 'shopify_list_products',
    description: 'List products from the connected Shopify store.',
    schema: {
        type: 'object',
        properties: {
            limit: { type: 'number', description: 'Number of products to return (default 10)' },
            status: { type: 'string', description: 'Filter by status (active, archived, draft)', enum: ['active', 'archived', 'draft', 'any'] }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const creds = await gituShopifyManager.getConnection(context.userId);
        if (!creds) throw new Error('Shopify store not connected. Please connect your store in settings first.');

        const result = await gituShopifyManager.listProducts(creds, {
            limit: args.limit || 10,
            status: args.status
        });

        return {
            success: true,
            count: result.items.length,
            products: result.items.map(p => ({
                id: p.id,
                title: p.title,
                status: p.status,
                variants: p.variants?.length
            }))
        };
    }
};

/**
 * Tool: Get Sales Analytics
 */
const getShopifyAnalyticsTool: MCPTool = {
    name: 'shopify_analytics',
    description: 'Get sales analytics (order count, gross sales) for the store.',
    schema: {
        type: 'object',
        properties: {
            days: { type: 'number', description: 'Number of days to look back (default 30)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const creds = await gituShopifyManager.getConnection(context.userId);
        if (!creds) throw new Error('Shopify store not connected.');

        const days = args.days || 30;
        const minDate = new Date();
        minDate.setDate(minDate.getDate() - days);

        const analytics = await gituShopifyManager.getOrdersAnalytics(creds, {
            createdAtMin: minDate.toISOString(),
            limit: 50
        });

        return {
            success: true,
            period: `Last ${days} days`,
            ...analytics
        };
    }
};

/**
 * Tool: List Orders
 */
const listShopifyOrdersTool: MCPTool = {
    name: 'shopify_list_orders',
    description: 'List recent orders from the store.',
    schema: {
        type: 'object',
        properties: {
            limit: { type: 'number', description: 'Number of orders to return (default 5)' },
            status: { type: 'string', description: 'open, closed, or any', enum: ['open', 'closed', 'any'] }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const creds = await gituShopifyManager.getConnection(context.userId);
        if (!creds) throw new Error('Shopify store not connected.');

        const result = await gituShopifyManager.listOrders(creds, {
            limit: args.limit || 5,
            status: args.status || 'any',
            fields: 'id,name,total_price,financial_status,fulfillment_status,created_at'
        });

        return {
            success: true,
            orders: result.items
        };
    }
};

/**
 * Register Shopify Tools
 */
export function registerShopifyTools() {
    gituMCPHub.registerTool(listShopifyProductsTool);
    gituMCPHub.registerTool(getShopifyAnalyticsTool);
    gituMCPHub.registerTool(listShopifyOrdersTool);
    console.log('[ShopifyMCPTools] Registered shopify tools');
}
