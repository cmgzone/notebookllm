-- Add default model column to ai_models table
ALTER TABLE ai_models 
ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT FALSE;

-- Ensure only one model can be default at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_models_default 
ON ai_models (is_default) 
WHERE is_default = TRUE;

-- Set gemini-2.0-flash as default if no default exists
UPDATE ai_models 
SET is_default = TRUE 
WHERE model_id = 'gemini-2.0-flash' 
AND NOT EXISTS (SELECT 1 FROM ai_models WHERE is_default = TRUE);

-- If gemini-2.0-flash doesn't exist, set the first active model as default
UPDATE ai_models 
SET is_default = TRUE 
WHERE id = (
    SELECT id FROM ai_models 
    WHERE is_active = TRUE 
    AND NOT EXISTS (SELECT 1 FROM ai_models WHERE is_default = TRUE)
    ORDER BY created_at ASC 
    LIMIT 1
);
