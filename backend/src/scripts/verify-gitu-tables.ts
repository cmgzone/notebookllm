/**
 * Verify Gitu tables creation
 * Specifically checks for gitu_sessions, gitu_memories, gitu_linked_accounts
 */

import pool from '../config/database.js';

async function verifyTables() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Verifying Gitu tables...\n');
    
    // Check for the three main tables from the task
    const tablesToCheck = [
      'gitu_sessions',
      'gitu_memories',
      'gitu_linked_accounts'
    ];
    
    for (const tableName of tablesToCheck) {
      const result = await client.query(`
        SELECT 
          column_name,
          data_type,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position;
      `, [tableName]);
      
      if (result.rows.length > 0) {
        console.log(`✅ Table: ${tableName}`);
        console.log(`   Columns: ${result.rows.length}`);
        result.rows.forEach((col: any) => {
          console.log(`   - ${col.column_name} (${col.data_type})`);
        });
        console.log('');
      } else {
        console.log(`❌ Table ${tableName} not found!\n`);
      }
    }
    
    // Check indexes
    console.log('🔍 Checking indexes...\n');
    const indexResult = await client.query(`
      SELECT 
        tablename,
        indexname
      FROM pg_indexes
      WHERE tablename IN ('gitu_sessions', 'gitu_memories', 'gitu_linked_accounts')
      ORDER BY tablename, indexname;
    `);
    
    console.log(`✅ Found ${indexResult.rows.length} indexes:`);
    indexResult.rows.forEach((row: any) => {
      console.log(`   ✓ ${row.tablename}.${row.indexname}`);
    });
    
    console.log('\n✅ Verification complete!');
    
  } catch (error) {
    console.error('❌ Verification failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

verifyTables().catch(console.error);
