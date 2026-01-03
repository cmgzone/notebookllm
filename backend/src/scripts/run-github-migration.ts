/**
 * Run GitHub Integration Migration
 * Creates tables for GitHub OAuth and repository access
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running GitHub integration migration...\n');

  try {
    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '../../migrations/add_github_integration.sql');
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    // Execute the migration
    await pool.query(sql);

    console.log('✅ GitHub integration tables created successfully!\n');

    // Verify tables exist
    const tables = ['github_connections', 'github_repos', 'github_sources', 'github_rate_limits'];
    
    for (const table of tables) {
      const result = await pool.query(
        `SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_name = $1
        )`,
        [table]
      );
      
      const exists = result.rows[0].exists;
      console.log(`  ${exists ? '✓' : '✗'} ${table}`);
    }

    console.log('\n📋 Migration complete!');
    console.log('\nNext steps:');
    console.log('1. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET in .env');
    console.log('2. Set GITHUB_REDIRECT_URI for OAuth callback');
    console.log('3. Optionally set GITHUB_ENCRYPTION_KEY for token encryption');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
