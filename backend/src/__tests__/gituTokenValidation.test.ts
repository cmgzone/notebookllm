import { gituTerminalService } from '../services/gituTerminalService.js';
import pool from '../config/database.js';
import jwt from 'jsonwebtoken';

describe('GituTerminalService - Token Validation and Device Linking', () => {
  const testUserId = 'test-user-validation-' + Date.now();
  const testEmail = `test-validation-${Date.now()}@example.com`;
  const testDeviceId = 'test-device-' + Date.now();
  const testDeviceName = 'Test MacBook Pro';

  beforeAll(async () => {
    // Create test user
    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name) 
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );
  });

  afterAll(async () => {
    // Cleanup test data
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    await pool.end();
  });

  afterEach(async () => {
    // Clean up linked accounts after each test
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
  });

  describe('linkTerminal', () => {
    it('should successfully link terminal with valid pairing token', async () => {
      // Generate pairing token
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);

      // Link terminal
      const result = await gituTerminalService.linkTerminal(
        pairingToken.code,
        testDeviceId,
        testDeviceName
      );

      // Verify result
      expect(result.authToken).toBeDefined();
      expect(result.userId).toBe(testUserId);
      expect(result.expiresInDays).toBe(90);
      expect(result.expiresAt).toBeInstanceOf(Date);

      // Verify JWT token
      const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
      const decoded = jwt.verify(result.authToken, JWT_SECRET) as any;
      expect(decoded.userId).toBe(testUserId);
      expect(decoded.platform).toBe('terminal');
      expect(decoded.deviceId).toBe(testDeviceId);
      expect(decoded.type).toBe('gitu_terminal');
    });

    it('should create linked account record in database', async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken.code, testDeviceId, testDeviceName);

      // Check database
      const dbResult = await pool.query(
        `SELECT * FROM gitu_linked_accounts 
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      expect(dbResult.rows.length).toBe(1);
      expect(dbResult.rows[0].display_name).toBe(testDeviceName);
      expect(dbResult.rows[0].verified).toBe(true);
      expect(dbResult.rows[0].status).toBe('active');
    });

    it('should delete pairing token after successful linking', async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken.code, testDeviceId, testDeviceName);

      // Check that token is deleted
      const dbResult = await pool.query(
        'SELECT * FROM gitu_pairing_tokens WHERE code = $1',
        [pairingToken.code]
      );

      expect(dbResult.rows.length).toBe(0);
    });

    it('should reject invalid pairing token', async () => {
      await expect(
        gituTerminalService.linkTerminal('GITU-INVALID-TOKEN', testDeviceId, testDeviceName)
      ).rejects.toThrow('Invalid or expired pairing token');
    });

    it('should reject expired pairing token', async () => {
      // Create expired token directly in database
      const expiredCode = 'GITU-EXPIRED-TEST';
      const expiredDate = new Date(Date.now() - 10 * 60 * 1000); // 10 minutes ago

      await pool.query(
        `INSERT INTO gitu_pairing_tokens (code, user_id, expires_at)
         VALUES ($1, $2, $3)`,
        [expiredCode, testUserId, expiredDate]
      );

      await expect(
        gituTerminalService.linkTerminal(expiredCode, testDeviceId, testDeviceName)
      ).rejects.toThrow('Invalid or expired pairing token');
    });

    it('should update existing linked device if already linked', async () => {
      // First linking
      const pairingToken1 = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken1.code, testDeviceId, 'Old Name');

      // Second linking with same device
      const pairingToken2 = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken2.code, testDeviceId, 'New Name');

      // Check that only one record exists with updated name
      const dbResult = await pool.query(
        `SELECT * FROM gitu_linked_accounts 
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      expect(dbResult.rows.length).toBe(1);
      expect(dbResult.rows[0].display_name).toBe('New Name');
    });

    it('should require token parameter', async () => {
      await expect(
        gituTerminalService.linkTerminal('', testDeviceId, testDeviceName)
      ).rejects.toThrow('Token and deviceId are required');
    });

    it('should require deviceId parameter', async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      await expect(
        gituTerminalService.linkTerminal(pairingToken.code, '', testDeviceName)
      ).rejects.toThrow('Token and deviceId are required');
    });

    it('should use deviceId as display name if deviceName not provided', async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken.code, testDeviceId);

      const dbResult = await pool.query(
        `SELECT display_name FROM gitu_linked_accounts 
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      expect(dbResult.rows[0].display_name).toBe(testDeviceId);
    });
  });

  describe('validateAuthToken', () => {
    let validAuthToken: string;

    beforeEach(async () => {
      // Create a valid linked device
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      const linkResult = await gituTerminalService.linkTerminal(
        pairingToken.code,
        testDeviceId,
        testDeviceName
      );
      validAuthToken = linkResult.authToken;
    });

    it('should validate correct auth token', async () => {
      const result = await gituTerminalService.validateAuthToken(validAuthToken);

      expect(result.valid).toBe(true);
      expect(result.userId).toBe(testUserId);
      expect(result.deviceId).toBe(testDeviceId);
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(result.error).toBeUndefined();
    });

    it('should update last_used_at timestamp on validation', async () => {
      // Get initial timestamp
      const before = await pool.query(
        `SELECT last_used_at FROM gitu_linked_accounts 
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      // Wait a bit
      await new Promise(resolve => setTimeout(resolve, 100));

      // Validate token
      await gituTerminalService.validateAuthToken(validAuthToken);

      // Get updated timestamp
      const after = await pool.query(
        `SELECT last_used_at FROM gitu_linked_accounts 
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      expect(new Date(after.rows[0].last_used_at).getTime()).toBeGreaterThan(
        new Date(before.rows[0].last_used_at).getTime()
      );
    });

    it('should reject invalid auth token', async () => {
      const result = await gituTerminalService.validateAuthToken('invalid-token');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Invalid token');
    });

    it('should reject expired auth token', async () => {
      const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
      const expiredToken = jwt.sign(
        {
          userId: testUserId,
          platform: 'terminal',
          deviceId: testDeviceId,
          type: 'gitu_terminal'
        },
        JWT_SECRET,
        { expiresIn: '0s' } // Expired immediately
      );

      // Wait to ensure expiry
      await new Promise(resolve => setTimeout(resolve, 100));

      const result = await gituTerminalService.validateAuthToken(expiredToken);

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Token expired');
    });

    it('should reject token for unlinked device', async () => {
      // Unlink the device
      await gituTerminalService.unlinkTerminal(testUserId, testDeviceId);

      const result = await gituTerminalService.validateAuthToken(validAuthToken);

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Device not linked');
    });

    it('should reject token for inactive device', async () => {
      // Set device status to inactive
      await pool.query(
        `UPDATE gitu_linked_accounts SET status = 'inactive'
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      const result = await gituTerminalService.validateAuthToken(validAuthToken);

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Device status: inactive');
    });

    it('should reject token for suspended device', async () => {
      // Set device status to suspended
      await pool.query(
        `UPDATE gitu_linked_accounts SET status = 'suspended'
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      const result = await gituTerminalService.validateAuthToken(validAuthToken);

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Device status: suspended');
    });

    it('should reject non-terminal token', async () => {
      const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
      const nonTerminalToken = jwt.sign(
        {
          userId: testUserId,
          platform: 'whatsapp',
          deviceId: testDeviceId,
          type: 'gitu_whatsapp'
        },
        JWT_SECRET,
        { expiresIn: '90d' }
      );

      const result = await gituTerminalService.validateAuthToken(nonTerminalToken);

      expect(result.valid).toBe(false);
      expect(result.error).toBe('Not a terminal auth token');
    });

    it('should require authToken parameter', async () => {
      const result = await gituTerminalService.validateAuthToken('');

      expect(result.valid).toBe(false);
      expect(result.error).toBe('authToken is required');
    });
  });

  describe('Device Management', () => {
    it('should list all linked devices for user', async () => {
      // Link multiple devices
      const device1Id = testDeviceId + '-1';
      const device2Id = testDeviceId + '-2';

      const token1 = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(token1.code, device1Id, 'Device 1');

      const token2 = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(token2.code, device2Id, 'Device 2');

      // List devices
      const devices = await gituTerminalService.listLinkedDevices(testUserId);

      expect(devices.length).toBe(2);
      expect(devices.some(d => d.deviceId === device1Id)).toBe(true);
      expect(devices.some(d => d.deviceId === device2Id)).toBe(true);
    });

    it('should unlink device successfully', async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(pairingToken.code, testDeviceId, testDeviceName);

      await gituTerminalService.unlinkTerminal(testUserId, testDeviceId);

      const devices = await gituTerminalService.listLinkedDevices(testUserId);
      expect(devices.length).toBe(0);
    });

    it('should throw error when unlinking non-existent device', async () => {
      await expect(
        gituTerminalService.unlinkTerminal(testUserId, 'non-existent-device')
      ).rejects.toThrow('Device not found');
    });
  });

  describe('Token Refresh', () => {
    let validAuthToken: string;

    beforeEach(async () => {
      const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
      const linkResult = await gituTerminalService.linkTerminal(
        pairingToken.code,
        testDeviceId,
        testDeviceName
      );
      validAuthToken = linkResult.authToken;
    });

    it('should refresh valid auth token', async () => {
      // Wait a bit to ensure different iat (issued at) timestamp
      await new Promise(resolve => setTimeout(resolve, 1100));
      
      const result = await gituTerminalService.refreshAuthToken(validAuthToken);

      expect(result.authToken).toBeDefined();
      expect(result.authToken).not.toBe(validAuthToken); // New token should be different
      expect(result.expiresInDays).toBe(90);
      expect(result.expiresAt).toBeInstanceOf(Date);

      // Verify new token is valid
      const validation = await gituTerminalService.validateAuthToken(result.authToken);
      expect(validation.valid).toBe(true);
    });

    it('should reject refresh for unlinked device', async () => {
      await gituTerminalService.unlinkTerminal(testUserId, testDeviceId);

      await expect(
        gituTerminalService.refreshAuthToken(validAuthToken)
      ).rejects.toThrow('Device not linked');
    });

    it('should reject refresh for inactive device', async () => {
      await pool.query(
        `UPDATE gitu_linked_accounts SET status = 'inactive'
         WHERE user_id = $1 AND platform_user_id = $2`,
        [testUserId, testDeviceId]
      );

      await expect(
        gituTerminalService.refreshAuthToken(validAuthToken)
      ).rejects.toThrow('Device status: inactive');
    });
  });
});
