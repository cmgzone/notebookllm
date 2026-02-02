-- Migration to add Gitu Agents table
-- Handles autonomous sub-agents with hierarchy and memory

CREATE TABLE IF NOT EXISTS gitu_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_agent_id UUID REFERENCES gitu_agents(id) ON DELETE SET NULL,
    task TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, active, completed, failed, paused
    memory JSONB DEFAULT '{}', -- Agent's context/memory
    result JSONB DEFAULT '{}', -- Final output
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by user and status
CREATE INDEX IF NOT EXISTS idx_gitu_agents_user_status ON gitu_agents(user_id, status);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_gitu_agents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_gitu_agents_timestamp ON gitu_agents;
CREATE TRIGGER update_gitu_agents_timestamp
    BEFORE UPDATE ON gitu_agents
    FOR EACH ROW
    EXECUTE FUNCTION update_gitu_agents_updated_at();
