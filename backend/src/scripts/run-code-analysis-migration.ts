/**
 * Run Code Analysis Migration
 * Adds code_analysis, analysis_summary, analysis_rating, and analyzed_at columns to sources table
 */

import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running code analysis migration...\n');
  
  try {
    // Read migration SQL
    const migrationPath = path.join(__dirname, '../../migrations/add_code_analysis.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');
    
    // Execute migration
    await pool.query(migrationSQL);
    
    console.log('✅ Migration completed successfully!\n');
    
    // Verify columns exist
    const result = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sources' 
      AND column_name IN ('code_analysis', 'analysis_summary', 'analysis_rating', 'analyzed_at')
    `);
    
    console.log('📊 New columns added:');
    result.rows.forEach(row => {
      console.log(`   - ${row.column_name}: ${row.data_type}`);
    });
    
    // Count GitHub sources that need analysis
    const countResult = await pool.query(`
      SELECT COUNT(*) as count 
      FROM sources 
      WHERE type = 'github' AND analyzed_at IS NULL
    `);
    
    console.log(`\n📝 GitHub sources pending analysis: ${countResult.rows[0].count}`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
