import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running messaging migration...');
  
  try {
    const migrationPath = path.join(__dirname, '../../migrations/add_messaging.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Messaging tables created successfully!');
    console.log('   - direct_messages');
    console.log('   - conversations');
    console.log('   - group_messages');
    console.log('   - group_message_reads');
    
  } catch (error: any) {
    console.error('❌ Migration failed:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
