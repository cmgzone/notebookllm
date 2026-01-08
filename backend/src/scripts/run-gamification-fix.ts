import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Fixing gamification tables...');
  
  try {
    const migrationPath = path.join(__dirname, '../../migrations/fix_gamification_tables.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Gamification tables fixed!');
    console.log('   - user_stats (with TEXT user_id)');
    console.log('   - achievements (with TEXT user_id)');
    console.log('   - daily_challenges (with TEXT user_id)');
    
  } catch (error: any) {
    console.error('❌ Migration failed:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
