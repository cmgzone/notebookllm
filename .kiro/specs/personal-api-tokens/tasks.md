# Implementation Plan: Personal API Tokens

## Overview

This plan implements a personal API token system for authenticating MCP servers to user accounts. We'll build the database schema, backend service, API routes, auth middleware updates, and Flutter UI components.

## Tasks

- [x] 1. Database Migration for API Tokens
  - [x] 1.1 Create api_tokens table with user_id, name, token_hash, token_prefix, token_suffix, expires_at, last_used_at, revoked_at, metadata
    - _Requirements: 1.1, 1.3, 4.1_
  - [x] 1.2 Create token_usage_logs table for security auditing
    - _Requirements: 4.5_
  - [x] 1.3 Add indexes for performance (user_id, token_hash, active tokens)
    - _Requirements: 3.1_

- [x] 2. Token Service Implementation
  - [x] 2.1 Create tokenService.ts with generateToken, hashToken, validateToken, listTokens, revokeToken
    - _Requirements: 1.1, 1.3, 3.1, 4.1, 4.2_
  - [x] 2.2 Write property test for token generation security
    - **Property 1: Token Generation Security**
    - **Validates: Requirements 1.1, 4.2**
  - [x] 2.3 Write property test for token hash storage
    - **Property 2: Token Hash Storage**
    - **Validates: Requirements 1.3, 4.1**
  - [x] 2.4 Write property test for token validation round-trip
    - **Property 3: Token Validation Round-Trip**
    - **Validates: Requirements 3.1, 3.5**

- [x] 3. Token Revocation and Expiration
  - [x] 3.1 Implement token revocation in tokenService
    - _Requirements: 2.2, 2.3, 3.4_
  - [x] 3.2 Implement token expiration checking
    - _Requirements: 3.3_
  - [x] 3.3 Write property test for token revocation invalidation
    - **Property 4: Token Revocation Invalidation**
    - **Validates: Requirements 2.2, 2.3, 3.4**
  - [x] 3.4 Write property test for token expiration enforcement
    - **Property 5: Token Expiration Enforcement**
    - **Validates: Requirements 3.3**

- [x] 4. Auth Middleware Enhancement
  - [x] 4.1 Update auth middleware to detect and validate API tokens (Bearer nllm_xxx format)
    - _Requirements: 3.1, 3.5_
  - [x] 4.2 Add token usage logging on successful authentication
    - _Requirements: 3.2, 4.5_
  - [x] 4.3 Write property test for token usage logging
    - **Property 8: Token Usage Logging**
    - **Validates: Requirements 3.2, 4.5**

- [x] 5. Backend API Routes
  - [x] 5.1 Add POST /api/auth/tokens - Generate new token with name and optional expiration
    - _Requirements: 1.1, 1.4, 1.5_
  - [x] 5.2 Add GET /api/auth/tokens - List user's tokens with metadata
    - _Requirements: 2.1_
  - [x] 5.3 Add DELETE /api/auth/tokens/:id - Revoke a token
    - _Requirements: 2.2_
  - [x] 5.4 Add rate limiting for token generation (5 per hour)
    - _Requirements: 4.3_
  - [x] 5.5 Add max token limit check (10 per user)
    - _Requirements: 2.4, 2.5_
  - [x] 5.6 Write property test for token list completeness
    - **Property 6: Token List Completeness**
    - **Validates: Requirements 2.1**
  - [x] 5.7 Write property test for multi-token independence
    - **Property 7: Multi-Token Independence**
    - **Validates: Requirements 2.4**

- [x] 6. Checkpoint - Backend Complete
  - Ensure all backend tests pass, ask the user if questions arise.

- [x] 7. Flutter API Service Updates
  - [x] 7.1 Add generateApiToken(name, expiresAt?) method to ApiService
    - _Requirements: 1.1, 1.4, 1.5_
  - [x] 7.2 Add listApiTokens() method
    - _Requirements: 2.1_
  - [x] 7.3 Add revokeApiToken(tokenId) method
    - _Requirements: 2.2_

- [x] 8. Flutter UI - API Tokens Section
  - [x] 8.1 Create ApiTokensSection widget for Agent Connections screen
    - _Requirements: 5.1_
  - [x] 8.2 Create TokenGenerationDialog with copy functionality and warning
    - _Requirements: 5.2, 5.3_
  - [x] 8.3 Create TokenListItem widget showing name, dates, and partial token
    - _Requirements: 2.1_
  - [x] 8.4 Add revoke confirmation dialog
    - _Requirements: 5.5_
  - [x] 8.5 Add MCP configuration instructions display
    - _Requirements: 5.4_

- [x] 9. Update MCP Server Documentation
  - [x] 9.1 Update README.md with personal token authentication instructions
    - _Requirements: 3.5_
  - [x] 9.2 Update mcp-config-example.json with token placeholder
    - _Requirements: 3.5_
  - [x] 9.3 Update CODING_AGENT_SETUP.md with token generation steps
    - _Requirements: 5.4_

- [x] 10. Final Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks including property-based tests are required
- Backend tasks (1-6) should be completed before Flutter tasks
- The auth middleware update (4) is critical for the feature to work
- Token is only shown once during generation - this is a security feature

