-- Fix Gitu Memory Categories
-- Remove category constraint to allow unlimited flexibility

-- Drop the old constraint to allow any category
ALTER TABLE gitu_memories DROP CONSTRAINT IF EXISTS valid_memory_category;

-- Add a simple NOT NULL constraint to ensure category is always provided
ALTER TABLE gitu_memories ALTER COLUMN category SET NOT NULL;

-- Add a check to ensure category is not empty
ALTER TABLE gitu_memories ADD CONSTRAINT category_not_empty 
  CHECK (length(trim(category)) > 0);

COMMENT ON COLUMN gitu_memories.category IS 'Memory category - can be any string (e.g., personal, work, relationship, skill, etc.). No predefined list to allow maximum flexibility.';
