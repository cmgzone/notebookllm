-- Stripe Payment Integration Migration
-- Run this after subscription_schema.sql

-- Add Stripe columns to payment_transactions table
ALTER TABLE payment_transactions 
ADD COLUMN IF NOT EXISTS stripe_payment_intent_id VARCHAR(255);

-- Add Stripe API keys to api_keys table
-- Note: Replace with your actual Stripe keys (encrypted)
-- Test keys start with pk_test_ and sk_test_
-- Live keys start with pk_live_ and sk_live_

-- Example: Add test keys (replace with your actual keys)
-- INSERT INTO api_keys (service_name, encrypted_value, is_active)
-- VALUES 
--   ('stripe_publishable_key', 'pk_test_your_publishable_key', true),
--   ('stripe_secret_key', 'sk_test_your_secret_key', true)
-- ON CONFLICT (service_name) DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value;

-- Add Stripe test mode setting
INSERT INTO app_settings (key, value, description)
VALUES ('stripe_test_mode', 'true', 'Enable Stripe test mode')
ON CONFLICT (key) DO NOTHING;

-- Create app_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS app_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Verify migration
SELECT 'Stripe migration completed!' AS status;
