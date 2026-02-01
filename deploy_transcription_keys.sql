-- Deploy Transcription API Keys to Neon Database
-- Run this SQL in your Neon console: https://console.neon.tech

-- Ensure api_keys table exists
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Deepgram API Key (for real-time transcription)
-- Set this value from your secret manager (do not commit real keys)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('deepgram', 'REPLACE_WITH_DEEPGRAM_API_KEY', 'Deepgram Real-time Transcription API', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- AssemblyAI API Key (for high-accuracy transcription)
-- Set this value from your secret manager (do not commit real keys)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('assemblyai', 'REPLACE_WITH_ASSEMBLYAI_API_KEY', 'AssemblyAI Transcription API', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- Verify the keys were inserted
SELECT service_name, description, updated_at FROM api_keys WHERE service_name IN ('deepgram', 'assemblyai');
