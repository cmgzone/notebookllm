import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';
import { gituPermissionManager } from '../services/gituPermissionManager.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Granular Permissions - Requests, Approval, Scope, Expiry', () => {
  const testUserId = `test-user-perms-${Date.now()}`;
  const testEmail = `test-perms-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

  let userAuthToken: string;

  beforeAll(async () => {
    await pool.query(
      `CREATE TABLE IF NOT EXISTS gitu_permissions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        resource TEXT NOT NULL,
        actions TEXT[] NOT NULL,
        scope JSONB DEFAULT '{}',
        granted_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ,
        revoked_at TIMESTAMPTZ
      );`
    );

    await pool.query(
      `CREATE TABLE IF NOT EXISTS gitu_permission_requests (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        resource TEXT NOT NULL,
        actions TEXT[] NOT NULL,
        scope JSONB DEFAULT '{}',
        expires_at TIMESTAMPTZ,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        requested_at TIMESTAMPTZ DEFAULT NOW(),
        responded_at TIMESTAMPTZ,
        granted_permission_id UUID
      );`
    );

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
      await pool.query('DELETE FROM gitu_permission_requests WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_permissions WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
  });

  it('creates and approves a permission request, then lists permissions', async () => {
    const createResp = await request(app)
      .post('/api/gitu/permissions/requests')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({
        resource: 'files',
        actions: ['read'],
        scope: { allowedPaths: ['*'] },
        reason: 'Need to read files',
        expiresInDays: 7,
      })
      .expect(201);

    const requestId = createResp.body.request.id as string;

    const listPending = await request(app)
      .get('/api/gitu/permissions/requests?status=pending')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);

    expect(listPending.body.requests.some((r: any) => r.id === requestId)).toBe(true);

    const approveResp = await request(app)
      .post(`/api/gitu/permissions/requests/${requestId}/approve`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({})
      .expect(200);

    expect(approveResp.body.permission.resource).toBe('files');
    expect(approveResp.body.permission.actions).toContain('read');

    const permsResp = await request(app)
      .get('/api/gitu/permissions?resource=files')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);

    expect(permsResp.body.permissions.length).toBeGreaterThan(0);
  });

  it('revokes a granted permission via API', async () => {
    const granted = await gituPermissionManager.grantPermission(testUserId, {
      resource: 'shell',
      actions: ['execute'],
      scope: { allowedCommands: ['echo'] },
      expiresAt: new Date(Date.now() + 60_000),
    });

    await request(app)
      .post(`/api/gitu/permissions/${granted.id}/revoke`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({})
      .expect(200);

    const permsResp = await request(app)
      .get('/api/gitu/permissions?resource=shell')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);

    const found = (permsResp.body.permissions as any[]).find((p) => p.id === granted.id);
    expect(found).toBeTruthy();
    expect(found.revokedAt).toBeTruthy();

    await request(app)
      .post(`/api/gitu/permissions/${granted.id}/revoke`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({})
      .expect(404);
  });

  it('enforces expiry and wildcard path scope in checkPermission', async () => {
    await pool.query(`DELETE FROM gitu_permissions WHERE user_id = $1 AND resource = 'files'`, [testUserId]);

    const expired = await gituPermissionManager.grantPermission(testUserId, {
      resource: 'files',
      actions: ['read'],
      scope: { allowedPaths: ['*'] },
      expiresAt: new Date(Date.now() - 60_000),
    });

    const expiredAllowed = await gituPermissionManager.checkPermission(testUserId, {
      resource: 'files',
      action: 'read',
      scope: { path: 'any/path' },
    });
    expect(expiredAllowed).toBe(false);

    const active = await gituPermissionManager.grantPermission(testUserId, {
      resource: 'files',
      actions: ['read'],
      scope: { allowedPaths: ['*'] },
      expiresAt: new Date(Date.now() + 60_000),
    });

    const activeAllowed = await gituPermissionManager.checkPermission(testUserId, {
      resource: 'files',
      action: 'read',
      scope: { path: 'any/path' },
    });
    expect(activeAllowed).toBe(true);

    await gituPermissionManager.revokePermission(testUserId, expired.id);
    await gituPermissionManager.revokePermission(testUserId, active.id);
  });
});
