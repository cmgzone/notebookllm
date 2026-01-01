import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// Build connection string from environment variables
const connectionString = process.env.DATABASE_URL || 
    `postgresql://${process.env.NEON_USERNAME}:${process.env.NEON_PASSWORD}@${process.env.NEON_HOST}:${process.env.NEON_PORT || 5432}/${process.env.NEON_DATABASE}?sslmode=require`;

const pool = new Pool({
    connectionString,
    ssl: {
        rejectUnauthorized: false,
    },
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
});

// Test the connection
pool.on('connect', () => {
    console.log('✅ Connected to Neon database');
});

pool.on('error', (err) => {
    console.error('❌ Unexpected error on idle client', err);
});

// Initialize database tables
export async function initializeDatabase() {
    const client = await pool.connect();
    try {
        console.log('🔧 Initializing database tables...');
        
        // Core tables
        await client.query(`
            -- Users table
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                email TEXT UNIQUE NOT NULL,
                display_name TEXT,
                password_hash TEXT NOT NULL,
                password_salt TEXT,
                email_verified BOOLEAN DEFAULT false,
                two_factor_enabled BOOLEAN DEFAULT false,
                avatar_url TEXT,
                role TEXT DEFAULT 'user',
                reset_token TEXT,
                reset_token_expiry TIMESTAMPTZ,
                verification_token TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            -- Notebooks table
            CREATE TABLE IF NOT EXISTS notebooks (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                description TEXT,
                cover_image TEXT,
                is_agent_notebook BOOLEAN DEFAULT false,
                agent_session_id TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            -- Sources table
            CREATE TABLE IF NOT EXISTS sources (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                notebook_id UUID NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                content TEXT,
                url TEXT,
                media_data BYTEA,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            -- Chunks table (for RAG)
            CREATE TABLE IF NOT EXISTS chunks (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                source_id UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
                content_text TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                embedding VECTOR(1536),
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            -- Tags table
            CREATE TABLE IF NOT EXISTS tags (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                color TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            -- Notebook-Tags junction
            CREATE TABLE IF NOT EXISTS notebook_tags (
                notebook_id UUID REFERENCES notebooks(id) ON DELETE CASCADE,
                tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (notebook_id, tag_id)
            );

            -- Source-Tags junction
            CREATE TABLE IF NOT EXISTS source_tags (
                source_id UUID REFERENCES sources(id) ON DELETE CASCADE,
                tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (source_id, tag_id)
            );

            -- Create indexes
            CREATE INDEX IF NOT EXISTS idx_notebooks_user_id ON notebooks(user_id);
            CREATE INDEX IF NOT EXISTS idx_notebooks_agent ON notebooks(is_agent_notebook) WHERE is_agent_notebook = true;
            CREATE INDEX IF NOT EXISTS idx_sources_notebook_id ON sources(notebook_id);
            CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON chunks(source_id);
            CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id);
        `);

        // Subscription tables
        await client.query(`
            CREATE TABLE IF NOT EXISTS subscription_plans (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits_per_month INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_free_plan BOOLEAN DEFAULT false,
                is_active BOOLEAN DEFAULT true,
                features JSONB DEFAULT '[]',
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS user_subscriptions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                plan_id UUID REFERENCES subscription_plans(id),
                current_credits INTEGER DEFAULT 0,
                credits_consumed_this_month INTEGER DEFAULT 0,
                last_renewal_date TIMESTAMPTZ,
                next_renewal_date TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(user_id)
            );

            CREATE TABLE IF NOT EXISTS credit_transactions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                amount INTEGER NOT NULL,
                transaction_type TEXT NOT NULL,
                description TEXT,
                balance_after INTEGER,
                metadata JSONB,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS credit_packages (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        // Gamification tables
        await client.query(`
            CREATE TABLE IF NOT EXISTS user_stats (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                total_xp INTEGER DEFAULT 0,
                level INTEGER DEFAULT 1,
                current_streak INTEGER DEFAULT 0,
                longest_streak INTEGER DEFAULT 0,
                notebooks_created INTEGER DEFAULT 0,
                sources_added INTEGER DEFAULT 0,
                quizzes_completed INTEGER DEFAULT 0,
                flashcards_reviewed INTEGER DEFAULT 0,
                study_time_minutes INTEGER DEFAULT 0,
                last_activity_date DATE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS achievements (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                achievement_id TEXT NOT NULL,
                current_value INTEGER DEFAULT 0,
                is_unlocked BOOLEAN DEFAULT false,
                unlocked_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(user_id, achievement_id)
            );

            CREATE TABLE IF NOT EXISTS daily_challenges (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                target_value INTEGER NOT NULL,
                current_value INTEGER DEFAULT 0,
                is_completed BOOLEAN DEFAULT false,
                xp_reward INTEGER DEFAULT 0,
                date DATE NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(user_id, type, date)
            );
        `);

        // Study tools tables
        await client.query(`
            CREATE TABLE IF NOT EXISTS flashcard_decks (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
                source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
                title TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS flashcards (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                deck_id UUID NOT NULL REFERENCES flashcard_decks(id) ON DELETE CASCADE,
                question TEXT NOT NULL,
                answer TEXT NOT NULL,
                difficulty TEXT DEFAULT 'medium',
                times_reviewed INTEGER DEFAULT 0,
                times_correct INTEGER DEFAULT 0,
                last_reviewed_at TIMESTAMPTZ,
                next_review_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS quizzes (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
                source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
                title TEXT NOT NULL,
                times_attempted INTEGER DEFAULT 0,
                last_score INTEGER,
                best_score INTEGER,
                last_attempted_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS quiz_questions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
                question TEXT NOT NULL,
                options JSONB NOT NULL,
                correct_option_index INTEGER NOT NULL,
                explanation TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS mind_maps (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
                source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
                title TEXT NOT NULL,
                root_node JSONB NOT NULL,
                text_content TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS infographics (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
                source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
                title TEXT NOT NULL,
                image_url TEXT,
                image_base64 TEXT,
                style TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        console.log('✅ Core tables initialized');
    } catch (error) {
        console.error('❌ Database initialization error:', error);
        throw error;
    } finally {
        client.release();
    }
}

// Call initialization
initializeDatabase().catch(console.error);

export default pool;
