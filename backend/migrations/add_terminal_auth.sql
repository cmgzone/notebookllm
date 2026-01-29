-- Terminal Authentication Migration
-- Adds pairing tokens table for terminal device linking

-- ============================================================================
-- PAIRING TOKENS TABLE
-- ============================================================================

-- Pairing tokens for terminal authentication
-- These are short-lived tokens (5 minutes) used to link terminal devices
CREATE TABLE IF NOT EXISTS gitu_pairing_tokens (
  code TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gitu_pairing_tokens_expiry ON gitu_pairing_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_gitu_pairing_tokens_user ON gitu_pairing_tokens(user_id);

-- ============================================================================
-- CLEANUP FUNCTION
-- ============================================================================

-- Function to clean up expired pairing tokens
CREATE OR REPLACE FUNCTION cleanup_expired_pairing_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM gitu_pairing_tokens WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE gitu_pairing_tokens IS 'Short-lived tokens (5 min) for linking terminal devices to user accounts';
COMMENT ON COLUMN gitu_pairing_tokens.code IS 'Pairing code in format GITU-XXXX-YYYY';
COMMENT ON COLUMN gitu_pairing_tokens.user_id IS 'User who generated this pairing token';
COMMENT ON COLUMN gitu_pairing_tokens.expires_at IS 'Token expiry timestamp (5 minutes from creation)';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Terminal authentication migration completed successfully';
  RAISE NOTICE 'Created table: gitu_pairing_tokens';
  RAISE NOTICE 'Created function: cleanup_expired_pairing_tokens()';
  RAISE NOTICE 'Pairing tokens expire after 5 minutes';
  RAISE NOTICE 'Auth tokens expire after 90 days';
END $$;
