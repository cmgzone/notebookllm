import pool from '../config/database.js';

async function checkAllSocialTables() {
  try {
    console.log('Checking all social tables...');
    
    const tables = [
      'friendships',
      'study_groups', 
      'study_group_members',
      'study_sessions',
      'notebook_shares',
      'activities',
      'activity_reactions',
      'leaderboard_snapshots',
      'group_invitations'
    ];
    
    for (const table of tables) {
      const result = await pool.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'public' 
          AND table_name = $1
        )
      `, [table]);
      
      const exists = result.rows[0].exists;
      console.log(`  ${exists ? '✅' : '❌'} ${table}`);
    }
    
    // Test a simple query
    console.log('\nTesting friends query...');
    const friendsResult = await pool.query('SELECT COUNT(*) FROM friendships');
    console.log('  Friendships count:', friendsResult.rows[0].count);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkAllSocialTables();
