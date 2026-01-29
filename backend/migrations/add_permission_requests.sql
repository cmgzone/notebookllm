CREATE TABLE IF NOT EXISTS gitu_permission_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource TEXT NOT NULL,
  actions TEXT[] NOT NULL,
  scope JSONB DEFAULT '{}',
  expires_at TIMESTAMPTZ,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  granted_permission_id UUID REFERENCES gitu_permissions(id) ON DELETE SET NULL,
  CONSTRAINT valid_permission_request_status CHECK (status IN ('pending', 'approved', 'denied'))
);

CREATE INDEX IF NOT EXISTS idx_gitu_permission_requests_user ON gitu_permission_requests(user_id, status, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_permission_requests_status ON gitu_permission_requests(status, requested_at DESC);

