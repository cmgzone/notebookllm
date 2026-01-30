/**
 * Link a test Telegram account for testing the Telegram adapter
 * 
 * This script creates a test user and links a Telegram account to it.
 * 
 * Usage:
 *   npx tsx src/scripts/link-telegram-test-account.ts <telegram_chat_id>
 * 
 * Example:
 *   npx tsx src/scripts/link-telegram-test-account.ts 123456789
 * 
 * To get your Telegram chat ID:
 * 1. Message your bot on Telegram
 * 2. Check the error message or bot logs for the chat ID
 * 3. Or use @userinfobot on Telegram to get your ID
 */

import dotenv from 'dotenv';
import pool from '../config/database.js';

dotenv.config();

async function linkTelegramTestAccount() {
  const telegramChatId = process.argv[2];

  if (!telegramChatId) {
    console.error('❌ Please provide a Telegram chat ID');
    console.log('\nUsage:');
    console.log('  npx tsx src/scripts/link-telegram-test-account.ts <telegram_chat_id>');
    console.log('\nTo get your Telegram chat ID:');
    console.log('  1. Message your bot on Telegram');
    console.log('  2. Check the error logs for the chat ID');
    console.log('  3. Or use @userinfobot on Telegram\n');
    process.exit(1);
  }

  try {
    console.log('🔗 Linking Telegram test account...\n');

    // Check if account is already linked
    const existingLink = await pool.query(
      `SELECT * FROM gitu_linked_accounts 
       WHERE platform = 'telegram' AND platform_user_id = $1`,
      [telegramChatId]
    );

    if (existingLink.rows.length > 0) {
      console.log('✅ Telegram account already linked!');
      console.log(`   User ID: ${existingLink.rows[0].user_id}`);
      console.log(`   Chat ID: ${existingLink.rows[0].platform_user_id}`);
      console.log(`   Status: ${existingLink.rows[0].status}`);
      if (existingLink.rows[0].linked_at) {
        console.log(`   Linked at: ${new Date(existingLink.rows[0].linked_at).toLocaleString()}\n`);
      } else {
        console.log('   Linked at: (unknown)\n');
      }
      return;
    }

    // Create or get test user
    let userId: string;
    const testEmail = 'telegram-test@notebookllm.com';
    
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [testEmail]
    );

    if (existingUser.rows.length > 0) {
      userId = existingUser.rows[0].id;
      console.log(`✅ Using existing test user: ${userId}`);
    } else {
      // Create new test user with generated ID
      const hashedPassword = 'test-password-hash'; // Simple hash for testing
      const newUser = await pool.query(
        `INSERT INTO users (id, email, password_hash, email_verified, role)
         VALUES (gen_random_uuid(), $1, $2, true, 'user')
         RETURNING id`,
        [testEmail, hashedPassword]
      );
      userId = newUser.rows[0].id;
      console.log(`✅ Created new test user: ${userId}`);
    }

    // Link Telegram account
    await pool.query(
      `INSERT INTO gitu_linked_accounts 
       (user_id, platform, platform_user_id, display_name, status)
       VALUES ($1, 'telegram', $2, $3, 'active')`,
      [userId, telegramChatId, 'Telegram Test User']
    );

    console.log('✅ Telegram account linked successfully!\n');
    console.log('📋 Account Details:');
    console.log(`   User ID: ${userId}`);
    console.log(`   Email: ${testEmail}`);
    console.log(`   Telegram Chat ID: ${telegramChatId}`);
    console.log(`   Status: active\n`);

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
