-- Migration: Add plan quota limits (notes + MCP)
-- Purpose:
-- - Enforce how many text notes a user can store (notes_limit)
-- - Allow per-plan MCP quotas (mcp_*), falling back to mcp_settings when NULL

ALTER TABLE subscription_plans
  ADD COLUMN IF NOT EXISTS notes_limit INTEGER,
  ADD COLUMN IF NOT EXISTS mcp_sources_limit INTEGER,
  ADD COLUMN IF NOT EXISTS mcp_tokens_limit INTEGER,
  ADD COLUMN IF NOT EXISTS mcp_api_calls_per_day INTEGER;

-- Backfill reasonable defaults for existing plans (safe, idempotent).
UPDATE subscription_plans
SET notes_limit = CASE
  WHEN is_free_plan THEN 100
  WHEN LOWER(name) LIKE '%pro%' THEN 1000
  WHEN LOWER(name) LIKE '%ultra%' THEN 10000
  ELSE 10000
END
WHERE notes_limit IS NULL;

UPDATE subscription_plans
SET mcp_sources_limit = CASE
  WHEN is_free_plan THEN 10
  WHEN LOWER(name) LIKE '%pro%' THEN 200
  WHEN LOWER(name) LIKE '%ultra%' THEN 1000
  ELSE 1000
END
WHERE mcp_sources_limit IS NULL;

UPDATE subscription_plans
SET mcp_tokens_limit = CASE
  WHEN is_free_plan THEN 3
  WHEN LOWER(name) LIKE '%pro%' THEN 10
  WHEN LOWER(name) LIKE '%ultra%' THEN 25
  ELSE 25
END
WHERE mcp_tokens_limit IS NULL;

UPDATE subscription_plans
SET mcp_api_calls_per_day = CASE
  WHEN is_free_plan THEN 100
  WHEN LOWER(name) LIKE '%pro%' THEN 2000
  WHEN LOWER(name) LIKE '%ultra%' THEN 10000
  ELSE 10000
END
WHERE mcp_api_calls_per_day IS NULL;
