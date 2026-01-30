/**
 * Link a test Telegram account for testing the Telegram adapter
 * 
 * This script links a Telegram user ID to an existing NotebookLLM user.
 * 
 * Usage:
 *   npx tsx src/scripts/link-telegram-test-account.ts <telegram_user_id> <user_id_or_email>
 * 
 * Example:
 *   npx tsx src/scripts/link-telegram-test-account.ts 123456789 65aa5d12-2454-44fe-97ec-ea97f1dd63c1
 * 
 * To get your Telegram user ID:
 * 1. Message your bot on Telegram
 * 2. Send /id and copy the "Telegram User ID"
 */

import dotenv from 'dotenv';
import pool from '../config/database.js';

dotenv.config();

async function linkTelegramTestAccount() {
  const telegramUserId = process.argv[2];
  const userIdOrEmail = process.argv[3];

  if (!telegramUserId || !userIdOrEmail) {
    console.error('❌ Please provide a Telegram user ID and a user ID (or email)');
    console.log('\nUsage:');
    console.log('  npx tsx src/scripts/link-telegram-test-account.ts <telegram_user_id> <user_id_or_email>');
    console.log('\nTo get your Telegram user ID:');
    console.log('  1. Message your bot on Telegram');
    console.log('  2. Send /id and copy the "Telegram User ID"');
    console.log('\nTo get your NotebookLLM user ID:');
    console.log('  - Open the app and copy it from your profile/settings, or');
    console.log("  - Query the database: SELECT id, email FROM users WHERE email = '<your email>';\n");
    process.exit(1);
  }

  try {
    console.log('🔗 Linking Telegram test account...\n');

    await pool.query(`ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active'`);
    await pool.query(`ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ DEFAULT NOW()`);
    await pool.query(`ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ DEFAULT NOW()`);
    await pool.query(`ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false`);
    await pool.query(`ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false`);

    let userId = userIdOrEmail;
    if (!userIdOrEmail.includes('-') || userIdOrEmail.length < 16) {
      const userRes = await pool.query('SELECT id FROM users WHERE email = $1', [userIdOrEmail]);
      if (userRes.rows.length === 0) {
        console.error('❌ No user found for email:', userIdOrEmail);
        process.exit(1);
      }
      userId = userRes.rows[0].id;
    } else {
      const userRes = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
      if (userRes.rows.length === 0) {
        console.error('❌ No user found for user ID:', userId);
        process.exit(1);
      }
    }

    // Check if account is already linked
    const existingLink = await pool.query(
      `SELECT * FROM gitu_linked_accounts 
       WHERE platform = 'telegram' AND platform_user_id = $1`,
      [telegramUserId]
    );

    if (existingLink.rows.length > 0) {
      const currentUserId = existingLink.rows[0].user_id;
      if (currentUserId === userId) {
        console.log('✅ Telegram account already linked!');
        console.log(`   User ID: ${existingLink.rows[0].user_id}`);
        console.log(`   Telegram User ID: ${existingLink.rows[0].platform_user_id}`);
        console.log(`   Status: ${existingLink.rows[0].status ?? 'active'}`);
        if (existingLink.rows[0].linked_at) {
          console.log(`   Linked at: ${new Date(existingLink.rows[0].linked_at).toLocaleString()}\n`);
        } else {
          console.log('   Linked at: (unknown)\n');
        }
        return;
      }
      await pool.query(
        `UPDATE gitu_linked_accounts
         SET user_id = $1, status = 'active', last_used_at = NOW()
         WHERE platform = 'telegram' AND platform_user_id = $2`,
        [userId, telegramUserId]
      );
      console.log('✅ Telegram account re-linked to a different user.\n');
    }

    // Link Telegram account
    const inserted = await pool.query(
      `INSERT INTO gitu_linked_accounts 
       (user_id, platform, platform_user_id, display_name, status, linked_at, last_used_at)
       VALUES ($1, 'telegram', $2, $3, 'active', NOW(), NOW())
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           display_name = COALESCE(EXCLUDED.display_name, gitu_linked_accounts.display_name),
           status = 'active',
           last_used_at = NOW()
       RETURNING *`,
      [userId, telegramUserId, 'Telegram']
    );

    console.log('✅ Telegram account linked successfully!\n');
    console.log('📋 Account Details:');
    console.log(`   User ID: ${inserted.rows[0].user_id}`);
    console.log(`   Telegram User ID: ${inserted.rows[0].platform_user_id}`);
    console.log(`   Status: ${inserted.rows[0].status ?? 'active'}\n`);

    console.log('🎉 You can now test the Telegram bot!');
    console.log('   1. Run: npx tsx src/scripts/test-telegram-adapter.ts');
    console.log('   2. Message your bot on Telegram');
    console.log('   3. The bot should now respond!\n');

  } catch (error) {
    console.error('❌ Error linking Telegram account:', error);
    process.exit(1);
  } finally {
    try {
      await pool.end();
    } catch {}
  }
}

linkTelegramTestAccount().catch(console.error);
