-- Migration to add 'web' and 'universal' to allowed platforms in Gitu tables

-- Normalize any legacy/unknown platform values before enforcing constraints
UPDATE gitu_messages
SET platform = 'web'
WHERE platform IS NULL
   OR platform NOT IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal');

UPDATE gitu_sessions
SET platform = 'web'
WHERE platform IS NULL
   OR platform NOT IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal');

UPDATE gitu_linked_accounts
SET platform = 'web'
WHERE platform IS NULL
   OR platform NOT IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal');

ALTER TABLE gitu_messages DROP CONSTRAINT IF EXISTS valid_message_platform;
ALTER TABLE gitu_messages ADD CONSTRAINT valid_message_platform 
  CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal'));

ALTER TABLE gitu_sessions DROP CONSTRAINT IF EXISTS valid_session_platform;
ALTER TABLE gitu_sessions ADD CONSTRAINT valid_session_platform
  CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal'));

ALTER TABLE gitu_linked_accounts DROP CONSTRAINT IF EXISTS valid_linked_account_platform;
ALTER TABLE gitu_linked_accounts ADD CONSTRAINT valid_linked_account_platform 
  CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web', 'universal'));

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Updated Gitu platform constraints to include web and universal';
END $$;
