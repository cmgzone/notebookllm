-- Social Features Migration
-- Adds friendships, study groups, notebook sharing, activity feed, and leaderboards
-- Note: All ID columns use TEXT to match existing tables (users, notebooks have TEXT ids)

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS group_invitations CASCADE;
DROP TABLE IF EXISTS leaderboard_snapshots CASCADE;
DROP TABLE IF EXISTS activity_reactions CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS notebook_shares CASCADE;
DROP TABLE IF EXISTS study_sessions CASCADE;
DROP TABLE IF EXISTS study_group_members CASCADE;
DROP TABLE IF EXISTS study_groups CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;

-- ============================================
-- FRIENDSHIPS
-- ============================================
CREATE TABLE friendships (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  user_id TEXT NOT NULL,
  friend_id TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  UNIQUE(user_id, friend_id),
  CHECK (user_id != friend_id)
);

CREATE INDEX idx_friendships_user ON friendships(user_id);
CREATE INDEX idx_friendships_friend ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);

-- ============================================
-- STUDY GROUPS
-- ============================================
CREATE TABLE study_groups (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  owner_id TEXT NOT NULL,
  icon VARCHAR(50) DEFAULT '📚',
  cover_image_url TEXT,
  is_public BOOLEAN DEFAULT false,
  max_members INT DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_study_groups_owner ON study_groups(owner_id);
CREATE INDEX idx_study_groups_public ON study_groups(is_public) WHERE is_public = true;

-- ============================================
-- STUDY GROUP MEMBERS
-- ============================================
CREATE TABLE study_group_members (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by TEXT,
  UNIQUE(group_id, user_id)
);

CREATE INDEX idx_study_group_members_group ON study_group_members(group_id);
CREATE INDEX idx_study_group_members_user ON study_group_members(user_id);

-- ============================================
-- STUDY SESSIONS (scheduled group study times)
-- ============================================
CREATE TABLE study_sessions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  group_id TEXT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INT DEFAULT 60,
  meeting_url TEXT,
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_study_sessions_group ON study_sessions(group_id);
CREATE INDEX idx_study_sessions_scheduled ON study_sessions(scheduled_at);

-- ============================================
-- NOTEBOOK SHARING
-- ============================================
CREATE TABLE notebook_shares (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  notebook_id TEXT NOT NULL,
  shared_with_user_id TEXT,
  shared_with_group_id TEXT,
  permission VARCHAR(20) DEFAULT 'viewer' CHECK (permission IN ('viewer', 'editor')),
  shared_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (shared_with_user_id IS NOT NULL OR shared_with_group_id IS NOT NULL)
);

CREATE INDEX idx_notebook_shares_notebook ON notebook_shares(notebook_id);
CREATE INDEX idx_notebook_shares_user ON notebook_shares(shared_with_user_id);
CREATE INDEX idx_notebook_shares_group ON notebook_shares(shared_with_group_id);

-- Add is_public column to notebooks if not exists
ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

-- ============================================
-- ACTIVITY FEED
-- ============================================
CREATE TABLE activities (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  user_id TEXT NOT NULL,
  activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN (
    'achievement_unlocked', 'quiz_completed', 'flashcard_deck_completed',
    'notebook_created', 'notebook_shared', 'study_streak', 'level_up',
    'joined_group', 'study_session_completed', 'friend_added'
  )),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  reference_id TEXT,
  reference_type VARCHAR(50),
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activities_user ON activities(user_id);
CREATE INDEX idx_activities_created ON activities(created_at DESC);
CREATE INDEX idx_activities_type ON activities(activity_type);
CREATE INDEX idx_activities_public ON activities(is_public) WHERE is_public = true;

-- ============================================
-- ACTIVITY REACTIONS
-- ============================================
CREATE TABLE activity_reactions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  activity_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  reaction_type VARCHAR(20) DEFAULT 'like' CHECK (reaction_type IN ('like', 'celebrate', 'support', 'love')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(activity_id, user_id)
);

CREATE INDEX idx_activity_reactions_activity ON activity_reactions(activity_id);
CREATE INDEX idx_activity_reactions_user ON activity_reactions(user_id);

-- ============================================
-- LEADERBOARD SNAPSHOTS (for performance)
-- ============================================
CREATE TABLE leaderboard_snapshots (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  user_id TEXT NOT NULL,
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

CREATE INDEX idx_leaderboard_period ON leaderboard_snapshots(period_type, period_start);
CREATE INDEX idx_leaderboard_xp ON leaderboard_snapshots(xp_earned DESC);
CREATE INDEX idx_leaderboard_user ON leaderboard_snapshots(user_id);

-- ============================================
-- GROUP INVITATIONS
-- ============================================
CREATE TABLE group_invitations (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  group_id TEXT NOT NULL,
  invited_user_id TEXT NOT NULL,
  invited_by TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  UNIQUE(group_id, invited_user_id)
);

CREATE INDEX idx_group_invitations_user ON group_invitations(invited_user_id);
CREATE INDEX idx_group_invitations_group ON group_invitations(group_id);
