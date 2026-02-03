import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';
import { spawn } from 'node:child_process';
import pool from '../config/database.js';
import { gituMCPHub, type MCPTool, type MCPContext, type MCPToolSchema } from './gituMCPHub.js';
import { gituUserSandboxService } from './gituUserSandboxService.js';
import { gituPermissionManager } from './gituPermissionManager.js';

type ExternalMcpConnectionRow = {
  id: string;
  user_id: string;
  name: string;
  command: string;
  args: any;
  env: any;
  env_keys?: any;
  created_at: any;
  updated_at: any;
};

async function ensureTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS gitu_external_mcp_connections (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      command TEXT NOT NULL,
      args JSONB DEFAULT '[]'::jsonb,
      env JSONB DEFAULT '{}'::jsonb,
      env_keys JSONB DEFAULT '[]'::jsonb,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_id, name)
    );
  `);

  await pool.query(`
    ALTER TABLE gitu_external_mcp_connections
      ADD COLUMN IF NOT EXISTS env_keys JSONB DEFAULT '[]'::jsonb;
  `);
}

function normalizeSchema(inputSchema: any): MCPToolSchema {
  const schema = inputSchema && typeof inputSchema === 'object' ? inputSchema : {};
  const properties = schema.properties && typeof schema.properties === 'object' ? schema.properties : {};
  const required = Array.isArray(schema.required) ? schema.required : undefined;
  return {
    type: 'object',
    properties,
    ...(required ? { required } : {}),
  };
}

async function proxyClient(userId: string) {
  const sandbox = await gituUserSandboxService.ensureUserSandbox(userId);
  if (!sandbox.hostPort) throw new Error('SANDBOX_NOT_READY');
  return axios.create({
    baseURL: `http://127.0.0.1:${sandbox.hostPort}`,
    headers: {
      'Content-Type': 'application/json',
      'X-Gitu-Proxy-Token': sandbox.proxyToken,
    },
    timeout: 60_000,
  });
}

function slugify(input: string) {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40) || 'mcp';
}

function validateEnv(env: any) {
  const obj = typeof env === 'object' && env !== null ? env : {};
  const keys = Object.keys(obj);
  if (keys.length > 50) throw new Error('ENV_TOO_MANY_KEYS');
  for (const k of keys) {
    if (!/^[A-Z0-9_]{1,64}$/.test(k)) throw new Error('ENV_KEY_INVALID');
    const v = obj[k];
    if (typeof v !== 'string') throw new Error('ENV_VALUE_INVALID');
    if (v.length > 2000) throw new Error('ENV_VALUE_TOO_LARGE');
  }
  return { env: obj as Record<string, string>, keys };
}

function validateInstallSpec(install: any) {
  const type = String(install?.type || '').trim();
  const spec = String(install?.spec || '').trim();
  if (!type || !spec) throw new Error('INSTALL_SPEC_REQUIRED');
  if (type !== 'npm' && type !== 'git' && type !== 'pip') throw new Error('INSTALL_TYPE_INVALID');

  if (type === 'git') {
    if (!/^https:\/\/.+/i.test(spec)) throw new Error('GIT_URL_INVALID');
    return { type, spec };
  }

  if (!/^[a-zA-Z0-9@._/\\-]+$/.test(spec)) throw new Error('INSTALL_SPEC_INVALID');
  return { type, spec };
}

