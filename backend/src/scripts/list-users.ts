/**
 * List users from the database
 * Helper script to find user IDs for testing
 */

import pool from '../config/database.js';
import dotenv from 'dotenv';

dotenv.config();

async function listUsers() {
  try {
    console.log('📋 Fetching users from database...\n');

    const result = await pool.query(
      'SELECT id, email, created_at FROM users ORDER BY created_at DESC LIMIT 10'
    );

    if (result.rows.length === 0) {
      console.log('❌ No users found in database.');
      console.log('\nYou may need to create a user first.');
      return;
    }

    console.log(`✅ Found ${result.rows.length} users:\n`);
    
    result.rows.forEach((user, index) => {
      console.log(`${index + 1}. User ID: ${user.id}`);
      console.log(`   Email: ${user.email || 'N/A'}`);
      console.log(`   Created: ${user.created_at.toLocaleString()}`);
      console.log();
    });

    console.log('💡 To test the terminal adapter, use:');
    console.log(`   npx tsx src/scripts/test-terminal-adapter.ts ${result.rows[0].id}`);
    console.log();

  } catch (error) {
    console.error('❌ Error fetching users:', error);
  } finally {
    await pool.end();
  }
}

listUsers();
