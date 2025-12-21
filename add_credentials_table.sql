-- Add global API keys table (shared by all users)
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_api_keys_service ON api_keys(service_name);

-- Comment
COMMENT ON TABLE api_keys IS 'Stores encrypted API keys shared by all users';

-- You'll insert the encrypted keys using the app or a script
-- Example structure (don't run this - it's just for reference):
-- INSERT INTO api_keys (service_name, encrypted_value, description) 
-- VALUES ('gemini', 'ENCRYPTED_VALUE_HERE', 'Gemini AI API Key');
