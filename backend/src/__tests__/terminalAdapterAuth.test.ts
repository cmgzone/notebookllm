/**
 * Terminal Adapter Authentication Tests
 * 
 * Tests the authentication commands in the terminal adapter:
 * - gitu auth <token>
 * - gitu auth status
 * - gitu auth logout
 * - gitu auth refresh
 */

import { terminalAdapter } from '../adapters/terminalAdapter.js';
import { gituTerminalService } from '../services/gituTerminalService.js';
import pool from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

describe('Terminal Adapter Authentication', () => {
  let testUserId: string;
  let pairingToken: string;

  beforeAll(async () => {
    // Create a test user
    testUserId = uuidv4();
    const email = `test-terminal-auth-${testUserId}@example.com`;
    
    await pool.query(
      `INSERT INTO users (id, email, password_hash)
       VALUES ($1, $2, $3)`,
      [testUserId, email, 'hash']
    );
  });

  afterAll(async () => {
    // Clean up test data
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    await pool.end();
  });

  describe('Pairing Token Generation', () => {
    it('should generate a valid pairing token', async () => {
      const token = await gituTerminalService.generatePairingToken(testUserId);
      
      expect(token.code).toMatch(/^GITU-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
      expect(token.userId).toBe(testUserId);
      expect(token.expiresInSeconds).toBe(300); // 5 minutes
      expect(token.expiresAt).toBeInstanceOf(Date);
      
      pairingToken = token.code;
    });
  });

  describe('Terminal Linking', () => {
    it('should link terminal with valid pairing token', async () => {
      const deviceId = 'test-device-123';
      const deviceName = 'Test Device';
      
      const result = await gituTerminalService.linkTerminal(
        pairingToken,
        deviceId,
        deviceName
      );
      
      expect(result.authToken).toBeDefined();
      expect(result.userId).toBe(testUserId);
      expect(result.expiresInDays).toBe(90);
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('should fail with invalid pairing token', async () => {
      await expect(
        gituTerminalService.linkTerminal('INVALID-TOKEN', 'device-id')
      ).rejects.toThrow('Invalid or expired pairing token');
    });
  });

  describe('Token Validation', () => {
    let authToken: string;

    beforeAll(async () => {
      // Generate new pairing token and link
      const token = await gituTerminalService.generatePairingToken(testUserId);
      const result = await gituTerminalService.linkTerminal(
        token.code,
        'test-device-validation',
        'Test Device Validation'
      );
      authToken = result.authToken;
    });

    it('should validate a valid auth token', async () => {
      const validation = await gituTerminalService.validateAuthToken(authToken);
      
      expect(validation.valid).toBe(true);
      expect(validation.userId).toBe(testUserId);
      expect(validation.deviceId).toBe('test-device-validation');
      expect(validation.expiresAt).toBeInstanceOf(Date);
    });

    it('should reject invalid auth token', async () => {
      const validation = await gituTerminalService.validateAuthToken('invalid-token');
      
      expect(validation.valid).toBe(false);
      expect(validation.error).toBeDefined();
    });
  });

  describe('Token Refresh', () => {
    let authToken: string;

    beforeAll(async () => {
      // Generate new pairing token and link
      const token = await gituTerminalService.generatePairingToken(testUserId);
      const result = await gituTerminalService.linkTerminal(
        token.code,
        'test-device-refresh',
        'Test Device Refresh'
      );
      authToken = result.authToken;
    });

    it('should refresh a valid auth token', async () => {
      // Wait a second to ensure different iat (issued at) timestamp
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const result = await gituTerminalService.refreshAuthToken(authToken);
      
      expect(result.authToken).toBeDefined();
      expect(result.authToken).not.toBe(authToken); // Should be a new token
      expect(result.expiresInDays).toBe(90);
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('should fail to refresh invalid token', async () => {
      await expect(
        gituTerminalService.refreshAuthToken('invalid-token')
      ).rejects.toThrow();
    });
  });

  describe('Terminal Unlinking', () => {
    let deviceId: string;

    beforeAll(async () => {
      // Generate new pairing token and link
      deviceId = 'test-device-unlink';
      const token = await gituTerminalService.generatePairingToken(testUserId);
      await gituTerminalService.linkTerminal(token.code, deviceId, 'Test Device Unlink');
    });

    it('should unlink a terminal device', async () => {
      await expect(
        gituTerminalService.unlinkTerminal(testUserId, deviceId)
      ).resolves.not.toThrow();
      
      // Verify device is unlinked
      const devices = await gituTerminalService.listLinkedDevices(testUserId);
      const unlinkedDevice = devices.find(d => d.deviceId === deviceId);
      expect(unlinkedDevice).toBeUndefined();
    });

    it('should fail to unlink non-existent device', async () => {
      await expect(
        gituTerminalService.unlinkTerminal(testUserId, 'non-existent-device')
      ).rejects.toThrow('Device not found');
    });
  });

  describe('Device Listing', () => {
    beforeAll(async () => {
      // Link multiple devices
      for (let i = 1; i <= 3; i++) {
        const token = await gituTerminalService.generatePairingToken(testUserId);
        await gituTerminalService.linkTerminal(
          token.code,
          `test-device-list-${i}`,
          `Test Device ${i}`
        );
      }
    });

    it('should list all linked devices', async () => {
      const devices = await gituTerminalService.listLinkedDevices(testUserId);
      
      expect(devices.length).toBeGreaterThanOrEqual(3);
      
      devices.forEach(device => {
        expect(device.deviceId).toBeDefined();
        expect(device.deviceName).toBeDefined();
        expect(device.linkedAt).toBeInstanceOf(Date);
        expect(device.lastUsedAt).toBeInstanceOf(Date);
        expect(device.status).toBe('active');
      });
    });
  });
});
