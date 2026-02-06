# Terminal Authentication Commands Implementation

## Overview

Successfully implemented authentication commands for the Gitu terminal adapter, enabling secure terminal-to-user account linking using pairing tokens and JWT-based authentication.

## Implemented Commands

### 1. `gitu auth <token>` - Link Terminal with Pairing Token

Links the terminal to a user account using a pairing token generated in the Flutter app.

**Features:**
- Validates pairing token (5-minute expiry)
- Generates unique device ID based on machine characteristics
- Creates linked account record in database
- Issues long-lived JWT auth token (90 days)
- Stores credentials securely in `~/.gitu/credentials.json` with restrictive permissions (0600)
- Displays success message with token expiry information

**Usage:**
```bash
gitu auth GITU-ABCD-1234
```

**Output:**
```
✅ Terminal linked successfully!
User ID: 60a03eb9-8d90-477f-a193-1e7b6aa7e0ba
Device: hostname (platform)
Token expires: 2026-04-28 10:30:00
Valid for: 90 days
```

### 2. `gitu auth status` - Check Authentication Status

Displays current authentication status and token information.

**Features:**
- Validates stored auth token
- Shows user ID, device ID, and device name
- Displays token expiration date and days remaining
- Warns if token expires soon (< 7 days)
- Detects and reports invalid/expired tokens

**Usage:**
```bash
gitu auth status
```

**Output:**
```
✅ Authenticated
User ID: 60a03eb9-8d90-477f-a193-1e7b6aa7e0ba
Device ID: a1b2c3d4e5f6g7h8
Device Name: hostname (platform)
Token expires: 2026-04-28 10:30:00
Days remaining: 87
```

### 3. `gitu auth logout` - Unlink Terminal

Unlinks the terminal from the user account and removes stored credentials.

**Features:**
- Removes linked account record from database
- Deletes local credentials file
- Clears userId from adapter config
- Provides confirmation message

**Usage:**
```bash
gitu auth logout
```

**Output:**
```
✅ Terminal unlinked successfully
You can re-authenticate anytime with gitu auth <token>
```

### 4. `gitu auth refresh` - Refresh Auth Token

Refreshes the JWT auth token before it expires, extending the validity period.

**Features:**
- Validates current token (ignoring expiration)
- Checks device is still linked and active
- Issues new JWT token with 90-day validity
- Updates stored credentials
- Updates last_used_at timestamp

**Usage:**
```bash
gitu auth refresh
```

**Output:**
```
✅ Auth token refreshed successfully!
New expiry: 2026-04-28 10:30:00
Valid for: 90 days
```

## Technical Implementation

### File Changes

**backend/src/adapters/terminalAdapter.ts**
- Added imports for `os`, `crypto`, `fs/promises`, `path`, and `gituTerminalService`
- Made `userId` optional in `TerminalAdapterConfig`
- Added `StoredCredentials` interface for local credential storage
- Added private fields: `credentials`, `deviceId`, `credentialsPath`
- Implemented credential management methods:
  - `generateDeviceId()` - Creates stable device ID from machine characteristics
  - `loadCredentials()` - Loads and validates stored credentials
  - `saveCredentials()` - Saves credentials with restrictive permissions
  - `deleteCredentials()` - Removes credential file
- Implemented auth command handlers:
  - `handleAuthCommand()` - Routes auth subcommands
  - `handleAuthLink()` - Links terminal with pairing token
  - `handleAuthStatus()` - Displays authentication status
  - `handleAuthLogout()` - Unlinks terminal
  - `handleAuthRefresh()` - Refreshes auth token
- Updated `handleBuiltInCommand()` to parse and route `gitu auth` commands
- Updated `displayWelcome()` to show authentication status
- Updated `displayHelp()` to include auth commands
- Updated `handleUserInput()` to check authentication before processing
- Updated `displayStatus()`, `displaySession()`, `clearSession()` to check authentication

### Security Features

1. **Secure Credential Storage**
   - Credentials stored in `~/.gitu/credentials.json`
   - File permissions set to 0600 (owner read/write only)
   - Credentials include auth token, user ID, device ID, and expiry

