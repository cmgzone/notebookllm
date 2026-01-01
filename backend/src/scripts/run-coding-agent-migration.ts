/**
 * Run coding agent migration
 * Adds support for code verification sources
 */

import pool from '../config/database.js';

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🔧 Running coding agent migration...');
    
    await client.query('BEGIN');
    
    // Add user_id column to sources
    await client.query(`
      ALTER TABLE sources ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE
    `);
    console.log('✅ Added user_id column to sources');
    
    // Add metadata column
    await client.query(`
      ALTER TABLE sources ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'
    `);
    console.log('✅ Added metadata column to sources');
    
    // Create indexes
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_sources_user_id ON sources(user_id);
      CREATE INDEX IF NOT EXISTS idx_sources_type ON sources(type);
    `);
    console.log('✅ Created indexes');
    
    // Update existing sources
    await client.query(`
      UPDATE sources s
      SET user_id = n.user_id
      FROM notebooks n
      WHERE s.notebook_id = n.id
      AND s.user_id IS NULL
    `);
    console.log('✅ Updated existing sources with user_id');
    
    await client.query('COMMIT');
    console.log('✅ Migration completed successfully!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
