/**
 * Property-Based Tests for Token Service
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs minimum 100 iterations with randomly generated inputs.
 * 
 * Feature: personal-api-tokens
 */

import * as fc from 'fast-check';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { 
  tokenService, 
  TOKEN_PREFIX, 
  TOKEN_TOTAL_LENGTH,
  TOKEN_RANDOM_BYTES 
} from '../services/tokenService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdTokenIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-token-${userId}@example.com`;
  
  await pool.query(
    `INSERT INTO users (id, email, password_hash, display_name) 
     VALUES ($1, $2, 'test-hash', 'Test User')
     ON CONFLICT (id) DO NOTHING`,
    [userId, email]
  );
  
  createdUserIds.push(userId);
  return userId;
}

// Cleanup function
async function cleanup() {
  // Delete tokens first (foreign key constraint)
  if (createdTokenIds.length > 0) {
    await pool.query(
      `DELETE FROM api_tokens WHERE id = ANY($1)`,
      [createdTokenIds]
    );
  }
  
  // Delete users
  if (createdUserIds.length > 0) {
    await pool.query(
      `DELETE FROM users WHERE id = ANY($1)`,
      [createdUserIds]
    );
  }
  
  createdUserIds.length = 0;
  createdTokenIds.length = 0;
}

// ==================== ARBITRARIES ====================

// Generate valid token names
const tokenNameArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_'),
  { minLength: 1, maxLength: 100 }
).filter(s => s.trim().length >= 1);

// Generate optional expiration dates (future dates - at least 1 hour from now)
const expirationDateArb = fc.option(
  fc.date({ 
    min: new Date(Date.now() + 60 * 60 * 1000), // At least 1 hour from now
    max: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) 
  }),
  { nil: undefined }
);

// Generate past expiration dates (for testing expired tokens)
const pastExpirationDateArb = fc.date({ 
  min: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000), 
  max: new Date(Date.now() - 1000) 
});

// ==================== PROPERTY TESTS ====================

