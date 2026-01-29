import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Terminal Auth + Shell Permissions - E2E', () => {
  const testUserId = `test-user-terminal-shell-${Date.now()}`;
  const testEmail = `test-terminal-shell-${Date.now()}@example.com`;
  const testDeviceId = `test-device-terminal-shell-${Date.now()}`;
  const testDeviceName = 'Test Terminal Device';
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const cwd = process.cwd();

  let userAuthToken: string;

  beforeAll(async () => {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_pairing_tokens (
        code TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_pairing_tokens_user ON gitu_pairing_tokens(user_id);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_linked_accounts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        platform_user_id TEXT NOT NULL,
        display_name TEXT,
        verified BOOLEAN DEFAULT false,
        status TEXT DEFAULT 'active',
        linked_at TIMESTAMPTZ DEFAULT NOW(),
        last_used_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id, platform);
    `);

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

    userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });
  });

  afterAll(async () => {
    try {
      await pool.query('DELETE FROM gitu_shell_audit_logs WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
  });

  it('allows terminal-authenticated shell execute after user grants permissions', async () => {
    const tokenResp = await request(app)
      .post('/api/gitu/terminal/generate-token')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);

    const pairingToken = tokenResp.body.token as string;

    const linkResp = await request(app)
      .post('/api/gitu/terminal/link')
      .send({ token: pairingToken, deviceId: testDeviceId, deviceName: testDeviceName })
      .expect(200);

    const terminalAuthToken = linkResp.body.authToken as string;

    await request(app)
      .put('/api/gitu/shell/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedCommands: ['node'], allowedPaths: [cwd], allowUnsandboxed: false })
      .expect(200);

    const blockedUnsandboxed = await request(app)
      .post('/api/gitu/shell/execute')
      .set('Authorization', `Bearer ${terminalAuthToken}`)
      .send({ command: 'node', args: ['-e', 'console.log("x")'], sandboxed: false, timeoutMs: 30_000, dryRun: true })
      .expect(403);

    expect(blockedUnsandboxed.body.result.error).toBe('UNSANDBOXED_MODE_NOT_ALLOWED');

    const okSandboxed = await request(app)
      .post('/api/gitu/shell/execute')
      .set('Authorization', `Bearer ${terminalAuthToken}`)
      .send({ command: 'node', args: ['-e', 'console.log("ok")'], cwd, sandboxed: true, timeoutMs: 30_000, dryRun: true })
      .expect(200);

    expect(okSandboxed.body.result.success).toBe(true);
    expect(okSandboxed.body.result.mode).toBe('dry_run');
    expect(okSandboxed.body.result.auditLogId).toBeDefined();
  });
});
