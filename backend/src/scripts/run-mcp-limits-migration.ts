/**
 * Migration Runner: MCP Limits Tables
 * Creates mcp_settings and user_mcp_usage tables
 */

import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running MCP Limits Migration...\n');

  try {
    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '../../migrations/add_mcp_limits.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

    // Execute the migration
    await pool.query(migrationSQL);

    console.log('✅ MCP limits tables created successfully!');

    // Verify the tables exist
    const tablesResult = await pool.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('mcp_settings', 'user_mcp_usage')
    `);

    console.log('\n📋 Created tables:');
    tablesResult.rows.forEach(row => {
      console.log(`   - ${row.table_name}`);
    });

    // Show default settings
    const settingsResult = await pool.query('SELECT * FROM mcp_settings WHERE id = $1', ['default']);
    if (settingsResult.rows.length > 0) {
      const settings = settingsResult.rows[0];
      console.log('\n⚙️  Default MCP Settings:');
      console.log(`   Free Plan:`);
      console.log(`     - Sources Limit: ${settings.free_sources_limit}`);
      console.log(`     - Tokens Limit: ${settings.free_tokens_limit}`);
      console.log(`     - API Calls/Day: ${settings.free_api_calls_per_day}`);
      console.log(`   Premium Plan:`);
      console.log(`     - Sources Limit: ${settings.premium_sources_limit}`);
      console.log(`     - Tokens Limit: ${settings.premium_tokens_limit}`);
      console.log(`     - API Calls/Day: ${settings.premium_api_calls_per_day}`);
    }

    console.log('\n✨ Migration completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
