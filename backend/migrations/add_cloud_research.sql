-- Add cloud research support
-- Run this migration to add new columns and tables for cloud-based research

-- Add new columns to research_sessions if they don't exist
ALTER TABLE research_sessions 
ADD COLUMN IF NOT EXISTS depth VARCHAR(20) DEFAULT 'standard',
ADD COLUMN IF NOT EXISTS template VARCHAR(50) DEFAULT 'general',
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'completed';

-- Add new columns to research_sources if they don't exist
ALTER TABLE research_sources 
ADD COLUMN IF NOT EXISTS credibility VARCHAR(20) DEFAULT 'unknown',
ADD COLUMN IF NOT EXISTS credibility_score INTEGER DEFAULT 60;

-- Create research_jobs table for background processing
CREATE TABLE IF NOT EXISTS research_jobs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    status_message TEXT,
    progress DECIMAL(3,2) DEFAULT 0,
    session_id TEXT REFERENCES research_sessions(id) ON DELETE SET NULL,
    error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Create index for faster job lookups
CREATE INDEX IF NOT EXISTS idx_research_jobs_user_status ON research_jobs(user_id, status);
CREATE INDEX IF NOT EXISTS idx_research_jobs_created ON research_jobs(created_at DESC);

-- Update existing sources to have default credibility
UPDATE research_sources 
SET credibility = 'unknown', credibility_score = 60 
WHERE credibility IS NULL;
