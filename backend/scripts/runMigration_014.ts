import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../src/config/database.js';

async function runMigration() {
  try {
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);
    const sqlPath = path.join(__dirname, '..', 'migrations', '014_make_gitu_messages_platform_user_id_nullable.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Running migration: 014_make_gitu_messages_platform_user_id_nullable.sql');
    await pool.query(sql);
    console.log('Migration successful!');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigration();

