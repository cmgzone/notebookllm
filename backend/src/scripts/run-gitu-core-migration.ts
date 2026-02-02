import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('🚀 Starting Gitu Core migration...\n');
    await client.query('BEGIN');
    const sqlPath = path.join(__dirname, '../../migrations/add_gitu_core.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('🎉 Gitu Core migration completed successfully!');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
