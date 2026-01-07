import { pool } from '../config/database';
import * as fs from 'fs';
import * as path from 'path';

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Running social features migration...');
    
    const migrationPath = path.join(__dirname, '../../migrations/add_social_features.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    
    console.log('✅ Social features migration completed successfully!');
    console.log('Tables created:');
    console.log('  - friendships');
    console.log('  - study_groups');
    console.log('  - study_group_members');
    console.log('  - study_sessions');
    console.log('  - notebook_shares');
    console.log('  - activities');
    console.log('  - activity_reactions');
    console.log('  - leaderboard_snapshots');
    console.log('  - group_invitations');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
