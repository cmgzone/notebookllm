-- Group Moderation & Roles
-- Adds moderator role, bans, and audit logs

-- Expand role check to include 'moderator'
ALTER TABLE study_group_members
  DROP CONSTRAINT IF EXISTS study_group_members_role_check;

ALTER TABLE study_group_members
  ADD CONSTRAINT study_group_members_role_check
  CHECK (role IN ('owner', 'admin', 'moderator', 'member'));

-- Group bans
CREATE TABLE IF NOT EXISTS group_bans (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  banned_by TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_bans_group ON group_bans(group_id);
CREATE INDEX IF NOT EXISTS idx_group_bans_user ON group_bans(user_id);

-- Group audit logs
CREATE TABLE IF NOT EXISTS group_audit_logs (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  group_id TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  action TEXT NOT NULL,
  target_user_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_audit_group ON group_audit_logs(group_id);
CREATE INDEX IF NOT EXISTS idx_group_audit_actor ON group_audit_logs(actor_id);
