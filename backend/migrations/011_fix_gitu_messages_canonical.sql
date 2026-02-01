-- Canonical repair migration for gitu_messages
-- Unifies schema across older migrations and runtime ensureGituSchema()
-- Targets runtime expectations in backend services (timestamp + JSON content)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'gitu_messages'
  ) THEN
    CREATE TABLE gitu_messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      platform TEXT NOT NULL,
      platform_user_id TEXT,
      session_id TEXT,
      role TEXT NOT NULL DEFAULT 'user',
      content JSONB NOT NULL,
      timestamp TIMESTAMPTZ DEFAULT NOW(),
      metadata JSONB DEFAULT '{}',
      CONSTRAINT valid_message_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'))
    );
  END IF;
END $$;

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
          WHEN content ~ '^\s*[\{\[]' OR content ~ '^\s*\"' THEN gitu_try_parse_jsonb(content)
          ELSE to_jsonb(content)
        END
      );
  END IF;

  UPDATE gitu_messages SET content = '{}'::jsonb WHERE content IS NULL;
  ALTER TABLE gitu_messages ALTER COLUMN content SET NOT NULL;
END $$;

DROP FUNCTION IF EXISTS gitu_try_parse_jsonb(TEXT);

ALTER TABLE gitu_messages DROP CONSTRAINT IF EXISTS valid_message_platform;
ALTER TABLE gitu_messages
  ADD CONSTRAINT valid_message_platform
  CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'));

CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_timestamp ON gitu_messages(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_platform_timestamp ON gitu_messages(user_id, platform, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_messages_timestamp ON gitu_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_messages_session ON gitu_messages(session_id);
