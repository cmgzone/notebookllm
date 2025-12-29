-- Add context_window column to ai_models table if it doesn't exist
ALTER TABLE ai_models 
ADD COLUMN IF NOT EXISTS context_window INTEGER DEFAULT 0;

-- Update existing models with default context windows
UPDATE ai_models SET context_window = 1000000 WHERE provider = 'google' AND context_window = 0;
UPDATE ai_models SET context_window = 128000 WHERE provider = 'openrouter' AND context_window = 0;
UPDATE ai_models SET context_window = 200000 WHERE provider = 'anthropic' AND context_window = 0;
UPDATE ai_models SET context_window = 128000 WHERE provider = 'openai' AND context_window = 0;
