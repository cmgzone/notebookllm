-- Manual script to add OpenRouter API key to Neon database
-- Run this in Neon Console SQL Editor: https://console.neon.tech

-- Step 1: Make sure the api_keys table exists
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 2: Insert OpenRouter API key (REPLACE WITH YOUR ENCRYPTED KEY)
-- Note: You need to encrypt your key first using the app or script

-- Option A: If you want to store it UNENCRYPTED (NOT RECOMMENDED for production)
-- Uncomment and replace YOUR_OPENROUTER_KEY_HERE with your actual key:
/*
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('openrouter', 'YOUR_OPENROUTER_KEY_HERE', 'OpenRouter API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;
*/

-- Option B: Use the app to encrypt and store (RECOMMENDED)
-- 1. Add your key to .env file:
--    OPENROUTER_API_KEY=sk-or-v1-your-key-here
-- 
-- 2. Run the QuickDeployKeys screen in your app
--    OR
-- 3. Run this code in your app:
--    final credService = ref.read(globalCredentialsServiceProvider);
--    await credService.storeApiKey(
--      service: 'openrouter',
--      apiKey: 'sk-or-v1-your-key-here',
--      description: 'OpenRouter API Key',
--    );

-- Verify the key was added:
SELECT service_name, description, updated_at FROM api_keys WHERE service_name = 'openrouter';

-- View all API keys:
SELECT service_name, description, updated_at FROM api_keys ORDER BY service_name;
