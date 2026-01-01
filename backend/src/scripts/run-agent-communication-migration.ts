/**
 * Run agent communication migration
 * Adds support for bidirectional communication between users and third-party coding agents
 * Requirements: 3.5, 4.1, 4.4
 */

import pool from '../config/database.js';

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🔧 Running agent communication migration...');
    
    await client.query('BEGIN');
    
    // Create agent_sessions table (using TEXT for notebook_id to match notebooks.id type)
    await client.query(`
      CREATE TABLE IF NOT EXISTS agent_sessions (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        agent_name TEXT NOT NULL,
        agent_identifier TEXT NOT NULL,
        webhook_url TEXT,
        webhook_secret TEXT,
        notebook_id TEXT REFERENCES notebooks(id) ON DELETE SET NULL,
        status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'disconnected')),
        last_activity TIMESTAMPTZ DEFAULT NOW(),
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, agent_identifier)
      )
    `);
    console.log('✅ Created agent_sessions table');
    
    // Create source_conversations table (using TEXT for source_id to match sources.id type)
    await client.query(`
      CREATE TABLE IF NOT EXISTS source_conversations (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
        source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
        agent_session_id TEXT REFERENCES agent_sessions(id) ON DELETE SET NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(source_id)
      )
    `);
    console.log('✅ Created source_conversations table');
    
    // Create conversation_messages table
    await client.query(`
      CREATE TABLE IF NOT EXISTS conversation_messages (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
        conversation_id TEXT NOT NULL REFERENCES source_conversations(id) ON DELETE CASCADE,
        role TEXT NOT NULL CHECK (role IN ('user', 'agent')),
        content TEXT NOT NULL,
        metadata JSONB DEFAULT '{}',
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);
    console.log('✅ Created conversation_messages table');
    
    // Create indexes for performance
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_agent_sessions_user ON agent_sessions(user_id);
      CREATE INDEX IF NOT EXISTS idx_agent_sessions_status ON agent_sessions(status);
      CREATE INDEX IF NOT EXISTS idx_agent_sessions_agent_identifier ON agent_sessions(agent_identifier);
      CREATE INDEX IF NOT EXISTS idx_source_conversations_source ON source_conversations(source_id);
      CREATE INDEX IF NOT EXISTS idx_source_conversations_agent_session ON source_conversations(agent_session_id);
      CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation ON conversation_messages(conversation_id);
      CREATE INDEX IF NOT EXISTS idx_conversation_messages_unread ON conversation_messages(conversation_id, is_read) WHERE is_read = false;
      CREATE INDEX IF NOT EXISTS idx_conversation_messages_created ON conversation_messages(created_at);
    `);
    console.log('✅ Created indexes for performance');
    
    // Add agent notebook support columns (using TEXT for agent_session_id to match agent_sessions.id type)
    await client.query(`
      ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS is_agent_notebook BOOLEAN DEFAULT false;
      ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS agent_session_id TEXT REFERENCES agent_sessions(id) ON DELETE SET NULL;
    `);
    console.log('✅ Added agent notebook columns to notebooks table');
    
    // Create index for agent notebooks
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_notebooks_agent ON notebooks(is_agent_notebook) WHERE is_agent_notebook = true;
    `);
    console.log('✅ Created index for agent notebooks');
    
    await client.query('COMMIT');
    console.log('✅ Agent communication migration completed successfully!');
    
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
