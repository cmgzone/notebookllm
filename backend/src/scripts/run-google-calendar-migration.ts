import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const sqlPath = path.join(__dirname, '../../migrations/add_google_calendar_integration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query(sql);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(error);
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

