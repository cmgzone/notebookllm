-- Social Sharing Features Migration
-- Adds sharing, discovery, view tracking, and privacy controls for notebooks and plans

-- =====================================================
-- 1. Add sharing columns to notebooks table
-- =====================================================
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false;
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0;

-- =====================================================
-- 2. Add sharing columns to plans table
-- =====================================================
ALTER TABLE plans ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0;

-- =====================================================
-- 3. Create shared_content table for social feed posts
-- =====================================================
CREATE TABLE IF NOT EXISTS shared_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_type VARCHAR(50) NOT NULL, -- 'notebook', 'plan'
    content_id UUID NOT NULL,
    caption TEXT,
    is_public BOOLEAN DEFAULT true,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_shared_content_user ON shared_content(user_id);
CREATE INDEX IF NOT EXISTS idx_shared_content_type ON shared_content(content_type);
CREATE INDEX IF NOT EXISTS idx_shared_content_public ON shared_content(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_shared_content_created ON shared_content(created_at DESC);

-- =====================================================
-- 4. Create content_views table for tracking views
-- =====================================================
CREATE TABLE IF NOT EXISTS content_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type VARCHAR(50) NOT NULL, -- 'notebook', 'plan', 'shared_content'
    content_id UUID NOT NULL,
    viewer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    viewer_ip VARCHAR(45), -- For anonymous view tracking
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for efficient queries and preventing duplicate views
CREATE INDEX IF NOT EXISTS idx_content_views_content ON content_views(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_views_viewer ON content_views(viewer_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_content_views_unique ON content_views(content_type, content_id, viewer_id) 
    WHERE viewer_id IS NOT NULL;

-- =====================================================
-- 5. Create content_likes table for social engagement
-- =====================================================
CREATE TABLE IF NOT EXISTS content_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type VARCHAR(50) NOT NULL, -- 'notebook', 'plan', 'shared_content'
    content_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(content_type, content_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_content_likes_content ON content_likes(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_likes_user ON content_likes(user_id);

-- =====================================================
-- 6. Create content_saves table for bookmarking
-- =====================================================
CREATE TABLE IF NOT EXISTS content_saves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type VARCHAR(50) NOT NULL,
    content_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(content_type, content_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_content_saves_user ON content_saves(user_id);

-- =====================================================
-- 7. Function to increment view count
-- =====================================================
CREATE OR REPLACE FUNCTION increment_view_count(
    p_content_type VARCHAR(50),
    p_content_id UUID,
    p_viewer_id UUID DEFAULT NULL,
    p_viewer_ip VARCHAR(45) DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_already_viewed BOOLEAN := false;
BEGIN
    -- Check if already viewed by this user
    IF p_viewer_id IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM content_views 
            WHERE content_type = p_content_type 
            AND content_id = p_content_id 
            AND viewer_id = p_viewer_id
        ) INTO v_already_viewed;
    END IF;
    
    -- If not already viewed, record the view
    IF NOT v_already_viewed THEN
        INSERT INTO content_views (content_type, content_id, viewer_id, viewer_ip)
        VALUES (p_content_type, p_content_id, p_viewer_id, p_viewer_ip)
        ON CONFLICT DO NOTHING;
        
        -- Update view count on the content
        IF p_content_type = 'notebook' THEN
            UPDATE notebooks SET view_count = view_count + 1 WHERE id = p_content_id;
        ELSIF p_content_type = 'plan' THEN
            UPDATE plans SET view_count = view_count + 1 WHERE id = p_content_id;
        ELSIF p_content_type = 'shared_content' THEN
            UPDATE shared_content SET view_count = view_count + 1 WHERE id = p_content_id;
        END IF;
        
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. Add activity type for content sharing
-- =====================================================
DO $$
BEGIN
    -- Add new activity types if not already in the constraint
    ALTER TABLE activities DROP CONSTRAINT IF EXISTS activities_activity_type_check;
    ALTER TABLE activities ADD CONSTRAINT activities_activity_type_check CHECK (
        activity_type IN (
            'achievement_unlocked', 'quiz_completed', 'flashcard_deck_completed',
            'notebook_created', 'notebook_shared', 'study_streak', 'level_up',
            'joined_group', 'study_session_completed', 'friend_added',
            'source_shared', 'plan_shared', 'podcast_generated', 'research_completed',
            'image_uploaded', 'ebook_created', 'project_started', 'mindmap_created',
            'infographic_created', 'story_created',
            'content_shared', 'content_liked', 'content_saved'
        )
    );
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Could not update activity_type constraint: %', SQLERRM;
END $$;
