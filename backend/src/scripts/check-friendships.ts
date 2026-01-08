import pool from '../config/database.js';

async function check() {
  console.log('Checking friendships...\n');
  
  const friendships = await pool.query('SELECT * FROM friendships WHERE status = $1', ['accepted']);
  console.log('Accepted friendships:', friendships.rows.length);
  friendships.rows.forEach(f => console.log(f));
  
  console.log('\n--- All friendships ---');
  const all = await pool.query('SELECT * FROM friendships');
  console.log('Total:', all.rows.length);
  all.rows.forEach(f => console.log(f));
  
  await pool.end();
}

check();
