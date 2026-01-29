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
    connectionTimeoutMillis: 60000, // Increased to 60s for Neon cold starts and heavy operations
    // Keep connections alive
    keepAlive: true,
    keepAliveInitialDelayMillis: 10000,
    // Query timeout for long-running operations
    query_timeout: 60000, // 60 seconds
});

(globalThis as any).__notebookLlmPgPool = pool;

// Helper function to execute query with retry for connection issues
export async function queryWithRetry<T>(
    queryFn: () => Promise<T>,
    maxRetries: number = 3
): Promise<T> {
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await queryFn();
        } catch (error: any) {
            lastError = error;
            const isConnectionError =
                error.message?.includes('Connection terminated') ||
                error.message?.includes('connection timeout') ||
                error.code === 'ECONNRESET' ||
                error.code === 'ETIMEDOUT';

            if (!isConnectionError || attempt === maxRetries) {
                throw error;
            }

            console.log(`Database connection attempt ${attempt}/${maxRetries} failed, retrying...`);
            await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
    }

    throw lastError;
}

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

        // Core tables - split into smaller chunks
        await client.query(`
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
        `);

        await client.query(`
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
        `);

        await client.query(`
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
        `);

        await client.query(`
            CREATE TABLE IF NOT EXISTS chunks (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                source_id UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
                content_text TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                embedding VECTOR(1536),
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        await client.query(`
            CREATE TABLE IF NOT EXISTS tags (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                color TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        await client.query(`
            CREATE TABLE IF NOT EXISTS notebook_tags (
                notebook_id UUID REFERENCES notebooks(id) ON DELETE CASCADE,
                tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (notebook_id, tag_id)
            );

            CREATE TABLE IF NOT EXISTS source_tags (
                source_id UUID REFERENCES sources(id) ON DELETE CASCADE,
                tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (source_id, tag_id)
            );
        `);

        // Create indexes separately
        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_notebooks_user_id ON notebooks(user_id);
            CREATE INDEX IF NOT EXISTS idx_notebooks_agent ON notebooks(is_agent_notebook) WHERE is_agent_notebook = true;
            CREATE INDEX IF NOT EXISTS idx_sources_notebook_id ON sources(notebook_id);
            CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON chunks(source_id);
            CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id);
        `);

        // Subscription tables - split into smaller chunks
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
        `);

        await client.query(`
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
        `);

        await client.query(`
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

        // Gamification tables - split into smaller chunks
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
        `);

        await client.query(`
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
        `);

        await client.query(`
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

        // Study tools tables - split into smaller chunks
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
        `);

        await client.query(`
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
        `);

        await client.query(`
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
        `);

        await client.query(`
            CREATE TABLE IF NOT EXISTS quiz_questions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
                question TEXT NOT NULL,
                options JSONB NOT NULL,
                correct_option_index INTEGER NOT NULL,
                explanation TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        await client.query(`
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

        // API tokens table
        await client.query(`
            CREATE TABLE IF NOT EXISTS api_tokens (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                token_hash TEXT NOT NULL UNIQUE,
                token_prefix TEXT NOT NULL,
                token_suffix TEXT NOT NULL,
                expires_at TIMESTAMPTZ,
                last_used_at TIMESTAMPTZ,
                revoked_at TIMESTAMPTZ,
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS token_usage_logs (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                token_id TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                ip_address TEXT,
                user_agent TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_api_tokens_user ON api_tokens(user_id);
            CREATE INDEX IF NOT EXISTS idx_api_tokens_hash ON api_tokens(token_hash);
            CREATE INDEX IF NOT EXISTS idx_api_tokens_active ON api_tokens(user_id) WHERE revoked_at IS NULL;
        `);

        console.log('✅ API tokens tables initialized');

        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_linked_accounts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                platform TEXT NOT NULL,
                platform_user_id TEXT NOT NULL,
                display_name TEXT,
                linked_at TIMESTAMPTZ DEFAULT NOW(),
                last_used_at TIMESTAMPTZ DEFAULT NOW(),
                verified BOOLEAN DEFAULT false,
                is_primary BOOLEAN DEFAULT false,
                UNIQUE(platform, platform_user_id),
                CONSTRAINT valid_linked_account_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id);
            CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_platform ON gitu_linked_accounts(platform, platform_user_id);
        `);
        console.log('✅ Linked accounts table initialized');
        await client.query(`
            ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ DEFAULT NOW();
            ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
            ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;
            CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id);
            CREATE INDEX IF NOT EXISTS idx_gitu_linked_accounts_platform ON gitu_linked_accounts(platform, platform_user_id);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_permissions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                resource TEXT NOT NULL,
                actions TEXT[] NOT NULL,
                scope JSONB DEFAULT '{}',
                granted_at TIMESTAMPTZ DEFAULT NOW(),
                expires_at TIMESTAMPTZ,
                revoked_at TIMESTAMPTZ
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_permissions_user ON gitu_permissions(user_id, resource);
            CREATE INDEX IF NOT EXISTS idx_gitu_permissions_active ON gitu_permissions(user_id, resource) WHERE revoked_at IS NULL;
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_automation_rules (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                description TEXT,
                trigger JSONB NOT NULL,
                conditions JSONB DEFAULT '[]',
                actions JSONB NOT NULL,
                enabled BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_automation_user ON gitu_automation_rules(user_id, enabled);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_rule_executions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                rule_id UUID NOT NULL REFERENCES gitu_automation_rules(id) ON DELETE CASCADE,
                matched BOOLEAN NOT NULL,
                success BOOLEAN NOT NULL,
                result JSONB,
                error TEXT,
                executed_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_user_time ON gitu_rule_executions(user_id, executed_at DESC);
            CREATE INDEX IF NOT EXISTS idx_gitu_rule_exec_rule_time ON gitu_rule_executions(rule_id, executed_at DESC);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_plugins (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                description TEXT,
                code TEXT NOT NULL,
                entrypoint TEXT DEFAULT 'run',
                config JSONB DEFAULT '{}',
                source_catalog_id UUID,
                source_catalog_version TEXT,
                enabled BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_plugins_user ON gitu_plugins(user_id, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_gitu_plugins_enabled ON gitu_plugins(user_id, enabled);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_plugin_catalog (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                slug TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                description TEXT,
                code TEXT NOT NULL,
                entrypoint TEXT DEFAULT 'run',
                version TEXT DEFAULT '1.0.0',
                author TEXT,
                tags JSONB DEFAULT '[]',
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_active ON gitu_plugin_catalog(is_active, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_updated ON gitu_plugin_catalog(updated_at DESC);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_plugin_executions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                plugin_id UUID NOT NULL REFERENCES gitu_plugins(id) ON DELETE CASCADE,
                success BOOLEAN NOT NULL,
                duration_ms INTEGER DEFAULT 0,
                result JSONB,
                error TEXT,
                logs JSONB DEFAULT '[]',
                executed_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_user_time ON gitu_plugin_executions(user_id, executed_at DESC);
            CREATE INDEX IF NOT EXISTS idx_gitu_plugin_exec_plugin_time ON gitu_plugin_executions(plugin_id, executed_at DESC);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS file_audit_logs (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL,
                action TEXT NOT NULL,
                path TEXT NOT NULL,
                success BOOLEAN DEFAULT true,
                error_message TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_file_audit_user ON file_audit_logs(user_id);
            CREATE INDEX IF NOT EXISTS idx_file_audit_action ON file_audit_logs(action);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_shell_audit_logs (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                mode TEXT NOT NULL CHECK (mode IN ('sandboxed', 'unsandboxed', 'dry_run')),
                command TEXT NOT NULL,
                args JSONB DEFAULT '[]',
                cwd TEXT,
                success BOOLEAN DEFAULT true,
                exit_code INTEGER,
                error_message TEXT,
                duration_ms INTEGER,
                stdout_bytes INTEGER DEFAULT 0,
                stderr_bytes INTEGER DEFAULT 0,
                stdout_truncated BOOLEAN DEFAULT false,
                stderr_truncated BOOLEAN DEFAULT false,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_user ON gitu_shell_audit_logs(user_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_gitu_shell_audit_mode ON gitu_shell_audit_logs(mode);
        `);
        await client.query(`
            CREATE TABLE IF NOT EXISTS gmail_connections (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL UNIQUE,
                email TEXT,
                access_token TEXT NOT NULL,
                refresh_token TEXT,
                scopes TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                last_used_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_gmail_user ON gmail_connections(user_id);
        `);

        // Agent communication tables
        await client.query(`
            CREATE TABLE IF NOT EXISTS agent_sessions (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                user_id TEXT NOT NULL,
                agent_name TEXT NOT NULL,
                agent_identifier TEXT NOT NULL,
                webhook_url TEXT,
                webhook_secret TEXT,
                notebook_id TEXT,
                status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'disconnected')),
                last_activity TIMESTAMPTZ DEFAULT NOW(),
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(user_id, agent_identifier)
            );
        `);

        await client.query(`
            CREATE TABLE IF NOT EXISTS source_conversations (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                source_id TEXT NOT NULL,
                agent_session_id TEXT REFERENCES agent_sessions(id) ON DELETE SET NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(source_id)
            );

            CREATE TABLE IF NOT EXISTS conversation_messages (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                conversation_id TEXT NOT NULL REFERENCES source_conversations(id) ON DELETE CASCADE,
                role TEXT NOT NULL CHECK (role IN ('user', 'agent')),
                content TEXT NOT NULL,
                metadata JSONB DEFAULT '{}',
                is_read BOOLEAN DEFAULT false,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_agent_sessions_user ON agent_sessions(user_id);
            CREATE INDEX IF NOT EXISTS idx_agent_sessions_status ON agent_sessions(status);
            CREATE INDEX IF NOT EXISTS idx_agent_sessions_agent_identifier ON agent_sessions(agent_identifier);
            CREATE INDEX IF NOT EXISTS idx_source_conversations_source ON source_conversations(source_id);
            CREATE INDEX IF NOT EXISTS idx_source_conversations_agent_session ON source_conversations(agent_session_id);
            CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation ON conversation_messages(conversation_id);
            CREATE INDEX IF NOT EXISTS idx_conversation_messages_unread ON conversation_messages(conversation_id, is_read) WHERE is_read = false;
        `);

        console.log('✅ Agent communication tables initialized');
        console.log('✅ Core tables initialized');
    } catch (error) {
        console.error('❌ Database initialization error:', error);
        throw error;
    } finally {
        client.release();
    }
}

// Call initialization
// NOTE: Commented out to prevent multiple initializations when module is imported
// initializeDatabase().catch(console.error);

export default pool;
