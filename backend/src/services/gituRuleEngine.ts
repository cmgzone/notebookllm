import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { gituPermissionManager } from './gituPermissionManager.js';
import { listDir, readFile, writeFile } from './gituFileManager.js';
import { gituShellManager, type ShellExecuteResult } from './gituShellManager.js';

export type RuleTrigger =
  | { type: 'manual' }
  | { type: 'event'; eventType: string };

export type RuleCondition =
  | { type: 'equals'; path: string; value: any }
  | { type: 'contains'; path: string; value: string }
  | { type: 'exists'; path: string };

export type RuleAction =
  | {
      type: 'shell.execute';
      command: string;
      args?: string[];
      cwd?: string;
      timeoutMs?: number;
      sandboxed?: boolean;
    }
  | { type: 'files.write'; path: string; content: string }
  | { type: 'files.read'; path: string }
  | { type: 'files.list'; path: string };

export interface AutomationRule {
  id: string;
  userId: string;
  name: string;
  description?: string | null;
  trigger: RuleTrigger;
  conditions: RuleCondition[];
  actions: RuleAction[];
  enabled: boolean;
  createdAt: Date;
}

export interface RuleValidationResult {
  valid: boolean;
  errors: string[];
}

export interface ExecuteRuleResult {
  ruleId: string;
  matched: boolean;
  conditionResults: { index: number; ok: boolean }[];
  actionResults: Array<{
    index: number;
    type: RuleAction['type'];
    success: boolean;
    output?: any;
    error?: string;
  }>;
}

type AnyObj = Record<string, any>;

const normalizeScopePath = (p: string) =>
  p
    .trim()
    .replace(/^(\.\/|\.\\)+/, '')
    .replace(/\\/g, '/')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

function getByPath(input: any, pathExpr: string) {
  if (!pathExpr) return undefined;
  const parts = pathExpr.split('.').map(p => p.trim()).filter(Boolean);
  let cur: any = input;
  for (const key of parts) {
    if (cur === null || cur === undefined) return undefined;
    if (typeof cur !== 'object') return undefined;
    cur = (cur as AnyObj)[key];
  }
  return cur;
}

function asArray(value: any): any[] {
  if (Array.isArray(value)) return value;
  return [];
}

function isString(v: any): v is string {
  return typeof v === 'string';
}

function isObject(v: any): v is Record<string, any> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function parseTrigger(raw: any): RuleTrigger | null {
  if (!isObject(raw)) return null;
  if (raw.type === 'manual') return { type: 'manual' };
  if (raw.type === 'event' && isString(raw.eventType) && raw.eventType.trim().length > 0) {
    return { type: 'event', eventType: raw.eventType.trim() };
  }
  return null;
}

function parseConditions(raw: any): RuleCondition[] | null {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) return null;
  const out: RuleCondition[] = [];
  for (const c of raw) {
    if (!isObject(c) || !isString(c.type)) return null;
    if (c.type === 'equals' && isString(c.path) && c.path.trim().length > 0) {
      out.push({ type: 'equals', path: c.path.trim(), value: (c as AnyObj).value });
      continue;
    }
    if (c.type === 'contains' && isString(c.path) && isString((c as AnyObj).value)) {
      out.push({ type: 'contains', path: c.path.trim(), value: String((c as AnyObj).value) });
      continue;
    }
    if (c.type === 'exists' && isString(c.path) && c.path.trim().length > 0) {
      out.push({ type: 'exists', path: c.path.trim() });
      continue;
    }
    return null;
  }
  return out;
}

function parseActions(raw: any): RuleAction[] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const out: RuleAction[] = [];
  for (const a of raw) {
    if (!isObject(a) || !isString(a.type)) return null;

    if (a.type === 'shell.execute') {
      const command = (a as AnyObj).command;
      const args = (a as AnyObj).args;
      const cwd = (a as AnyObj).cwd;
      const timeoutMs = (a as AnyObj).timeoutMs;
      const sandboxed = (a as AnyObj).sandboxed;

      if (!isString(command) || command.trim().length === 0) return null;
      if (args !== undefined && !Array.isArray(args)) return null;
      if (cwd !== undefined && !isString(cwd)) return null;
      if (timeoutMs !== undefined && typeof timeoutMs !== 'number') return null;
      if (sandboxed !== undefined && typeof sandboxed !== 'boolean') return null;

      out.push({
        type: 'shell.execute',
        command: command.trim(),
        args: Array.isArray(args) ? args.filter(isString) : undefined,
        cwd: isString(cwd) ? cwd.trim() : undefined,
        timeoutMs: typeof timeoutMs === 'number' ? timeoutMs : undefined,
        sandboxed: typeof sandboxed === 'boolean' ? sandboxed : undefined,
      });
      continue;
    }

    if (a.type === 'files.write') {
      const p = (a as AnyObj).path;
      const content = (a as AnyObj).content;
      if (!isString(p) || p.trim().length === 0) return null;
      if (!isString(content)) return null;
      out.push({ type: 'files.write', path: p.trim(), content });
      continue;
    }

    if (a.type === 'files.read') {
      const p = (a as AnyObj).path;
      if (!isString(p) || p.trim().length === 0) return null;
      out.push({ type: 'files.read', path: p.trim() });
      continue;
    }

    if (a.type === 'files.list') {
      const p = (a as AnyObj).path;
      if (!isString(p) || p.trim().length === 0) return null;
      out.push({ type: 'files.list', path: p.trim() });
      continue;
    }

    return null;
  }
  return out;
}

