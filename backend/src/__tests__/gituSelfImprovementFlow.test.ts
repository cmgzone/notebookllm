import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import fs from 'fs/promises';
import crypto from 'crypto';
import path from 'path';
import { jest } from '@jest/globals';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';
import { gituPermissionManager } from '../services/gituPermissionManager.js';
import { gituAIRouter } from '../services/gituAIRouter.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

function sha256(input: string) {
  return crypto.createHash('sha256').update(input, 'utf8').digest('hex');
}

describe('Self-improvement mission flow', () => {
  const testUserId = `test-user-improve-${Date.now()}`;
  const testEmail = `test-improve-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  let userAuthToken: string;

  const targetPath = 'backend/src/services/gituAgentOrchestrator.ts';

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

    const missionsSql = await fs.readFile('migrations/010_create_gitu_missions.sql', 'utf8');
    await pool.query(missionsSql);

    const agentsSql = await fs.readFile('migrations/add_gitu_agents.sql', 'utf8');
    await pool.query(agentsSql);

    const evalSql = await fs.readFile('migrations/013_create_gitu_evaluations.sql', 'utf8');
    await pool.query(evalSql);

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
      await pool.query('DELETE FROM gitu_evaluations WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_mission_logs WHERE mission_id IN (SELECT id FROM gitu_missions WHERE user_id = $1)', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_missions WHERE user_id = $1', [testUserId]);
    } catch {}
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

  it('requests files read permission when missing', async () => {
    await pool.query(`DELETE FROM gitu_permissions WHERE user_id = $1`, [testUserId]);
    await pool.query(`DELETE FROM gitu_permission_requests WHERE user_id = $1`, [testUserId]);

    const resp = await request(app)
      .post('/api/gitu/improvement/start')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ objective: 'Improve stability', targetPaths: [targetPath] })
      .expect(201);

    expect(resp.body.success).toBe(true);
    expect(resp.body.permissionRequests?.filesRead).toBeTruthy();
    expect(resp.body.mission?.status).toBe('paused');
  });

  it('generates a proposal when files read permission is granted', async () => {
    await pool.query(`DELETE FROM gitu_permissions WHERE user_id = $1`, [testUserId]);
    await pool.query(`DELETE FROM gitu_permission_requests WHERE user_id = $1`, [testUserId]);

    await gituPermissionManager.grantPermission(testUserId, {
      resource: 'files',
      actions: ['read'],
      scope: { allowedPaths: [targetPath] },
      expiresAt: new Date(Date.now() + 60_000),
    });

    const current = await fs.readFile(path.join(process.cwd(), '..', targetPath), 'utf8');
    const currentHash = sha256(current);

    const routeSpy = jest.spyOn(gituAIRouter, 'route').mockResolvedValue({
      content: `\`\`\`json\n${JSON.stringify({
        summary: 'No-op improvement proposal for test',
        risks: [],
        files: [
          {
            path: targetPath,
            expectedOldSha256: currentHash,
            newContent: current,
            reason: 'Test: keep file unchanged'
          }
        ],
        verification: { commands: [] }
      })}\n\`\`\``
    } as any);

    const resp = await request(app)
      .post('/api/gitu/improvement/start')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ objective: 'Improve stability', targetPaths: [targetPath] })
      .expect(201);

    routeSpy.mockRestore();

    expect(resp.body.success).toBe(true);
    expect(resp.body.proposal?.summary).toContain('No-op improvement');
    expect(resp.body.proposal?.files?.length).toBe(1);
  });
});
