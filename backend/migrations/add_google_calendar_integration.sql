CREATE TABLE IF NOT EXISTS gitu_google_calendar_connections (
  user_id TEXT PRIMARY KEY,
  email TEXT,
  encrypted_access_token TEXT NOT NULL,
  encrypted_refresh_token TEXT,
  expires_at TIMESTAMPTZ,
  scopes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_gitu_google_calendar_connections_user_id
  ON gitu_google_calendar_connections(user_id);

