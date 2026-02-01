import { spawn } from 'child_process';
import path from 'path';
import pool from '../config/database.js';
import { gituPermissionManager, type Permission } from './gituPermissionManager.js';
import { gituRemoteTerminalService } from './gituRemoteTerminalService.js';

export type ShellTrustMode = 'sandboxed' | 'unsandboxed';

export interface GituShellManagerDeps {
  spawn?: typeof spawn;
  pool?: typeof pool;
  permissionManager?: typeof gituPermissionManager;
}

export interface ShellExecuteRequest {
  command: string;
  args?: string[];
  cwd?: string;
  timeoutMs?: number;
  sandboxed?: boolean;
  dryRun?: boolean;
}

export interface ShellExecuteResult {
  success: boolean;
  mode: ShellTrustMode | 'dry_run';
  command: string;
  args: string[];
  cwd: string | null;
  exitCode: number | null;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  durationMs: number;
  stdoutTruncated: boolean;
  stderrTruncated: boolean;
  auditLogId?: string;
  error?: string;
}

export interface ShellExecutionHooks {
  onStdoutChunk?: (chunk: Buffer) => void;
  onStderrChunk?: (chunk: Buffer) => void;
  registerCancel?: (cancel: () => void) => void;
}

const DEFAULT_TIMEOUT_MS = 60_000;
const MAX_STDOUT_BYTES = 512 * 1024;
const MAX_STDERR_BYTES = 512 * 1024;

const normalizeScopePath = (p: string) =>
  p
    .trim()
    .replace(/^(\.\/|\.\\)+/, '')
    .replace(/\\/g, '/')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

function commandForScope(command: string, args: string[]) {
  const trimmed = command.trim();
  const rest = args.map(a => a.trim()).filter(Boolean);
  return [trimmed, ...rest].join(' ').trim();
}

function isActive(p: Permission) {
  const now = new Date();
  return !p.revokedAt && (!p.expiresAt || p.expiresAt > now);
}

function hasUnsandboxedAllowance(p: Permission) {
  return Boolean((p.scope as any)?.customScope?.allowUnsandboxed === true);
}

function commandAllowed(allowedCommands: string[] | undefined, requestedCommand: string) {
  if (!allowedCommands || allowedCommands.length === 0) return false;
  if (allowedCommands.includes('*')) return true;
  return allowedCommands.some(allowed => requestedCommand.startsWith(allowed));
}

function pathAllowed(allowedPaths: string[] | undefined, requestedPath: string) {
  if (!allowedPaths || allowedPaths.length === 0) return false;
  if (allowedPaths.includes('*')) return true;

  const requested = normalizeScopePath(requestedPath);
  return allowedPaths.some(ap => {
    const allowed = normalizeScopePath(ap);
    if (!allowed) return false;
    return requested === allowed || requested.startsWith(`${allowed}/`);
  });
}

async function writeAuditLog(
  poolClient: typeof pool,
  input: {
    userId: string;
    mode: 'sandboxed' | 'unsandboxed' | 'dry_run';
    command: string;
    args: string[];
    cwd: string | null;
    success: boolean;
    exitCode: number | null;
    errorMessage: string | null;
    durationMs: number;
    stdoutBytes: number;
    stderrBytes: number;
    stdoutTruncated: boolean;
    stderrTruncated: boolean;
    deviceId?: string;
    deviceName?: string;
  }
) {
  try {
    const columnsResult = await poolClient.query(
      `SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'gitu_shell_audit_logs'`
    );
    const columns = new Set((columnsResult.rows as any[]).map(r => String(r.column_name)));
    const hasDeviceId = columns.has('device_id');
    const hasDeviceName = columns.has('device_name');

    const insertColumns = [
      'user_id',
      'mode',
      'command',
      'args',
      'cwd',
      'success',
      'exit_code',
      'error_message',
      'duration_ms',
      'stdout_bytes',
      'stderr_bytes',
      'stdout_truncated',
      'stderr_truncated',
      ...(hasDeviceId ? ['device_id'] : []),
      ...(hasDeviceName ? ['device_name'] : []),
    ];

    const values: any[] = [
      input.userId,
      input.mode,
      input.command,
      JSON.stringify(input.args),
      input.cwd,
      input.success,
      input.exitCode,
      input.errorMessage,
      input.durationMs,
      input.stdoutBytes,
      input.stderrBytes,
      input.stdoutTruncated,
      input.stderrTruncated,
      ...(hasDeviceId ? [input.deviceId ?? null] : []),
      ...(hasDeviceName ? [input.deviceName ?? null] : []),
    ];

    const placeholders = insertColumns.map((_, i) => `$${i + 1}`).join(', ');

    const result = await poolClient.query(
      `INSERT INTO gitu_shell_audit_logs (${insertColumns.join(', ')})
       VALUES (${placeholders})
       RETURNING id`,
      values
    );
    return String(result.rows[0]?.id);
  } catch {
    return undefined;
  }
}

