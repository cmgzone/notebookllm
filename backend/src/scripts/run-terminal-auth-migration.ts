import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function runMigration() {
  console.log('🚀 Running Terminal Authentication migration...');

  try {
    // Read the migration SQL file
    const migrationPath = join(__dirname, '../../migrations/add_terminal_auth.sql');
    const migrationSQL = readFileSync(migrationPath, 'utf-8');

    // Execute the migration
    await pool.query(migrationSQL);

    console.log('✅ Terminal Authentication migration completed successfully!');
    console.log('');
    console.log('Created:');
    console.log('  - gitu_pairing_tokens table');
    console.log('  - cleanup_expired_pairing_tokens() function');
    console.log('');
    console.log('Terminal authentication is now ready to use!');
    console.log('');
    console.log('Next steps:');
    console.log('  1. Add Gitu routes to backend/src/index.ts');
    console.log('  2. Implement terminal auth commands in terminalAdapter.ts');
    console.log('  3. Create Flutter UI for terminal connection');
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
