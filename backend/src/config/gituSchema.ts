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
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        platform TEXT NOT NULL,
        platform_user_id TEXT NOT NULL,
        display_name TEXT,
        linked_at TIMESTAMPTZ DEFAULT NOW(),
        last_used_at TIMESTAMPTZ DEFAULT NOW(),
        verified BOOLEAN DEFAULT false,
        is_primary BOOLEAN DEFAULT false,
        status TEXT DEFAULT 'active',
        UNIQUE(platform, platform_user_id),
        CONSTRAINT valid_linked_account_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'))
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
      DECLARE
        user_id_type TEXT;
      BEGIN
        SELECT data_type INTO user_id_type
        FROM information_schema.columns
        WHERE table_name = 'gitu_linked_accounts' AND column_name = 'user_id';

        IF user_id_type IS NOT NULL AND user_id_type <> 'uuid' THEN
          ALTER TABLE gitu_linked_accounts ALTER COLUMN user_id TYPE UUID USING user_id::uuid;
        END IF;
      END $$;
      ALTER TABLE gitu_linked_accounts DROP CONSTRAINT IF EXISTS valid_linked_account_platform;
      ALTER TABLE gitu_linked_accounts
        ADD CONSTRAINT valid_linked_account_platform
        CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'));
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
        platform TEXT NOT NULL,
        platform_user_id TEXT,
        session_id TEXT,
        role TEXT NOT NULL DEFAULT 'user',
        content JSONB NOT NULL,
        metadata JSONB DEFAULT '{}',
        timestamp TIMESTAMPTZ DEFAULT NOW(),
        CONSTRAINT valid_message_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'))
      );

      CREATE INDEX IF NOT EXISTS idx_gitu_messages_session ON gitu_messages(session_id);
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_platform ON gitu_messages(user_id, platform);
      CREATE INDEX IF NOT EXISTS idx_gitu_messages_timestamp ON gitu_messages(timestamp);
    `);

    await client.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='created_at')
           AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='timestamp') THEN
          ALTER TABLE gitu_messages ADD COLUMN timestamp TIMESTAMPTZ;
          EXECUTE 'UPDATE gitu_messages SET timestamp = created_at WHERE timestamp IS NULL';
          ALTER TABLE gitu_messages ALTER COLUMN timestamp SET DEFAULT NOW();
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='timestamp') THEN
          ALTER TABLE gitu_messages ADD COLUMN timestamp TIMESTAMPTZ DEFAULT NOW();
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='metadata') THEN
          ALTER TABLE gitu_messages ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='platform_user_id') THEN
          ALTER TABLE gitu_messages ADD COLUMN platform_user_id TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='session_id') THEN
          ALTER TABLE gitu_messages ADD COLUMN session_id TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='role') THEN
          ALTER TABLE gitu_messages ADD COLUMN role TEXT DEFAULT 'user';
        END IF;

        UPDATE gitu_messages SET role = 'user' WHERE role IS NULL;
        ALTER TABLE gitu_messages ALTER COLUMN role SET DEFAULT 'user';
        ALTER TABLE gitu_messages ALTER COLUMN role SET NOT NULL;
      END $$;
    `);

    await client.query(`
      DO $$
      DECLARE
        user_id_type TEXT;
      BEGIN
        SELECT data_type INTO user_id_type
        FROM information_schema.columns
        WHERE table_name = 'gitu_messages' AND column_name = 'user_id';

        IF user_id_type IS NULL THEN
          ALTER TABLE gitu_messages ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE;
        ELSIF user_id_type <> 'uuid' THEN
          ALTER TABLE gitu_messages ALTER COLUMN user_id TYPE UUID USING user_id::uuid;
        END IF;

        ALTER TABLE gitu_messages ALTER COLUMN user_id SET NOT NULL;
      END $$;
    `);

    await client.query(`
      CREATE OR REPLACE FUNCTION gitu_try_parse_jsonb(input TEXT) RETURNS JSONB
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RETURN input::jsonb;
      EXCEPTION WHEN OTHERS THEN
        RETURN to_jsonb(input);
      END;
      $$;

      DO $$
      DECLARE
        content_type TEXT;
      BEGIN
        SELECT data_type INTO content_type
        FROM information_schema.columns
        WHERE table_name = 'gitu_messages' AND column_name = 'content';

        IF content_type IS NULL THEN
          ALTER TABLE gitu_messages ADD COLUMN content JSONB;
        ELSIF content_type <> 'jsonb' THEN
          ALTER TABLE gitu_messages
            ALTER COLUMN content TYPE JSONB
            USING (
              CASE
                WHEN content IS NULL THEN '{}'::jsonb
                WHEN content ~ '^\\s*[\\{\\[]' OR content ~ '^\\s*\\\"' THEN gitu_try_parse_jsonb(content)
                ELSE to_jsonb(content)
              END
            );
        END IF;

        UPDATE gitu_messages SET content = '{}'::jsonb WHERE content IS NULL;
        ALTER TABLE gitu_messages ALTER COLUMN content SET NOT NULL;
      END $$;

      DROP FUNCTION IF EXISTS gitu_try_parse_jsonb(TEXT);
    `);

    await client.query(`
      ALTER TABLE gitu_messages DROP CONSTRAINT IF EXISTS valid_message_platform;
      ALTER TABLE gitu_messages
        ADD CONSTRAINT valid_message_platform
        CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'));
    `);
  } finally {
    client.release();
  }
}
