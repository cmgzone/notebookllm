# GitHub Integration Requirements

## Overview
Enable NotebookLLM app to access GitHub repositories, allowing the AI to analyze code and enabling coding agents (via MCP) to communicate with the app about repositories.

## Requirements

### 1. GitHub Authentication
- **1.1** Users can connect their GitHub account via OAuth
- **1.2** Support for GitHub personal access tokens as alternative
- **1.3** Secure token storage in backend database
- **1.4** Token refresh and revocation support

### 2. Repository Access (Mobile App)
- **2.1** List user's repositories (owned + accessible)
- **2.2** Browse repository file structure
- **2.3** View file contents with syntax highlighting
- **2.4** Search code within repositories
- **2.5** Add repository as a "source" to notebooks

### 3. AI Integration (Mobile App)
- **3.1** AI can analyze repository structure
- **3.2** AI can answer questions about code
- **3.3** AI can suggest improvements
- **3.4** Context-aware chat about specific files/repos

### 4. MCP Tools for Coding Agents
- **4.1** `connect_github` - Link GitHub account to MCP session
- **4.2** `list_repos` - List accessible repositories
- **4.3** `get_repo_structure` - Get file tree of a repo
- **4.4** `get_file` - Get file contents
- **4.5** `search_code` - Search across repos
- **4.6** `analyze_repo` - AI analysis of repository
- **4.7** `create_issue` - Create GitHub issue
- **4.8** `create_pr_comment` - Comment on PRs

### 5. Agent-to-App Communication
- **5.1** Coding agent can request app AI to analyze code
- **5.2** App AI can respond with insights
- **5.3** Bidirectional context sharing
- **5.4** Real-time updates via WebSocket

### 6. Security
- **6.1** Encrypted token storage
- **6.2** Scope-limited OAuth permissions
- **6.3** Rate limiting for GitHub API calls
- **6.4** Audit logging for repository access

## Database Schema

```sql
-- GitHub connections
CREATE TABLE github_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  github_user_id TEXT NOT NULL,
  github_username TEXT NOT NULL,
  access_token_encrypted TEXT NOT NULL,
  refresh_token_encrypted TEXT,
  token_expires_at TIMESTAMP,
  scopes TEXT[],
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Cached repositories
CREATE TABLE github_repos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id UUID REFERENCES github_connections(id),
  github_repo_id BIGINT NOT NULL,
  full_name TEXT NOT NULL,
  description TEXT,
  default_branch TEXT DEFAULT 'main',
  is_private BOOLEAN DEFAULT false,
  last_synced_at TIMESTAMP,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Repository sources (link to notebooks)
CREATE TABLE github_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id UUID REFERENCES sources(id),
  repo_id UUID REFERENCES github_repos(id),
  file_path TEXT,
  branch TEXT,
  commit_sha TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## API Endpoints

### Backend Routes
- `POST /api/github/connect` - Initiate OAuth flow
- `GET /api/github/callback` - OAuth callback
- `POST /api/github/token` - Connect via PAT
- `DELETE /api/github/disconnect` - Remove connection
- `GET /api/github/repos` - List repositories
- `GET /api/github/repos/:owner/:repo/tree` - Get file tree
- `GET /api/github/repos/:owner/:repo/contents/:path` - Get file
- `GET /api/github/search` - Search code
- `POST /api/github/analyze` - AI analysis

### MCP Endpoints (via coding-agent routes)
- `GET /api/coding-agent/github/repos` - List repos for agent
- `GET /api/coding-agent/github/file` - Get file for agent
- `POST /api/coding-agent/github/analyze` - Request AI analysis
