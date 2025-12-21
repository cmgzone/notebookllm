-- Create AI_MODELS table
CREATE TABLE IF NOT EXISTS ai_models (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name TEXT NOT NULL,
  model_id TEXT NOT NULL,
  provider TEXT NOT NULL, -- 'gemini', 'openrouter', 'openai', etc.
  description TEXT,
  cost_input DECIMAL(10, 6) DEFAULT 0, -- Cost per 1k input tokens
  cost_output DECIMAL(10, 6) DEFAULT 0, -- Cost per 1k output tokens
  context_window INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  is_premium BOOLEAN DEFAULT FALSE, -- Requires subscription?
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_ai_models_provider ON ai_models(provider);
