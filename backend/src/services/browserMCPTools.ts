import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituBrowserManager } from './gituBrowserManager.js';

/**
 * Tool: Navigate
 */
const browserNavigateTool: MCPTool = {
    name: 'browser_navigate',
    description: 'Navigate the browser to a specific URL.',
    schema: {
        type: 'object',
        properties: {
            url: { type: 'string', description: 'The URL to visit' }
        },
        required: ['url']
    },
    handler: async (args: any, context: MCPContext) => {
        const page = await gituBrowserManager.getPage(context.userId);
        try {
            await page.goto(args.url, { timeout: 30000, waitUntil: 'domcontentloaded' });
            const title = await page.title();
            return {
                success: true,
                title,
                url: page.url()
            };
        } catch (e: any) {
            throw new Error(`Navigation failed: ${e.message}`);
        }
    }
};

/**
 * Tool: Read Content
 */
const browserReadTool: MCPTool = {
    name: 'browser_read',
    description: 'Read the text content of the current page.',
    schema: {
        type: 'object',
        properties: {
            selector: { type: 'string', description: 'Optional CSS selector to read specific element', default: 'body' },
            format: { type: 'string', description: 'text, html, or markdown', enum: ['text', 'html', 'markdown'], default: 'text' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const page = await gituBrowserManager.getPage(context.userId);
        const selector = args.selector || 'body';

        try {
            if (args.format === 'html') {
                const content = await page.locator(selector).innerHTML();
                return { success: true, content };
            }

            // Default to text (smart innerText)
            const content = await page.locator(selector).innerText();
            return { success: true, content };
        } catch (e: any) {
            throw new Error(`Read failed: ${e.message}`);
        }
    }
};

/**
 * Tool: Click
 */
const browserClickTool: MCPTool = {
    name: 'browser_click',
    description: 'Click an element on the current page.',
    schema: {
        type: 'object',
        properties: {
            selector: { type: 'string', description: 'CSS selector of element to click' }
        },
        required: ['selector']
    },
    handler: async (args: any, context: MCPContext) => {
        const page = await gituBrowserManager.getPage(context.userId);
        try {
            await page.click(args.selector, { timeout: 10000 });
            return { success: true, message: `Clicked ${args.selector}` };
        } catch (e: any) {
            throw new Error(`Click failed: ${e.message}`);
        }
    }
};

/**
 * Tool: Screenshot
 */
const browserScreenshotTool: MCPTool = {
    name: 'browser_screenshot',
    description: 'Take a screenshot of the current page.',
    schema: {
        type: 'object',
        properties: {
            fullPage: { type: 'boolean', default: false }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const page = await gituBrowserManager.getPage(context.userId);
        try {
            const buffer = await page.screenshot({ fullPage: args.fullPage, type: 'jpeg', quality: 80 });
            const base64 = buffer.toString('base64');
            return {
                success: true,
                image: `data:image/jpeg;base64,${base64}`,
                note: "Image data returned in base64 format."
            };
        } catch (e: any) {
            throw new Error(`Screenshot failed: ${e.message}`);
        }
    }
};

/**
 * Tool: Type
 */
const browserTypeTool: MCPTool = {
    name: 'browser_type',
    description: 'Type text into an input field.',
    schema: {
        type: 'object',
        properties: {
            selector: { type: 'string', description: 'CSS selector of the input' },
            text: { type: 'string', description: 'Text to type' }
        },
        required: ['selector', 'text']
    },
    handler: async (args: any, context: MCPContext) => {
        const page = await gituBrowserManager.getPage(context.userId);
        try {
            await page.fill(args.selector, args.text);
            return { success: true, message: `Typed into ${args.selector}` };
        } catch (e: any) {
            throw new Error(`Type failed: ${e.message}`);
        }
    }
};

/**
 * Register Browser Tools
 */
export function registerBrowserTools() {
    gituMCPHub.registerTool(browserNavigateTool);
    gituMCPHub.registerTool(browserReadTool);
    gituMCPHub.registerTool(browserClickTool);
    gituMCPHub.registerTool(browserTypeTool);
    gituMCPHub.registerTool(browserScreenshotTool);
    console.log('[BrowserMCPTools] Registered Playwright browser tools');
}