async function execInUserSandbox(userId: string, command: string, cwd?: string, timeoutMs: number = 60_000) {
  const sandbox = await gituUserSandboxService.ensureUserSandbox(userId);
  if (!sandbox.containerName) throw new Error('SANDBOX_NOT_READY');

  const ok = await gituPermissionManager.checkPermission(userId, {
    resource: 'shell',
    action: 'execute',
    scope: { command },
  });
  if (!ok) {
    throw new Error('SHELL_PERMISSION_DENIED');
  }

  const cwdValue = typeof cwd === 'string' && cwd.trim().length > 0 ? cwd.trim() : '/workspace';
  const cwdInContainer = cwdValue.startsWith('/') ? cwdValue : `/workspace/${cwdValue.replace(/^\/+/, '')}`;

  const args = ['exec', '-w', cwdInContainer, sandbox.containerName, 'sh', '-lc', command];

  return await new Promise<{ exitCode: number | null; stdout: string; stderr: string; timedOut: boolean }>(resolve => {
    const child = spawn('docker', args, { shell: false, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let timedOut = false;
    const t = setTimeout(() => {
      timedOut = true;
      try { child.kill('SIGKILL'); } catch { }
    }, Math.max(1_000, timeoutMs));

    child.stdout?.on('data', (c: Buffer) => stdoutChunks.push(c));
    child.stderr?.on('data', (c: Buffer) => stderrChunks.push(c));

    child.on('close', code => {
      clearTimeout(t);
      resolve({
        exitCode: typeof code === 'number' ? code : null,
        stdout: Buffer.concat(stdoutChunks).toString('utf8'),
        stderr: Buffer.concat(stderrChunks).toString('utf8'),
        timedOut,
      });
    });

    child.on('error', err => {
      clearTimeout(t);
      resolve({
        exitCode: null,
        stdout: Buffer.concat(stdoutChunks).toString('utf8'),
        stderr: (Buffer.concat(stderrChunks).toString('utf8') || '') + err.message,
        timedOut,
      });
    });
  });
}

const connectExternalMcpTool: MCPTool = {
  name: 'connect_external_mcp',
  description: 'Connect an external MCP server inside the user sandbox and register its tools.',
  schema: {
    type: 'object',
    properties: {
      name: { type: 'string', description: 'Connection name (unique per user)' },
      command: { type: 'string', description: 'Command to start the MCP server inside the sandbox' },
      args: { type: 'array', items: { type: 'string' }, description: 'Command args' },
      env: { type: 'object', description: 'Environment variables map' },
    },
    required: ['name', 'command'],
  },
  handler: async (args: any, context: MCPContext) => {
    await ensureTables();
    const connectionName = String(args?.name || '').trim();
    const command = String(args?.command || '').trim();
    const cmdArgs = Array.isArray(args?.args) ? args.args.map((a: any) => String(a)) : [];
    const { env, keys: envKeys } = validateEnv(args?.env);

    if (!connectionName) throw new Error('NAME_REQUIRED');
    if (!command) throw new Error('COMMAND_REQUIRED');

    const existingRes = await pool.query(
      `SELECT id FROM gitu_external_mcp_connections WHERE user_id = $1 AND name = $2`,
      [context.userId, connectionName]
    );
    const connectionId = existingRes.rows[0]?.id ? String(existingRes.rows[0].id) : uuidv4();

    await pool.query(
      `INSERT INTO gitu_external_mcp_connections (id, user_id, name, command, args, env)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (user_id, name)
       DO UPDATE SET command = EXCLUDED.command, args = EXCLUDED.args, env = EXCLUDED.env, updated_at = NOW()
       RETURNING id`,
      // Do NOT persist env values; store keys only for visibility
      [connectionId, context.userId, connectionName, command, JSON.stringify(cmdArgs), JSON.stringify({})]
    );

    await pool.query(
      `UPDATE gitu_external_mcp_connections
       SET env_keys = $1, updated_at = NOW()
       WHERE user_id = $2 AND id = $3`,
      [JSON.stringify(envKeys), context.userId, connectionId]
    );

    const client = await proxyClient(context.userId);
    const registerRes = await client.post('/servers/register', {
      serverId: connectionId,
      command,
      args: cmdArgs,
      env,
    });

    const tools = Array.isArray(registerRes.data?.tools) ? registerRes.data.tools : [];
    const registered: { toolName: string; remoteName: string }[] = [];

    for (const t of tools) {
      const remoteName = String(t?.name || '').trim();
      if (!remoteName) continue;
      const toolName = `ext_${connectionId}_${remoteName}`;
      const schema = normalizeSchema(t?.inputSchema);

      gituMCPHub.registerUserTool(context.userId, {
        name: toolName,
        description: `[external:${connectionName}] ${String(t?.description || '')}`.trim(),
        schema,
        handler: async (toolArgs: any, ctx: MCPContext) => {
          const c = await proxyClient(ctx.userId);
          const r = await c.post(`/servers/${connectionId}/call`, {
            name: remoteName,
            arguments: toolArgs || {},
          });
          return r.data?.result ?? r.data;
        },
      });

      registered.push({ toolName, remoteName });
    }

    return {
      success: true,
      connectionId,
      name: connectionName,
      toolCount: registered.length,
      tools: registered,
      envKeys,
      envStored: false,
    };
  },
};

const autoInstallAndConnectMcpTool: MCPTool = {
  name: 'auto_install_and_connect_mcp',
  description: 'Install an MCP server inside the user sandbox, then connect it and register its tools.',
  schema: {
    type: 'object',
    properties: {
      name: { type: 'string', description: 'Connection name (unique per user)' },
      install: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['npm', 'git', 'pip'], description: 'Install method' },
          spec: { type: 'string', description: 'Package name or git https URL' },
        },
        required: ['type', 'spec'],
      },
      start: {
        type: 'object',
        properties: {
          command: { type: 'string', description: 'Command to start MCP server inside sandbox' },
          args: { type: 'array', items: { type: 'string' }, description: 'Args to start MCP server' },
        },
        required: ['command'],
      },
      env: { type: 'object', description: 'Environment variables for the MCP server process (not persisted)' },
      workdir: { type: 'string', description: 'Optional work directory under /workspace' },
    },
    required: ['name', 'install', 'start'],
  },
  handler: async (args: any, context: MCPContext) => {
    const name = String(args?.name || '').trim();
    if (!name) throw new Error('NAME_REQUIRED');
    const install = validateInstallSpec(args?.install);
    const startCommand = String(args?.start?.command || '').trim();
    const startArgs = Array.isArray(args?.start?.args) ? args.start.args.map((a: any) => String(a)) : [];
    if (!startCommand) throw new Error('START_COMMAND_REQUIRED');

    const { env } = validateEnv(args?.env);

    const slug = slugify(name);
    const baseDir = typeof args?.workdir === 'string' && args.workdir.trim().length > 0
      ? `/workspace/${slugify(args.workdir)}`
      : `/workspace/external-mcp/${slug}`;

    await execInUserSandbox(context.userId, `mkdir -p "${baseDir}"`, '/');

    if (install.type === 'git') {
      const repoDir = `${baseDir}/repo`;
      const cmd = [
        `if [ -d "${repoDir}/.git" ]; then`,
        `  cd "${repoDir}" && git fetch --all --prune && git pull --ff-only;`,
        `else`,
        `  rm -rf "${repoDir}" && git clone "${install.spec}" "${repoDir}";`,
        `fi`,
      ].join(' ');
      await execInUserSandbox(context.userId, cmd, '/');
    } else if (install.type === 'npm') {
      const cmd = `cd "${baseDir}" && npm init -y >/dev/null 2>&1 || true && npm install ${install.spec} --omit=dev`;
      await execInUserSandbox(context.userId, cmd, '/');
    } else if (install.type === 'pip') {
      const cmd = `pip install --user ${install.spec}`;
      await execInUserSandbox(context.userId, cmd, '/');
    }

    return await connectExternalMcpTool.handler(
      {
        name,
        command: startCommand,
        args: startArgs,
        env,
      },
      context
    );
  },
};

