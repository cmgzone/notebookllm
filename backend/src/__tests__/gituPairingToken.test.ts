import { gituTerminalService } from '../services/gituTerminalService.js';
import pool from '../config/database.js';

describe('GituTerminalService - Pairing Token Generation', () => {
  const testUserId = 'test-user-' + Date.now();
  const testEmail = `test-${Date.now()}@example.com`;

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
    await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    await pool.end();
  });

  describe('generatePairingToken', () => {
    it('should generate a pairing token with correct format', async () => {
      const result = await gituTerminalService.generatePairingToken(testUserId);

      // Verify token format: GITU-XXXX-YYYY
      expect(result.code).toMatch(/^GITU-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
      expect(result.userId).toBe(testUserId);
      expect(result.expiresInSeconds).toBe(300); // 5 minutes = 300 seconds
    });

    it('should set expiry to 5 minutes from now', async () => {
      const beforeGeneration = Date.now();
      const result = await gituTerminalService.generatePairingToken(testUserId);
      const afterGeneration = Date.now();

      const expiryTime = result.expiresAt.getTime();
      const expectedMinExpiry = beforeGeneration + (5 * 60 * 1000);
      const expectedMaxExpiry = afterGeneration + (5 * 60 * 1000);

      expect(expiryTime).toBeGreaterThanOrEqual(expectedMinExpiry);
      expect(expiryTime).toBeLessThanOrEqual(expectedMaxExpiry);
    });

    it('should store token in database', async () => {
      const result = await gituTerminalService.generatePairingToken(testUserId);

      const dbResult = await pool.query(
        'SELECT * FROM gitu_pairing_tokens WHERE code = $1',
        [result.code]
      );

      expect(dbResult.rows.length).toBe(1);
      expect(dbResult.rows[0].user_id).toBe(testUserId);
      expect(new Date(dbResult.rows[0].expires_at).getTime()).toBe(result.expiresAt.getTime());
    });

    it('should generate unique tokens', async () => {
      const token1 = await gituTerminalService.generatePairingToken(testUserId);
      const token2 = await gituTerminalService.generatePairingToken(testUserId);

      expect(token1.code).not.toBe(token2.code);
    });
  });
});
