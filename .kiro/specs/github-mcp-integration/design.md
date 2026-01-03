# Design Document: GitHub-MCP Integration

## Overview

This design bridges the GitHub Integration and Coding Agent Communication systems, enabling seamless code discussions between users, the notebook AI, and external coding agents. The system creates GitHub-aware sources that can be referenced by both the notebook AI and MCP-connected coding agents, with unified context sharing and GitHub action capabilities.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         User's GitHub Account                                │
│                    (Repositories, Files, Issues)                            │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │ GitHub API
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Backend GitHub Service                               │
│  • OAuth token management                                                    │
│  • Repository caching                                                        │
│  • File content fetching                                                     │
│  • Rate limit handling                                                       │
│  • Audit logging                                                             │
└──────────┬──────────────────────────────────────────┬───────────────────────┘
           │                                          │
           ▼                                          ▼
┌──────────────────────────┐              ┌──────────────────────────────────┐
│   Flutter App (Mobile)   │              │      MCP Server (Coding Agents)  │
│  • GitHub file browser   │              │  • github_list_repos             │
│  • Add as Source UI      │              │  • github_get_file               │
│  • Notebook AI chat      │              │  • github_search_code            │
│  • GitHub action buttons │              │  • github_add_as_source          │
│  • Source chat with agent│              │  • github_analyze_repo           │
└──────────┬───────────────┘              └──────────┬───────────────────────┘
           │                                          │
           ▼                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Unified Context Service                              │
│  • GitHub source context builder                                            │
│  • Agent source context builder                                             │
│  • Cross-reference resolution                                               │
│  • Context caching and invalidation                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. GitHub Source Service

Manages GitHub files as notebook sources.

```typescript
interface GitHubSourceMetadata {
  type: 'github';
  owner: string;
  repo: string;
  path: string;
  branch: string;
  commitSha: string;
  language: string;
  size: number;
  lastFetchedAt: string;
  githubUrl: string;
}

interface GitHubSourceService {
  createSource(notebookId: string, params: CreateGitHubSourceParams): Promise<Source>;
  refreshSource(sourceId: string): Promise<Source>;
  checkForUpdates(sourceId: string): Promise<{ hasUpdates: boolean; newSha?: string }>;
  getSourceWithContent(sourceId: string): Promise<SourceWithContent>;
}

interface CreateGitHubSourceParams {
  owner: string;
  repo: string;
  path: string;
  branch?: string;
  userId: string;
}
```

### 2. Unified Context Builder

Builds AI context from multiple source types.

```typescript
interface CodeContext {
  sources: ContextSource[];
  repoStructure?: RepoStructure;
  relatedFiles?: RelatedFile[];
  agentSources?: AgentSource[];
}

interface ContextSource {
  id: string;
  type: 'github' | 'code' | 'text';
  title: string;
  content: string;
  language?: string;
  metadata: Record<string, any>;
}

interface UnifiedContextBuilder {
  buildContext(notebookId: string, options?: ContextOptions): Promise<CodeContext>;
  addGitHubContext(context: CodeContext, sourceId: string): Promise<CodeContext>;
  addRelatedFiles(context: CodeContext, repoInfo: RepoInfo): Promise<CodeContext>;
  getContextForAgent(sessionId: string, sourceId: string): Promise<CodeContext>;
}

interface ContextOptions {
  includeGitHubSources?: boolean;
  includeAgentSources?: boolean;
  includeRepoStructure?: boolean;
  maxTokens?: number;
}
```

### 3. GitHub Webhook Payload Builder

Builds webhook payloads with GitHub context.

```typescript
interface GitHubWebhookPayload extends WebhookPayload {
  githubContext?: {
    owner: string;
    repo: string;
    path: string;
    branch: string;
    currentContent: string;
    language: string;
    repoStructure?: string[];
  };
}

interface GitHubWebhookBuilder {
  buildPayload(sourceId: string, message: string, history: Message[]): Promise<GitHubWebhookPayload>;
  includeFileContent(payload: GitHubWebhookPayload): Promise<GitHubWebhookPayload>;
}
```

### 4. GitHub Action Service

Handles GitHub actions from chat suggestions.

```typescript
interface GitHubActionService {
  createIssue(params: CreateIssueParams): Promise<Issue>;
  parseIssueSuggestion(aiResponse: string): IssueSuggestion | null;
  parseCodeSuggestion(aiResponse: string): CodeSuggestion | null;
  generateDiff(original: string, suggested: string): string;
}

interface CreateIssueParams {
  owner: string;
  repo: string;
  title: string;
  body: string;
  labels?: string[];
  sourceId?: string;  // Link back to the source that triggered this
}

interface IssueSuggestion {
  title: string;
  body: string;
  labels?: string[];
}

interface CodeSuggestion {
  original?: string;
  suggested: string;
  description: string;
  lineRange?: { start: number; end: number };
}
```

### 5. Audit Logger

Logs all GitHub API interactions.

```typescript
interface GitHubAuditLog {
  id: string;
  userId: string;
  action: 'list_repos' | 'get_file' | 'search' | 'create_issue' | 'add_source';
  owner?: string;
  repo?: string;
  path?: string;
  agentSessionId?: string;
  success: boolean;
  errorMessage?: string;
  timestamp: Date;
}

interface AuditLogger {
  log(entry: Omit<GitHubAuditLog, 'id' | 'timestamp'>): Promise<void>;
  getLogsForUser(userId: string, options?: AuditQueryOptions): Promise<GitHubAuditLog[]>;
}
```

## Data Models

### Database Schema Additions

