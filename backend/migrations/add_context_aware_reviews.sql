-- Context-Aware Code Reviews Migration
-- Adds support for GitHub context in code reviews

-- Add related_files_used column to track which files were used for context
ALTER TABLE code_reviews 
ADD COLUMN IF NOT EXISTS related_files_used JSONB DEFAULT NULL;

-- Add index for querying reviews that used context
CREATE INDEX IF NOT EXISTS idx_code_reviews_has_context 
ON code_reviews((related_files_used IS NOT NULL));

-- Comment for documentation
COMMENT ON COLUMN code_reviews.related_files_used IS 
'Array of file paths from GitHub that were used as context for the review';
