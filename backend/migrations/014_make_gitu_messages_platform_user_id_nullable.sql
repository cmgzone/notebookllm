-- Make platform_user_id nullable for internal/system/agent messages
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'gitu_messages'
      AND column_name = 'platform_user_id'
  ) THEN
    BEGIN
      ALTER TABLE gitu_messages ALTER COLUMN platform_user_id DROP NOT NULL;
    EXCEPTION WHEN others THEN
      NULL;
    END;
  END IF;
END $$;

