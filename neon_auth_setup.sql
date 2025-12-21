-- ==========================================
-- Neon Authorize (RLS) Setup Script
-- ==========================================

-- This script sets up Row Level Security for the custom auth system.
-- The authenticated user's ID is passed via the application layer.

-- 1. Enable Row Level Security (RLS) on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebook_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_credentials ENABLE ROW LEVEL SECURITY;

-- 2. Create Policies

-- USERS Table
-- Users can insert their own profile (during sign up)
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (id = auth.user_id());

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (id = auth.user_id());

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (id = auth.user_id());

-- NOTEBOOKS Table
-- Users can do everything with their own notebooks
CREATE POLICY "Users can manage own notebooks" ON notebooks
  FOR ALL USING (user_id = auth.user_id());

-- SOURCES Table
-- Users can manage sources if they own the parent notebook
CREATE POLICY "Users can manage own sources" ON sources
  FOR ALL USING (
    notebook_id IN (SELECT id FROM notebooks WHERE user_id = auth.user_id())
  );

-- CHUNKS Table
-- Users can manage chunks if they own the parent source
CREATE POLICY "Users can manage own chunks" ON chunks
  FOR ALL USING (
    source_id IN (
      SELECT s.id FROM sources s
      JOIN notebooks n ON s.notebook_id = n.id
      WHERE n.user_id = auth.user_id()
    )
  );

-- TAGS Table
-- Users can manage their own tags
CREATE POLICY "Users can manage own tags" ON tags
  FOR ALL USING (user_id = auth.user_id());

-- NOTEBOOK_TAGS Table
-- Users can manage tags on their notebooks
CREATE POLICY "Users can manage own notebook tags" ON notebook_tags
  FOR ALL USING (
    notebook_id IN (SELECT id FROM notebooks WHERE user_id = auth.user_id())
  );

-- USER_CREDENTIALS Table
-- Users can manage their own credentials
CREATE POLICY "Users can manage own credentials" ON user_credentials
  FOR ALL USING (user_id = auth.user_id());

-- 3. Grant permissions to the authenticated role
-- Replace 'authenticated' with the actual role name Neon uses for authenticated users (often 'authenticated' or 'neondb_owner' depending on setup, but for RLS usually a specific role is used).
-- For now, we grant to public but RLS restricts access.
GRANT ALL ON users TO public;
GRANT ALL ON notebooks TO public;
GRANT ALL ON sources TO public;
GRANT ALL ON chunks TO public;
GRANT ALL ON tags TO public;
GRANT ALL ON notebook_tags TO public;
GRANT ALL ON user_credentials TO public;

-- Note: In a strict production environment, you should grant to a specific role, not public.
