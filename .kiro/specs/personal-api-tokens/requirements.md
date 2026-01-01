# Requirements Document

## Introduction

This feature enables users to generate personal API tokens for authenticating third-party coding agents (via MCP) to their NotebookLLM account. Instead of using short-lived JWT tokens, users can create long-lived API tokens that they configure in their MCP server settings. This follows the pattern used by GitHub, OpenAI, and other services for API authentication.

## Glossary

- **Personal_API_Token**: A long-lived, user-generated token for authenticating API requests from external services
- **Token_Service**: Backend service responsible for generating, validating, and revoking tokens
- **Token_Hash**: A secure hash of the token stored in the database (the actual token is only shown once)
- **MCP_Server**: Model Context Protocol server that coding agents use to communicate with the app

## Requirements

### Requirement 1: Token Generation

**User Story:** As a user, I want to generate a personal API token, so that I can authenticate my coding agents to my account.

#### Acceptance Criteria

1. WHEN a user requests a new token, THE System SHALL generate a cryptographically secure random token with a "nllm_" prefix
2. WHEN a token is generated, THE System SHALL display the full token exactly once and warn the user to copy it
3. WHEN a token is generated, THE System SHALL store only the hashed version in the database
4. THE User SHALL be able to provide an optional name/description for the token
5. THE User SHALL be able to set an optional expiration date (default: never expires)

### Requirement 2: Token Management

**User Story:** As a user, I want to view and manage my API tokens, so that I can track which tokens exist and revoke them if needed.

#### Acceptance Criteria

1. WHEN a user views their tokens, THE System SHALL display a list showing token name, creation date, last used date, and partial token (last 4 characters)
2. THE User SHALL be able to revoke any token at any time
3. WHEN a token is revoked, THE System SHALL immediately invalidate it for all future requests
4. THE System SHALL support multiple active tokens per user (up to 10)
5. IF a user attempts to create more than 10 tokens, THEN THE System SHALL prompt them to revoke an existing token first

### Requirement 3: Token Authentication

**User Story:** As a coding agent developer, I want to authenticate API requests using a personal token, so that my agent can access the user's data.

#### Acceptance Criteria

1. WHEN an API request includes a valid token in the Authorization header, THE System SHALL authenticate the request as the token's owner
2. WHEN a token is used, THE System SHALL update the "last used" timestamp
3. IF an expired token is used, THEN THE System SHALL reject the request with a 401 status
4. IF a revoked token is used, THEN THE System SHALL reject the request with a 401 status
5. THE System SHALL accept tokens in the format "Bearer nllm_xxxxx" in the Authorization header

### Requirement 4: Token Security

**User Story:** As a security-conscious user, I want my tokens to be secure, so that my account is protected from unauthorized access.

#### Acceptance Criteria

1. THE System SHALL use SHA-256 hashing for storing token hashes
2. THE System SHALL generate tokens with at least 32 bytes of cryptographic randomness
3. THE System SHALL rate-limit token generation to 5 tokens per hour per user
4. WHEN a token is compromised, THE User SHALL be able to revoke it immediately
5. THE System SHALL log all token usage for security auditing

### Requirement 5: Flutter UI Integration

**User Story:** As a user, I want to manage my API tokens from the app, so that I can easily create and revoke tokens.

#### Acceptance Criteria

1. THE System SHALL provide a "API Tokens" section in the Agent Connections screen
2. WHEN a user generates a token, THE System SHALL display a modal with the token and a copy button
3. THE System SHALL show a warning that the token will only be displayed once
4. THE User SHALL be able to see usage instructions for configuring MCP servers
5. THE System SHALL provide a confirmation dialog before revoking a token

