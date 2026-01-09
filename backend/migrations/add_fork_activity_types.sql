-- Add notebook_forked and plan_forked to the activities table CHECK constraint
-- This allows the new fork activity types to be stored

-- First, drop the existing constraint
ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_activity_type_check;

-- Add the updated constraint with new activity types
ALTER TABLE activities ADD CONSTRAINT activities_activity_type_check CHECK (
  activity_type IN (
    'achievement_unlocked',
    'quiz_completed',
    'flashcard_deck_completed',
    'notebook_created',
    'notebook_shared',
    'notebook_forked',
    'study_streak',
    'level_up',
    'joined_group',
    'study_session_completed',
    'friend_added',
    'source_shared',
    'plan_shared',
    'plan_forked',
    'podcast_generated',
    'research_completed',
    'image_uploaded',
    'ebook_created',
    'project_started',
    'mindmap_created',
    'infographic_created',
    'story_created',
    'content_shared',
    'content_liked',
    'content_saved'
  )
);
