import pool from '../config/database.js';

async function checkSourcesSchema() {
  const result = await pool.query(`
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = 'sources' 
    ORDER BY ordinal_position
  `);
  console.log('Sources table columns:');
  console.log(result.rows.map(x => x.column_name).join(', '));
  await pool.end();
}

checkSourcesSchema();
