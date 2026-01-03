-- GitHub-MCP Integration Migration
-- Bridges GitHub Integration and Coding Agent Communication systems
-- Requirements: 1.3, 1.4, 7.3

-- ==================== GITHUB AUDIT LOGS TABLE ====================
-- Logs all GitHub API interactions for audit purposes
-- Requirements: 7.3

CREATE TABLE IF NOT EXISTS github_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('list_repos', 'get_file', 'search', 'create_issue', 'add_source', 'analyze_repo', 'get_tree')),
  owner TEXT,
  repo TEXT,
  path TEXT,
  agent_session_id TEXT REFERENCES agent_sessions(id) ON DELETE SET NULL,
  success BOOLEAN DEFAULT true,
  error_message TEXT,
  request_metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_github_audit_user ON github_audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_github_audit_repo ON github_audit_logs(owner, repo);
CREATE INDEX IF NOT EXISTS idx_github_audit_action ON github_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_github_audit_agent_session ON github_audit_logs(agent_session_id) WHERE agent_session_id IS NOT NULL;

-- ==================== GITHUB SOURCE CACHE TABLE ====================
-- Tracks freshness of GitHub source content for cache invalidation
-- Requirements: 1.3, 1.4

CREATE TABLE IF NOT EXISTS github_source_cache (
  source_id TEXT PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
  owner TEXT NOT NULL,
  repo TEXT NOT NULL,
  path TEXT NOT NULL,
  branch TEXT NOT NULL,
  commit_sha TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  last_checked_at TIMESTAMPTZ DEFAULT NOW(),
  last_modified_at TIMESTAMPTZ,
  UNIQUE(owner, repo, path, branch)
);

-- Index for cache invalidation queries (find stale entries)
CREATE INDEX IF NOT EXISTS idx_github_cache_stale ON github_source_cache(last_checked_at);
CREATE INDEX IF NOT EXISTS idx_github_cache_repo ON github_source_cache(owner, repo);

-- ==================== VERIFICATION ====================
SELECT 'GitHub-MCP integration tables created successfully!' as status;
