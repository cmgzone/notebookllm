import pool from '../config/database.js';

async function runMigration() {
    console.log('Running cloud research migration...');
    
    try {
        // Add columns to research_sessions
        console.log('Adding columns to research_sessions...');
        await pool.query(`
            ALTER TABLE research_sessions 
            ADD COLUMN IF NOT EXISTS depth VARCHAR(20) DEFAULT 'standard',
            ADD COLUMN IF NOT EXISTS template VARCHAR(50) DEFAULT 'general',
            ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'completed'
        `);
        console.log('✓ research_sessions columns added');

        // Add columns to research_sources
        console.log('Adding columns to research_sources...');
        await pool.query(`
            ALTER TABLE research_sources 
            ADD COLUMN IF NOT EXISTS credibility VARCHAR(20) DEFAULT 'unknown',
            ADD COLUMN IF NOT EXISTS credibility_score INTEGER DEFAULT 60
        `);
        console.log('✓ research_sources columns added');

        // Create research_jobs table
        console.log('Creating research_jobs table...');
        await pool.query(`
            CREATE TABLE IF NOT EXISTS research_jobs (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                query TEXT NOT NULL,
                config JSONB NOT NULL DEFAULT '{}',
                status VARCHAR(20) NOT NULL DEFAULT 'pending',
                status_message TEXT,
                progress DECIMAL(3,2) DEFAULT 0,
                session_id TEXT REFERENCES research_sessions(id) ON DELETE SET NULL,
                error TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                completed_at TIMESTAMP WITH TIME ZONE
            )
        `);
        console.log('✓ research_jobs table created');

        // Create indexes
        console.log('Creating indexes...');
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_research_jobs_user_status ON research_jobs(user_id, status)`);
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_research_jobs_created ON research_jobs(created_at DESC)`);
        console.log('✓ Indexes created');

        // Update existing sources
        console.log('Updating existing sources...');
        await pool.query(`
            UPDATE research_sources 
            SET credibility = 'unknown', credibility_score = 60 
            WHERE credibility IS NULL
        `);
        console.log('✓ Existing sources updated');

        console.log('\n✅ Cloud research migration completed successfully!');
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

runMigration();
