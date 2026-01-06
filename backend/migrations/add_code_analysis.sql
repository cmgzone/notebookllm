-- Migration: Add Code Analysis Support
-- This adds fields to store AI-generated code analysis for GitHub sources
-- Improves fact-checking results by providing deep knowledge about code

-- Add code_analysis column to sources table (stores JSON analysis result)
ALTER TABLE sources ADD COLUMN IF NOT EXISTS code_analysis JSONB;

-- Add analysis_summary column for quick access to the summary text
ALTER TABLE sources ADD COLUMN IF NOT EXISTS analysis_summary TEXT;

-- Add analysis_rating column for quick filtering/sorting by quality
ALTER TABLE sources ADD COLUMN IF NOT EXISTS analysis_rating SMALLINT;

-- Add analyzed_at timestamp
ALTER TABLE sources ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ;

-- Create index for filtering by rating
CREATE INDEX IF NOT EXISTS idx_sources_analysis_rating ON sources(analysis_rating) WHERE analysis_rating IS NOT NULL;

-- Create index for finding unanalyzed sources
CREATE INDEX IF NOT EXISTS idx_sources_unanalyzed ON sources(type, analyzed_at) WHERE type = 'github' AND analyzed_at IS NULL;

-- Add comment explaining the columns
COMMENT ON COLUMN sources.code_analysis IS 'JSON object containing full AI code analysis (rating, components, quality metrics, etc.)';
COMMENT ON COLUMN sources.analysis_summary IS 'Human-readable summary of the code analysis for fact-checking context';
COMMENT ON COLUMN sources.analysis_rating IS 'Code quality rating 1-10 for quick filtering';
COMMENT ON COLUMN sources.analyzed_at IS 'Timestamp when the code was analyzed';
