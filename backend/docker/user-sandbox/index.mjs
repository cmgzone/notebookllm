import http from 'node:http';
import { URL } from 'node:url';

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const proxyToken = String(process.env.GITU_PROXY_TOKEN || '').trim();
const port = (() => {
  const p = Number(process.env.GITU_PROXY_PORT || '7337');
  return Number.isFinite(p) && p > 0 ? p : 7337;
})();

const sessions = new Map();

function sendJson(res, status, body) {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(json),
  });
  res.end(json);
}

function unauthorized(res) {
  sendJson(res, 401, { error: 'UNAUTHORIZED' });
}

function notFound(res) {
  sendJson(res, 404, { error: 'NOT_FOUND' });
}

function badRequest(res, message) {
  sendJson(res, 400, { error: 'BAD_REQUEST', message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString('utf8').trim();
  if (!raw) return {};
  return JSON.parse(raw);
}

function requireAuth(req) {
  if (!proxyToken) return true;
  const got = String(req.headers['x-gitu-proxy-token'] || '').trim();
  return got === proxyToken;
}

async function connectSession(serverId, config) {
  const command = String(config.command || '').trim();
  if (!command) throw new Error('COMMAND_REQUIRED');
  const args = Array.isArray(config.args) ? config.args.map(a => String(a)) : [];
  const env = typeof config.env === 'object' && config.env !== null ? config.env : {};

  const transport = new StdioClientTransport({ command, args, env });
  const client = new Client({ name: 'gitu-sandbox-proxy', version: '1.0.0' }, { capabilities: {} });
  await client.connect(transport);

  sessions.set(serverId, { serverId, config: { command, args, env }, client, transport });
  return sessions.get(serverId);
}

async function listToolsFor(serverId) {
  const sess = sessions.get(serverId);
  if (!sess) throw new Error('SERVER_NOT_CONNECTED');
  if (typeof sess.client.listTools === 'function') {
    const out = await sess.client.listTools();
    return out?.tools ?? out;
  }
  const out = await sess.client.request({ method: 'tools/list', params: {} });
  return out?.tools ?? out;
}

async function callToolFor(serverId, name, args) {
  const sess = sessions.get(serverId);
  if (!sess) throw new Error('SERVER_NOT_CONNECTED');
  if (typeof sess.client.callTool === 'function') {
    return await sess.client.callTool({ name, arguments: args || {} });
  }
  return await sess.client.request({ method: 'tools/call', params: { name, arguments: args || {} } });
}

async function disconnect(serverId) {
  const sess = sessions.get(serverId);
  if (!sess) return false;
  try {
    if (typeof sess.client.close === 'function') await sess.client.close();
  } catch {}
  try {
    if (typeof sess.transport.close === 'function') await sess.transport.close();
  } catch {}
  sessions.delete(serverId);
  return true;
}

const server = http.createServer(async (req, res) => {
  try {
    if (!requireAuth(req)) return unauthorized(res);
    const url = new URL(req.url || '/', 'http://localhost');

    if (req.method === 'GET' && url.pathname === '/health') {
      return sendJson(res, 200, { ok: true });
    }

    if (req.method === 'GET' && url.pathname === '/servers') {
      return sendJson(res, 200, {
        servers: Array.from(sessions.values()).map(s => ({ serverId: s.serverId, command: s.config.command, args: s.config.args })),
      });
    }

    if (req.method === 'POST' && url.pathname === '/servers/register') {
      const body = await readBody(req);
      const serverId = String(body.serverId || '').trim();
      if (!serverId) return badRequest(res, 'serverId is required');
      if (sessions.has(serverId)) {
        const tools = await listToolsFor(serverId);
        return sendJson(res, 200, { serverId, alreadyConnected: true, tools });
      }
      const sess = await connectSession(serverId, body);
      const tools = await listToolsFor(serverId);
      return sendJson(res, 200, { serverId: sess.serverId, connected: true, tools });
    }

    const toolListMatch = url.pathname.match(/^\\/servers\\/([^/]+)\\/tools$/);
    if (req.method === 'GET' && toolListMatch) {
      const serverId = toolListMatch[1];
      const tools = await listToolsFor(serverId);
      return sendJson(res, 200, { serverId, tools });
    }

    const callToolMatch = url.pathname.match(/^\\/servers\\/([^/]+)\\/call$/);
    if (req.method === 'POST' && callToolMatch) {
      const serverId = callToolMatch[1];
      const body = await readBody(req);
      const name = String(body.name || '').trim();
      if (!name) return badRequest(res, 'name is required');
      const result = await callToolFor(serverId, name, body.arguments || body.args || {});
      return sendJson(res, 200, { serverId, name, result });
    }

    const disconnectMatch = url.pathname.match(/^\\/servers\\/([^/]+)$/);
    if (req.method === 'DELETE' && disconnectMatch) {
      const serverId = disconnectMatch[1];
      const ok = await disconnect(serverId);
      return sendJson(res, 200, { serverId, disconnected: ok });
    }

    return notFound(res);
  } catch (e) {
    return sendJson(res, 500, { error: 'INTERNAL_ERROR', message: e?.message || String(e) });
  }
});

server.listen(port, '0.0.0.0');

