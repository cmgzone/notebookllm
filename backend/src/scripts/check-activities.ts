import pool from '../config/database.js';

async function checkActivities() {
  console.log('Checking activities table...\n');
  
  try {
    // Check if table exists
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'activities'
      )
    `);
    console.log('Activities table exists:', tableCheck.rows[0].exists);
    
    // Count activities
    const countResult = await pool.query('SELECT COUNT(*) FROM activities');
    console.log('Total activities:', countResult.rows[0].count);
    
    // Get recent activities
    const recentResult = await pool.query(`
      SELECT a.*, u.display_name as username
      FROM activities a
      LEFT JOIN users u ON u.id = a.user_id
      ORDER BY a.created_at DESC
      LIMIT 10
    `);
    
    console.log('\nRecent activities:');
    if (recentResult.rows.length === 0) {
      console.log('  No activities found');
    } else {
      recentResult.rows.forEach((row, i) => {
        console.log(`  ${i + 1}. [${row.activity_type}] ${row.title}`);
        console.log(`     User: ${row.username || row.user_id}`);
        console.log(`     Created: ${row.created_at}`);
      });
    }
    
    // Check constraint
    const constraintResult = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid) as definition
      FROM pg_constraint
      WHERE conrelid = 'activities'::regclass
      AND contype = 'c'
    `);
    
    console.log('\nConstraints:');
    constraintResult.rows.forEach(row => {
      console.log(`  ${row.conname}`);
    });
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkActivities();
