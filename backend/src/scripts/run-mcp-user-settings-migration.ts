/**
 * Run MCP User Settings Migration
 * Adds table for user-specific MCP settings like code analysis model preference
 */

import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Running MCP User Settings migration...\n');
    
    // Read and execute migration SQL
    const migrationPath = path.join(__dirname, '../../migrations/add_mcp_user_settings.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await client.query(sql);
    
    console.log('✅ MCP User Settings migration completed successfully!\n');
    
    // Verify table exists
    const result = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'mcp_user_settings'
      ORDER BY ordinal_position
    `);
    
    console.log('📋 mcp_user_settings table columns:');
    result.rows.forEach(row => {
      console.log(`   - ${row.column_name}: ${row.data_type}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
