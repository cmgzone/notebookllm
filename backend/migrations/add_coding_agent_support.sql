-- Migration: Add coding agent support
-- Adds user_id to sources table and metadata column for verification data

-- Add user_id column to sources (allows sources without notebooks)
ALTER TABLE sources ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id) ON DELETE CASCADE;

-- Add metadata column for storing verification results
ALTER TABLE sources ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_sources_user_id ON sources(user_id);
CREATE INDEX IF NOT EXISTS idx_sources_type ON sources(type);
CREATE INDEX IF NOT EXISTS idx_sources_metadata_verified ON sources((metadata->>'isVerified'));

-- Update existing sources to have user_id from their notebook
UPDATE sources s
SET user_id = n.user_id
FROM notebooks n
WHERE s.notebook_id = n.id
AND s.user_id IS NULL;
