-- Add category column to notebooks table
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General';

-- Update existing notebooks to have 'General' category
UPDATE notebooks SET category = 'General' WHERE category IS NULL;