function matchesTrigger(trigger: RuleTrigger, context: any): boolean {
  if (trigger.type === 'manual') return true;
  const eventType = getByPath(context, 'event.type');
  return typeof eventType === 'string' && eventType === trigger.eventType;
}

function evalCondition(condition: RuleCondition, context: any): boolean {
  const v = getByPath(context, condition.path);
  if (condition.type === 'exists') return v !== undefined && v !== null;
  if (condition.type === 'equals') return v === condition.value;
  if (condition.type === 'contains') {
    if (typeof v === 'string') return v.includes(condition.value);
    if (Array.isArray(v)) return v.some(item => String(item).includes(condition.value));
    return false;
  }
  return false;
}

class GituRuleEngine {
  validateRule(input: {
    name?: unknown;
    description?: unknown;
    trigger?: unknown;
    conditions?: unknown;
    actions?: unknown;
    enabled?: unknown;
  }): RuleValidationResult {
    const errors: string[] = [];
    const name = input.name;
    if (!isString(name) || name.trim().length < 2) errors.push('NAME_REQUIRED');

    const trigger = parseTrigger(input.trigger);
    if (!trigger) errors.push('TRIGGER_INVALID');

    const conditions = parseConditions(input.conditions);
    if (!conditions) errors.push('CONDITIONS_INVALID');

    const actions = parseActions(input.actions);
    if (!actions) errors.push('ACTIONS_INVALID');

    if (typeof input.enabled !== 'boolean' && input.enabled !== undefined) errors.push('ENABLED_INVALID');

    return { valid: errors.length === 0, errors };
  }

