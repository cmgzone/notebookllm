
import pool from '../config/database.js';

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Starting Gitu Web Platform Update...\n');
    
    await client.query('BEGIN');
    
    console.log('📝 Updating platform constraints...');
    await client.query(`
      ALTER TABLE gitu_messages DROP CONSTRAINT IF EXISTS valid_message_platform;
      ALTER TABLE gitu_messages ADD CONSTRAINT valid_message_platform 
        CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'));

      ALTER TABLE gitu_linked_accounts DROP CONSTRAINT IF EXISTS valid_linked_account_platform;
      ALTER TABLE gitu_linked_accounts ADD CONSTRAINT valid_linked_account_platform 
        CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'));
    `);
    
    console.log('✅ Updated constraints to include "web" platform');
    
    await client.query('COMMIT');
    console.log('\n🎉 Migration completed successfully!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