export class GituShellManager {
  private readonly spawn: typeof spawn;
  private readonly pool: typeof pool;
  private readonly permissionManager: typeof gituPermissionManager;

  constructor(deps: GituShellManagerDeps = {}) {
    this.spawn = deps.spawn ?? spawn;
    this.pool = deps.pool ?? pool;
    this.permissionManager = deps.permissionManager ?? gituPermissionManager;
  }

  async execute(userId: string, request: ShellExecuteRequest, hooks: ShellExecutionHooks = {}): Promise<ShellExecuteResult> {
    const args = Array.isArray(request.args) ? request.args : [];
    const cwd = typeof request.cwd === 'string' && request.cwd.trim().length > 0 ? request.cwd.trim() : null;
    const timeoutMs =
      typeof request.timeoutMs === 'number' && Number.isFinite(request.timeoutMs) && request.timeoutMs > 0
        ? Math.min(request.timeoutMs, 10 * 60_000)
        : DEFAULT_TIMEOUT_MS;
    const sandboxed = request.sandboxed !== false;

    if (!request.command || typeof request.command !== 'string' || request.command.trim().length === 0) {
      return {
        success: false,
        mode: sandboxed ? 'sandboxed' : 'unsandboxed',
        command: request.command ?? '',
        args,
        cwd,
        exitCode: null,
        stdout: '',
        stderr: '',
        timedOut: false,
        durationMs: 0,
        stdoutTruncated: false,
        stderrTruncated: false,
        error: 'COMMAND_REQUIRED',
      };
    }

    const requestedCommand = commandForScope(request.command, args);

    const permissions = (await this.permissionManager.listPermissions(userId, 'shell')).filter(isActive);
    const executePermissions = permissions.filter(p => p.actions.includes('execute'));
    if (executePermissions.length === 0) {
      return {
        success: false,
        mode: sandboxed ? 'sandboxed' : 'unsandboxed',
        command: request.command,
        args,
        cwd,
        exitCode: null,
        stdout: '',
        stderr: '',
        timedOut: false,
        durationMs: 0,
        stdoutTruncated: false,
        stderrTruncated: false,
        error: 'SHELL_PERMISSION_DENIED',
      };
    }

    const commandOk = executePermissions.some(p => commandAllowed(p.scope?.allowedCommands, requestedCommand));
    if (!commandOk) {
      return {
        success: false,
        mode: sandboxed ? 'sandboxed' : 'unsandboxed',
        command: request.command,
        args,
        cwd,
        exitCode: null,
        stdout: '',
        stderr: '',
        timedOut: false,
        durationMs: 0,
        stdoutTruncated: false,
        stderrTruncated: false,
        error: 'SHELL_COMMAND_NOT_ALLOWED',
      };
    }

    // Check if user has a remote terminal connected.
    // If so, we may route the command to the user's actual computer, but only after permission checks.
    if (gituRemoteTerminalService.hasConnection(userId)) {
      const remoteAllowed = executePermissions.some(hasUnsandboxedAllowance);
      if (!remoteAllowed) {
        return {
          success: false,
          mode: 'unsandboxed',
          command: request.command,
          args,
          cwd,
          exitCode: null,
          stdout: '',
          stderr: '',
          timedOut: false,
          durationMs: 0,
          stdoutTruncated: false,
          stderrTruncated: false,
          error: 'REMOTE_EXECUTION_NOT_ALLOWED',
        };
      }

      if (cwd) {
        const cwdOk = executePermissions.some(p => pathAllowed(p.scope?.allowedPaths, cwd));
        if (!cwdOk) {
          return {
            success: false,
            mode: 'unsandboxed',
            command: request.command,
            args,
            cwd,
            exitCode: null,
            stdout: '',
            stderr: '',
            timedOut: false,
            durationMs: 0,
            stdoutTruncated: false,
            stderrTruncated: false,
            error: 'SHELL_CWD_NOT_ALLOWED',
          };
        }
      }

      const startTime = Date.now();
      let stdout = '';
      let stderr = '';
      let stdoutBytes = 0;
      let stderrBytes = 0;
      let stdoutTruncated = false;
      let stderrTruncated = false;

      const wrappedHooks: ShellExecutionHooks = {
        ...hooks,
        onStdoutChunk: (chunk: Buffer) => {
          hooks.onStdoutChunk?.(chunk);
          stdoutBytes += chunk.length;
          if (!stdoutTruncated) {
            const remaining = MAX_STDOUT_BYTES - Buffer.byteLength(stdout, 'utf8');
            if (remaining <= 0) {
              stdoutTruncated = true;
              return;
            }
            const text = chunk.toString('utf8');
            stdout += text.length > remaining ? text.slice(0, remaining) : text;
            if (text.length > remaining) stdoutTruncated = true;
          }
        },
        onStderrChunk: (chunk: Buffer) => {
          hooks.onStderrChunk?.(chunk);
          stderrBytes += chunk.length;
          if (!stderrTruncated) {
            const remaining = MAX_STDERR_BYTES - Buffer.byteLength(stderr, 'utf8');
            if (remaining <= 0) {
              stderrTruncated = true;
              return;
            }
            const text = chunk.toString('utf8');
            stderr += text.length > remaining ? text.slice(0, remaining) : text;
            if (text.length > remaining) stderrTruncated = true;
          }
        },
      };

      const remote = await gituRemoteTerminalService.executeRemote(
        userId,
        {
          ...request,
          sandboxed: false,
        },
        wrappedHooks
      );

      const exitCodeRaw = (remote.result as any)?.exitCode;
      const exitCode = typeof exitCodeRaw === 'number' ? exitCodeRaw : null;
      const successRaw = (remote.result as any)?.success;
      const success = typeof successRaw === 'boolean' ? successRaw : exitCode === 0;
      const errorMessage = typeof (remote.result as any)?.error === 'string' ? (remote.result as any).error : null;

      const durationMs = Date.now() - startTime;

      const auditLogId = await writeAuditLog(this.pool, {
        userId,
        mode: 'unsandboxed',
        command: request.command,
        args,
        cwd,
        success,
        exitCode,
        errorMessage,
        durationMs,
        stdoutBytes,
        stderrBytes,
        stdoutTruncated,
        stderrTruncated,
        deviceId: remote.deviceId,
        deviceName: remote.deviceName,
      });

      return {
        success,
        mode: 'unsandboxed',
        command: request.command,
        args,
        cwd,
        exitCode,
        stdout,
        stderr,
        timedOut: false,
        durationMs,
        stdoutTruncated,
        stderrTruncated,
        auditLogId,
        ...(errorMessage ? { error: errorMessage } : {}),
      };
    }

    if (!sandboxed) {
      const unsandboxedAllowed = executePermissions.some(hasUnsandboxedAllowance);
      if (!unsandboxedAllowed) {
        return {
          success: false,
          mode: 'unsandboxed',
          command: request.command,
          args,
          cwd,
          exitCode: null,
          stdout: '',
          stderr: '',
          timedOut: false,
          durationMs: 0,
          stdoutTruncated: false,
          stderrTruncated: false,
          error: 'UNSANDBOXED_MODE_NOT_ALLOWED',
        };
      }
    }

    if (sandboxed) {
      if (!cwd) {
        return {
          success: false,
          mode: 'sandboxed',
          command: request.command,
          args,
          cwd,
          exitCode: null,
          stdout: '',
          stderr: '',
          timedOut: false,
          durationMs: 0,
          stdoutTruncated: false,
          stderrTruncated: false,
          error: 'CWD_REQUIRED_FOR_SANDBOX',
        };
      }

      const cwdOk = executePermissions.some(p => pathAllowed(p.scope?.allowedPaths, cwd));
      if (!cwdOk) {
        return {
          success: false,
          mode: 'sandboxed',
          command: request.command,
          args,
          cwd,
          exitCode: null,
          stdout: '',
          stderr: '',
          timedOut: false,
          durationMs: 0,
          stdoutTruncated: false,
          stderrTruncated: false,
          error: 'SHELL_CWD_NOT_ALLOWED',
        };
      }
    }

    const mode: ShellTrustMode = sandboxed ? 'sandboxed' : 'unsandboxed';

    if (request.dryRun) {
      const auditLogId = await writeAuditLog(this.pool, {
        userId,
        mode: 'dry_run',
        command: request.command,
        args,
        cwd,
        success: true,
        exitCode: null,
        errorMessage: null,
        durationMs: 0,
        stdoutBytes: 0,
        stderrBytes: 0,
        stdoutTruncated: false,
        stderrTruncated: false,
      });

      return {
        success: true,
        mode: 'dry_run',
        command: request.command,
        args,
        cwd,
        exitCode: null,
        stdout: '',
        stderr: '',
        timedOut: false,
        durationMs: 0,
        stdoutTruncated: false,
        stderrTruncated: false,
        auditLogId,
      };
    }

    const startedAt = Date.now();
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let stdoutTruncated = false;
    let stderrTruncated = false;
    let timedOut = false;

    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];

