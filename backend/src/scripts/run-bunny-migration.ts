import pool from '../config/database.js';

async function runBunnyMigration() {
    const client = await pool.connect();
    try {
        console.log('🔧 Running Bunny CDN migration...');

        // Add CDN-related columns to sources table
        await client.query(`
            ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_url TEXT;
            ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_path TEXT;
            ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_size BIGINT;
        `);
        console.log('✅ Added media_url, media_path, media_size columns to sources');

        // Create index for faster lookups
        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_sources_media_url ON sources(media_url) WHERE media_url IS NOT NULL;
        `);
        console.log('✅ Created index on media_url');

        // Create media_uploads table to track direct uploads (user_id as TEXT to match existing schema)
        await client.query(`
            CREATE TABLE IF NOT EXISTS media_uploads (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL,
                path TEXT NOT NULL,
                url TEXT NOT NULL,
                filename TEXT NOT NULL,
                type TEXT DEFAULT 'file',
                size BIGINT DEFAULT 0,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ Created media_uploads table');

        // Create indexes for media_uploads
        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_media_uploads_user ON media_uploads(user_id);
            CREATE INDEX IF NOT EXISTS idx_media_uploads_path ON media_uploads(path);
        `);
        console.log('✅ Created indexes on media_uploads');

        console.log('🎉 Bunny CDN migration completed successfully!');
    } catch (error) {
        console.error('❌ Migration error:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

runBunnyMigration().catch(console.error);
