import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import fs from 'fs/promises';
import path from 'path';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Gitu Rule Engine - Integration', () => {
  const testUserId = `test-user-rules-${Date.now()}`;
  const testEmail = `test-rules-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });

  const allowedDir = `tmp/gitu-rules-test-${Date.now()}`;
  const allowedFilePath = `${allowedDir}/hello.txt`;
  const repoRoot = path.resolve(process.cwd(), '..');
  const allowedDirAbs = path.join(repoRoot, allowedDir);

  beforeAll(async () => {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_permissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        resource TEXT NOT NULL,
        actions TEXT[] NOT NULL,
        scope JSONB DEFAULT '{}',
        granted_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ,
        revoked_at TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_permissions_user ON gitu_permissions(user_id, resource);
      CREATE INDEX IF NOT EXISTS idx_gitu_permissions_active ON gitu_permissions(user_id, resource) WHERE revoked_at IS NULL;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_automation_rules (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        trigger JSONB NOT NULL,
        conditions JSONB DEFAULT '[]',
        actions JSONB NOT NULL,
        enabled BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_automation_user ON gitu_automation_rules(user_id, enabled);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_rule_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        rule_id UUID NOT NULL,
        matched BOOLEAN NOT NULL,
        success BOOLEAN NOT NULL,
        result JSONB,
        error TEXT,
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_user_time ON gitu_rule_executions(user_id, executed_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_rule_time ON gitu_rule_executions(rule_id, executed_at DESC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS file_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        path TEXT NOT NULL,
        success BOOLEAN DEFAULT true,
        error_message TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_file_audit_user ON file_audit_logs(user_id);
      CREATE INDEX IF NOT EXISTS idx_file_audit_action ON file_audit_logs(action);
    `);

    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name) 
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );

    await fs.mkdir(allowedDirAbs, { recursive: true });
  });

  afterAll(async () => {
    try {
      await pool.query('DELETE FROM file_audit_logs WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_rule_executions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_automation_rules WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
    await fs.rm(allowedDirAbs, { recursive: true, force: true });
  });

  it('creates, validates, lists, and executes a manual rule with file actions', async () => {
    await request(app)
      .put('/api/gitu/files/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedPaths: [allowedDir] })
      .expect(200);

    const validate = await request(app)
      .post('/api/gitu/rules/validate')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({
        name: 'Write hello',
        trigger: { type: 'manual' },
        conditions: [],
        actions: [{ type: 'files.write', path: allowedFilePath, content: 'hello' }],
        enabled: true,
      })
      .expect(200);
    expect(validate.body.result.valid).toBe(true);

    const created = await request(app)
      .post('/api/gitu/rules')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({
        name: 'Write then read',
        trigger: { type: 'manual' },
        conditions: [{ type: 'exists', path: 'event.type' }],
        actions: [
          { type: 'files.write', path: allowedFilePath, content: 'hello' },
          { type: 'files.read', path: allowedFilePath },
        ],
        enabled: true,
      })
      .expect(201);

    const ruleId = created.body.rule.id as string;
    expect(ruleId).toBeTruthy();

    const list = await request(app)
      .get('/api/gitu/rules')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);
    expect((list.body.rules as any[]).some(r => r.id === ruleId)).toBe(true);

    const executeNoMatch = await request(app)
      .post(`/api/gitu/rules/${ruleId}/execute`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ context: { event: {} } })
      .expect(200);
    expect(executeNoMatch.body.result.matched).toBe(false);

    const execute = await request(app)
      .post(`/api/gitu/rules/${ruleId}/execute`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ context: { event: { type: 'manual' } } })
      .expect(200);

    expect(execute.body.result.matched).toBe(true);
    expect(execute.body.result.actionResults[0].success).toBe(true);
    expect(execute.body.result.actionResults[1].success).toBe(true);
    expect(execute.body.result.actionResults[1].output.content).toBe('hello');

    const history = await request(app)
      .get(`/api/gitu/rules/${ruleId}/executions`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ limit: 10 })
      .expect(200);
    expect((history.body.executions as any[]).length).toBeGreaterThanOrEqual(2);
  });

  it('honors event triggers and conditions', async () => {
    const created = await request(app)
      .post('/api/gitu/rules')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({
        name: 'Event-only rule',
        trigger: { type: 'event', eventType: 'email.received' },
        conditions: [{ type: 'equals', path: 'event.type', value: 'email.received' }],
        actions: [{ type: 'files.list', path: allowedDir }],
        enabled: true,
      })
      .expect(201);

    const ruleId = created.body.rule.id as string;

    const noMatch = await request(app)
      .post(`/api/gitu/rules/${ruleId}/execute`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ context: { event: { type: 'other' } } })
      .expect(200);
    expect(noMatch.body.result.matched).toBe(false);

    const match = await request(app)
      .post(`/api/gitu/rules/${ruleId}/execute`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ context: { event: { type: 'email.received' } } })
      .expect(200);
    expect(match.body.result.matched).toBe(true);
    expect(match.body.result.actionResults[0].success).toBe(true);
  });
});
