import axios from 'axios';
import pool from '../config/database.js';
import { gituUserSandboxService } from './gituUserSandboxService.js';
import type { MCPTool, MCPToolSchema } from './gituMCPHub.js';

type ConnectionRow = {
  id: string;
  name: string;
  command: string;
  args: any;
  env: any;
};

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

async function getConnections(userId: string): Promise<ConnectionRow[]> {
  try {
    const res = await pool.query(
      `SELECT id, name, command, args, env
       FROM gitu_external_mcp_connections
       WHERE user_id = $1
       ORDER BY updated_at DESC`,
      [userId]
    );
    return (res.rows as any[]).map(r => ({
      id: String(r.id),
      name: String(r.name),
      command: String(r.command),
      args: r.args ?? [],
      env: r.env ?? {},
    }));
  } catch {
    return [];
  }
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

export async function hydrateExternalMcpToolsForUser(
  userId: string,
  register: (tool: MCPTool) => void
): Promise<void> {
  const connections = await getConnections(userId);
  if (connections.length === 0) return;

  const client = await proxyClient(userId);

  for (const conn of connections) {
    try {
      const registerRes = await client.post('/servers/register', {
        serverId: conn.id,
        command: conn.command,
        args: Array.isArray(conn.args) ? conn.args : [],
        env: typeof conn.env === 'object' && conn.env !== null ? conn.env : {},
      });

      const tools = Array.isArray(registerRes.data?.tools) ? registerRes.data.tools : [];
      for (const t of tools) {
        const remoteName = String(t?.name || '').trim();
        if (!remoteName) continue;
        const toolName = `ext_${conn.id}_${remoteName}`;
        const schema = normalizeSchema(t?.inputSchema);

        register({
          name: toolName,
          description: `[external:${conn.name}] ${String(t?.description || '')}`.trim(),
          schema,
          handler: async (toolArgs: any, _context: any) => {
            const r = await client.post(`/servers/${conn.id}/call`, {
              name: remoteName,
              arguments: toolArgs || {},
            });
            return r.data?.result ?? r.data;
          },
        });
      }
    } catch {}
  }
}
