-- Add icon_name column to onboarding_screens table
ALTER TABLE onboarding_screens ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'auto_awesome';
