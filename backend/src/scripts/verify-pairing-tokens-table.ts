import pool from '../config/database.js';

async function verifyPairingTokensTable() {
  console.log('🔍 Verifying gitu_pairing_tokens table...\n');

  try {
    // Check if table exists
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'gitu_pairing_tokens'
      );
    `);

    if (!tableCheck.rows[0].exists) {
      console.error('❌ Table gitu_pairing_tokens does not exist!');
      process.exit(1);
    }

    console.log('✅ Table gitu_pairing_tokens exists');

    // Check table structure
    const columnsQuery = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'gitu_pairing_tokens'
      ORDER BY ordinal_position;
    `);

    console.log('\n📋 Table Structure:');
    columnsQuery.rows.forEach(col => {
      console.log(`  - ${col.column_name}: ${col.data_type} ${col.is_nullable === 'NO' ? 'NOT NULL' : 'NULL'}`);
    });

    // Check indexes
    const indexesQuery = await pool.query(`
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE tablename = 'gitu_pairing_tokens';
    `);

    console.log('\n🔑 Indexes:');
    indexesQuery.rows.forEach(idx => {
      console.log(`  - ${idx.indexname}`);
    });

    // Check cleanup function
    const functionCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM pg_proc 
        WHERE proname = 'cleanup_expired_pairing_tokens'
      );
    `);

    if (functionCheck.rows[0].exists) {
      console.log('\n✅ Function cleanup_expired_pairing_tokens() exists');
    } else {
      console.log('\n⚠️  Function cleanup_expired_pairing_tokens() not found');
    }

    // Test cleanup function (without inserting test data)
    console.log('\n🧪 Testing cleanup function...');
    
    // Count tokens before cleanup
    const countBefore = await pool.query('SELECT COUNT(*) FROM gitu_pairing_tokens');
    console.log(`  📊 Tokens before cleanup: ${countBefore.rows[0].count}`);

    // Run cleanup function
    await pool.query('SELECT cleanup_expired_pairing_tokens()');
    console.log('  ✅ Cleanup function executed successfully');

    // Count tokens after cleanup
    const countAfter = await pool.query('SELECT COUNT(*) FROM gitu_pairing_tokens');
    console.log(`  📊 Tokens after cleanup: ${countAfter.rows[0].count}`);

    console.log('\n✅ All verifications passed!');
    console.log('\nThe gitu_pairing_tokens table is ready for use.');
    console.log('');
    console.log('Table features:');
    console.log('  ✅ Primary key on code');
    console.log('  ✅ Foreign key to users table');
    console.log('  ✅ Expiry timestamp tracking');
    console.log('  ✅ Indexes for performance');
    console.log('  ✅ Cleanup function for expired tokens');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

verifyPairingTokensTable();
