CREATE OR REPLACE FUNCTION gitu_safe_to_jsonb(input TEXT) RETURNS JSONB
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
  col_type TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gitu_scheduled_tasks') THEN
    RETURN;
  END IF;

  ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS cron TEXT;
  UPDATE gitu_scheduled_tasks SET cron = '* * * * *' WHERE cron IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN cron SET DEFAULT '* * * * *';
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN cron SET NOT NULL;

  ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS max_retries INTEGER;
  UPDATE gitu_scheduled_tasks SET max_retries = 3 WHERE max_retries IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN max_retries SET DEFAULT 3;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN max_retries SET NOT NULL;

  ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS retry_count INTEGER;
  UPDATE gitu_scheduled_tasks SET retry_count = 0 WHERE retry_count IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN retry_count SET DEFAULT 0;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN retry_count SET NOT NULL;

  ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS last_run_status TEXT;
  ALTER TABLE gitu_scheduled_tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
  UPDATE gitu_scheduled_tasks SET updated_at = NOW() WHERE updated_at IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN updated_at SET DEFAULT NOW();
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN updated_at SET NOT NULL;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gitu_scheduled_tasks' AND column_name = 'action') THEN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'gitu_scheduled_tasks' AND column_name = 'action';
    IF col_type IS NOT NULL AND col_type <> 'jsonb' THEN
      BEGIN
        ALTER TABLE gitu_scheduled_tasks ALTER COLUMN action DROP DEFAULT;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN action TYPE JSONB USING gitu_safe_to_jsonb(action);
    END IF;
  ELSE
    ALTER TABLE gitu_scheduled_tasks ADD COLUMN action JSONB;
  END IF;
  UPDATE gitu_scheduled_tasks SET action = jsonb_build_object('type','memories.detectContradictions') WHERE action IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN action SET NOT NULL;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gitu_scheduled_tasks' AND column_name = 'trigger') THEN
    SELECT data_type INTO col_type
    FROM information_schema.columns
    WHERE table_name = 'gitu_scheduled_tasks' AND column_name = 'trigger';
    IF col_type IS NOT NULL AND col_type <> 'jsonb' THEN
      BEGIN
        ALTER TABLE gitu_scheduled_tasks ALTER COLUMN trigger DROP DEFAULT;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
      ALTER TABLE gitu_scheduled_tasks ALTER COLUMN trigger TYPE JSONB USING gitu_safe_to_jsonb(trigger);
    END IF;
  ELSE
    ALTER TABLE gitu_scheduled_tasks ADD COLUMN trigger JSONB;
  END IF;
  UPDATE gitu_scheduled_tasks SET trigger = jsonb_build_object('type','cron') WHERE trigger IS NULL;
  ALTER TABLE gitu_scheduled_tasks ALTER COLUMN trigger SET NOT NULL;
END $$;

DROP FUNCTION IF EXISTS gitu_safe_to_jsonb(TEXT);
