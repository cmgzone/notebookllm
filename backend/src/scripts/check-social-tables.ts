import pool from '../config/database.js';

async function checkSocialTables() {
  try {
    console.log('Checking social tables...');
    
    const result = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND (
        table_name LIKE '%friend%' 
        OR table_name LIKE '%group%' 
        OR table_name LIKE '%activit%' 
        OR table_name LIKE '%leader%'
        OR table_name LIKE '%notebook_share%'
      )
      ORDER BY table_name
    `);
    
    console.log('Social tables found:');
    result.rows.forEach(row => console.log('  -', row.table_name));
    
    if (result.rows.length === 0) {
      console.log('No social tables found! Migration may not have run.');
    }
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkSocialTables();
