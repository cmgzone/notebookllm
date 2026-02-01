/**
 * Add gitu_messages table to existing Gitu schema
 */

import pool from '../config/database.js';

async function addGituMessagesTable() {
  try {
    console.log('✅ Connected to Neon database');
    console.log('🚀 Adding gitu_messages table...\n');

    // Check if table already exists
    const checkResult = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'gitu_messages'
      );
    `);

    if (checkResult.rows[0].exists) {
      console.log('ℹ️  gitu_messages table already exists');
      process.exit(0);
    }

    // Create gitu_messages table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform TEXT NOT NULL,
        platform_user_id TEXT,
        content JSONB NOT NULL,
        timestamp TIMESTAMPTZ DEFAULT NOW(),
        metadata JSONB DEFAULT '{}',
        CONSTRAINT valid_message_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
      );
    `);
    console.log('✅ Created gitu_messages table');

    // Create indexes
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_user ON gitu_messages(user_id, timestamp DESC);
    `);
    console.log('✅ Created idx_gitu_messages_user index');

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_platform ON gitu_messages(user_id, platform, timestamp DESC);
    `);
    console.log('✅ Created idx_gitu_messages_platform index');

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_timestamp ON gitu_messages(timestamp DESC);
    `);
    console.log('✅ Created idx_gitu_messages_timestamp index');

    // Add status column to linked accounts if not exists
    await pool.query(`
      ALTER TABLE gitu_linked_accounts 
      ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
    `);
    console.log('✅ Added status column to gitu_linked_accounts');

    await pool.query(`
      DO $$ 
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint 
          WHERE conname = 'valid_linked_account_status'
        ) THEN
          ALTER TABLE gitu_linked_accounts 
          ADD CONSTRAINT valid_linked_account_status 
          CHECK (status IN ('active', 'inactive', 'suspended'));
        END IF;
      END $$;
    `);
    console.log('✅ Added status constraint to gitu_linked_accounts');

    // Add comment
    await pool.query(`
      COMMENT ON TABLE gitu_messages IS 'Message history and audit trail for all platforms';
    `);

    console.log('\n✅ gitu_messages table added successfully!');
    console.log('\n🔍 Verifying table...');

    // Verify table
    const verifyResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'gitu_messages'
      ORDER BY ordinal_position;
    `);

    console.log(`\n✓ gitu_messages table has ${verifyResult.rows.length} columns:`);
    verifyResult.rows.forEach(row => {
      console.log(`   ✓ ${row.column_name} (${row.data_type})`);
    });

    // Verify indexes
    const indexResult = await pool.query(`
      SELECT indexname 
      FROM pg_indexes 
      WHERE tablename = 'gitu_messages'
      ORDER BY indexname;
    `);

    console.log(`\n✓ Found ${indexResult.rows.length} indexes:`);
    indexResult.rows.forEach(row => {
      console.log(`   ✓ ${row.indexname}`);
    });

    console.log('\n🎉 Migration complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

addGituMessagesTable();
