# QR Code Authentication Implementation

## Overview

The QR code authentication feature allows users to authenticate their terminal with the Gitu service by scanning a QR code in the NotebookLLM Flutter app. This provides a more user-friendly alternative to manually entering pairing tokens.

## Implementation Status

✅ **COMPLETE** - QR code generation with session ID implemented

## Architecture

### Flow Diagram

```
┌─────────────┐                    ┌──────────────┐                    ┌─────────────┐
│  Terminal   │                    │   Backend    │                    │ Flutter App │
│   (CLI)     │                    │  WebSocket   │                    │             │
└──────┬──────┘                    └──────┬───────┘                    └──────┬──────┘
       │                                  │                                   │
       │ 1. gitu auth --qr                │                                   │
       ├─────────────────────────────────>│                                   │
       │                                  │                                   │
       │ 2. WebSocket Connect             │                                   │
       │    (deviceId, deviceName)        │                                   │
       ├─────────────────────────────────>│                                   │
       │                                  │                                   │
       │ 3. QR Data Message               │                                   │
       │    (sessionId, qrData)           │                                   │
       │<─────────────────────────────────┤                                   │
       │                                  │                                   │
       │ 4. Display QR Code               │                                   │
       │    (in terminal)                 │                                   │
       │                                  │                                   │
       │                                  │ 5. Scan QR Code                   │
       │                                  │<──────────────────────────────────┤
       │                                  │                                   │
       │ 6. Status Update (scanned)       │                                   │
       │<─────────────────────────────────┤                                   │
       │                                  │                                   │
       │                                  │ 7. Confirm Auth (HTTP)            │
       │                                  │<──────────────────────────────────┤
       │                                  │                                   │
       │ 8. Auth Token Message            │                                   │
       │    (authToken, userId)           │                                   │
       │<─────────────────────────────────┤                                   │
       │                                  │                                   │
       │ 9. Save Credentials              │                                   │
       │    (local storage)               │                                   │
       │                                  │                                   │
       │ 10. Close Connection             │                                   │
       │<─────────────────────────────────┤                                   │
       │                                  │                                   │
```

## Components

### 1. Terminal Adapter (`terminalAdapter.ts`)

**New Command:** `gitu auth --qr`

**Implementation:**
- Connects to WebSocket endpoint at `/api/gitu/terminal/qr-auth`
- Receives QR data from backend
- Displays QR code in terminal using `qrcode-terminal` library
- Waits for authentication confirmation
- Saves credentials locally

**Key Features:**
- Real-time status updates (scanned, authenticated, expired, rejected)
- Automatic timeout after 3 minutes
- Heartbeat pings to keep connection alive
- Graceful error handling

### 2. QR Auth WebSocket Service (`gituQRAuthWebSocketService.ts`)

**Responsibilities:**
- Manages WebSocket connections from terminals
- Generates unique session IDs
- Creates QR code data (deep link URL)
- Handles authentication flow
- Sends auth tokens to terminals

**Session Management:**
- 2-minute expiry for QR codes
- Automatic cleanup of expired sessions
- Status tracking (pending, scanned, authenticated, expired, rejected)

### 3. QR Code Data Format

**URL Scheme:**
```
notebookllm://gitu/qr-auth?session={sessionId}&device={deviceId}&name={deviceName}
```

**Parameters:**
- `session`: Unique session ID (e.g., `qr_1769632815651_y5t3d`)
- `device`: Device ID (persistent identifier)
- `name`: Human-readable device name (e.g., `MacBook Pro (darwin)`)

## WebSocket Messages

### 1. QR Data Message (Backend → Terminal)

```json
{
  "type": "qr_data",
  "payload": {
    "sessionId": "qr_1769632815651_y5t3d",
    "qrData": "notebookllm://gitu/qr-auth?session=...",
    "expiresAt": "2026-01-28T20:42:15.885Z",
    "expiresInSeconds": 120,
    "message": "Scan this QR code in the NotebookLLM app to authenticate"
  }
}
```

### 2. Status Update Message (Backend → Terminal)

```json
{
  "type": "status_update",
  "payload": {
    "status": "scanned",
    "message": "QR code scanned, authenticating..."
  }
}
```

**Possible statuses:**
- `scanned`: User scanned the QR code
- `expired`: QR code expired (2 minutes)
- `rejected`: User rejected authentication

### 3. Auth Token Message (Backend → Terminal)

```json
{
  "type": "auth_token",
  "payload": {
    "authToken": "jwt-token-here",
    "userId": "user-123",
    "expiresAt": "2026-04-28T20:40:16.022Z",
    "expiresInDays": 90,
    "message": "Authentication successful! You can now use Gitu."
  }
}
```

### 4. Error Message (Backend → Terminal)

```json
{
  "type": "error",
  "payload": {
    "error": "Session expired"
  }
}
```

### 5. Ping/Pong (Heartbeat)

```json
{
  "type": "ping"
}
```

```json
{
  "type": "pong"
}
```

## Usage

### Terminal User

```bash
# Authenticate using QR code
gitu auth --qr

# Alternative syntax
gitu auth -qr
gitu auth qr
```

