import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Gitu Shell Execution - Integration', () => {
  const testUserId = `test-user-shell-${Date.now()}`;
  const testEmail = `test-shell-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });
  const cwd = process.cwd();

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
      CREATE TABLE IF NOT EXISTS gitu_shell_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        command TEXT NOT NULL,
        args JSONB DEFAULT '[]',
        cwd TEXT,
        success BOOLEAN DEFAULT true,
        exit_code INTEGER,
        error_message TEXT,
        duration_ms INTEGER,
        stdout_bytes INTEGER DEFAULT 0,
        stderr_bytes INTEGER DEFAULT 0,
        stdout_truncated BOOLEAN DEFAULT false,
        stderr_truncated BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_user ON gitu_shell_audit_logs(user_id, created_at DESC);
    `);

    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name) 
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );
  });

  afterAll(async () => {
    try {
      await pool.query('DELETE FROM gitu_shell_audit_logs WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
  });

  it('accepts sandboxed dry-run when allowed and records audit logs', async () => {
    await request(app)
      .put('/api/gitu/shell/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedCommands: ['node'], allowedPaths: [cwd], allowUnsandboxed: false })
      .expect(200);

    const run = await request(app)
      .post('/api/gitu/shell/execute')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ command: 'node', args: ['-e', 'console.log("ok")'], cwd, sandboxed: true, timeoutMs: 30_000, dryRun: true })
      .expect(200);

    expect(run.body.result.success).toBe(true);
    expect(run.body.result.mode).toBe('dry_run');

    const logs = await request(app)
      .get('/api/gitu/shell/audit-logs')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ limit: 10 })
      .expect(200);

    const modes = (logs.body.logs as any[]).map(l => l.mode);
    expect(modes).toContain('dry_run');
  });

  it('blocks unsandboxed mode unless explicitly granted', async () => {
    const blocked = await request(app)
      .post('/api/gitu/shell/execute')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ command: 'node', args: ['-e', 'console.log("x")'], sandboxed: false, timeoutMs: 30_000 })
      .expect(403);

    expect(blocked.body.result.error).toBe('UNSANDBOXED_MODE_NOT_ALLOWED');

    await request(app)
      .put('/api/gitu/shell/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedCommands: ['node'], allowedPaths: [cwd], allowUnsandboxed: true })
      .expect(200);

    const ok = await request(app)
      .post('/api/gitu/shell/execute')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ command: 'node', args: ['-e', 'console.log("ok2")'], sandboxed: false, timeoutMs: 30_000 })
      .expect(200);

    expect(ok.body.result.success).toBe(true);
    expect(ok.body.result.exitCode).toBe(0);
  });
});
