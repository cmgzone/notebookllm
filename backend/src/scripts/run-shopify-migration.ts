import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running Shopify integration migration...\n');

  try {
    const migrationPath = path.join(__dirname, '../../migrations/add_shopify_integration.sql');
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    await pool.query(sql);

    console.log('✅ Shopify integration tables created successfully!\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
