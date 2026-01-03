# Implementation Plan: GitHub-MCP Integration

## Overview

This plan implements the bridge between GitHub Integration and Coding Agent Communication systems, enabling unified code context sharing between the notebook AI and MCP-connected coding agents.

## Tasks

- [x] 1. Database Schema and Migrations
  - [x] 1.1 Create migration for github_audit_logs table
    - Add table with user_id, action, owner, repo, path, agent_session_id, success, error_message
    - Add indexes for user queries and repo lookups
    - _Requirements: 7.3_
  - [x] 1.2 Create migration for github_source_cache table
    - Add table with source_id, owner, repo, path, branch, commit_sha, content_hash, timestamps
    - Add unique constraint and stale cache index
    - _Requirements: 1.3, 1.4_
  - [x] 1.3 Run migrations and verify schema
    - Execute migrations against Neon database
    - Verify tables and indexes created correctly
    - _Requirements: 1.2, 7.3_

- [x] 2. Backend GitHub Source Service
  - [x] 2.1 Create GitHubSourceService in backend
    - Implement createSource() to create GitHub sources with full metadata
    - Implement refreshSource() to fetch latest content from GitHub
    - Implement checkForUpdates() to compare commit SHAs
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - [x] 2.2 Write property test for source creation completeness
    - **Property 1: GitHub Source Creation Completeness**
    - **Validates: Requirements 1.1, 1.2, 3.4**
  - [x] 2.3 Implement language detection utility
    - Map file extensions to language identifiers
    - Handle edge cases (no extension, unknown extension)
    - _Requirements: 1.5_
  - [x] 2.4 Write property test for language detection
    - **Property 4: Language Detection Accuracy**
    - **Validates: Requirements 1.5**
  - [x] 2.5 Implement cache freshness logic
    - Check lastFetchedAt against 1-hour threshold
    - Return cached content or trigger refresh
    - _Requirements: 1.3_
  - [x] 2.6 Write property test for cache freshness
    - **Property 2: Source Cache Freshness**
    - **Validates: Requirements 1.3**

- [x] 3. Checkpoint - Backend Source Service
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Backend Audit Logger
  - [x] 4.1 Create AuditLogger service
    - Implement log() to record GitHub API interactions
    - Implement getLogsForUser() with pagination and filtering
    - _Requirements: 7.3_
  - [x] 4.2 Write property test for audit logging
    - **Property 9: Issue Creation Data Integrity (audit portion)**
    - **Validates: Requirements 7.3**
  - [x] 4.3 Integrate audit logging into GitHub routes
    - Add logging calls to all GitHub API endpoints
    - Include agent session ID when available
    - _Requirements: 7.3_

- [x] 5. Backend Unified Context Builder
  - [x] 5.1 Create UnifiedContextBuilder service
    - Implement buildContext() to gather all source types
    - Implement addGitHubContext() to include GitHub source content
    - Implement getContextForAgent() for MCP context requests
    - _Requirements: 2.1, 5.1, 5.3_
  - [x] 5.2 Write property test for unified context
    - **Property 6: Unified Context Inclusion**
    - **Validates: Requirements 2.1, 5.1, 5.3**
  - [x] 5.3 Add context endpoint to coding-agent routes
    - GET /api/coding-agent/context/:notebookId
    - Include both GitHub and agent sources
    - _Requirements: 5.3_

- [x] 6. Checkpoint - Backend Context Service
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. MCP Server GitHub Tool Enhancements
  - [x] 7.1 Enhance github_add_as_source tool handler
    - Call GitHubSourceService.createSource()
    - Return created source with full metadata
    - _Requirements: 3.4_
  - [x] 7.2 Add authorization checks to all GitHub tools
    - Verify user has GitHub connection before API calls
    - Return GITHUB_NOT_CONNECTED error if not connected
    - _Requirements: 3.5, 7.1, 7.2_
  - [x] 7.3 Write property test for MCP authorization
    - **Property 5: MCP GitHub Tool Authorization**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.5**
  - [x] 7.4 Add rate limit handling to MCP tools
    - Parse GitHub rate limit headers
    - Return user-friendly error with reset time
    - _Requirements: 7.4_
  - [x] 7.5 Write property test for rate limit handling
    - **Property 11: Rate Limit Handling**
    - **Validates: Requirements 7.4**

- [x] 8. Backend Webhook Enhancement for GitHub Sources
  - [x] 8.1 Create GitHubWebhookBuilder service
    - Extend webhook payload with GitHub context
    - Include current file content, owner, repo, path, branch
    - _Requirements: 4.2_
  - [x] 8.2 Write property test for webhook payload
    - **Property 7: GitHub Webhook Payload Completeness**
    - **Validates: Requirements 4.2**
  - [x] 8.3 Update webhook sending logic
    - Detect GitHub sources and use enhanced builder
    - Maintain backward compatibility for non-GitHub sources
    - _Requirements: 4.2_