```sql
-- GitHub sources metadata (extends sources table)
-- The sources table already exists, we add GitHub-specific fields via metadata JSONB

-- GitHub audit logs
CREATE TABLE github_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  owner TEXT,
  repo TEXT,
  path TEXT,
  agent_session_id UUID REFERENCES agent_sessions(id) ON DELETE SET NULL,
  success BOOLEAN DEFAULT true,
  error_message TEXT,
  request_metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for audit queries
CREATE INDEX idx_github_audit_user ON github_audit_logs(user_id, created_at DESC);
CREATE INDEX idx_github_audit_repo ON github_audit_logs(owner, repo);

-- GitHub source cache (for freshness tracking)
CREATE TABLE github_source_cache (
  source_id UUID PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
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

-- Index for cache invalidation queries
CREATE INDEX idx_github_cache_stale ON github_source_cache(last_checked_at);
```

### Enhanced Source Model for GitHub

```typescript
interface GitHubSource extends Source {
  type: 'github';
  metadata: {
    type: 'github';
    owner: string;
    repo: string;
    path: string;
    branch: string;
    commitSha: string;
    language: string;
    size: number;
    lastFetchedAt: string;
    githubUrl: string;
    // Optional agent context
    agentSessionId?: string;
    agentName?: string;
  };
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: GitHub Source Creation Completeness

*For any* GitHub file added as a source (via app or MCP), the created source SHALL contain all required metadata fields: owner, repo, path, branch, commitSha, language, and githubUrl.

**Validates: Requirements 1.1, 1.2, 3.4**

### Property 2: Source Cache Freshness

*For any* GitHub source viewed, if the last fetch time is older than 1 hour, the system SHALL fetch fresh content; if newer than 1 hour, the system SHALL return cached content without API call.

**Validates: Requirements 1.3**

### Property 3: File Update Detection

*For any* GitHub source where the current commit SHA differs from the stored commit SHA, the system SHALL indicate the file has been updated.

**Validates: Requirements 1.4**

### Property 4: Language Detection Accuracy

*For any* file with a known extension (.ts, .py, .dart, .js, .java, etc.), the system SHALL detect and store the correct language identifier.

**Validates: Requirements 1.5**

### Property 5: MCP GitHub Tool Authorization

*For any* MCP GitHub tool call, if the user has no GitHub connection, the system SHALL return an error with code "GITHUB_NOT_CONNECTED"; if connected, the system SHALL return valid data.

**Validates: Requirements 3.1, 3.2, 3.3, 3.5**

### Property 6: Unified Context Inclusion

*For any* notebook with both GitHub sources and agent-saved code sources, the context builder SHALL include content from both source types in the AI context.

**Validates: Requirements 2.1, 5.1, 5.3**

### Property 7: GitHub Webhook Payload Completeness

*For any* follow-up message about a GitHub source, the webhook payload SHALL include: sourceId, current file content, owner, repo, path, branch, and language.

**Validates: Requirements 4.2**

### Property 8: Agent Source Chat Enablement

*For any* source created by a coding agent (with agentSessionId in metadata), the source SHALL have chat functionality enabled.

**Validates: Requirements 4.1**

### Property 9: Issue Creation Data Integrity

*For any* issue created from an AI suggestion, the GitHub issue SHALL contain the exact title and body provided, and the audit log SHALL record the creation.

**Validates: Requirements 6.4, 7.3**

### Property 10: Access Control Enforcement

*For any* GitHub API request, the system SHALL only return data for repositories the user has access to, and requests for inaccessible repos SHALL return 403 errors.

**Validates: Requirements 7.1, 7.2**

### Property 11: Rate Limit Handling

*For any* GitHub API response with rate limit headers indicating exhaustion, the system SHALL return a user-friendly error message and not retry until the reset time.

**Validates: Requirements 7.4**

### Property 12: Token Revocation Cascade

*For any* GitHub disconnection event, all cached tokens SHALL be invalidated, and subsequent API calls SHALL fail with "GITHUB_NOT_CONNECTED" error.

**Validates: Requirements 7.5**

## Error Handling

| Error Scenario | Handling Strategy |
|----------------|-------------------|
| GitHub API rate limit | Return 429 with reset time, cache response |
| File not found (404) | Return clear error, offer to remove source |
| Repository access denied | Return 403, suggest reconnecting GitHub |
| GitHub connection expired | Prompt OAuth re-authentication |
| Large file (>1MB) | Truncate content, warn user |
| Network timeout | Retry once, then return cached content if available |
| Invalid file path | Validate before API call, return 400 |
| Agent session invalid | Return 401, require new session |

## Testing Strategy

### Unit Tests
- GitHub source metadata validation
- Language detection for various file extensions
- Cache freshness calculation
- Diff generation for code suggestions
- Issue suggestion parsing from AI responses

### Property-Based Tests (using fast-check)
- Source creation completeness (Property 1)
- Cache freshness logic (Property 2)
- Update detection (Property 3)
- Language detection (Property 4)
- Authorization checks (Property 5)
- Context unification (Property 6)
- Webhook payload structure (Property 7)
- Access control (Property 10)

### Integration Tests
- End-to-end: Add GitHub file → Chat with AI → Create issue
- MCP flow: Agent lists repos → Gets file → Adds as source → User chats
- Context sharing: Agent saves code → Notebook AI references it
- Token revocation: Disconnect GitHub → Verify all calls fail

### Testing Framework
- Jest for unit and integration tests
- fast-check for property-based testing
- Minimum 100 iterations per property test
- Tag format: **Feature: github-mcp-integration, Property {number}: {property_text}**

