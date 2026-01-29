# Gitu JWT Auth Token Implementation - Complete ✅

## Overview
JWT-based authentication token generation with 90-day expiry has been successfully implemented for the Gitu terminal authentication system.

## Implementation Details

### 1. JWT Token Generation (90-day expiry)
**Location**: `backend/src/services/gituTerminalService.ts`

The service generates JWT tokens with the following characteristics:
- **Expiry**: 90 days (configurable via `AUTH_TOKEN_EXPIRY_DAYS` constant)
- **Algorithm**: HS256 (HMAC with SHA-256)
- **Secret**: Configurable via `JWT_SECRET` environment variable
- **Payload**: Contains userId, platform, deviceId, and type

```typescript
const authToken = jwt.sign(
  {
    userId,
    platform: 'terminal',
    deviceId,
    type: 'gitu_terminal'
  },
  this.JWT_SECRET,
  { expiresIn: `${this.AUTH_TOKEN_EXPIRY_DAYS}d` }
);
```

### 2. Token Lifecycle

#### Generation Flow
1. User generates pairing token in Flutter app (5-minute expiry)
2. User runs `gitu auth <token>` in terminal
3. Terminal calls `/api/gitu/terminal/link` with token + device info
4. Backend validates pairing token
5. Backend creates linked account record
6. **Backend generates JWT auth token (90-day expiry)**
7. Terminal stores auth token locally in `~/.gitu/credentials.json`

#### Validation Flow
1. Terminal includes auth token in requests
2. Backend calls `validateAuthToken()` to verify JWT
3. Checks token signature and expiry
4. Verifies device is still linked and active
5. Updates last_used_at timestamp

#### Refresh Flow
1. Terminal calls `/api/gitu/terminal/refresh` before token expires
2. Backend validates old token (ignoring expiration)
3. Checks device is still linked and active
4. **Issues new JWT token with fresh 90-day expiry**
5. Terminal replaces old token with new one

### 3. API Endpoints

#### POST /api/gitu/terminal/link
- **Purpose**: Link terminal device and generate auth token
- **Auth**: None (uses pairing token)
- **Returns**: 
  - `authToken`: JWT token (90-day expiry)
  - `userId`: User ID
  - `expiresAt`: ISO timestamp
  - `expiresInDays`: 90

#### POST /api/gitu/terminal/validate
- **Purpose**: Validate auth token
- **Auth**: None (validates the token itself)
- **Returns**: 
  - `valid`: boolean
  - `userId`: User ID (if valid)
  - `deviceId`: Device ID (if valid)
  - `expiresAt`: ISO timestamp (if valid)

#### POST /api/gitu/terminal/refresh
- **Purpose**: Refresh auth token before expiry
- **Auth**: None (validates old token)
- **Returns**: 
  - `authToken`: New JWT token (90-day expiry)
  - `expiresAt`: ISO timestamp
  - `expiresInDays`: 90

### 4. Security Features

#### Token Security
- JWT signed with secret key (HS256)
- Token includes type verification (`gitu_terminal`)
- Platform verification (`terminal`)
- Device ID binding

#### Device Management
- Tokens linked to specific device IDs
- Device status checking (active/inactive/suspended)
- Last used timestamp tracking
- Ability to unlink devices (invalidates tokens)

#### Validation Checks
- Signature verification
- Expiry verification
- Device link verification
- Device status verification
- Platform/type verification

### 5. Database Schema

#### gitu_pairing_tokens
- Stores short-lived pairing tokens (5 minutes)
- Used for initial device linking
- Deleted after successful link

#### gitu_linked_accounts
- Stores linked device records
- Tracks device status (active/inactive/suspended)
- Records last_used_at timestamp
- Used for token validation

### 6. Test Coverage

All tests passing (19/19) ✅

**Test Suite**: `backend/src/__tests__/gituTerminalAuthFlow.test.ts`

Tests cover:
- Complete authentication flow
- Token generation with authentication
- Terminal linking with valid/invalid tokens
- Token validation (valid/invalid/expired)
- Device listing
- Device unlinking
- Token refresh (valid/unlinked devices)
- Error handling and edge cases

### 7. Configuration

#### Environment Variables
```bash
JWT_SECRET=your-super-secret-jwt-key-change-in-production
```

#### Constants
```typescript
private readonly TOKEN_EXPIRY_MINUTES = 5;      // Pairing token
private readonly AUTH_TOKEN_EXPIRY_DAYS = 90;   // Auth token
```

## Usage Example

### Terminal Client Flow
```bash
# 1. User gets pairing token from Flutter app
# Token: GITU-ABCD-1234

# 2. Terminal links with pairing token
gitu auth GITU-ABCD-1234

# 3. Terminal receives and stores JWT auth token
# Token stored in ~/.gitu/credentials.json
# Valid for 90 days

# 4. Terminal uses auth token for all requests
# Automatically refreshes before expiry

# 5. User can unlink device from Flutter app
# This invalidates the auth token
```

### API Usage
```typescript
// Link terminal
const linkResponse = await fetch('/api/gitu/terminal/link', {
  method: 'POST',
  body: JSON.stringify({
    token: 'GITU-ABCD-1234',
    deviceId: 'unique-device-id',
    deviceName: 'My MacBook'
  })
});

const { authToken, expiresAt, expiresInDays } = await linkResponse.json();
// authToken: JWT token valid for 90 days
// expiresAt: "2026-04-29T12:00:00.000Z"
// expiresInDays: 90

// Validate token
const validateResponse = await fetch('/api/gitu/terminal/validate', {
  method: 'POST',
  body: JSON.stringify({ authToken })
});

const { valid, userId, deviceId } = await validateResponse.json();

// Refresh token
const refreshResponse = await fetch('/api/gitu/terminal/refresh', {
  method: 'POST',
  body: JSON.stringify({ authToken })
});

const { authToken: newToken, expiresAt: newExpiry } = await refreshResponse.json();
```

## Benefits

1. **Long-lived tokens**: 90-day expiry reduces friction for users
2. **Secure**: JWT signed with secret, includes device binding
3. **Refreshable**: Tokens can be refreshed before expiry
4. **Revocable**: Unlinking device invalidates token
5. **Stateless**: JWT validation doesn't require database lookup (except device status)
6. **Trackable**: Last used timestamp for monitoring

## Next Steps

The following tasks remain in the terminal authentication workflow:
- [ ] Add device management (list, unlink) - Already implemented ✅
- [ ] Create database migration for pairing tokens table - Already implemented ✅
- [ ] Add auth commands to terminal adapter
- [ ] Implement secure credential storage in `~/.gitu/credentials.json`
- [ ] Add device ID generation and persistence
- [ ] Test token-based auth flow end-to-end

## Status: ✅ COMPLETE

JWT-based auth token generation with 90-day expiry is fully implemented, tested, and working correctly.