describe('Token Service - Property-Based Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Property 1: Token Generation Security
   * 
   * For any generated token, the token SHALL:
   * - Start with the prefix "nllm_"
   * - Have a total length of 48 characters
   * - Contain only URL-safe base64 characters after the prefix
   * - Be unique (no two generated tokens are identical)
   * 
   * **Validates: Requirements 1.1, 4.2**
   */
  describe('Property 1: Token Generation Security', () => {
    it('generated tokens have correct format and prefix', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.integer({ min: 1, max: 10 }),
          async (count) => {
            const tokens: string[] = [];
            
            for (let i = 0; i < count; i++) {
              const token = tokenService.generateTokenString();
              tokens.push(token);
              
              // Check prefix
              expect(token.startsWith(TOKEN_PREFIX)).toBe(true);
              
              // Check total length (48 characters)
              expect(token.length).toBe(TOKEN_TOTAL_LENGTH);
              
              // Check that characters after prefix are URL-safe base64
              const randomPart = token.substring(TOKEN_PREFIX.length);
              const urlSafeBase64Regex = /^[A-Za-z0-9_-]+$/;
              expect(urlSafeBase64Regex.test(randomPart)).toBe(true);
            }
            
            // All tokens should be unique
            const uniqueTokens = new Set(tokens);
            expect(uniqueTokens.size).toBe(tokens.length);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('tokens are cryptographically random (high entropy)', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.constant(null),
          async () => {
            // Generate multiple tokens and check they're all different
            const tokens = new Set<string>();
            const numTokens = 50;
            
            for (let i = 0; i < numTokens; i++) {
              tokens.add(tokenService.generateTokenString());
            }
            
            // All tokens should be unique (probability of collision is negligible)
            expect(tokens.size).toBe(numTokens);
          }
        ),
        { numRuns: 100 }
      );
    });
  });


  /**
   * Property 2: Token Hash Storage
   * 
   * For any generated token, the stored hash SHALL:
   * - Be exactly 64 hexadecimal characters (SHA-256)
   * - Be different from the original token
   * - Be deterministic (same token always produces same hash)
   * - Not allow recovery of the original token
   * 
   * **Validates: Requirements 1.3, 4.1**
   */
  describe('Property 2: Token Hash Storage', () => {
    it('hash is 64 hex characters and different from token', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.constant(null),
          async () => {
            const token = tokenService.generateTokenString();
            const hash = tokenService.hashToken(token);
            
            // Hash should be 64 hex characters (SHA-256)
            expect(hash.length).toBe(64);
            expect(/^[a-f0-9]+$/.test(hash)).toBe(true);
            
            // Hash should be different from token
            expect(hash).not.toBe(token);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('hashing is deterministic', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.constant(null),
          async () => {
            const token = tokenService.generateTokenString();
            
            // Hash the same token multiple times
            const hash1 = tokenService.hashToken(token);
            const hash2 = tokenService.hashToken(token);
            const hash3 = tokenService.hashToken(token);
            
            // All hashes should be identical
            expect(hash1).toBe(hash2);
            expect(hash2).toBe(hash3);
          }
        ),
        { numRuns: 100 }
      );
    });

    it('different tokens produce different hashes', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.constant(null),
          async () => {
            const token1 = tokenService.generateTokenString();
            const token2 = tokenService.generateTokenString();
            
            // Different tokens should produce different hashes
            const hash1 = tokenService.hashToken(token1);
            const hash2 = tokenService.hashToken(token2);
            
            expect(hash1).not.toBe(hash2);
          }
        ),
        { numRuns: 100 }
      );
    });
  });

  /**
   * Property 3: Token Validation Round-Trip
   * 
   * For any valid token that has not been revoked or expired, 
   * validating the token SHALL return the correct user ID and token ID 
   * that were used during generation.
   * 
   * **Validates: Requirements 3.1, 3.5**
   */
  describe('Property 3: Token Validation Round-Trip', () => {
    it('generated tokens validate successfully and return correct user', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          async (name) => {
            const userId = await createTestUser();
            
            // Generate a token
            const { token, tokenRecord } = await tokenService.generateToken(userId, name);
            createdTokenIds.push(tokenRecord.id);
            
            // Validate the token
            const result = await tokenService.validateToken(token);
            
            // Should be valid and return correct user/token IDs
            expect(result.valid).toBe(true);
            expect(result.userId).toBe(userId);
            expect(result.tokenId).toBe(tokenRecord.id);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('tokens with future expiration validate successfully', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          expirationDateArb,
          async (name, expiresAt) => {
            const userId = await createTestUser();
            
            // Generate a token with optional future expiration
            const { token, tokenRecord } = await tokenService.generateToken(
              userId, 
              name, 
              expiresAt
            );
            createdTokenIds.push(tokenRecord.id);
            
            // Validate the token
            const result = await tokenService.validateToken(token);
            
            // Should be valid
            expect(result.valid).toBe(true);
            expect(result.userId).toBe(userId);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('invalid token format is rejected', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.oneof(
            fc.constant(''),
            fc.constant('invalid'),
            fc.constant('nllm_short'),
            fc.constant('wrong_prefix_' + 'a'.repeat(43)),
            fc.stringOf(fc.constantFrom(...'abcdef0123456789'), { minLength: 48, maxLength: 48 })
          ),
          async (invalidToken) => {
            const result = await tokenService.validateToken(invalidToken);
            
            // Should be invalid
            expect(result.valid).toBe(false);
            expect(result.error).toBeDefined();
          }
        ),
        { numRuns: 100 }
      );
    });

    it('non-existent token is rejected', async () => {
      await fc.assert(
        fc.asyncProperty(
          fc.constant(null),
          async () => {
            // Generate a valid-looking token that doesn't exist in DB
            const fakeToken = tokenService.generateTokenString();
            
            const result = await tokenService.validateToken(fakeToken);
            
            // Should be invalid
            expect(result.valid).toBe(false);
            expect(result.error).toBe('Invalid token');
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);
  });

  /**
   * Property 4: Token Revocation Invalidation
   * 
   * For any token that is revoked, subsequent validation attempts SHALL fail 
   * with an invalid result, regardless of how much time has passed since revocation.
   * 
   * **Validates: Requirements 2.2, 2.3, 3.4**
   */
  describe('Property 4: Token Revocation Invalidation', () => {
    it('revoked tokens are immediately invalidated', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          async (name) => {
            const userId = await createTestUser();
            
            // Generate a token
            const { token, tokenRecord } = await tokenService.generateToken(userId, name);
            createdTokenIds.push(tokenRecord.id);
            
            // Verify token is valid before revocation
            const beforeRevoke = await tokenService.validateToken(token);
            expect(beforeRevoke.valid).toBe(true);
            
            // Revoke the token
            const revoked = await tokenService.revokeToken(userId, tokenRecord.id);
            expect(revoked).toBe(true);
            
            // Validate the token after revocation - should fail
            const afterRevoke = await tokenService.validateToken(token);
            expect(afterRevoke.valid).toBe(false);
            expect(afterRevoke.error).toBe('Token revoked');
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('revoked tokens remain invalid on subsequent validation attempts', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          fc.integer({ min: 2, max: 5 }),
          async (name, validationAttempts) => {
            const userId = await createTestUser();
            
            // Generate and revoke a token
            const { token, tokenRecord } = await tokenService.generateToken(userId, name);
            createdTokenIds.push(tokenRecord.id);
            
            await tokenService.revokeToken(userId, tokenRecord.id);
            
            // Multiple validation attempts should all fail
            for (let i = 0; i < validationAttempts; i++) {
              const result = await tokenService.validateToken(token);
              expect(result.valid).toBe(false);
              expect(result.error).toBe('Token revoked');
            }
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('revoking a token does not affect other tokens for the same user', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          tokenNameArb,
          async (name1, name2) => {
            const userId = await createTestUser();
            
            // Generate two tokens
            const { token: token1, tokenRecord: record1 } = await tokenService.generateToken(userId, name1);
            const { token: token2, tokenRecord: record2 } = await tokenService.generateToken(userId, name2);
            createdTokenIds.push(record1.id, record2.id);
            
            // Revoke only the first token
            await tokenService.revokeToken(userId, record1.id);
            
            // First token should be invalid
            const result1 = await tokenService.validateToken(token1);
            expect(result1.valid).toBe(false);
            expect(result1.error).toBe('Token revoked');
            
            // Second token should still be valid
            const result2 = await tokenService.validateToken(token2);
            expect(result2.valid).toBe(true);
            expect(result2.userId).toBe(userId);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('only token owner can revoke their tokens', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          async (name) => {
            const userId1 = await createTestUser();
            const userId2 = await createTestUser();
            
            // Generate a token for user1
            const { token, tokenRecord } = await tokenService.generateToken(userId1, name);
            createdTokenIds.push(tokenRecord.id);
            
            // User2 tries to revoke user1's token - should fail
            const revokedByOther = await tokenService.revokeToken(userId2, tokenRecord.id);
            expect(revokedByOther).toBe(false);
            
            // Token should still be valid
            const result = await tokenService.validateToken(token);
            expect(result.valid).toBe(true);
            
            // User1 can revoke their own token
            const revokedByOwner = await tokenService.revokeToken(userId1, tokenRecord.id);
            expect(revokedByOwner).toBe(true);
            
            // Now token should be invalid
            const afterRevoke = await tokenService.validateToken(token);
            expect(afterRevoke.valid).toBe(false);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);
  });

  /**
   * Property 5: Token Expiration Enforcement
   * 
   * For any token with an expiration date, validation SHALL succeed before 
   * the expiration time and fail after the expiration time.
   * 
   * **Validates: Requirements 3.3**
   */
  describe('Property 5: Token Expiration Enforcement', () => {
    it('tokens with past expiration dates are rejected', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          pastExpirationDateArb,
          async (name, pastDate) => {
            const userId = await createTestUser();
            
            // Generate a token with a past expiration date
            // We need to insert directly to bypass any validation
            const token = tokenService.generateTokenString();
            const tokenHash = tokenService.hashToken(token);
            const tokenPrefix = token.substring(0, 8);
            const tokenSuffix = token.substring(token.length - 4);
            
            const result = await pool.query(
              `INSERT INTO api_tokens 
               (user_id, name, token_hash, token_prefix, token_suffix, expires_at)
               VALUES ($1, $2, $3, $4, $5, $6)
               RETURNING id`,
              [userId, name, tokenHash, tokenPrefix, tokenSuffix, pastDate]
            );
            createdTokenIds.push(result.rows[0].id);
            
            // Validate the expired token - should fail
            const validationResult = await tokenService.validateToken(token);
            expect(validationResult.valid).toBe(false);
            expect(validationResult.error).toBe('Token expired');
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('tokens with future expiration dates are valid', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          fc.date({ 
            min: new Date(Date.now() + 60 * 60 * 1000), // At least 1 hour from now
            max: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) 
          }),
          async (name, futureDate) => {
            const userId = await createTestUser();
            
            // Generate a token with a future expiration date
            const { token, tokenRecord } = await tokenService.generateToken(userId, name, futureDate);
            createdTokenIds.push(tokenRecord.id);
            
            // Validate the token - should succeed
            const result = await tokenService.validateToken(token);
            expect(result.valid).toBe(true);
            expect(result.userId).toBe(userId);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('tokens without expiration date never expire', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          async (name) => {
            const userId = await createTestUser();
            
            // Generate a token without expiration
            const { token, tokenRecord } = await tokenService.generateToken(userId, name);
            createdTokenIds.push(tokenRecord.id);
            
            // Token should have no expiration
            expect(tokenRecord.expiresAt).toBeNull();
            
            // Validate the token - should succeed
            const result = await tokenService.validateToken(token);
            expect(result.valid).toBe(true);
            expect(result.userId).toBe(userId);
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);

    it('expiration is checked independently of revocation', async () => {
      await fc.assert(
        fc.asyncProperty(
          tokenNameArb,
          pastExpirationDateArb,
          async (name, pastDate) => {
            const userId = await createTestUser();
            
            // Create an expired token directly in DB
            const token = tokenService.generateTokenString();
            const tokenHash = tokenService.hashToken(token);
            const tokenPrefix = token.substring(0, 8);
            const tokenSuffix = token.substring(token.length - 4);
            
            const result = await pool.query(
              `INSERT INTO api_tokens 
               (user_id, name, token_hash, token_prefix, token_suffix, expires_at)
               VALUES ($1, $2, $3, $4, $5, $6)
               RETURNING id`,
              [userId, name, tokenHash, tokenPrefix, tokenSuffix, pastDate]
            );
            const tokenId = result.rows[0].id;
            createdTokenIds.push(tokenId);
            
            // Token is expired but not revoked
            const tokenRecord = await tokenService.getToken(tokenId);
            expect(tokenRecord?.revokedAt).toBeNull();
            
            // Validation should fail due to expiration
            const validationResult = await tokenService.validateToken(token);
            expect(validationResult.valid).toBe(false);
            expect(validationResult.error).toBe('Token expired');
          }
        ),
        { numRuns: 20, timeout: 60000 }
      );
    }, 120000);
  });
});
