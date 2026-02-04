-- Fix Gitu Memory Categories
-- Add missing memory categories to the constraint

-- Drop the old constraint
ALTER TABLE gitu_memories DROP CONSTRAINT IF EXISTS valid_memory_category;

-- Add the new constraint with all valid categories
ALTER TABLE gitu_memories ADD CONSTRAINT valid_memory_category 
  CHECK (category IN (
    'personal', 
    'work', 
    'preference', 
    'fact', 
    'context',
    'relationship',
    'skill',
    'goal',
    'habit',
    'event',
    'location',
    'contact'
  ));

COMMENT ON CONSTRAINT valid_memory_category ON gitu_memories IS 'Expanded memory categories to support relationship tracking and other memory types';
