import pool from '../config/database.js';
import { gituIdentityManager } from '../services/gituIdentityManager.js';

const testUserId = 'user-identity-test';

describe('GituIdentityManager', () => {
  beforeAll(async () => {
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash, is_active)
       VALUES ($1, $2, $3, $4, true)
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, 'identity@test.local', 'Identity Tester', 'hash']
    );
  });

  afterAll(async () => {
    await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
    await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    await pool.end();
  });

  test('link and list accounts', async () => {
    const acc = await gituIdentityManager.linkAccount({
      userId: testUserId,
      platform: 'terminal',
      platformUserId: 'device-123',
      displayName: 'Dev Terminal',
    });
    expect(acc.userId).toBe(testUserId);
    expect(acc.platform).toBe('terminal');

    const list = await gituIdentityManager.listLinkedAccounts(testUserId);
    expect(list.length).toBeGreaterThan(0);
    expect(list[0].platform).toBeDefined();
  });

  test('set primary and verify account', async () => {
    const primary = await gituIdentityManager.setPrimary(testUserId, 'terminal', 'device-123');
    expect(primary).not.toBeNull();
    const verified = await gituIdentityManager.verifyAccount(testUserId, 'terminal', 'device-123');
    expect(verified).not.toBeNull();
  });

  test('trust levels reflect verification', async () => {
    const levels = await gituIdentityManager.getTrustLevels(testUserId);
    expect(['low', 'medium', 'high']).toContain(levels.terminal);
  });

  test('unlink account', async () => {
    const ok = await gituIdentityManager.unlinkAccount(testUserId, 'terminal', 'device-123');
    expect(ok).toBe(true);
    const list = await gituIdentityManager.listLinkedAccounts(testUserId);
    const found = list.some(a => a.platform === 'terminal' && a.platformUserId === 'device-123');
    expect(found).toBe(false);
  });
});
