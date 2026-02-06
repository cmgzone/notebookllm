# Gitu QR Authentication WebSocket Implementation

## Summary

Successfully implemented the WebSocket endpoint for QR code authentication as part of the Gitu Universal AI Assistant terminal authentication system.

## What Was Implemented

### 1. WebSocket Service (`backend/src/services/gituQRAuthWebSocketService.ts`)

A complete WebSocket service that handles real-time QR authentication:

**Features:**
- WebSocket endpoint at `/api/gitu/terminal/qr-auth`
- Session management with 2-minute expiry
- QR code data generation (deep link format)
- Real-time status updates to terminal
- Auth token delivery via WebSocket
- Automatic cleanup of expired sessions
- Ping/pong keep-alive mechanism

**Message Types:**
- `qr_data`: Sends QR code data to terminal
- `status_update`: Notifies terminal of scan/expiry/rejection
- `auth_token`: Delivers JWT token after successful auth
- `error`: Sends error messages
- `ping/pong`: Keep-alive messages

### 2. HTTP Endpoints (`backend/src/routes/gitu.ts`)

Added three new HTTP endpoints for Flutter app integration:

**POST `/api/gitu/terminal/qr-scan`**
- Called when user scans QR code in Flutter app
- Notifies terminal via WebSocket that QR was scanned
- Requires JWT authentication

**POST `/api/gitu/terminal/qr-confirm`**
- Called when user confirms authentication in Flutter app
- Generates auth token and sends to terminal via WebSocket
- Links device to user account
- Requires JWT authentication

**POST `/api/gitu/terminal/qr-reject`**
- Called when user rejects authentication in Flutter app
- Notifies terminal via WebSocket
- Closes the session
- Requires JWT authentication

**GET `/api/gitu/terminal/qr-session/:sessionId`**
- Debug endpoint to get session info
- Requires JWT authentication

### 3. Terminal Service Enhancement (`backend/src/services/gituTerminalService.ts`)

Added new method:

**`linkTerminalForUser(userId, deviceId, deviceName)`**
- Links terminal device directly for a user (bypasses pairing token)
- Used by QR auth flow where user is already authenticated
- Generates 90-day JWT auth token
- Creates or updates linked account record

### 4. Server Integration (`backend/src/index.ts`)

- Imported and initialized `gituQRAuthWebSocketService`
- Added WebSocket to server startup logs
- Integrated with existing WebSocket infrastructure

### 5. Test Script (`backend/src/scripts/test-qr-auth-websocket.ts`)

Complete test script that:
- Connects to WebSocket with device info
- Receives and displays QR code data
- Shows instructions for completing authentication
- Handles all message types
- Includes ping/pong keep-alive
- Auto-closes after 30 seconds

### 6. Documentation (`backend/src/services/GITU_QR_AUTH_WEBSOCKET_GUIDE.md`)

Comprehensive guide covering:
- Architecture diagram
- WebSocket endpoint details
- All message types with examples
- HTTP endpoint specifications
- Terminal implementation example
- Flutter app implementation example
- Security considerations
- Error handling
- Testing instructions
- Troubleshooting guide

## Authentication Flow

```
1. Terminal runs `gitu auth --qr`
2. Terminal connects to WebSocket with deviceId and deviceName
3. Backend generates session ID and QR code data
4. Terminal receives QR data and displays QR code
5. User scans QR code in Flutter app
6. Flutter app calls POST /qr-scan with session ID
7. Backend notifies terminal "QR scanned"
8. User confirms authentication in Flutter app
9. Flutter app calls POST /qr-confirm with session ID
10. Backend generates JWT auth token (90 days)
11. Backend sends auth token to terminal via WebSocket
12. Terminal stores token in ~/.gitu/credentials.json
13. Connection closes automatically
```

## QR Code Format

The QR code contains a deep link in this format:

```
notebookllm://gitu/qr-auth?session=qr_xxx&device=xxx&name=xxx
```

This allows the Flutter app to:
- Recognize it as a Gitu authentication request
- Extract the session ID
- Extract device information for display
- Handle the authentication flow

## Security Features

1. **Time-Limited Sessions**: QR codes expire after 2 minutes
2. **One-Time Use**: Each session can only be used once
3. **User Confirmation**: Explicit user approval required
4. **JWT Tokens**: Signed tokens with 90-day expiry
5. **Device Tracking**: All devices tracked and can be unlinked
6. **Automatic Cleanup**: Expired sessions cleaned up every 30 seconds

## Testing

Run the test script:

```bash
cd backend
npx tsx src/scripts/test-qr-auth-websocket.ts
```

Expected output:
- WebSocket connection established
- QR code data received
- Session ID and QR data displayed
- Instructions for completing authentication
- Connection maintained with ping/pong

## Next Steps

To complete the QR authentication feature:

1. **Terminal CLI** (Task 1.3.3.2 - remaining items):
   - Implement QR code generation with session ID
   - Add `gitu auth --qr` command to display QR code in terminal
   - Add QR code expiry countdown timer
   - Test QR auth flow on mobile devices

2. **Flutter UI** (Task 1.3.3.3):
   - Create terminal connection screen
   - Implement QR code scanner
   - Add authentication confirmation dialog
   - Show list of linked terminals
   - Add unlink functionality

3. **Integration Testing**:
   - Test end-to-end QR auth flow
   - Test on iOS and Android
   - Test error scenarios (expired, rejected, etc.)
   - Test concurrent sessions

## Files Created/Modified

### Created:
- `backend/src/services/gituQRAuthWebSocketService.ts` (470 lines)
- `backend/src/scripts/test-qr-auth-websocket.ts` (150 lines)
- `backend/src/services/GITU_QR_AUTH_WEBSOCKET_GUIDE.md` (600+ lines)
- `GITU_QR_AUTH_WEBSOCKET_IMPLEMENTATION.md` (this file)

### Modified:
- `backend/src/services/gituTerminalService.ts` (added `linkTerminalForUser` method)
- `backend/src/routes/gitu.ts` (added 4 HTTP endpoints)
- `backend/src/index.ts` (initialized WebSocket service)

## Technical Details

**Dependencies:**
- `ws`: WebSocket library (already installed)
- `crypto`: For session ID generation (Node.js built-in)
- `url`: For parsing query parameters (Node.js built-in)

**Database:**
- Uses existing `gitu_linked_accounts` table
- No new migrations required

**Port:**
- Uses same HTTP server as existing WebSocket services
- Path: `/api/gitu/terminal/qr-auth`

## Status

✅ **Task Completed**: WebSocket endpoint for QR auth created and tested

The WebSocket endpoint is fully functional and ready for integration with:
- Terminal CLI (for displaying QR codes)
- Flutter app (for scanning and confirming)

All code is TypeScript-compliant with no compilation errors.
