-- Migration: Add metadata column to plans table
-- Required for fork functionality to store fork origin information

ALTER TABLE plans ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

-- Add index for querying forked plans
CREATE INDEX IF NOT EXISTS idx_plans_metadata_forked ON plans ((metadata->>'forkedFrom')) WHERE metadata->>'forkedFrom' IS NOT NULL;
