-- Step 1: Create the api_keys table
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_api_keys_service ON api_keys(service_name);

-- Step 2: Insert your API keys (ENCRYPTED)
-- Note: These are encrypted using AES-256 encryption
-- The app will decrypt them automatically

-- Gemini API Key (encrypted)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('gemini', 'ENCRYPTED_GEMINI_KEY_HERE', 'Gemini AI API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- ElevenLabs API Key (encrypted)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('elevenlabs', 'ENCRYPTED_ELEVENLABS_KEY_HERE', 'ElevenLabs API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- Serper API Key (encrypted)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('serper', 'ENCRYPTED_SERPER_KEY_HERE', 'Serper API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- Verify the keys were inserted
SELECT service_name, description, updated_at FROM api_keys;