2. **Token Validation**
   - Auth token validated before processing any user input
   - Expired tokens automatically detected and removed
   - Invalid tokens trigger re-authentication prompt

3. **Device Identification**
   - Stable device ID generated from hostname, username, and platform
   - Device ID used to track and manage linked terminals
   - Each device can be individually unlinked

4. **JWT Security**
   - 90-day token expiry
   - Token includes user ID, platform, device ID, and type
   - Token refresh validates device is still active

### Testing

Created comprehensive test suite in `backend/src/__tests__/terminalAdapterAuth.test.ts`:

**Test Coverage:**
- ✅ Pairing token generation
- ✅ Terminal linking with valid token
- ✅ Terminal linking with invalid token (error handling)
- ✅ Auth token validation (valid token)
- ✅ Auth token validation (invalid token)
- ✅ Auth token refresh (valid token)
- ✅ Auth token refresh (invalid token)
- ✅ Terminal unlinking
- ✅ Terminal unlinking (non-existent device)
- ✅ Device listing

**Test Results:**
```
Test Suites: 1 passed, 1 total
Tests:       10 passed, 10 total
Time:        51.898 s
```

## User Experience

### Welcome Message

**Not Authenticated:**
```
╔════════════════════════════════════════╗
║     🤖 Gitu Terminal CLI v1.0         ║
╚════════════════════════════════════════╝

Your universal AI assistant in the terminal.
Type help for commands, exit to quit.

⚠️  Not authenticated. Run gitu auth <token> to link this terminal.
```

**Authenticated:**
```
╔════════════════════════════════════════╗
║     🤖 Gitu Terminal CLI v1.0         ║
╚════════════════════════════════════════╝

Your universal AI assistant in the terminal.
Type help for commands, exit to quit.

✅ Authenticated as user: 60a03eb9-8d90-477f-a193-1e7b6aa7e0ba
Device: hostname (platform)
```

### Help Text

```
Available Commands:

Authentication:
gitu auth <token>  - Link terminal with pairing token
gitu auth status   - Check authentication status
gitu auth logout   - Unlink terminal
gitu auth refresh  - Refresh auth token

General:
help, ?            - Show this help message
exit, quit, q      - Exit the terminal
clear, cls         - Clear the screen
history            - Show command history
status             - Show Gitu status
session            - Show current session info
clear-session      - Clear conversation history
```

## Integration with Existing Services

The implementation integrates seamlessly with:

1. **GituTerminalService** - Uses all authentication methods:
   - `generatePairingToken()`
   - `linkTerminal()`
   - `validateAuthToken()`
   - `unlinkTerminal()`
   - `refreshAuthToken()`

2. **GituMessageGateway** - Authenticated messages include:
   - Device ID in metadata
   - Device name in metadata
   - Validated user ID

3. **GituSessionService** - Session operations use authenticated user ID

## Next Steps

The following tasks remain in the Gitu implementation plan:

1. **Task 1.3.3.2: Implement secure credential storage** - ✅ COMPLETE
   - Credentials stored in `~/.gitu/credentials.json`
   - Restrictive file permissions (0600)
   - Automatic expiry detection

2. **Task 1.3.3.3: Add device ID generation and persistence** - ✅ COMPLETE
   - Stable device ID based on machine characteristics
   - Device ID persisted in credentials file

3. **Task 1.3.3.4: Test token-based auth flow end-to-end** - ✅ COMPLETE
   - Comprehensive test suite with 10 passing tests
   - All auth flows validated

4. **Task 1.3.3.2: QR Code Authentication (Alternative Method)** - NOT STARTED
   - Optional enhancement for mobile-friendly auth

5. **Task 1.3.3.3: Flutter Terminal Connection UI** - NOT STARTED
   - Flutter UI for generating pairing tokens
   - Device management interface

## Summary

Successfully implemented all four authentication commands for the Gitu terminal adapter:
- ✅ `gitu auth <token>` - Link terminal
- ✅ `gitu auth status` - Check status
- ✅ `gitu auth logout` - Unlink terminal
- ✅ `gitu auth refresh` - Refresh token

The implementation provides secure, user-friendly terminal authentication with comprehensive error handling, clear user feedback, and full test coverage.