    let child;

    if (sandboxed) {
      const fullCommand = commandForScope(request.command, args);
      const dockerArgs = [
        'run',
        '--rm',
        '--network',
        'none',
        '-v',
        `${path.resolve(cwd!)}:/workspace`,
        '-w',
        '/workspace',
        '--cpus',
        '0.5',
        '--memory',
        '512m',
        '--pids-limit',
        '64',
        'gitu-sandbox',
        fullCommand,
      ];

      child = this.spawn('docker', dockerArgs, {
        shell: false,
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } else {
      child = this.spawn(request.command, args, {
        cwd: cwd ?? undefined,
        shell: false,
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    }

    const kill = () => {
      try {
        child.kill('SIGKILL');
      } catch { }
    };

    if (hooks.registerCancel) {
      hooks.registerCancel(kill);
    }

    const timeout = setTimeout(() => {
      timedOut = true;
      kill();
    }, timeoutMs);

    child.stdout?.on('data', (chunk: Buffer) => {
      if (stdoutTruncated) return;
      stdoutBytes += chunk.length;
      if (stdoutBytes > MAX_STDOUT_BYTES) {
        stdoutTruncated = true;
        kill();
        return;
      }
      hooks.onStdoutChunk?.(chunk);
      stdoutChunks.push(chunk);
    });

    child.stderr?.on('data', (chunk: Buffer) => {
      if (stderrTruncated) return;
      stderrBytes += chunk.length;
      if (stderrBytes > MAX_STDERR_BYTES) {
        stderrTruncated = true;
        kill();
        return;
      }
      hooks.onStderrChunk?.(chunk);
      stderrChunks.push(chunk);
    });

    const { exitCode, errorMessage } = await new Promise<{ exitCode: number | null; errorMessage: string | null }>(
      resolve => {
        let resolved = false;
        child.on('error', err => {
          if (resolved) return;
          resolved = true;
          resolve({ exitCode: null, errorMessage: err.message });
        });
        child.on('close', code => {
          if (resolved) return;
          resolved = true;
          resolve({ exitCode: typeof code === 'number' ? code : null, errorMessage: null });
        });
      }
    );

    clearTimeout(timeout);

    const durationMs = Date.now() - startedAt;
    const stdout = Buffer.concat(stdoutChunks).toString('utf8');
    const stderr = Buffer.concat(stderrChunks).toString('utf8');
    const success = !timedOut && !errorMessage && exitCode === 0;

    const auditLogId = await writeAuditLog(this.pool, {
      userId,
      mode,
      command: request.command,
      args,
      cwd,
      success,
      exitCode,
      errorMessage: errorMessage ?? (timedOut ? 'TIMEOUT' : exitCode === 0 ? null : 'NON_ZERO_EXIT'),
      durationMs,
      stdoutBytes,
      stderrBytes,
      stdoutTruncated,
      stderrTruncated,
    });

    return {
      success,
      mode,
      command: request.command,
      args,
      cwd,
      exitCode,
      stdout,
      stderr,
      timedOut,
      durationMs,
      stdoutTruncated,
      stderrTruncated,
      auditLogId,
      error: success ? undefined : errorMessage ?? (timedOut ? 'TIMEOUT' : 'NON_ZERO_EXIT'),
    };
  }
}

export const gituShellManager = new GituShellManager();
