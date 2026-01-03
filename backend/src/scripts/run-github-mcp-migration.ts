/**
 * Run GitHub-MCP Integration Migration
 * Creates tables for audit logging and source caching
 * Requirements: 1.3, 1.4, 7.3
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running GitHub-MCP integration migration...\n');

  try {
    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '../../migrations/add_github_mcp_integration.sql');
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    // Execute the migration
    await pool.query(sql);

    console.log('✅ GitHub-MCP integration tables created successfully!\n');

    // Verify tables exist
    const tables = ['github_audit_logs', 'github_source_cache'];
    
    console.log('📋 Verifying tables:');
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

    // Verify indexes exist
    console.log('\n📋 Verifying indexes:');
    const indexes = [
      'idx_github_audit_user',
      'idx_github_audit_repo',
      'idx_github_audit_action',
      'idx_github_audit_agent_session',
      'idx_github_cache_stale',
      'idx_github_cache_repo'
    ];

    for (const index of indexes) {
      const result = await pool.query(
        `SELECT EXISTS (
          SELECT FROM pg_indexes 
          WHERE indexname = $1
        )`,
        [index]
      );
      
      const exists = result.rows[0].exists;
      console.log(`  ${exists ? '✓' : '✗'} ${index}`);
    }

    console.log('\n✅ Migration complete!');
    console.log('\nThis migration adds:');
    console.log('  - github_audit_logs: Tracks all GitHub API interactions');
    console.log('  - github_source_cache: Manages source content freshness');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
