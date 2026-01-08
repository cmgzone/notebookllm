import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function runMigration() {
  console.log('Running notifications migration...');
  
  try {
    const sql = readFileSync(
      join(__dirname, '../../migrations/add_notifications.sql'),
      'utf-8'
    );
    
    await pool.query(sql);
    console.log('✅ Notifications migration completed successfully');
    
    // Verify tables
    const tables = await pool.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('notifications', 'notification_settings')
    `);
    console.log('Created tables:', tables.rows.map(r => r.table_name));
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
