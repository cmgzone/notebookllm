import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import * as gituGmailOperations from './gituGmailOperations.js';

/**
 * Tool: Search Gmail
 * Searches for emails in the user's Gmail account using Gmail search syntax.
 */
const searchGmailTool: MCPTool = {
    name: 'search_gmail',
    description: 'Search for emails in your Gmail account. returns a list of matching message snippets.',
    schema: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'Gmail search query (e.g., "from:boss important", "subject:meeting", "is:unread")'
            },
            limit: {
                type: 'number',
                description: 'Maximum number of emails to return',
                default: 5
            }
        },
        required: ['query']
    },
    handler: async (args: any, context: MCPContext) => {
        const { query, limit = 5 } = args;

        try {
            const response = await gituGmailOperations.listMessages(context.userId, query, limit);
            const messages = response.messages || [];

            if (messages.length === 0) {
                return {
                    success: true,
                    count: 0,
                    messages: [],
                    message: `No emails found matching query: "${query}"`
                };
            }

            // Fetch details for each message to get snippet and metadata
            // detailed info is fetched in parallel
            const detailedMessages = await Promise.all(
                messages.slice(0, limit).map(async (msg: any) => {
                    try {
                        const details = await gituGmailOperations.getMessage(context.userId, msg.id);
                        const headers = details.payload.headers;
                        const subject = headers.find((h: any) => h.name === 'Subject')?.value || '(No Subject)';
                        const from = headers.find((h: any) => h.name === 'From')?.value || '(Unknown)';
                        const date = headers.find((h: any) => h.name === 'Date')?.value || '';

                        return {
                            id: msg.id,
                            threadId: msg.threadId,
                            subject,
                            from,
                            date,
                            snippet: details.snippet
                        };
                    } catch (err) {
                        return { id: msg.id, error: 'Failed to fuzzy fetch details' };
                    }
                })
            );

            return {
                success: true,
                count: detailedMessages.length,
                messages: detailedMessages
            };

        } catch (error: any) {
            if (error.message === 'GMAIL_NOT_CONNECTED') {
                throw new Error('Gmail is not connected. Please ask the user to link their Gmail account in settings.');
            }
            throw error;
        }
    }
};

/**
 * Tool: Send Email
 * Sends an email from the user's Gmail account.
 */
const sendEmailTool: MCPTool = {
    name: 'send_email',
    description: 'Send an email using your Gmail account. WARNING: This sends the email immediately.',
    schema: {
        type: 'object',
        properties: {
            to: { type: 'string', description: 'Recipient email address' },
            subject: { type: 'string', description: 'Email subject' },
            body: { type: 'string', description: 'Email body content (text)' }
        },
        required: ['to', 'subject', 'body']
    },
    handler: async (args: any, context: MCPContext) => {
        const { to, subject, body } = args;

        try {
            const result = await gituGmailOperations.sendEmail(context.userId, to, subject, body);

            return {
                success: true,
                messageId: result.id,
                threadId: result.threadId,
                message: `Email sent to ${to} with subject "${subject}"`
            };
        } catch (error: any) {
            if (error.message === 'GMAIL_NOT_CONNECTED') {
                throw new Error('Gmail is not connected. Please link your account first.');
            }
            throw error;
        }
    }
};

/**
 * Register all Gmail tools
 */
export function registerGmailTools() {
    gituMCPHub.registerTool(searchGmailTool);
    gituMCPHub.registerTool(sendEmailTool);
    console.log('[GmailMCPTools] Registered search_gmail and send_email tools');
}
