-- Migration: Add social sharing columns to notebooks and plans
-- Date: 2026-01-18

BEGIN;

-- Add social sharing columns to notebooks table
ALTER TABLE notebooks 
  ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS category TEXT;

-- Add social sharing columns to plans table
ALTER TABLE plans 
  ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notebooks_is_public ON notebooks(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_notebooks_view_count ON notebooks(view_count DESC);
CREATE INDEX IF NOT EXISTS idx_plans_is_public ON plans(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_plans_view_count ON plans(view_count DESC);

COMMIT;
