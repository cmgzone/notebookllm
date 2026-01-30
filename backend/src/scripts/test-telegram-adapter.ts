/**
 * Test script for Telegram Adapter
 * 
 * This script tests the Telegram adapter functionality.
 * 
 * Prerequisites:
 * 1. Create a Telegram bot via @BotFather
 * 2. Get the bot token
 * 3. Add TELEGRAM_BOT_TOKEN to .env file
 * 4. Link a Telegram account in gitu_linked_accounts table
 * 
 * Usage:
 *   tsx src/scripts/test-telegram-adapter.ts
 */

import dotenv from 'dotenv';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import pool from '../config/database.js';

dotenv.config();

async function testTelegramAdapter() {
  console.log('🤖 Testing Telegram Adapter...\n');

  // Check for bot token
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  if (!botToken) {
    console.error('❌ TELEGRAM_BOT_TOKEN not found in .env file');
    console.log('\nTo test the Telegram adapter:');
    console.log('1. Create a bot via @BotFather on Telegram');
    console.log('2. Get the bot token');
    console.log('3. Add TELEGRAM_BOT_TOKEN=your_token_here to backend/.env');
    console.log('4. Run this script again');
    process.exit(1);
  }

  try {
    // Initialize the adapter
    console.log('📡 Initializing Telegram adapter...');
    await telegramAdapter.initialize(botToken, { polling: true });
    console.log('✅ Telegram adapter initialized\n');

    // Get bot info
    const botInfo = await telegramAdapter.getBotInfo();
    if (botInfo) {
      console.log('🤖 Bot Info:');
      console.log(`   Username: @${botInfo.username}`);
      console.log(`   Name: ${botInfo.first_name}`);
      console.log(`   ID: ${botInfo.id}\n`);
    }

    // Set bot commands
    console.log('⚙️  Setting bot commands...');
    await telegramAdapter.setCommands([
      { command: 'start', description: 'Start the bot' },
      { command: 'help', description: 'Show help message' },
      { command: 'status', description: 'Check Gitu status' },
      { command: 'notebooks', description: 'List notebooks' },
      { command: 'session', description: 'View session info' },
      { command: 'clear', description: 'Clear conversation history' },
      { command: 'settings', description: 'View settings' },
    ]);
    console.log('✅ Bot commands set\n');

    // Check for linked accounts
    console.log('🔗 Checking for linked Telegram accounts...');
    const result = await pool.query(
      `SELECT user_id, platform_user_id, display_name, linked_at 
       FROM gitu_linked_accounts 
       WHERE platform = 'telegram' AND status = 'active'`
    );

    if (result.rows.length === 0) {
      console.log('⚠️  No linked Telegram accounts found');
      console.log('\nTo link a Telegram account:');
      console.log('1. Open the NotebookLLM Flutter app');
      console.log('2. Go to Settings > Gitu > Connected Platforms');
      console.log('3. Click "Connect Telegram"');
      console.log('4. Follow the linking process\n');
    } else {
      console.log(`✅ Found ${result.rows.length} linked account(s):`);
      result.rows.forEach((row, index) => {
        console.log(`   ${index + 1}. User: ${row.user_id}`);
        console.log(`      Telegram User ID: ${row.platform_user_id}`);
        console.log(`      Name: ${row.display_name || 'N/A'}`);
        console.log(`      Linked: ${new Date(row.linked_at).toLocaleString()}`);
      });
      console.log();
    }

    // Set up message handler for testing
    telegramAdapter.onMessage(async (message) => {
      console.log('📨 Received message:');
      console.log(`   From: ${message.userId}`);
      console.log(`   Platform: ${message.platform}`);
      console.log(`   Text: ${message.content.text || '[no text]'}`);
      console.log(`   Attachments: ${message.content.attachments?.length || 0}`);
      console.log();
    });

    console.log('✅ Telegram adapter is ready!');
    console.log('\n📱 Test the bot:');
    console.log(`   1. Open Telegram and search for @${botInfo?.username}`);
    console.log('   2. Send /start to begin');
    console.log('   3. Try sending messages and commands');
    console.log('   4. Watch this console for incoming messages\n');
    console.log('Press Ctrl+C to stop the bot\n');

    // Keep the script running
    process.on('SIGINT', async () => {
      console.log('\n\n🛑 Stopping Telegram adapter...');
      await telegramAdapter.disconnect();
      await pool.end();
      console.log('✅ Telegram adapter stopped');
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ Error testing Telegram adapter:', error);
    process.exit(1);
  }
}

// Run the test
testTelegramAdapter().catch(console.error);
