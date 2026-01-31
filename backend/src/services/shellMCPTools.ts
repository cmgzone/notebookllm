import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituShellManager } from './gituShellManager.js';

/**
 * Tool: Execute Command
 * Execute a shell command in a secure environment.
 */
const executeCommandTool: MCPTool = {
    name: 'execute_command',
    description: 'Execute a shell command. Use this to run Python scripts, install packages (npm/pip), or perform system operations. Commands are sandboxed by default.',
    schema: {
        type: 'object',
        properties: {
            command: { type: 'string', description: 'The command to execute (e.g., "python script.py", "npm install", "ls -la")' },
            args: { type: 'array', items: { type: 'string' }, description: 'Arguments for the command' },
            timeout: { type: 'number', description: 'Timeout in milliseconds (default 60000)', default: 60000 },
            sandboxed: { type: 'boolean', description: 'Run in a secure Docker sandbox (default true)', default: true }
        },
        required: ['command']
    },
    handler: async (args: any, context: MCPContext) => {
        const { command, args: commandArgs = [], timeout, sandboxed = true } = args;

        // Log the attempt
        console.log(`[ShellMCP] User ${context.userId} requesting: ${command} ${commandArgs.join(' ')} (Sandbox: ${sandboxed})`);

        try {
            const result = await gituShellManager.execute(context.userId, {
                command,
                args: commandArgs,
                timeoutMs: timeout,
                sandboxed: sandboxed,
                cwd: sandboxed ? '/workspace' : process.cwd()
            });

            if (!result.success) {
                // handle known error strings from the manager
                if (result.error === 'SHELL_PERMISSION_DENIED') {
                    throw new Error('You do not have permission to execute shell commands. Please request permission in Settings > Gitu > Permissions.');
                }
                if (result.error === 'SHELL_COMMAND_NOT_ALLOWED') {
                    throw new Error(`The command "${command}" is not allowed by your current permission scope.`);
                }
            }

            return {
                success: result.success,
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr,
                duration: `${result.durationMs}ms`,
                mode: result.mode
            };
        } catch (error: any) {
            // Should not happen often as manager captures most errors, but just in case
            throw new Error(`Execution failed: ${error.message}`);
        }
    }
};

/**
 * Register Shell Tools
 */
export function registerShellTools() {
    gituMCPHub.registerTool(executeCommandTool);
    console.log('[ShellMCPTools] Registered execute_command tool');
}