const sandboxShellExecTool: MCPTool = {
  name: 'sandbox_shell_exec',
  description: 'Execute a shell command inside the user sandbox container (network enabled).',
  schema: {
    type: 'object',
    properties: {
      command: { type: 'string', description: 'Shell command to run (sh -lc)' },
      cwd: { type: 'string', description: 'Working directory inside container (default: /workspace)' },
      timeoutMs: { type: 'number', description: 'Timeout in ms (default: 60000)' },
    },
    required: ['command'],
  },
  handler: async (args: any, context: MCPContext) => {
    const command = String(args?.command || '').trim();
    if (!command) throw new Error('COMMAND_REQUIRED');
    const cwd = typeof args?.cwd === 'string' ? args.cwd : undefined;
    const timeoutMs = typeof args?.timeoutMs === 'number' && Number.isFinite(args.timeoutMs) ? Number(args.timeoutMs) : 60_000;
    const result = await execInUserSandbox(context.userId, command, cwd, timeoutMs);
    return result;
  },
};

const listExternalMcpTool: MCPTool = {
  name: 'list_external_mcp',
  description: 'List external MCP connections for the user.',
  schema: {
    type: 'object',
    properties: {},
  },
  handler: async (_args: any, context: MCPContext) => {
    await ensureTables();
    const res = await pool.query(
      `SELECT id, name, command, args, env, env_keys, created_at, updated_at
       FROM gitu_external_mcp_connections
       WHERE user_id = $1
       ORDER BY updated_at DESC`,
      [context.userId]
    );

    const connections = (res.rows as ExternalMcpConnectionRow[]).map(r => ({
      id: String(r.id),
      name: String(r.name),
      command: String(r.command),
      args: r.args ?? [],
      envKeys: Array.isArray(r.env_keys) ? r.env_keys : [],
      envStored: false,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    }));

    return { connections };
  },
};

const disconnectExternalMcpTool: MCPTool = {
  name: 'disconnect_external_mcp',
  description: 'Disconnect an external MCP server and remove its registered tools.',
  schema: {
    type: 'object',
    properties: {
      connectionId: { type: 'string', description: 'Connection ID (from list_external_mcp)' },
      name: { type: 'string', description: 'Connection name (alternative to connectionId)' },
      delete: { type: 'boolean', description: 'Delete the connection record', default: false },
    },
  },
  handler: async (args: any, context: MCPContext) => {
    await ensureTables();
    const connectionIdArg = String(args?.connectionId || '').trim();
    const nameArg = String(args?.name || '').trim();
    const shouldDelete = Boolean(args?.delete);

    let connectionId = connectionIdArg;
    if (!connectionId && nameArg) {
      const res = await pool.query(
        `SELECT id FROM gitu_external_mcp_connections WHERE user_id = $1 AND name = $2`,
        [context.userId, nameArg]
      );
      connectionId = res.rows[0]?.id ? String(res.rows[0].id) : '';
    }
    if (!connectionId) throw new Error('CONNECTION_NOT_FOUND');

    try {
      const c = await proxyClient(context.userId);
      await c.delete(`/servers/${connectionId}`);
    } catch {}

    gituMCPHub.unregisterUserToolsByPrefix(context.userId, `ext_${connectionId}_`);

    if (shouldDelete) {
      await pool.query(
        `DELETE FROM gitu_external_mcp_connections WHERE user_id = $1 AND id = $2`,
        [context.userId, connectionId]
      );
    }

    return { success: true, connectionId, deleted: shouldDelete };
  },
};

export function registerExternalMcpTools() {
  gituMCPHub.registerTool(connectExternalMcpTool);
  gituMCPHub.registerTool(autoInstallAndConnectMcpTool);
  gituMCPHub.registerTool(sandboxShellExecTool);
  gituMCPHub.registerTool(listExternalMcpTool);
  gituMCPHub.registerTool(disconnectExternalMcpTool);
}
