import pool from './database.js';

export async function ensureGituSchema(): Promise<void> {
  const client = await pool.connect();
  try {
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

    await client.query(`
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS description TEXT;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS cost_input DECIMAL DEFAULT 0;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS cost_output DECIMAL DEFAULT 0;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS context_window INTEGER DEFAULT 0;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false;
      ALTER TABLE ai_models ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    `);

    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_models_default
      ON ai_models (is_default)
      WHERE is_default = TRUE;
    `);

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
        status TEXT DEFAULT 'active',
        UNIQUE(platform, platform_user_id),
        CONSTRAINT valid_linked_account_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
      );
    `);

    await client.query(`
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS display_name TEXT;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS id UUID;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS linked_at TIMESTAMPTZ DEFAULT NOW();
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ DEFAULT NOW();
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT false;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;
      ALTER TABLE gitu_linked_accounts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
      ALTER TABLE gitu_linked_accounts ALTER COLUMN id SET DEFAULT gen_random_uuid();
      UPDATE gitu_linked_accounts SET id = gen_random_uuid() WHERE id IS NULL;
      UPDATE gitu_linked_accounts SET status = 'active' WHERE status IS NULL;
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'valid_linked_account_status'
        ) THEN
          ALTER TABLE gitu_linked_accounts
            ADD CONSTRAINT valid_linked_account_status
            CHECK (status IN ('active','inactive','suspended'));
        END IF;
      END $$;
    `);

    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_gitu_linked_accounts_id
      ON gitu_linked_accounts (id);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS gitu_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        session_id TEXT,
        platform TEXT NOT NULL,
        platform_user_id TEXT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        metadata JSONB DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_gitu_messages_session ON gitu_messages(session_id);
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_platform ON gitu_messages(user_id, platform);
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_created ON gitu_messages(created_at);
    `);
  } finally {
    client.release();
  }
}