  async createRule(userId: string, input: AnyObj): Promise<AutomationRule> {
    const v = this.validateRule(input);
    if (!v.valid) throw new Error(v.errors.join(','));

    const id = uuidv4();
    const name = String(input.name).trim();
    const description = isString(input.description) ? input.description.trim() : null;
    const trigger = parseTrigger(input.trigger)!;
    const conditions = parseConditions(input.conditions) ?? [];
    const actions = parseActions(input.actions)!;
    const enabled = typeof input.enabled === 'boolean' ? input.enabled : true;

    const result = await pool.query(
      `INSERT INTO gitu_automation_rules (id, user_id, name, description, trigger, conditions, actions, enabled)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        id,
        userId,
        name,
        description,
        JSON.stringify(trigger),
        JSON.stringify(conditions),
        JSON.stringify(actions),
        enabled,
      ]
    );
    return this.mapRow(result.rows[0]);
  }

  async listRules(userId: string, options?: { enabled?: boolean }): Promise<AutomationRule[]> {
    const where: string[] = ['user_id = $1'];
    const params: any[] = [userId];
    let i = 2;
    if (typeof options?.enabled === 'boolean') {
      where.push(`enabled = $${i++}`);
      params.push(options.enabled);
    }
    const res = await pool.query(
      `SELECT * FROM gitu_automation_rules WHERE ${where.join(' AND ')} ORDER BY created_at DESC`,
      params
    );
    return res.rows.map(r => this.mapRow(r));
  }

  async getRule(userId: string, ruleId: string): Promise<AutomationRule | null> {
    const res = await pool.query(`SELECT * FROM gitu_automation_rules WHERE id = $1 AND user_id = $2`, [
      ruleId,
      userId,
    ]);
    if (res.rows.length === 0) return null;
    return this.mapRow(res.rows[0]);
  }

  async updateRule(userId: string, ruleId: string, updates: AnyObj): Promise<AutomationRule> {
    const existing = await this.getRule(userId, ruleId);
    if (!existing) throw new Error('RULE_NOT_FOUND');

    const next = {
      name: updates.name ?? existing.name,
      description: updates.description ?? existing.description,
      trigger: updates.trigger ?? existing.trigger,
      conditions: updates.conditions ?? existing.conditions,
      actions: updates.actions ?? existing.actions,
      enabled: updates.enabled ?? existing.enabled,
    };

    const v = this.validateRule(next);
    if (!v.valid) throw new Error(v.errors.join(','));

    const trigger = parseTrigger(next.trigger)!;
    const conditions = parseConditions(next.conditions) ?? [];
    const actions = parseActions(next.actions)!;

    const res = await pool.query(
      `UPDATE gitu_automation_rules
       SET name = $1,
           description = $2,
           trigger = $3,
           conditions = $4,
           actions = $5,
           enabled = $6
       WHERE id = $7 AND user_id = $8
       RETURNING *`,
      [
        String(next.name).trim(),
        isString(next.description) ? next.description.trim() : null,
        JSON.stringify(trigger),
        JSON.stringify(conditions),
        JSON.stringify(actions),
        Boolean(next.enabled),
        ruleId,
        userId,
      ]
    );
    return this.mapRow(res.rows[0]);
  }

  async deleteRule(userId: string, ruleId: string): Promise<boolean> {
    const res = await pool.query(`DELETE FROM gitu_automation_rules WHERE id = $1 AND user_id = $2 RETURNING id`, [
      ruleId,
      userId,
    ]);
    return res.rows.length > 0;
  }

  async executeRule(userId: string, ruleId: string, context: any): Promise<ExecuteRuleResult> {
    const rule = await this.getRule(userId, ruleId);
    if (!rule) throw new Error('RULE_NOT_FOUND');
    if (!rule.enabled) {
      return { ruleId, matched: false, conditionResults: [], actionResults: [] };
    }

    const matched = matchesTrigger(rule.trigger, context) && rule.conditions.every(c => evalCondition(c, context));
    const conditionResults = rule.conditions.map((c, index) => ({ index, ok: evalCondition(c, context) }));

    if (!matched) {
      const result: ExecuteRuleResult = { ruleId, matched: false, conditionResults, actionResults: [] };
      await this.recordExecution(userId, ruleId, false, true, result, null);
      return result;
    }

    const actionResults: ExecuteRuleResult['actionResults'] = [];
    for (let index = 0; index < rule.actions.length; index++) {
      const action = rule.actions[index];
      try {
        if (action.type === 'shell.execute') {
          const result: ShellExecuteResult = await gituShellManager.execute(userId, {
            command: action.command,
            args: action.args,
            cwd: action.cwd,
            timeoutMs: action.timeoutMs,
            sandboxed: action.sandboxed,
          });
          actionResults.push({
            index,
            type: action.type,
            success: result.success,
            output: {
              exitCode: result.exitCode,
              stdout: result.stdout,
              stderr: result.stderr,
              auditLogId: result.auditLogId,
              timedOut: result.timedOut,
              durationMs: result.durationMs,
            },
            error: result.success ? undefined : result.error,
          });
          continue;
        }

        if (action.type === 'files.write') {
          const p = normalizeScopePath(action.path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'write',
            scope: { path: p },
          });
          if (!ok) {
            actionResults.push({ index, type: action.type, success: false, error: 'FILE_ACCESS_DENIED' });
            continue;
          }
          await writeFile(userId, p, action.content);
          actionResults.push({ index, type: action.type, success: true, output: { path: p } });
          continue;
        }

        if (action.type === 'files.read') {
          const p = normalizeScopePath(action.path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'read',
            scope: { path: p },
          });
          if (!ok) {
            actionResults.push({ index, type: action.type, success: false, error: 'FILE_ACCESS_DENIED' });
            continue;
          }
          const content = await readFile(userId, p);
          actionResults.push({ index, type: action.type, success: true, output: { path: p, content } });
          continue;
        }

        if (action.type === 'files.list') {
          const p = normalizeScopePath(action.path);
          const ok = await gituPermissionManager.checkPermission(userId, {
            resource: 'files',
            action: 'read',
            scope: { path: p },
          });
          if (!ok) {
            actionResults.push({ index, type: action.type, success: false, error: 'FILE_ACCESS_DENIED' });
            continue;
          }
          const entries = await listDir(userId, p);
          actionResults.push({ index, type: action.type, success: true, output: { path: p, entries } });
          continue;
        }
      } catch (e: any) {
        actionResults.push({
          index,
          type: action.type,
          success: false,
          error: e?.message || String(e),
        });
      }
    }

    const result: ExecuteRuleResult = { ruleId, matched: true, conditionResults, actionResults };
    const success = actionResults.every(a => a.success);
    await this.recordExecution(userId, ruleId, true, success, result, null);
    return result;
  }

  private async recordExecution(
    userId: string,
    ruleId: string,
    matched: boolean,
    success: boolean,
    result: ExecuteRuleResult | null,
    error: string | null
  ) {
    try {
      await pool.query(
        `INSERT INTO gitu_rule_executions (user_id, rule_id, matched, success, result, error)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, ruleId, matched, success, result ? JSON.stringify(result) : null, error]
      );
    } catch {}
  }

  private mapRow(row: any): AutomationRule {
    const trigger = parseTrigger(row.trigger) ?? ({ type: 'manual' } as RuleTrigger);
    const conditions = parseConditions(row.conditions) ?? [];
    const actions = parseActions(row.actions) ?? [];
    return {
      id: row.id,
      userId: row.user_id,
      name: row.name,
      description: row.description ?? null,
      trigger,
      conditions,
      actions,
      enabled: Boolean(row.enabled),
      createdAt: row.created_at ? new Date(row.created_at) : new Date(),
    };
  }
}

export const gituRuleEngine = new GituRuleEngine();
