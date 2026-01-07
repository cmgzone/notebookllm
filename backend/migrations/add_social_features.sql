-- Social Features Migration
-- Adds friendships, study groups, notebook sharing, activity feed, and leaderboards

-- ============================================
-- FRIENDSHIPS
-- ============================================
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  UNIQUE(user_id, friend_id),
  CHECK (user_id != friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON friendships(status);

-- ============================================
-- STUDY GROUPS
-- ============================================
CREATE TABLE IF NOT EXISTS study_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  icon VARCHAR(50) DEFAULT '📚',
  cover_image_url TEXT,
  is_public BOOLEAN DEFAULT false,
  max_members INT DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_groups_owner ON study_groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_public ON study_groups(is_public) WHERE is_public = true;


-- ============================================
-- STUDY GROUP MEMBERS
-- ============================================
CREATE TABLE IF NOT EXISTS study_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by UUID REFERENCES users(id),
  UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_study_group_members_group ON study_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_study_group_members_user ON study_group_members(user_id);

-- ============================================
-- STUDY SESSIONS (scheduled group study times)
-- ============================================
CREATE TABLE IF NOT EXISTS study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INT DEFAULT 60,
  meeting_url TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_sessions_group ON study_sessions(group_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_scheduled ON study_sessions(scheduled_at);

-- ============================================
-- NOTEBOOK SHARING
-- ============================================
CREATE TABLE IF NOT EXISTS notebook_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notebook_id UUID NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
  shared_with_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  shared_with_group_id UUID REFERENCES study_groups(id) ON DELETE CASCADE,
  permission VARCHAR(20) DEFAULT 'viewer' CHECK (permission IN ('viewer', 'editor')),
  shared_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (shared_with_user_id IS NOT NULL OR shared_with_group_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_notebook_shares_notebook ON notebook_shares(notebook_id);
CREATE INDEX IF NOT EXISTS idx_notebook_shares_user ON notebook_shares(shared_with_user_id);
CREATE INDEX IF NOT EXISTS idx_notebook_shares_group ON notebook_shares(shared_with_group_id);

-- Add is_public column to notebooks if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notebooks' AND column_name = 'is_public') THEN
    ALTER TABLE notebooks ADD COLUMN is_public BOOLEAN DEFAULT false;
  END IF;
END $$;


-- ============================================
-- ACTIVITY FEED
-- ============================================
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN (
    'achievement_unlocked', 'quiz_completed', 'flashcard_deck_completed',
    'notebook_created', 'notebook_shared', 'study_streak', 'level_up',
    'joined_group', 'study_session_completed', 'friend_added'
  )),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  reference_id UUID, -- ID of related entity (notebook, quiz, etc.)
  reference_type VARCHAR(50), -- Type of related entity
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_user ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_created ON activities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_public ON activities(is_public) WHERE is_public = true;

-- ============================================
-- ACTIVITY REACTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS activity_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction_type VARCHAR(20) DEFAULT 'like' CHECK (reaction_type IN ('like', 'celebrate', 'support', 'love')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_activity_reactions_activity ON activity_reactions(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_reactions_user ON activity_reactions(user_id);

-- ============================================
-- LEADERBOARD SNAPSHOTS (for performance)
-- ============================================
CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('daily', 'weekly', 'monthly', 'all_time')),
  period_start DATE NOT NULL,
  xp_earned INT DEFAULT 0,
  quizzes_completed INT DEFAULT 0,
  flashcards_reviewed INT DEFAULT 0,
  study_minutes INT DEFAULT 0,
  streak_days INT DEFAULT 0,
  rank INT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, period_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_period ON leaderboard_snapshots(period_type, period_start);
CREATE INDEX IF NOT EXISTS idx_leaderboard_xp ON leaderboard_snapshots(xp_earned DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_user ON leaderboard_snapshots(user_id);

-- ============================================
-- GROUP INVITATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS group_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  invited_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  UNIQUE(group_id, invited_user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_invitations_user ON group_invitations(invited_user_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_group ON group_invitations(group_id);
