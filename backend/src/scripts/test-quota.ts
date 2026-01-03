/**
 * Test script for MCP quota endpoint
 */

import pool from '../config/database.js';
import { mcpLimitsService } from '../services/mcpLimitsService.js';

async function testQuota() {
  console.log('🧪 Testing MCP Quota...\n');

  try {
    // Test 1: Get settings
    console.log('1. Testing getSettings()...');
    const settings = await mcpLimitsService.getSettings();
    console.log('   ✅ Settings:', JSON.stringify(settings, null, 2));

    // Test 2: Get a test user ID
    console.log('\n2. Getting a test user...');
    const userResult = await pool.query('SELECT id, email FROM users LIMIT 1');
    if (userResult.rows.length === 0) {
      console.log('   ❌ No users found in database');
      return;
    }
    const testUserId = userResult.rows[0].id;
    console.log(`   ✅ Using user: ${userResult.rows[0].email} (${testUserId})`);

    // Test 3: Get user usage
    console.log('\n3. Testing getUserUsage()...');
    const usage = await mcpLimitsService.getUserUsage(testUserId);
    console.log('   ✅ Usage:', JSON.stringify(usage, null, 2));

    // Test 4: Check if user is premium
    console.log('\n4. Testing isUserPremium()...');
    const isPremium = await mcpLimitsService.isUserPremium(testUserId);
    console.log(`   ✅ Is Premium: ${isPremium}`);

    // Test 5: Get full quota
    console.log('\n5. Testing getUserQuota()...');
    const quota = await mcpLimitsService.getUserQuota(testUserId);
    console.log('   ✅ Quota:', JSON.stringify(quota, null, 2));

    console.log('\n✨ All tests passed!');
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await pool.end();
  }
}

testQuota();
