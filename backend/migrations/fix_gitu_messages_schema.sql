-- Fix for Gitu Messages Schema (Missing role column)
-- Fixes error: column "role" of relation "gitu_messages" does not exist

DO $$
BEGIN
    -- Add role column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='role') THEN
        ALTER TABLE gitu_messages ADD COLUMN role TEXT DEFAULT 'user';
        -- Update existing generic rows to avoid null issues if any
        UPDATE gitu_messages SET role = 'user' WHERE role IS NULL;
        ALTER TABLE gitu_messages ALTER COLUMN role SET NOT NULL;
    END IF;

    -- Add session_id column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='session_id') THEN
        ALTER TABLE gitu_messages ADD COLUMN session_id TEXT;
    END IF;

    -- Add platform_user_id column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_messages' AND column_name='platform_user_id') THEN
        ALTER TABLE gitu_messages ADD COLUMN platform_user_id TEXT;
    END IF;
END $$;
