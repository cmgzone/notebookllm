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

describe('Gitu File Permissions - Integration', () => {
  const testUserId = `test-user-file-perms-${Date.now()}`;
  const testEmail = `test-file-perms-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });

  const allowedDir = `tmp/gitu-file-permissions-test-${Date.now()}`;
  const allowedFilePath = `${allowedDir}/hello.txt`;
  const deniedDir = `tmp/gitu-file-permissions-denied-${Date.now()}`;
  const deniedFilePath = `${deniedDir}/secret.txt`;
  const repoRoot = path.resolve(process.cwd(), '..');
  const allowedDirAbs = path.join(repoRoot, allowedDir);
  const deniedDirAbs = path.join(repoRoot, deniedDir);
  const deniedFileAbs = path.join(repoRoot, deniedFilePath);

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
    await fs.mkdir(deniedDirAbs, { recursive: true });
    await fs.writeFile(deniedFileAbs, 'nope', 'utf8');
  });

  afterAll(async () => {
    try {
      await pool.query('DELETE FROM file_audit_logs WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
    await fs.rm(allowedDirAbs, { recursive: true, force: true });
    await fs.rm(deniedDirAbs, { recursive: true, force: true });
  });

  it('enforces allowed paths for file operations and exposes audit logs', async () => {
    await request(app)
      .put('/api/gitu/files/permissions')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ allowedPaths: [allowedDir] })
      .expect(200);

    await request(app)
      .post('/api/gitu/files/write')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ path: allowedFilePath, content: 'hello' })
      .expect(200);

    const readOk = await request(app)
      .get('/api/gitu/files/read')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ path: allowedFilePath })
      .expect(200);
    expect(readOk.body.content).toBe('hello');

    await request(app)
      .get('/api/gitu/files/read')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ path: deniedFilePath })
      .expect(403);

    const logs = await request(app)
      .get('/api/gitu/files/audit-logs')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ limit: 20 })
      .expect(200);

    const actions = (logs.body.logs as any[]).map(l => l.action);
    expect(actions).toContain('write');
    expect(actions).toContain('read');
  });

  it('revokes access and blocks subsequent operations', async () => {
    await request(app)
      .post('/api/gitu/files/permissions/revoke')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);

    await request(app)
      .get('/api/gitu/files/read')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ path: allowedFilePath })
      .expect(403);
  });
});
