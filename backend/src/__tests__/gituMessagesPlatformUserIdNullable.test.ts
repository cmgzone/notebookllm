import pool from '../config/database.js';

describe('gitu_messages.platform_user_id nullable', () => {
  const testUserId = `test-user-gitu-messages-${Date.now()}`;
  const testEmail = `test-gitu-messages-${Date.now()}@example.com`;

  beforeAll(async () => {
    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name)
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform TEXT NOT NULL,
        platform_user_id TEXT,
        session_id TEXT,
        role TEXT NOT NULL DEFAULT 'user',
        content JSONB NOT NULL,
        metadata JSONB DEFAULT '{}',
        timestamp TIMESTAMPTZ DEFAULT NOW()
      );
    `);
  });

  afterAll(async () => {
    try {
      await pool.query(`DELETE FROM gitu_messages WHERE user_id = $1`, [testUserId]);
    } catch {}
    try {
      await pool.query(`DELETE FROM users WHERE id = $1`, [testUserId]);
    } catch {}
  });

  it('accepts NULL platform_user_id inserts', async () => {
    await pool.query(`ALTER TABLE gitu_messages ALTER COLUMN platform_user_id DROP NOT NULL`);

    await expect(
      pool.query(
        `INSERT INTO gitu_messages (user_id, platform, platform_user_id, role, content)
         VALUES ($1, $2, $3, $4, $5)`,
        [testUserId, 'terminal', null, 'user', { text: 'internal message' }]
      )
    ).resolves.toBeTruthy();
  });
});

