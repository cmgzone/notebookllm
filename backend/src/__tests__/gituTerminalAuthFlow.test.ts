import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';
import { authenticateToken } from '../middleware/auth.js';

// Create test app
const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Gitu Terminal Authentication Flow - Integration Tests', () => {
  const testUserId = 'test-user-auth-flow-' + Date.now();
  const testEmail = `test-auth-flow-${Date.now()}@example.com`;
  const testDeviceId = 'test-device-' + Date.now();
  const testDeviceName = 'Test Terminal';
  const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  
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

    // Create test user
    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name) 
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );

    // Generate user auth token for authenticated endpoints
    userAuthToken = jwt.sign({ userId: testUserId }, JWT_SECRET, { expiresIn: '1h' });
  });

  afterAll(async () => {
    // Cleanup test data
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
  });

  afterEach(async () => {
    // Clean up after each test
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
  });

  describe('Complete Authentication Flow', () => {
    it('should complete full terminal linking flow', async () => {
      // Step 1: Generate pairing token (user in Flutter app)
      const generateResponse = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .expect(200);

      expect(generateResponse.body.token).toMatch(/^GITU-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
      expect(generateResponse.body.expiresAt).toBeDefined();
      expect(generateResponse.body.expiresInSeconds).toBe(300);

      const pairingToken = generateResponse.body.token;

      // Step 2: Link terminal with pairing token (terminal CLI)
      const linkResponse = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: pairingToken,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        })
        .expect(200);

      expect(linkResponse.body.authToken).toBeDefined();
      expect(linkResponse.body.userId).toBe(testUserId);
      expect(linkResponse.body.expiresInDays).toBe(90);

      const terminalAuthToken = linkResponse.body.authToken;

      // Step 3: Validate terminal auth token
      const validateResponse = await request(app)
        .post('/api/gitu/terminal/validate')
        .send({ authToken: terminalAuthToken })
        .expect(200);

      expect(validateResponse.body.valid).toBe(true);
      expect(validateResponse.body.userId).toBe(testUserId);
      expect(validateResponse.body.deviceId).toBe(testDeviceId);

      // Step 4: List linked devices (user in Flutter app)
      const listResponse = await request(app)
        .get('/api/gitu/terminal/devices')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .expect(200);

      expect(listResponse.body.devices).toHaveLength(1);
      expect(listResponse.body.devices[0].deviceId).toBe(testDeviceId);
      expect(listResponse.body.devices[0].deviceName).toBe(testDeviceName);
      expect(listResponse.body.devices[0].status).toBe('active');

      // Step 5: Refresh auth token (terminal CLI)
      await new Promise(resolve => setTimeout(resolve, 1100)); // Wait for different iat
      
      const refreshResponse = await request(app)
        .post('/api/gitu/terminal/refresh')
        .send({ authToken: terminalAuthToken })
        .expect(200);

      expect(refreshResponse.body.authToken).toBeDefined();
      expect(refreshResponse.body.authToken).not.toBe(terminalAuthToken);
      expect(refreshResponse.body.expiresInDays).toBe(90);

      // Step 6: Unlink terminal (user in Flutter app)
      const unlinkResponse = await request(app)
        .post('/api/gitu/terminal/unlink')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .send({ deviceId: testDeviceId })
        .expect(200);

      expect(unlinkResponse.body.success).toBe(true);

      // Step 7: Verify device is unlinked
      const validateAfterUnlink = await request(app)
        .post('/api/gitu/terminal/validate')
        .send({ authToken: terminalAuthToken })
        .expect(200);

      expect(validateAfterUnlink.body.valid).toBe(false);
      expect(validateAfterUnlink.body.error).toBe('Device not linked');
    });
  });

  describe('POST /api/gitu/terminal/generate-token', () => {
    it('should require authentication', async () => {
      await request(app)
        .post('/api/gitu/terminal/generate-token')
        .expect(401);
    });

    it('should generate pairing token with valid auth', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .expect(200);

      expect(response.body.token).toMatch(/^GITU-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
      expect(response.body.expiresAt).toBeDefined();
      expect(response.body.expiresInSeconds).toBe(300);
    });
  });

  describe('POST /api/gitu/terminal/link', () => {
    let pairingToken: string;

    beforeEach(async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`);
      pairingToken = response.body.token;
    });

    it('should link terminal with valid token', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: pairingToken,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        })
        .expect(200);

      expect(response.body.authToken).toBeDefined();
      expect(response.body.userId).toBe(testUserId);
      expect(response.body.expiresInDays).toBe(90);
    });

    it('should reject invalid token', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: 'GITU-INVALID-TOKEN',
          deviceId: testDeviceId,
          deviceName: testDeviceName
        })
        .expect(401);

      expect(response.body.error).toContain('Invalid or expired');
    });

    it('should require token field', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          deviceId: testDeviceId,
          deviceName: testDeviceName
        })
        .expect(400);

      expect(response.body.error).toBeDefined();
    });

    it('should require deviceId field', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: pairingToken,
          deviceName: testDeviceName
        })
        .expect(400);

      expect(response.body.error).toBeDefined();
    });
  });

  describe('POST /api/gitu/terminal/validate', () => {
    let terminalAuthToken: string;

    beforeEach(async () => {
      const generateResponse = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`);

      const linkResponse = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: generateResponse.body.token,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        });

      terminalAuthToken = linkResponse.body.authToken;
    });

    it('should validate correct auth token', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/validate')
        .send({ authToken: terminalAuthToken })
        .expect(200);

      expect(response.body.valid).toBe(true);
      expect(response.body.userId).toBe(testUserId);
      expect(response.body.deviceId).toBe(testDeviceId);
    });

    it('should reject invalid auth token', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/validate')
        .send({ authToken: 'invalid-token' })
        .expect(200);

      expect(response.body.valid).toBe(false);
      expect(response.body.error).toBeDefined();
    });

    it('should require authToken field', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/validate')
        .send({})
        .expect(400);

      expect(response.body.error).toBe('authToken is required');
    });
  });

  describe('GET /api/gitu/terminal/devices', () => {
    it('should require authentication', async () => {
      await request(app)
        .get('/api/gitu/terminal/devices')
        .expect(401);
    });

    it('should list linked devices', async () => {
      // Link a device first
      const generateResponse = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`);

      await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: generateResponse.body.token,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        });

      // List devices
      const response = await request(app)
        .get('/api/gitu/terminal/devices')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .expect(200);

      expect(response.body.devices).toHaveLength(1);
      expect(response.body.devices[0].deviceId).toBe(testDeviceId);
      expect(response.body.devices[0].deviceName).toBe(testDeviceName);
    });

    it('should return empty array when no devices linked', async () => {
      const response = await request(app)
        .get('/api/gitu/terminal/devices')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .expect(200);

      expect(response.body.devices).toEqual([]);
    });
  });

  describe('POST /api/gitu/terminal/unlink', () => {
    beforeEach(async () => {
      // Link a device
      const generateResponse = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`);

      await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: generateResponse.body.token,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        });
    });

    it('should require authentication', async () => {
      await request(app)
        .post('/api/gitu/terminal/unlink')
        .send({ deviceId: testDeviceId })
        .expect(401);
    });

    it('should unlink device successfully', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/unlink')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .send({ deviceId: testDeviceId })
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    it('should return 404 for non-existent device', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/unlink')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .send({ deviceId: 'non-existent-device' })
        .expect(404);

      expect(response.body.error).toBe('Device not found');
    });
  });

  describe('POST /api/gitu/terminal/refresh', () => {
    let terminalAuthToken: string;

    beforeEach(async () => {
      const generateResponse = await request(app)
        .post('/api/gitu/terminal/generate-token')
        .set('Authorization', `Bearer ${userAuthToken}`);

      const linkResponse = await request(app)
        .post('/api/gitu/terminal/link')
        .send({
          token: generateResponse.body.token,
          deviceId: testDeviceId,
          deviceName: testDeviceName
        });

      terminalAuthToken = linkResponse.body.authToken;
    });

    it('should refresh valid auth token', async () => {
      await new Promise(resolve => setTimeout(resolve, 1100)); // Wait for different iat
      
      const response = await request(app)
        .post('/api/gitu/terminal/refresh')
        .send({ authToken: terminalAuthToken })
        .expect(200);

      expect(response.body.authToken).toBeDefined();
      expect(response.body.authToken).not.toBe(terminalAuthToken);
      expect(response.body.expiresInDays).toBe(90);
    });

    it('should reject refresh for unlinked device', async () => {
      // Unlink device first
      await request(app)
        .post('/api/gitu/terminal/unlink')
        .set('Authorization', `Bearer ${userAuthToken}`)
        .send({ deviceId: testDeviceId });

      const response = await request(app)
        .post('/api/gitu/terminal/refresh')
        .send({ authToken: terminalAuthToken })
        .expect(401);

      expect(response.body.error).toContain('not linked');
    });

    it('should require authToken field', async () => {
      const response = await request(app)
        .post('/api/gitu/terminal/refresh')
        .send({})
        .expect(400);

      expect(response.body.error).toBe('authToken is required');
    });
  });
});
