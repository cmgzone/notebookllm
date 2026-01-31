/**
 * Gitu Task Executor Service
 * Executes various task actions for the task scheduler.
 * 
 * Requirements: US-11 (Autonomous Wake-Up), US-17 (Task Execution)
 */

import { gituAIRouter } from './gituAIRouter.js';
import { gituMessageGateway } from './gituMessageGateway.js';
import axios from 'axios';

export interface TaskAction {
    type: 'send_message' | 'run_command' | 'ai_request' | 'webhook' | 'custom';
    platform?: string;    // Target platform for messages
    message?: string;     // Message content
    command?: string;     // Command to execute
    prompt?: string;      // AI prompt
    webhookUrl?: string;  // Webhook URL
    customCode?: string;  // Custom JavaScript code
    metadata?: Record<string, any>;
}

class GituTaskExecutor {
    /**
     * Execute a task action
     */
    async execute(userId: string, action: TaskAction): Promise<any> {
        switch (action.type) {
            case 'send_message':
                return this.executeSendMessage(userId, action);

            case 'ai_request':
                return this.executeAIRequest(userId, action);

            case 'webhook':
                return this.executeWebhook(userId, action);

            case 'run_command':
                return this.executeCommand(userId, action);

            case 'custom':
                return this.executeCustom(userId, action);

            default:
                throw new Error(`Unknown action type: ${action.type}`);
        }
    }

    /**
     * Send a message to a user on a specific platform
     */
    private async executeSendMessage(userId: string, action: TaskAction): Promise<{ sent: boolean }> {
        const message = action.message || 'Hello from Gitu!';

        // Use the message gateway to send to user's connected platforms
        await gituMessageGateway.notifyUser(userId, message);

        return { sent: true };
    }

    /**
     * Execute an AI request and optionally send the result
     */
    private async executeAIRequest(userId: string, action: TaskAction): Promise<{ response: string }> {
        const prompt = action.prompt || 'Hello!';

        const response = await gituAIRouter.route({
            userId,
            prompt,
            taskType: 'chat',
            platform: 'scheduler',
            includeSystemPrompt: true,
        });

        // If metadata indicates to send the response, do so
        if (action.metadata?.sendToUser) {
            await gituMessageGateway.notifyUser(userId, response.content);
        }

        return { response: response.content };
    }

    /**
     * Execute a webhook call
     */
    private async executeWebhook(userId: string, action: TaskAction): Promise<any> {
        if (!action.webhookUrl) {
            throw new Error('Webhook URL is required');
        }

        const response = await axios.post(action.webhookUrl, {
            userId,
            timestamp: new Date().toISOString(),
            metadata: action.metadata,
        }, {
            timeout: 30000,
            headers: {
                'Content-Type': 'application/json',
                'X-Gitu-User-Id': userId,
            },
        });

        return {
            status: response.status,
            data: response.data,
        };
    }

    /**
     * Execute a command (placeholder - would need shell access)
     */
    private async executeCommand(userId: string, action: TaskAction): Promise<{ output: string }> {
        // For security, we don't actually execute shell commands
        // This would need to be scoped to specific allowed commands
        console.log(`[TaskExecutor] Command execution requested for user ${userId}: ${action.command}`);

        return {
            output: 'Command execution is disabled for security.',
        };
    }

    /**
     * Execute custom code (placeholder - would need sandboxing)
     */
    private async executeCustom(userId: string, action: TaskAction): Promise<{ result: string }> {
        // For security, we don't actually execute custom code
        // This would need to be sandboxed in a secure environment
        console.log(`[TaskExecutor] Custom code execution requested for user ${userId}`);

        return {
            result: 'Custom code execution is not yet implemented.',
        };
    }
}

export const gituTaskExecutor = new GituTaskExecutor();
export default gituTaskExecutor;
