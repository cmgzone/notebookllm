import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running activity types fix migration...');
  
  try {
    const migrationPath = path.join(__dirname, '../../migrations/fix_activity_types.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Activity types fix migration completed successfully!');
    
    // Verify the constraint
    const result = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid) as definition
      FROM pg_constraint
      WHERE conrelid = 'activities'::regclass
      AND contype = 'c'
    `);
    
    console.log('\nCurrent constraints on activities table:');
    result.rows.forEach(row => {
      console.log(`  ${row.conname}: ${row.definition}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
