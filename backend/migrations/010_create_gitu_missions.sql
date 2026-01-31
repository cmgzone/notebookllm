-- Create table for multi-agent missions
CREATE TABLE IF NOT EXISTS gitu_missions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  objective TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('planning', 'active', 'completed', 'failed', 'paused')),
  context JSONB NOT NULL DEFAULT '{}',
  artifacts JSONB NOT NULL DEFAULT '{}',
  agent_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Create table for mission logs (audit trail of swarm activity)
CREATE TABLE IF NOT EXISTS gitu_mission_logs (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  mission_id TEXT NOT NULL REFERENCES gitu_missions(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_gitu_missions_user_status ON gitu_missions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_gitu_mission_logs_mission ON gitu_mission_logs(mission_id, created_at DESC);