**Output:**
```
🔐 QR Code Authentication

Connecting to authentication service...
✓ Connected to authentication service

📱 Scan this QR code in the NotebookLLM app:

[QR CODE DISPLAYED HERE]

Session ID: qr_1769632815651_y5t3d
Expires in: 120 seconds

⏳ Waiting for you to scan the QR code...

✓ QR code scanned!
Authenticating...

✅ Authentication successful!
User ID: user-123
Device: MacBook Pro (darwin)
Token expires: Apr 28, 2026, 8:40:16 PM
Valid for: 90 days
```

### Flutter App User

1. Open NotebookLLM app
2. Navigate to Gitu settings
3. Tap "Link Terminal"
4. Tap "Scan QR Code"
5. Scan the QR code displayed in terminal
6. Confirm authentication

## Security Features

### 1. Session Expiry
- QR codes expire after 2 minutes
- Prevents replay attacks
- Automatic cleanup of expired sessions

### 2. One-Time Use
- Each QR code can only be used once
- Session is deleted after authentication

### 3. Device Binding
- Auth token is bound to specific device ID
- Device ID is persistent and unique per terminal

### 4. Secure Token Storage
- Credentials stored in `~/.gitu/credentials.json`
- File permissions restricted to user only
- JWT tokens with 90-day expiry

### 5. WebSocket Security
- Connection requires valid device info
- Session validation on all operations
- Automatic disconnection on errors

## Error Handling

### Connection Errors
```
❌ WebSocket error: Connection refused
Make sure the backend server is running.
```

### Expired QR Code
```
❌ QR code expired
Please try again with gitu auth --qr
```

### Rejected Authentication
```
❌ Authentication rejected
Authentication rejected by user
```

### Timeout
```
⏱️  Authentication timeout
Please try again.
```

## Testing

### Test Script
```bash
cd backend
npx tsx src/scripts/test-qr-auth-command.ts
```

**Tests:**
1. QR code generation
2. URL parsing
3. WebSocket message format
4. Auth token message format

### Manual Testing

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Run Terminal Adapter:**
   ```bash
   npx tsx src/scripts/test-terminal-adapter.ts
   ```

3. **Execute QR Auth Command:**
   ```
   gitu auth --qr
   ```

4. **Scan QR Code:**
   - Use a QR code scanner app
   - Or implement Flutter app scanning

## Configuration

### Environment Variables

```bash
# Backend URL for WebSocket connection
BACKEND_URL=http://localhost:3000

# Or for production
BACKEND_URL=https://api.notebookllm.com
```

### WebSocket URL Construction

```typescript
const wsProtocol = process.env.NODE_ENV === 'production' ? 'wss' : 'ws';
const wsHost = process.env.BACKEND_URL?.replace(/^https?:\/\//, '') || 'localhost:3000';
const wsUrl = `${wsProtocol}://${wsHost}/api/gitu/terminal/qr-auth`;
```

## Next Steps

### Remaining Tasks (from Task 1.3.3.2)

- [ ] Add `gitu auth --qr` command to display QR code in terminal ✅ **DONE**
- [ ] Create Flutter UI for QR code scanning
- [ ] Implement QR code scanning in Flutter app (using `qr_code_scanner`)
- [ ] Add WebSocket connection for real-time auth confirmation
- [ ] Send auth token to terminal via WebSocket after scan
- [ ] Add QR code expiry (2 minutes) ✅ **DONE**
- [ ] Test QR auth flow on mobile devices
- [ ] Add fallback to token-based auth if QR fails

### Flutter Implementation

**Required Package:**
```yaml
dependencies:
  qr_code_scanner: ^1.0.1
```

**Deep Link Handling:**
```dart
// Handle notebookllm://gitu/qr-auth URLs
void handleQRAuthDeepLink(Uri uri) {
  final sessionId = uri.queryParameters['session'];
  final deviceId = uri.queryParameters['device'];
  final deviceName = uri.queryParameters['name'];
  
  // Show confirmation dialog
  // Call backend API to complete authentication
}
```

## Files Modified

1. `backend/src/adapters/terminalAdapter.ts`
   - Added `handleAuthQR()` method
   - Updated `handleAuthCommand()` to support `--qr` flag
   - Added WebSocket connection logic
   - Added QR code display using `qrcode-terminal`

## Files Created

1. `backend/src/scripts/test-qr-auth-command.ts`
   - Test script for QR code generation
   - Validates message formats
   - Demonstrates QR code display

2. `backend/src/adapters/QR_AUTH_IMPLEMENTATION.md`
   - This documentation file

## Dependencies

- `ws`: WebSocket client
- `qrcode-terminal`: QR code generation for terminal
- `chalk`: Terminal colors
- `crypto`: Session ID generation

## References

- Task: 1.3.3.2 (QR Code Authentication)
- Design: Section 1.3 (Message Gateway)
- Requirements: US-1.1 (Multi-Platform Access)
- Related: `gituQRAuthWebSocketService.ts`
- Related: `gituTerminalService.ts`

## Conclusion

The QR code authentication feature is now fully implemented on the terminal side. Users can run `gitu auth --qr` to display a QR code in their terminal, which can be scanned in the NotebookLLM Flutter app to complete authentication. The implementation includes proper error handling, security features, and a user-friendly experience.

The next step is to implement the Flutter app side of the QR code scanning and authentication confirmation flow.
