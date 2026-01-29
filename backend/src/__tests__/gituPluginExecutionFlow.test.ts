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

describe('Gitu Plugin System - Integration', () => {
  const testUserId = `test-user-plugins-${Date.now()}`;
  const testEmail = `test-plugins-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });

  const allowedDir = `tmp/gitu-plugins-test-${Date.now()}`;
  const allowedFilePath = `${allowedDir}/plugin.txt`;
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
      CREATE TABLE IF NOT EXISTS gitu_plugins (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        entrypoint TEXT DEFAULT 'run',
        config JSONB DEFAULT '{}',
        source_catalog_id UUID,
        source_catalog_version TEXT,
        enabled BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_user ON gitu_plugins(user_id, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_enabled ON gitu_plugins(user_id, enabled);
    `);
    await pool.query(`
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS config JSONB DEFAULT '{}';
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS source_catalog_id UUID;
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS source_catalog_version TEXT;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugin_executions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        plugin_id UUID NOT NULL,
        success BOOLEAN NOT NULL,
        duration_ms INTEGER DEFAULT 0,
        result JSONB,
        error TEXT,
        logs JSONB DEFAULT '[]',
        executed_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_user_time ON gitu_plugin_executions(user_id, executed_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_plugin_time ON gitu_plugin_executions(plugin_id, executed_at DESC);
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
      await pool.query('DELETE FROM gitu_plugin_executions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_plugins WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
    await fs.rm(allowedDirAbs, { recursive: true, force: true });
  });

  it('creates and executes a sandboxed plugin using file API', async () => {
    await request(app)
      .put('/api/gitu/files/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedPaths: [allowedDir] })
      .expect(200);

    const pluginCode = `
      module.exports = async (ctx) => {
        await ctx.gitu.files.write(ctx.input.path, ctx.input.content);
        const read = await ctx.gitu.files.read(ctx.input.path);
        return { ok: true, read };
      };
    `;

    const created = await request(app)
      .post('/api/gitu/plugins')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({
        name: 'File plugin',
        description: 'writes and reads a file',
        code: pluginCode,
        entrypoint: 'run',
        enabled: true,
      })
      .expect(201);

    const pluginId = created.body.plugin.id as string;
    expect(pluginId).toBeTruthy();

    const executed = await request(app)
      .post(`/api/gitu/plugins/${pluginId}/execute`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ input: { path: allowedFilePath, content: 'hello' }, context: { event: { type: 'manual' } } })
      .expect(200);

    expect(executed.body.result.success).toBe(true);
    expect(executed.body.result.result.ok).toBe(true);
    expect(executed.body.result.result.read).toBe('hello');

    const history = await request(app)
      .get(`/api/gitu/plugins/${pluginId}/executions`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ limit: 10 })
      .expect(200);

    expect((history.body.executions as any[]).length).toBeGreaterThanOrEqual(1);
  });

  it('rejects plugins with disallowed code', async () => {
    const pluginCode = `module.exports = async () => { return process.env; };`;
    const res = await request(app)
      .post('/api/gitu/plugins/validate')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ name: 'bad', code: pluginCode })
      .expect(200);
    expect(res.body.result.valid).toBe(false);
  });
});
