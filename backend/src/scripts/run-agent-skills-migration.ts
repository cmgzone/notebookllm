
import pool from '../config/database.js';

async function runMigration() {
    const client = await pool.connect();

    try {
        console.log('🔧 Running agent skills migration...');

        await client.query('BEGIN');

        await client.query(`
      CREATE TABLE IF NOT EXISTS agent_skills (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        description TEXT,
        content TEXT NOT NULL,
        parameters JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, name)
      )
    `);

        await client.query(`
      CREATE INDEX IF NOT EXISTS idx_agent_skills_user_id ON agent_skills(user_id);
    `);

        await client.query(`
      CREATE TABLE IF NOT EXISTS skill_catalog (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
        slug TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        content TEXT NOT NULL,
        parameters JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);

        await client.query(`
      CREATE INDEX IF NOT EXISTS idx_skill_catalog_active_updated ON skill_catalog(is_active, updated_at DESC);
    `);

        await client.query('COMMIT');
        console.log('✅ Agent skills migration completed successfully!');

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
