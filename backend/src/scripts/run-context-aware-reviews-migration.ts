/**
 * Run Context-Aware Reviews Migration
 * Adds related_files_used column to code_reviews table
 */

import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running context-aware reviews migration...');
  
  try {
    const migrationPath = path.join(__dirname, '../../migrations/add_context_aware_reviews.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(sql);
    
    console.log('✅ Migration completed successfully!');
    console.log('Added related_files_used column to code_reviews table');
    
  } catch (error: any) {
    if (error.message?.includes('already exists')) {
      console.log('✅ Column already exists, migration skipped');
    } else {
      console.error('❌ Migration failed:', error.message);
      throw error;
    }
  } finally {
    await pool.end();
  }
}

runMigration().catch(console.error);
