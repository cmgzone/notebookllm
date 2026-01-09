import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running fork activity types migration...');
  
  try {
    const migrationPath = path.join(__dirname, '../../migrations/add_fork_activity_types.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Fork activity types migration completed successfully!');
    
    // Verify the constraint
    const result = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid) as definition
      FROM pg_constraint
      WHERE conrelid = 'activities'::regclass
      AND conname = 'activities_activity_type_check'
    `);
    
    if (result.rows.length > 0) {
      console.log('✅ Constraint verified:', result.rows[0].conname);
    }
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
