CREATE TABLE IF NOT EXISTS gitu_evaluations (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL CHECK (target_type IN ('mission', 'agent')),
  mission_id TEXT REFERENCES gitu_missions(id) ON DELETE CASCADE,
  agent_id UUID REFERENCES gitu_agents(id) ON DELETE CASCADE,
  evaluator TEXT NOT NULL CHECK (evaluator IN ('system', 'user', 'auto')),
  score NUMERIC,
  passed BOOLEAN NOT NULL DEFAULT FALSE,
  criteria JSONB NOT NULL DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (target_type = 'mission' AND agent_id IS NULL AND mission_id IS NOT NULL) OR
    (target_type = 'agent' AND agent_id IS NOT NULL AND mission_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_gitu_evaluations_user_created ON gitu_evaluations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_evaluations_mission_created ON gitu_evaluations(mission_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gitu_evaluations_agent_created ON gitu_evaluations(agent_id, created_at DESC);
