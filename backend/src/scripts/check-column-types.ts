import pool from '../config/database.js';

async function checkColumnTypes() {
  try {
    const result = await pool.query(`
      SELECT table_name, column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name IN ('notebooks', 'plans', 'shared_content') 
        AND column_name IN ('id', 'content_id')
      ORDER BY table_name, column_name
    `);
    console.log('Column types:');
    console.log(result.rows);
    
    // Also check what's in shared_content
    const shared = await pool.query('SELECT id, content_type, content_id FROM shared_content LIMIT 5');
    console.log('\nSample shared_content:');
    console.log(shared.rows);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkColumnTypes();
