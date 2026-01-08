-- Fix Activity Types Migration
-- Adds missing activity types to the activities table CHECK constraint

-- Drop the existing constraint
ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_activity_type_check;

-- Add new constraint with all activity types
ALTER TABLE activities ADD CONSTRAINT activities_activity_type_check 
CHECK (activity_type IN (
  -- Original types
  'achievement_unlocked', 
  'quiz_completed', 
  'flashcard_deck_completed',
  'notebook_created', 
  'notebook_shared', 
  'study_streak', 
  'level_up',
  'joined_group', 
  'study_session_completed', 
  'friend_added',
  -- New content-rich activity types
  'source_shared',
  'plan_shared',
  'podcast_generated',
  'research_completed',
  'image_uploaded',
  'ebook_created',
  'project_started',
  'mindmap_created',
  'infographic_created',
  'story_created'
));
