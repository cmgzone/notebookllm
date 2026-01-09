import pool from '../config/database.js';

async function checkNotebooksSchema() {
  const result = await pool.query(`
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'notebooks' 
    ORDER BY ordinal_position
  `);
  console.log('Notebooks table columns:');
  for (const row of result.rows) {
    console.log(`  ${row.column_name}: ${row.data_type}`);
  }
  await pool.end();
}

checkNotebooksSchema();
