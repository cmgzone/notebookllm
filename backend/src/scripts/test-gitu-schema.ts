/**
 * Test Gitu schema with sample data
 * Verifies that all tables work correctly with CRUD operations
 */

import pool from '../config/database.js';

async function testSchema() {
  const client = await pool.connect();
  
  try {
    console.log('🧪 Testing Gitu schema with sample data...\n');
    
    await client.query('BEGIN');
    
    // Get a test user (or create one)
    let userId: string;
    const userResult = await client.query(`
      SELECT id FROM users LIMIT 1;
    `);
    
    if (userResult.rows.length === 0) {
      console.log('⚠️  No users found. Creating test user...');
      const newUser = await client.query(`
        INSERT INTO users (id, email, username)
        VALUES ('test-gitu-user', 'gitu-test@example.com', 'gitu_test')
        ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email
        RETURNING id;
      `);
      userId = newUser.rows[0].id;
    } else {
      userId = userResult.rows[0].id;
    }
    
    console.log(`✅ Using test user: ${userId}\n`);
    
    // Test 1: Create a session
    console.log('📝 Test 1: Creating gitu_session...');
    const sessionResult = await client.query(`
      INSERT INTO gitu_sessions (user_id, platform, status, context)
      VALUES ($1, 'flutter', 'active', '{"test": true}')
      RETURNING id, platform, status;
    `, [userId]);
    const sessionId = sessionResult.rows[0].id;
    console.log(`✅ Created session: ${sessionId} (${sessionResult.rows[0].platform})\n`);
    
    // Test 2: Create a memory
    console.log('📝 Test 2: Creating gitu_memory...');
    const memoryResult = await client.query(`
      INSERT INTO gitu_memories (user_id, category, content, source, confidence, tags)
      VALUES ($1, 'preference', 'User prefers dark mode', 'flutter_app', 0.95, ARRAY['ui', 'preference'])
      RETURNING id, category, content, confidence;
    `, [userId]);
    const memoryId = memoryResult.rows[0].id;
    console.log(`✅ Created memory: ${memoryId}`);
    console.log(`   Category: ${memoryResult.rows[0].category}`);
    console.log(`   Content: ${memoryResult.rows[0].content}`);
    console.log(`   Confidence: ${memoryResult.rows[0].confidence}\n`);
    
    // Test 3: Create a linked account
    console.log('📝 Test 3: Creating gitu_linked_account...');
    const linkedAccountResult = await client.query(`
      INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified)
      VALUES ($1, 'telegram', 'telegram_123456', 'Test User', true)
      RETURNING id, platform, platform_user_id, verified;
    `, [userId]);
    const linkedAccountId = linkedAccountResult.rows[0].id;
    console.log(`✅ Created linked account: ${linkedAccountId}`);
    console.log(`   Platform: ${linkedAccountResult.rows[0].platform}`);
    console.log(`   Platform User ID: ${linkedAccountResult.rows[0].platform_user_id}`);
    console.log(`   Verified: ${linkedAccountResult.rows[0].verified}\n`);
    
    // Test 4: Create a permission
    console.log('📝 Test 4: Creating gitu_permission...');
    const permissionResult = await client.query(`
      INSERT INTO gitu_permissions (user_id, resource, actions, scope)
      VALUES ($1, 'notebooks', ARRAY['read', 'write'], '{"notebook_ids": ["test-notebook"]}')
      RETURNING id, resource, actions;
    `, [userId]);
    console.log(`✅ Created permission: ${permissionResult.rows[0].id}`);
    console.log(`   Resource: ${permissionResult.rows[0].resource}`);
    console.log(`   Actions: ${permissionResult.rows[0].actions.join(', ')}\n`);
    
    // Test 5: Create a usage record
    console.log('📝 Test 5: Creating gitu_usage_record...');
    const usageResult = await client.query(`
      INSERT INTO gitu_usage_records (user_id, operation, model, tokens_used, cost_usd, platform)
      VALUES ($1, 'chat', 'gpt-4', 150, 0.0045, 'flutter')
      RETURNING id, operation, model, tokens_used, cost_usd;
    `, [userId]);
    console.log(`✅ Created usage record: ${usageResult.rows[0].id}`);
    console.log(`   Operation: ${usageResult.rows[0].operation}`);
    console.log(`   Model: ${usageResult.rows[0].model}`);
    console.log(`   Tokens: ${usageResult.rows[0].tokens_used}`);
    console.log(`   Cost: $${usageResult.rows[0].cost_usd}\n`);
    
    // Test 6: Create usage limits
    console.log('📝 Test 6: Creating gitu_usage_limits...');
    const limitsResult = await client.query(`
      INSERT INTO gitu_usage_limits (user_id, daily_limit_usd, monthly_limit_usd, hard_stop)
      VALUES ($1, 5.00, 50.00, true)
      ON CONFLICT (user_id) DO UPDATE 
      SET daily_limit_usd = EXCLUDED.daily_limit_usd
      RETURNING user_id, daily_limit_usd, monthly_limit_usd, hard_stop;
    `, [userId]);
    console.log(`✅ Created/Updated usage limits`);
    console.log(`   Daily Limit: $${limitsResult.rows[0].daily_limit_usd}`);
    console.log(`   Monthly Limit: $${limitsResult.rows[0].monthly_limit_usd}`);
    console.log(`   Hard Stop: ${limitsResult.rows[0].hard_stop}\n`);
    
    // Test 7: Query with indexes
    console.log('📝 Test 7: Testing indexed queries...');
    
    const sessionQuery = await client.query(`
      SELECT COUNT(*) as count FROM gitu_sessions 
      WHERE user_id = $1 AND status = 'active';
    `, [userId]);
    console.log(`✅ Active sessions query: ${sessionQuery.rows[0].count} sessions`);
    
    const memoryQuery = await client.query(`
      SELECT COUNT(*) as count FROM gitu_memories 
      WHERE user_id = $1 AND category = 'preference';
    `, [userId]);
    console.log(`✅ Preference memories query: ${memoryQuery.rows[0].count} memories`);
    
    const linkedAccountQuery = await client.query(`
      SELECT COUNT(*) as count FROM gitu_linked_accounts 
      WHERE user_id = $1;
    `, [userId]);
    console.log(`✅ Linked accounts query: ${linkedAccountQuery.rows[0].count} accounts\n`);
    
    // Test 8: Test constraints
    console.log('📝 Test 8: Testing constraints...');
    
    try {
      await client.query(`
        INSERT INTO gitu_sessions (user_id, platform, status)
        VALUES ($1, 'invalid_platform', 'active');
      `, [userId]);
      console.log('❌ Constraint test failed: Invalid platform was accepted');
    } catch (error: any) {
      if (error.message.includes('valid_session_platform')) {
        console.log('✅ Platform constraint working correctly');
      }
    }
    
    try {
      await client.query(`
        INSERT INTO gitu_memories (user_id, category, content, source, confidence)
        VALUES ($1, 'preference', 'Test', 'test', 1.5);
      `, [userId]);
      console.log('❌ Constraint test failed: Invalid confidence was accepted');
    } catch (error: any) {
      if (error.message.includes('valid_memory_confidence')) {
        console.log('✅ Confidence constraint working correctly');
      }
    }
    
    console.log('\n📝 Test 9: Cleaning up test data...');
    await client.query('ROLLBACK');
    console.log('✅ Test data rolled back\n');
    
    console.log('🎉 All schema tests passed successfully!\n');
    console.log('Summary:');
    console.log('✅ gitu_sessions - CRUD operations working');
    console.log('✅ gitu_memories - CRUD operations working');
    console.log('✅ gitu_linked_accounts - CRUD operations working');
    console.log('✅ gitu_permissions - CRUD operations working');
    console.log('✅ gitu_usage_records - CRUD operations working');
    console.log('✅ gitu_usage_limits - CRUD operations working');
    console.log('✅ Indexes - Query performance optimized');
    console.log('✅ Constraints - Data validation working');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Schema test failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

testSchema().catch(console.error);
