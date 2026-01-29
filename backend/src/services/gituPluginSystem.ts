import vm from 'node:vm';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { gituPermissionManager } from './gituPermissionManager.js';
import { listDir, readFile, writeFile } from './gituFileManager.js';
import { gituShellManager, type ShellExecuteResult } from './gituShellManager.js';

export interface GituPlugin {
  id: string;
  userId: string;
  name: string;
  description?: string | null;
  code: string;
  entrypoint: string;
  config: any;
  sourceCatalogId?: string | null;
  sourceCatalogVersion?: string | null;
  enabled: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface PluginExecutionRow {
  id: string;
  success: boolean;
  durationMs: number;
  result: any;
  error: string | null;
  logs: string[];
  executedAt: Date;
}

export interface PluginValidationResult {
  valid: boolean;
  errors: string[];
}

type AnyObj = Record<string, any>;

const normalizeScopePath = (p: string) =>
  p
    .trim()
    .replace(/^(\.\/|\.\\)+/, '')
    .replace(/\\/g, '/')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

const bannedPatterns: RegExp[] = [
  /\brequire\s*\(/i,
  /\bimport\s*\(/i,
  /\bprocess\b/i,
  /\bchild_process\b/i,
  /\bfs\b/i,
  /\bnet\b/i,
  /\bdgram\b/i,
  /\bworker_threads\b/i,
  /\bvm\b/i,
  /\beval\b/i,
];

function isString(v: any): v is string {
  return typeof v === 'string';
}

function safeJson(v: any) {
  try {
    return JSON.parse(JSON.stringify(v));
  } catch {
    return null;
  }
}

function buildSandbox(logs: string[]) {
  const consoleProxy = {
    log: (...args: any[]) => logs.push(args.map(a => (typeof a === 'string' ? a : JSON.stringify(safeJson(a)))).join(' ')),
    warn: (...args: any[]) => logs.push(args.map(a => (typeof a === 'string' ? a : JSON.stringify(safeJson(a)))).join(' ')),
    error: (...args: any[]) => logs.push(args.map(a => (typeof a === 'string' ? a : JSON.stringify(safeJson(a)))).join(' ')),
  };

  const sandbox: AnyObj = {
    console: consoleProxy,
    setTimeout: undefined,
    setInterval: undefined,
    clearTimeout: undefined,
    clearInterval: undefined,
    fetch: undefined,
    WebSocket: undefined,
  };

  return vm.createContext(sandbox, { name: 'gitu-plugin-sandbox' });
}

function compilePlugin(code: string, context: vm.Context, timeoutMs: number) {
  const wrapped = `(function() {
    const module = { exports: {} };
    const exports = module.exports;
    "use strict";
    ${code}
    return module.exports;
  })()`;
  const script = new vm.Script(wrapped, { filename: 'gitu-plugin.js' });
  return script.runInContext(context, { timeout: timeoutMs });
}

function resolveEntrypoint(exportsObj: any, entrypoint: string) {
  if (typeof exportsObj === 'function') return exportsObj;
  if (exportsObj && typeof exportsObj === 'object') {
    if (typeof exportsObj[entrypoint] === 'function') return exportsObj[entrypoint];
    if (typeof exportsObj.default === 'function') return exportsObj.default;
  }
  return null;
}

class GituPluginSystem {
  validatePlugin(input: {
    name?: unknown;
    code?: unknown;
    entrypoint?: unknown;
    enabled?: unknown;
    config?: unknown;
  }): PluginValidationResult {
    const errors: string[] = [];
    if (!isString(input.name) || input.name.trim().length < 2) errors.push('NAME_REQUIRED');
    if (!isString(input.code) || input.code.trim().length < 10) errors.push('CODE_REQUIRED');
    if (isString(input.code) && input.code.length > 100_000) errors.push('CODE_TOO_LARGE');
    if (input.enabled !== undefined && typeof input.enabled !== 'boolean') errors.push('ENABLED_INVALID');
    if (input.entrypoint !== undefined && (!isString(input.entrypoint) || input.entrypoint.trim().length < 1)) {
      errors.push('ENTRYPOINT_INVALID');
    }
    if (input.config !== undefined && (typeof input.config !== 'object' || input.config === null || Array.isArray(input.config))) {
      errors.push('CONFIG_INVALID');
    }

    if (isString(input.code)) {
      for (const re of bannedPatterns) {
        if (re.test(input.code)) {
          errors.push('CODE_DISALLOWED');
          break;
        }
      }
    }

    if (errors.length > 0) return { valid: false, errors };

    const logs: string[] = [];
    try {
      const ctx = buildSandbox(logs);
      const exportsObj = compilePlugin(String(input.code), ctx, 200);
      const entry = resolveEntrypoint(exportsObj, isString(input.entrypoint) ? input.entrypoint.trim() : 'run');
      if (!entry) return { valid: false, errors: ['ENTRYPOINT_NOT_FOUND'] };
      return { valid: true, errors: [] };
    } catch {
      return { valid: false, errors: ['CODE_COMPILE_ERROR'] };
    }
  }

  async createPlugin(userId: string, input: AnyObj): Promise<GituPlugin> {
    const v = this.validatePlugin(input);
    if (!v.valid) throw new Error(v.errors.join(','));

    const id = uuidv4();
    const name = String(input.name).trim();
    const description = isString(input.description) ? input.description.trim() : null;
    const code = String(input.code);
    const entrypoint = isString(input.entrypoint) ? input.entrypoint.trim() : 'run';
    const config =
      input.config !== undefined && typeof input.config === 'object' && input.config !== null && !Array.isArray(input.config)
        ? input.config
        : {};
    const enabled = typeof input.enabled === 'boolean' ? input.enabled : true;

    const res = await pool.query(
      `INSERT INTO gitu_plugins (id, user_id, name, description, code, entrypoint, config, source_catalog_id, source_catalog_version, enabled)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [id, userId, name, description, code, entrypoint, JSON.stringify(config), null, null, enabled]
    );
    return this.mapPluginRow(res.rows[0]);
  }

  async listPlugins(userId: string, options?: { enabled?: boolean }): Promise<GituPlugin[]> {
    const where: string[] = ['user_id = $1'];
    const params: any[] = [userId];
    let i = 2;
    if (typeof options?.enabled === 'boolean') {
      where.push(`enabled = $${i++}`);
      params.push(options.enabled);
    }
    const res = await pool.query(
      `SELECT * FROM gitu_plugins WHERE ${where.join(' AND ')} ORDER BY updated_at DESC`,
      params
    );
    return res.rows.map(r => this.mapPluginRow(r));
  }

  async getPlugin(userId: string, pluginId: string): Promise<GituPlugin | null> {
    const res = await pool.query(`SELECT * FROM gitu_plugins WHERE id = $1 AND user_id = $2`, [pluginId, userId]);
    if (res.rows.length === 0) return null;
    return this.mapPluginRow(res.rows[0]);
  }

  async updatePlugin(userId: string, pluginId: string, updates: AnyObj): Promise<GituPlugin> {
    const existing = await this.getPlugin(userId, pluginId);
    if (!existing) throw new Error('PLUGIN_NOT_FOUND');

    const next = {
      name: updates.name ?? existing.name,
      description: updates.description ?? existing.description,
      code: updates.code ?? existing.code,
      entrypoint: updates.entrypoint ?? existing.entrypoint,
      config: updates.config ?? existing.config,
      enabled: updates.enabled ?? existing.enabled,
    };

    const v = this.validatePlugin({
      name: next.name,
      code: next.code,
      entrypoint: next.entrypoint,
      config: next.config,
      enabled: next.enabled,
    });
    if (!v.valid) throw new Error(v.errors.join(','));

    const res = await pool.query(
      `UPDATE gitu_plugins
       SET name = $1,
           description = $2,
           code = $3,
           entrypoint = $4,
           config = $5,
           enabled = $6,
           updated_at = NOW()
       WHERE id = $7 AND user_id = $8
       RETURNING *`,
      [
        String(next.name).trim(),
        isString(next.description) ? next.description.trim() : null,
        String(next.code),
        String(next.entrypoint).trim(),
        JSON.stringify(
          typeof next.config === 'object' && next.config !== null && !Array.isArray(next.config) ? next.config : {}
        ),
        Boolean(next.enabled),
        pluginId,
        userId,
      ]
    );
    return this.mapPluginRow(res.rows[0]);
  }

  async deletePlugin(userId: string, pluginId: string): Promise<boolean> {
    const res = await pool.query(`DELETE FROM gitu_plugins WHERE id = $1 AND user_id = $2 RETURNING id`, [
      pluginId,
      userId,
    ]);
    return res.rows.length > 0;
  }

  async installFromCatalog(
    userId: string,
    catalogId: string,
    options?: { enabled?: boolean; config?: any }
  ): Promise<GituPlugin> {
    const enabled = typeof options?.enabled === 'boolean' ? options.enabled : true;
    const config =
      options?.config !== undefined && typeof options.config === 'object' && options.config !== null && !Array.isArray(options.config)
        ? options.config
        : {};

    const catalog = await pool.query(
      `SELECT id, name, description, code, entrypoint, version
       FROM gitu_plugin_catalog
       WHERE id = $1 AND is_active = true`,
      [catalogId]
    );
    if (catalog.rows.length === 0) throw new Error('CATALOG_PLUGIN_NOT_FOUND');

    const row = catalog.rows[0];
    const id = uuidv4();
    const res = await pool.query(
      `INSERT INTO gitu_plugins (id, user_id, name, description, code, entrypoint, config, source_catalog_id, source_catalog_version, enabled)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        id,
        userId,
        row.name,
        row.description ?? null,
        row.code,
        row.entrypoint ?? 'run',
        JSON.stringify(config),
        row.id,
        row.version ?? null,
        enabled,
      ]
    );
    return this.mapPluginRow(res.rows[0]);
  }

  async executePlugin(
    userId: string,
    pluginId: string,
    input?: any,
    context?: any,
    options?: { timeoutMs?: number }
  ) {
    const plugin = await this.getPlugin(userId, pluginId);
    if (!plugin) throw new Error('PLUGIN_NOT_FOUND');
    if (!plugin.enabled) throw new Error('PLUGIN_DISABLED');

    const timeoutMs = Math.min(Math.max(options?.timeoutMs ?? 10_000, 200), 60_000);
    const logs: string[] = [];
    const started = Date.now();

    try {
      const vmContext = buildSandbox(logs);
      const exportsObj = compilePlugin(plugin.code, vmContext, 200);
      const entry = resolveEntrypoint(exportsObj, plugin.entrypoint);
      if (!entry) throw new Error('ENTRYPOINT_NOT_FOUND');

      const gitu = this.buildGituApi(userId);
      const ctx = { input: safeJson(input), context: safeJson(context), config: safeJson(plugin.config), gitu };

      const resultPromise = Promise.resolve(entry(ctx));
      const result = await Promise.race([
        resultPromise,
        new Promise((_, reject) => setTimeout(() => reject(new Error('PLUGIN_TIMEOUT')), timeoutMs)),
      ]);

      const durationMs = Date.now() - started;
      const safeResult = safeJson(result);
      await this.recordExecution(userId, pluginId, true, durationMs, safeResult, null, logs);
      return { success: true, result: safeResult, logs, durationMs };
    } catch (e: any) {
      const durationMs = Date.now() - started;
      const message = e?.message || String(e);
      await this.recordExecution(userId, pluginId, false, durationMs, null, message, logs);
      return { success: false, error: message, logs, durationMs };
    }
  }

  async listExecutions(userId: string, pluginId: string, limit: number = 50, offset: number = 0): Promise<PluginExecutionRow[]> {
    const lim = Math.min(Math.max(limit, 1), 200);
    const off = Math.max(offset, 0);
    const res = await pool.query(
      `SELECT id, success, duration_ms, result, error, logs, executed_at
       FROM gitu_plugin_executions
       WHERE user_id = $1 AND plugin_id = $2
       ORDER BY executed_at DESC
       LIMIT $3 OFFSET $4`,
      [userId, pluginId, lim, off]
    );
    return res.rows.map((r: any) => ({
      id: r.id,
      success: Boolean(r.success),
      durationMs: r.duration_ms ?? 0,
      result: r.result ?? null,
      error: r.error ?? null,
      logs: Array.isArray(r.logs) ? r.logs : [],
      executedAt: r.executed_at ? new Date(r.executed_at) : new Date(),
    }));
  }

  private buildGituApi(userId: string) {
    return {
      files: {
        list: async (path: string) => {
          const p = normalizeScopePath(path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'read',
            scope: { path: p },
          });
          if (!ok) throw new Error('FILE_ACCESS_DENIED');
          return listDir(userId, p);
        },
        read: async (path: string) => {
          const p = normalizeScopePath(path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'read',
            scope: { path: p },
          });
          if (!ok) throw new Error('FILE_ACCESS_DENIED');
          return readFile(userId, p);
        },
        write: async (path: string, content: string) => {
          const p = normalizeScopePath(path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'write',
            scope: { path: p },
          });
          if (!ok) throw new Error('FILE_ACCESS_DENIED');
          await writeFile(userId, p, String(content));
          return { path: p };
        },
      },
      shell: {
        execute: async (params: {
          command: string;
          args?: string[];
          cwd?: string;
          timeoutMs?: number;
          sandboxed?: boolean;
        }): Promise<ShellExecuteResult> => {
          return gituShellManager.execute(userId, params);
        },
      },
    };
  }

  private async recordExecution(
    userId: string,
    pluginId: string,
    success: boolean,
    durationMs: number,
    result: any,
    error: string | null,
    logs: string[]
  ) {
    try {
      await pool.query(
        `INSERT INTO gitu_plugin_executions (user_id, plugin_id, success, duration_ms, result, error, logs)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [userId, pluginId, success, durationMs, result ? JSON.stringify(result) : null, error, JSON.stringify(logs)]
      );
    } catch {}
  }

  private mapPluginRow(row: any): GituPlugin {
    return {
      id: row.id,
      userId: row.user_id,
      name: row.name,
      description: row.description ?? null,
      code: row.code,
      entrypoint: row.entrypoint ?? 'run',
      config: row.config ?? {},
      sourceCatalogId: row.source_catalog_id ?? null,
      sourceCatalogVersion: row.source_catalog_version ?? null,
      enabled: Boolean(row.enabled),
      createdAt: row.created_at ? new Date(row.created_at) : new Date(),
      updatedAt: row.updated_at ? new Date(row.updated_at) : new Date(),
    };
  }
}

export const gituPluginSystem = new GituPluginSystem();
