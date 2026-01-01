# Design Document: Personal API Tokens

## Overview

This design implements a personal API token system that allows users to generate long-lived tokens for authenticating third-party coding agents. The system follows industry best practices used by GitHub, OpenAI, and similar services: tokens are generated with cryptographic randomness, only the hash is stored, and the full token is shown exactly once.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App                                   │
│  • API Tokens section in Agent Connections screen               │
│  • Token generation modal with copy functionality               │
│  • Token list with revoke actions                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTP API
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend API                                   │
│  Endpoints:                                                      │
│  • POST /api/auth/tokens - Generate new token                   │
│  • GET /api/auth/tokens - List user's tokens                    │
│  • DELETE /api/auth/tokens/:id - Revoke token                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Token Service                                 │
│  • generateToken() - Create cryptographically secure token      │
│  • hashToken() - SHA-256 hash for storage                       │
│  • validateToken() - Check token against stored hash            │
│  • revokeToken() - Mark token as revoked                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Database                                      │
│  • api_tokens table - Stores token metadata and hashes          │
│  • token_usage_logs table - Audit trail for security            │
└─────────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Server                                    │
│  • Uses token from CODING_AGENT_API_KEY env var                 │
│  • Sends token in Authorization: Bearer header                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Token Service

Handles token generation, validation, and management.

```typescript
interface ApiToken {
  id: string;
  userId: string;
  name: string;
  tokenHash: string;
  tokenPrefix: string;      // First 8 chars for identification
  tokenSuffix: string;      // Last 4 chars for display
  expiresAt: Date | null;
  lastUsedAt: Date | null;
  createdAt: Date;
  revokedAt: Date | null;
  metadata: Record<string, any>;
}

interface TokenGenerationResult {
  token: string;            // Full token (only returned once)
  tokenRecord: ApiToken;    // Stored record (without full token)
}

interface TokenService {
  generateToken(userId: string, name: string, expiresAt?: Date): Promise<TokenGenerationResult>;
  validateToken(token: string): Promise<{ valid: boolean; userId?: string; tokenId?: string }>;
  listTokens(userId: string): Promise<ApiToken[]>;
  revokeToken(userId: string, tokenId: string): Promise<boolean>;
  updateLastUsed(tokenId: string): Promise<void>;
}
```

### 2. Auth Middleware Enhancement

Updates to support both JWT and API token authentication.

```typescript
interface AuthResult {
  userId: string;
  authMethod: 'jwt' | 'api_token';
  tokenId?: string;         // If authenticated via API token
}

// Middleware checks Authorization header:
// 1. If starts with "Bearer nllm_" -> validate as API token
// 2. Otherwise -> validate as JWT
```

### 3. Flutter API Service

New methods for token management.

```dart
class ApiService {
  Future<Map<String, dynamic>> generateApiToken({
    required String name,
    DateTime? expiresAt,
  });
  
  Future<List<Map<String, dynamic>>> listApiTokens();
  
  Future<void> revokeApiToken(String tokenId);
}
```

## Data Models

### Database Schema

```sql
-- API tokens table
CREATE TABLE api_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  token_prefix TEXT NOT NULL,       -- First 8 chars (e.g., "nllm_abc")
  token_suffix TEXT NOT NULL,       -- Last 4 chars for display
  expires_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT valid_token_prefix CHECK (token_prefix LIKE 'nllm_%')
);

-- Indexes
CREATE INDEX idx_api_tokens_user ON api_tokens(user_id);
CREATE INDEX idx_api_tokens_hash ON api_tokens(token_hash);
CREATE INDEX idx_api_tokens_active ON api_tokens(user_id) 
  WHERE revoked_at IS NULL;

-- Token usage logs for security auditing
CREATE TABLE token_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_id UUID NOT NULL REFERENCES api_tokens(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_token_usage_token ON token_usage_logs(token_id);
CREATE INDEX idx_token_usage_time ON token_usage_logs(created_at);
```

### Token Format

```
nllm_[32 bytes of base64url-encoded random data]

Example: nllm_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2
```

- Prefix: `nllm_` (5 characters) - identifies as NotebookLLM token
- Random part: 43 characters (32 bytes base64url encoded)
- Total length: 48 characters



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Token Generation Security

*For any* generated token, the token SHALL:
- Start with the prefix "nllm_"
- Have a total length of 48 characters
- Contain only URL-safe base64 characters after the prefix
- Be unique (no two generated tokens are identical)

**Validates: Requirements 1.1, 4.2**

### Property 2: Token Hash Storage

*For any* generated token, the stored hash SHALL:
- Be exactly 64 hexadecimal characters (SHA-256)
- Be different from the original token
- Be deterministic (same token always produces same hash)
- Not allow recovery of the original token

**Validates: Requirements 1.3, 4.1**

### Property 3: Token Validation Round-Trip

*For any* valid token that has not been revoked or expired, validating the token SHALL return the correct user ID and token ID that were used during generation.

**Validates: Requirements 3.1, 3.5**

### Property 4: Token Revocation Invalidation

*For any* token that is revoked, subsequent validation attempts SHALL fail with an invalid result, regardless of how much time has passed since revocation.

**Validates: Requirements 2.2, 2.3, 3.4, 4.4**

### Property 5: Token Expiration Enforcement

*For any* token with an expiration date, validation SHALL succeed before the expiration time and fail after the expiration time.

**Validates: Requirements 3.3**

### Property 6: Token List Completeness

*For any* user with tokens, listing their tokens SHALL return all non-deleted tokens with: name, creation date, last used date (if any), and the last 4 characters of the token.

**Validates: Requirements 2.1**

### Property 7: Multi-Token Independence

*For any* user with multiple tokens, each token SHALL authenticate independently, and revoking one token SHALL not affect the validity of other tokens.

**Validates: Requirements 2.4**

### Property 8: Token Usage Logging

*For any* successful token authentication, a usage log entry SHALL be created containing the token ID, endpoint, and timestamp.

**Validates: Requirements 3.2, 4.5**

## Error Handling

| Error Scenario | Handling Strategy |
|----------------|-------------------|
| Invalid token format | Return 401 with "Invalid token format" |
| Token not found | Return 401 with "Invalid token" (don't reveal if token exists) |
| Token expired | Return 401 with "Token expired" |
| Token revoked | Return 401 with "Token revoked" |
| Max tokens reached | Return 400 with "Maximum tokens reached. Please revoke an existing token." |
| Rate limit exceeded | Return 429 with "Too many token requests. Please try again later." |
| Database error | Return 500 with generic error, log details internally |

## Testing Strategy

### Unit Tests
- Token generation format validation
- Hash function correctness
- Token validation logic
- Expiration date handling

### Property-Based Tests
- Token generation security (Property 1)
- Hash storage correctness (Property 2)
- Validation round-trip (Property 3)
- Revocation invalidation (Property 4)
- Expiration enforcement (Property 5)
- List completeness (Property 6)
- Multi-token independence (Property 7)
- Usage logging (Property 8)

### Integration Tests
- End-to-end token generation and usage
- MCP server authentication with personal token
- Rate limiting behavior

### Testing Framework
- Jest for unit and integration tests
- fast-check for property-based testing
- Minimum 100 iterations per property test

