import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituShellManager } from './gituShellManager.js';
import { gituRemoteTerminalService } from './gituRemoteTerminalService.js';
import { gituPermissionManager } from './gituPermissionManager.js';

const LOCAL_FILE_COMMANDS = new Set([
    'ls',
    'dir',
    'rg',
    'find',
    'fd',
    'cat',
    'type',
    'tree',
    'pwd',
    'get-childitem',
    'get-content'
]);

const DEFAULT_LOCAL_FILE_ALLOWED_COMMANDS = [
    'ls',
    'dir',
    'rg',
    'find',
    'fd',
    'cat',
    'type',
    'tree',
    'pwd',
    'Get-ChildItem',
    'Get-Content',
    'get-childitem',
    'get-content'
];

const DEFAULT_PERMISSION_DAYS = 30;

const baseCommand = (command: string) =>
    String(command || '')
        .trim()
        .split(/\s+/)
        .filter(Boolean)[0] || '';

const isLocalFileCommand = (command: string) => {
    const base = baseCommand(command).toLowerCase();
    return LOCAL_FILE_COMMANDS.has(base);
};

const buildLocalAccessError = (message: string) =>
    `LOCAL_ACCESS_NOT_GRANTED: ${message}`;

async function ensureLocalFileShellPermission(userId: string, command: string, cwd?: string) {
    const hasShell = await gituPermissionManager.hasAnyPermission(userId, 'shell');
    if (hasShell) return false;

    const allowedCommands = Array.from(
        new Set(
            [...DEFAULT_LOCAL_FILE_ALLOWED_COMMANDS, baseCommand(command)]
                .map(c => c?.trim())
                .filter(Boolean)
        )
    );

    const allowedPaths =
        typeof cwd === 'string' && cwd.trim().length > 0 ? [cwd.trim()] : [];

    const expiresAt = new Date(Date.now() + DEFAULT_PERMISSION_DAYS * 24 * 60 * 60 * 1000);

    const request = await gituPermissionManager.requestPermission(
        userId,
        {
            resource: 'shell',
            actions: ['execute'],
            scope: {
                allowedCommands,
                allowedPaths,
                customScope: { allowUnsandboxed: true }
            },
            expiresAt
        },
        'Auto-approved for local file access'
    );

    await gituPermissionManager.approveRequest(userId, request.id, { expiresAt });
    return true;
}

/**
 * Tool: Execute Command
 * Execute a shell command in a secure environment.
 */
const executeCommandTool: MCPTool = {
    name: 'execute_command',
    description: 'Execute a shell command. Use this to run Python scripts, install packages (npm/pip), or perform system operations. Commands are sandboxed by default. If a remote terminal is connected, unsandboxed commands run on the user\'s local computer.',
    schema: {
        type: 'object',
        properties: {
            command: { type: 'string', description: 'The command to execute (e.g., "python script.py", "npm install", "ls -la")' },
            args: { type: 'array', items: { type: 'string' }, description: 'Arguments for the command' },
            timeout: { type: 'number', description: 'Timeout in milliseconds (default 60000)', default: 60000 },
            sandboxed: { type: 'boolean', description: 'Run in a secure Docker sandbox (default true). Set false to use unsandboxed/remote execution when allowed.', default: true },
            cwd: { type: 'string', description: 'Working directory. For remote/local execution, use a path on the user\'s computer.' }
        },
        required: ['command']
    },
    handler: async (args: any, context: MCPContext) => {
        const { command, args: commandArgs = [], timeout, sandboxed = true, cwd } = args;

        // Log the attempt
        console.log(`[ShellMCP] User ${context.userId} requesting: ${command} ${commandArgs.join(' ')} (Sandbox: ${sandboxed})`);

        try {
            const hasRemote = gituRemoteTerminalService.hasConnection(context.userId);
            const resolvedCwd =
                typeof cwd === 'string' && cwd.trim().length > 0
                    ? cwd
                    : sandboxed
                        ? '/workspace'
                        : hasRemote
                            ? undefined
                            : process.cwd();
            const isLocalFileRequest = !sandboxed && isLocalFileCommand(command);
            const isPermissionError = (err?: string) =>
                err === 'SHELL_PERMISSION_DENIED' ||
                err === 'UNSANDBOXED_MODE_NOT_ALLOWED' ||
                err === 'REMOTE_EXECUTION_NOT_ALLOWED';

            if (isLocalFileRequest && !hasRemote) {
                throw new Error(
                    buildLocalAccessError(
                        'Local access not yet granted. Connect the Gitu CLI remote terminal to enable local file access.'
                    )
                );
            }

            const execute = () =>
                gituShellManager.execute(context.userId, {
                    command,
                    args: commandArgs,
                    timeoutMs: timeout,
                    sandboxed: sandboxed,
                    cwd: resolvedCwd
                });

            let result = await execute();

            if (!result.success && isLocalFileRequest && isPermissionError(result.error)) {
                try {
                    const granted = await ensureLocalFileShellPermission(context.userId, command, cwd);
                    if (granted) {
                        result = await execute();
                    }
                } catch {
                    // Fall through to user-facing error below.
                }
            }

            if (!result.success) {
                if (!sandboxed && isPermissionError(result.error)) {
                    throw new Error(
                        buildLocalAccessError(
                            'Local access not yet granted. Approve shell access in Settings > Gitu > Permissions and try again.'
                        )
                    );
                }
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
