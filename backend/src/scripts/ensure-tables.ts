import pool from '../config/database.js';

async function ensureTables() {
    const client = await pool.connect();
    try {
        console.log('🔧 Ensuring all required tables exist...');

        // Credit packages table
        await client.query(`
            CREATE TABLE IF NOT EXISTS credit_packages (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                description TEXT,
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ credit_packages table ready');

        // Subscription plans table
        await client.query(`
            CREATE TABLE IF NOT EXISTS subscription_plans (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                description TEXT,
                credits_per_month INTEGER NOT NULL DEFAULT 30,
                price DECIMAL NOT NULL DEFAULT 0,
                is_active BOOLEAN DEFAULT true,
                is_free_plan BOOLEAN DEFAULT false,
                features JSONB DEFAULT '[]',
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ subscription_plans table ready');

        // User subscriptions table
        await client.query(`
            CREATE TABLE IF NOT EXISTS user_subscriptions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL,
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
        console.log('✅ user_subscriptions table ready');

        // Credit transactions table
        await client.query(`
            CREATE TABLE IF NOT EXISTS credit_transactions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL,
                amount INTEGER NOT NULL,
                transaction_type TEXT NOT NULL,
                description TEXT,
                balance_after INTEGER,
                payment_method TEXT,
                payment_id TEXT,
                metadata JSONB,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ credit_transactions table ready');

        // Onboarding screens table
        await client.query(`
            CREATE TABLE IF NOT EXISTS onboarding_screens (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                title TEXT NOT NULL,
                description TEXT,
                image_url TEXT,
                icon_name TEXT,
                sort_order INTEGER DEFAULT 0,
                order_index INTEGER DEFAULT 0,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ onboarding_screens table ready');

        // App settings table (for privacy policy etc)
        await client.query(`
            CREATE TABLE IF NOT EXISTS app_settings (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                key TEXT UNIQUE NOT NULL,
                content TEXT,
                value TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ app_settings table ready');

        // AI models table
        await client.query(`
            CREATE TABLE IF NOT EXISTS ai_models (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                model_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                description TEXT,
                cost_input DECIMAL DEFAULT 0,
                cost_output DECIMAL DEFAULT 0,
                context_window INTEGER DEFAULT 0,
                is_active BOOLEAN DEFAULT true,
                is_premium BOOLEAN DEFAULT false,
                is_default BOOLEAN DEFAULT false,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ ai_models table ready');

        // API keys table
        await client.query(`
            CREATE TABLE IF NOT EXISTS api_keys (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                service_name TEXT UNIQUE NOT NULL,
                encrypted_value TEXT NOT NULL,
                description TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);
        console.log('✅ api_keys table ready');

        // Chat messages table
        await client.query(`
            CREATE TABLE IF NOT EXISTS chat_messages (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                notebook_id TEXT REFERENCES notebooks(id) ON DELETE CASCADE,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            
            CREATE INDEX IF NOT EXISTS idx_chat_messages_user_notebook ON chat_messages(user_id, notebook_id);
            CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);
        `);
        console.log('✅ chat_messages table ready');

        // Gitu Chat Tables (Compatible with GituSessionService)
        await client.query(`
            CREATE TABLE IF NOT EXISTS gitu_sessions (
                id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                platform TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                context JSONB NOT NULL DEFAULT '{}',
                started_at TIMESTAMPTZ DEFAULT NOW(),
                last_activity_at TIMESTAMPTZ DEFAULT NOW(),
                ended_at TIMESTAMPTZ
            );

            CREATE TABLE IF NOT EXISTS gitu_linked_accounts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                platform TEXT NOT NULL,
                platform_user_id TEXT NOT NULL,
                display_name TEXT,
                settings JSONB DEFAULT '{}',
                linked_at TIMESTAMPTZ DEFAULT NOW(),
                last_used_at TIMESTAMPTZ DEFAULT NOW(),
                verified BOOLEAN DEFAULT false,
                is_primary BOOLEAN DEFAULT false,
                status TEXT DEFAULT 'active',
                UNIQUE(platform, platform_user_id)
            );

            CREATE INDEX IF NOT EXISTS idx_gitu_sessions_user ON gitu_sessions(user_id);
            CREATE INDEX IF NOT EXISTS idx_gitu_sessions_platform ON gitu_sessions(platform);
            CREATE INDEX IF NOT EXISTS idx_gitu_sessions_status ON gitu_sessions(status);
        `);
        console.log('✅ Gitu chat tables ready');

        // Add is_active column to users if not exists
        try {
            await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true`);
            console.log('✅ users.is_active column ready');
        } catch (e) {
            // Column might already exist
        }

        console.log('');
        console.log('🎉 All tables are ready!');

    } catch (error) {
        console.error('❌ Error:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

ensureTables().catch(console.error);