- [x] 9. Checkpoint - Backend MCP and Webhook
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Backend GitHub Action Service
  - [x] 10.1 Create GitHubActionService
    - Implement createIssue() with audit logging
    - Implement parseIssueSuggestion() to extract issue data from AI responses
    - Implement generateDiff() for code comparison
    - _Requirements: 6.4_
  - [x] 10.2 Write property test for issue creation
    - **Property 9: Issue Creation Data Integrity**
    - **Validates: Requirements 6.4, 7.3**
  - [x] 10.3 Add issue creation endpoint
    - POST /api/github/repos/:owner/:repo/issues
    - Accept pre-filled title and body
    - _Requirements: 6.4_

- [x] 11. Backend Token Revocation Handler
  - [x] 11.1 Implement token revocation cascade
    - Clear all cached tokens on disconnect
    - Invalidate github_source_cache entries
    - _Requirements: 7.5_
  - [x] 11.2 Write property test for token revocation
    - **Property 12: Token Revocation Cascade**
    - **Validates: Requirements 7.5**
  - [x] 11.3 Add disconnect notification to agents
    - Notify connected agent sessions of GitHub disconnect
    - Update agent session status
    - _Requirements: 7.5_

- [x] 12. Checkpoint - Backend Complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Flutter GitHub Source Provider
  - [x] 13.1 Create GitHubSourceProvider
    - Implement addGitHubSource() to create sources via API
    - Implement refreshSource() to update cached content
    - Implement checkForUpdates() to detect file changes
    - _Requirements: 1.1, 1.3, 1.4_
  - [x] 13.2 Add GitHub source state management
    - Track loading, error, and update states
    - Handle cache invalidation
    - _Requirements: 1.3, 1.4_

- [x] 14. Flutter GitHub Source UI
  - [x] 14.1 Update GitHubFileBrowserScreen with "Add as Source" flow
    - Show notebook selector when adding source
    - Display success/error feedback
    - _Requirements: 1.1_
  - [x] 14.2 Create GitHubSourceCard widget
    - Display file info with syntax highlighting
    - Show "File Updated" indicator when SHA differs
    - Add quick actions: View on GitHub, Copy Link, Refresh
    - _Requirements: 1.4, 1.5, 6.3_
  - [x] 14.3 Integrate GitHub sources into notebook detail screen
    - Display GitHub sources alongside other source types
    - Enable chat functionality for agent-created sources
    - _Requirements: 4.1_

- [x] 15. Flutter Chat Integration
  - [x] 15.1 Update chat context builder for GitHub sources
    - Include GitHub source content in AI context
    - Add repository structure when available
    - _Requirements: 2.1_
  - [x] 15.2 Add GitHub action buttons to chat responses
    - Detect issue suggestions and show "Create Issue" button
    - Detect code suggestions and show "Copy Code" button
    - _Requirements: 6.1, 6.2_
  - [x] 15.3 Implement issue creation from chat
    - Pre-fill issue form with AI suggestion
    - Navigate to GitHub or create via API
    - _Requirements: 6.4_

- [x] 16. Flutter Agent Source Chat
  - [x] 16.1 Update SourceChatSheet for GitHub sources
    - Include file content in follow-up messages
    - Display code diffs when agent suggests changes
    - _Requirements: 4.2, 4.4_
  - [x] 16.2 Add "Create Issue" action for agent suggestions
    - Parse agent response for issue suggestions
    - Enable one-click issue creation
    - _Requirements: 4.5_

- [x] 17. Checkpoint - Flutter Integration
  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Access Control and Security
  - [x] 18.1 Implement repository access validation
    - Verify user has access before returning data
    - Return 403 for inaccessible repositories
    - _Requirements: 7.1_
  - [x] 18.2 Write property test for access control
    - **Property 10: Access Control Enforcement**
    - **Validates: Requirements 7.1, 7.2**
  - [x] 18.3 Add agent session validation to GitHub routes
    - Verify agent session belongs to requesting user
    - Reject requests with invalid sessions
    - _Requirements: 7.2_

- [x] 19. Final Integration Testing
  - [x] 19.1 Test end-to-end flow: App adds GitHub source → Chat with AI
    - Verify source creation, context inclusion, and AI response
    - _Requirements: 1.1, 2.1_
  - [x] 19.2 Test MCP flow: Agent adds source → User chats with agent
    - Verify MCP tool calls, webhook delivery, and response display
    - _Requirements: 3.4, 4.1, 4.2_
  - [x] 19.3 Test context sharing between notebook AI and agents
    - Verify both can access unified context
    - _Requirements: 5.1, 5.3_

- [ ] 20. Final Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All property-based tests are required for comprehensive coverage
- Backend uses TypeScript with Jest and fast-check for testing
- Flutter uses Dart with flutter_riverpod for state management
- All GitHub API calls must include audit logging
- Rate limits should be handled gracefully with user feedback
- Property tests should run minimum 100 iterations

