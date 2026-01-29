/**
 * List all Gitu tables and users table extensions
 */

import pool from '../config/database.js';

async function listTables() {
  const client = await pool.connect();
  
  try {
    // List all Gitu tables
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_name LIKE 'gitu_%' 
      ORDER BY table_name;
    `);
    
    console.log('✅ Gitu Tables Created:');
    result.rows.forEach((r: any) => console.log('   ✓', r.table_name));
    
    // List users table extensions
    const cols = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name LIKE 'gitu_%' 
      ORDER BY column_name;
    `);
    
    console.log('\n✅ Users Table Extensions:');
    cols.rows.forEach((r: any) => console.log(`   ✓ ${r.column_name} (${r.data_type})`));
    
    console.log(`\n📊 Total: ${result.rows.length} Gitu tables + ${cols.rows.length} user columns`);
    
  } finally {
    client.release();
    await pool.end();
  }
}

listTables().catch(console.error);
