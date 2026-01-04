-- GitHub Integration Migration
-- Adds tables for GitHub OAuth connections and repository access

-- GitHub connections (OAuth tokens)
CREATE TABLE IF NOT EXISTS github_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  github_user_id TEXT NOT NULL,
  github_username TEXT NOT NULL,
  github_email TEXT,
  github_avatar_url TEXT,
  access_token_encrypted TEXT NOT NULL,
  refresh_token_encrypted TEXT,
  token_expires_at TIMESTAMP WITH TIME ZONE,
  scopes TEXT[] DEFAULT ARRAY['repo', 'read:user'],
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Cached repositories for quick access
CREATE TABLE IF NOT EXISTS github_repos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id UUID NOT NULL REFERENCES github_connections(id) ON DELETE CASCADE,
  github_repo_id BIGINT NOT NULL,
  full_name TEXT NOT NULL,
  name TEXT NOT NULL,
  owner TEXT NOT NULL,
  description TEXT,
  default_branch TEXT DEFAULT 'main',
  is_private BOOLEAN DEFAULT false,
  is_fork BOOLEAN DEFAULT false,
  language TEXT,
  stars_count INTEGER DEFAULT 0,
  forks_count INTEGER DEFAULT 0,
  size_kb INTEGER DEFAULT 0,
  html_url TEXT,
  clone_url TEXT,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(connection_id, github_repo_id)
);

-- Link GitHub files to notebook sources
CREATE TABLE IF NOT EXISTS github_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id TEXT NOT NULL,
  repo_id UUID NOT NULL REFERENCES github_repos(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  branch TEXT DEFAULT 'main',
  commit_sha TEXT,
  file_size INTEGER,
  language TEXT,
  last_synced_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(source_id)
);

-- GitHub API rate limit tracking
CREATE TABLE IF NOT EXISTS github_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id UUID NOT NULL REFERENCES github_connections(id) ON DELETE CASCADE,
  resource TEXT NOT NULL, -- 'core', 'search', 'graphql'
  limit_value INTEGER NOT NULL,
  remaining INTEGER NOT NULL,
  reset_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(connection_id, resource)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_github_connections_user ON github_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_github_repos_connection ON github_repos(connection_id);
CREATE INDEX IF NOT EXISTS idx_github_repos_full_name ON github_repos(full_name);
CREATE INDEX IF NOT EXISTS idx_github_sources_source ON github_sources(source_id);
CREATE INDEX IF NOT EXISTS idx_github_sources_repo ON github_sources(repo_id);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_github_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER github_connections_updated
  BEFORE UPDATE ON github_connections
  FOR EACH ROW EXECUTE FUNCTION update_github_updated_at();

CREATE TRIGGER github_repos_updated
  BEFORE UPDATE ON github_repos
  FOR EACH ROW EXECUTE FUNCTION update_github_updated_at();

CREATE TRIGGER github_sources_updated
  BEFORE UPDATE ON github_sources
  FOR EACH ROW EXECUTE FUNCTION update_github_updated_at();
