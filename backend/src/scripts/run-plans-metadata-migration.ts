import pool from '../config/database.js';

async function runMigration() {
  console.log('Adding metadata column to plans table...');
  
  try {
    await pool.query(`
      ALTER TABLE plans ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL
    `);
    console.log('✅ Added metadata column to plans table');

    // Add index for querying forked plans
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_plans_metadata_forked 
      ON plans ((metadata->>'forkedFrom')) 
      WHERE metadata->>'forkedFrom' IS NOT NULL
    `);
    console.log('✅ Created index for forked plans');

    console.log('Migration completed successfully!');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigration();
