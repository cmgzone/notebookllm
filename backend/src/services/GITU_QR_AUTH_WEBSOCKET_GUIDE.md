# Gitu QR Authentication WebSocket Guide

## Overview

The Gitu QR Authentication WebSocket provides real-time communication for terminal authentication via QR code scanning. This is an alternative to the token-based authentication method.

## Architecture

```
┌─────────────┐                    ┌─────────────┐                    ┌─────────────┐
│  Terminal   │                    │   Backend   │                    │ Flutter App │
│   Client    │                    │  WebSocket  │                    │    (User)   │
└──────┬──────┘                    └──────┬──────┘                    └──────┬──────┘
       │                                  │                                  │
       │ 1. Connect WebSocket             │                                  │
       │  (deviceId, deviceName)          │                                  │
       ├─────────────────────────────────>│                                  │
       │                                  │                                  │
       │ 2. QR Data (sessionId, qrData)   │                                  │
       │<─────────────────────────────────┤                                  │
       │                                  │                                  │
       │ [Terminal displays QR code]      │                                  │
       │                                  │                                  │
       │                                  │ 3. User scans QR code            │
       │                                  │<─────────────────────────────────┤
       │                                  │                                  │
       │                                  │ 4. POST /qr-scan (sessionId)     │
       │                                  │<─────────────────────────────────┤
       │                                  │                                  │
       │ 5. Status: "scanned"             │                                  │
       │<─────────────────────────────────┤                                  │
       │                                  │                                  │
       │                                  │ 6. User confirms auth            │
       │                                  │<─────────────────────────────────┤
       │                                  │                                  │
       │                                  │ 7. POST /qr-confirm (sessionId)  │
       │                                  │<─────────────────────────────────┤
       │                                  │                                  │
       │ 8. Auth Token (JWT, 90 days)     │                                  │
       │<─────────────────────────────────┤                                  │
       │                                  │                                  │
       │ [Terminal stores token]          │                                  │
       │                                  │                                  │
       │ 9. Connection closes             │                                  │
       │<─────────────────────────────────┤                                  │
```

## WebSocket Endpoint

**URL:** `ws://localhost:3000/api/gitu/terminal/qr-auth`

**Query Parameters:**
- `deviceId` (required): Unique device identifier
- `deviceName` (required): Human-readable device name

**Example:**
```
ws://localhost:3000/api/gitu/terminal/qr-auth?deviceId=my-macbook-123&deviceName=My%20MacBook
```

## Message Types

### 1. QR Data (Server → Terminal)

Sent immediately after connection. Contains QR code data to display.

```json
{
  "type": "qr_data",
  "payload": {
    "sessionId": "qr_1234567890_abcdef123456",
    "qrData": "notebookllm://gitu/qr-auth?session=qr_xxx&device=xxx&name=xxx",
    "expiresAt": "2026-01-28T12:35:00.000Z",
    "expiresInSeconds": 120,
    "message": "Scan this QR code in the NotebookLLM app to authenticate"
  }
}
```

**Terminal Action:** Display QR code using the `qrData` string.

### 2. Status Update (Server → Terminal)

Sent when QR code is scanned or authentication status changes.

```json
{
  "type": "status_update",
  "payload": {
    "status": "scanned",
    "message": "QR code scanned, authenticating..."
  }
}
```

**Possible Statuses:**
- `scanned`: User scanned QR code
- `expired`: QR code expired (2 minutes)
- `rejected`: User rejected authentication

### 3. Auth Token (Server → Terminal)

Sent when authentication is successful. Contains JWT token for future requests.

```json
{
  "type": "auth_token",
  "payload": {
    "authToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "userId": "user-123",
    "expiresAt": "2026-04-28T12:30:00.000Z",
    "expiresInDays": 90,
    "message": "Authentication successful! You can now use Gitu."
  }
}
```

**Terminal Action:** 
1. Store `authToken` in `~/.gitu/credentials.json`
2. Close WebSocket connection
3. Display success message

### 4. Error (Server → Terminal)

Sent when an error occurs during authentication.

```json
{
  "type": "error",
  "payload": {
    "error": "Authentication failed: Device already linked"
  }
}
```

### 5. Ping/Pong (Bidirectional)

Keep-alive messages to maintain connection.

**Terminal → Server:**
```json
{
  "type": "ping"
}
```

**Server → Terminal:**
```json
{
  "type": "pong"
}
```

## HTTP Endpoints (Flutter App)

### 1. QR Scan

**Endpoint:** `POST /api/gitu/terminal/qr-scan`

**Headers:**
- `Authorization: Bearer <jwt-token>`

**Body:**
```json
{
  "sessionId": "qr_1234567890_abcdef123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "QR code scanned successfully"
}
```

**Called when:** User scans QR code in Flutter app.

### 2. Confirm Authentication

**Endpoint:** `POST /api/gitu/terminal/qr-confirm`

**Headers:**
- `Authorization: Bearer <jwt-token>`

**Body:**
```json
{
  "sessionId": "qr_1234567890_abcdef123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Authentication completed successfully"
}
```

**Called when:** User confirms authentication in Flutter app.

### 3. Reject Authentication

**Endpoint:** `POST /api/gitu/terminal/qr-reject`

**Headers:**
- `Authorization: Bearer <jwt-token>`

**Body:**
```json
{
  "sessionId": "qr_1234567890_abcdef123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Authentication rejected"
}
```

**Called when:** User rejects authentication in Flutter app.

## Terminal Implementation Example

```typescript
import WebSocket from 'ws';
import qrcode from 'qrcode-terminal';
import fs from 'fs';
import path from 'path';

async function authenticateWithQR() {
  const deviceId = getDeviceId(); // Get or generate device ID
  const deviceName = os.hostname();
  
  const ws = new WebSocket(
    `ws://localhost:3000/api/gitu/terminal/qr-auth?deviceId=${deviceId}&deviceName=${deviceName}`
  );

  ws.on('message', (data) => {
    const message = JSON.parse(data.toString());

    switch (message.type) {
      case 'qr_data':
        console.log('\n📱 Scan this QR code in the NotebookLLM app:\n');
        qrcode.generate(message.payload.qrData, { small: true });
        console.log(`\n⏱️  QR code expires in ${message.payload.expiresInSeconds} seconds\n`);
        break;

      case 'status_update':
        console.log(`\n📊 ${message.payload.message}`);
        if (message.payload.status === 'expired') {
          console.log('❌ QR code expired. Please try again.');
          ws.close();
        }
        break;

      case 'auth_token':
        console.log('\n✅ Authentication successful!');
        saveAuthToken(message.payload.authToken);
        ws.close();
        break;

      case 'error':
        console.error(`\n❌ Error: ${message.payload.error}`);
        ws.close();
        break;
    }
  });

  ws.on('close', () => {
    console.log('\n🔌 Connection closed');
  });
}

function saveAuthToken(token: string) {
  const credentialsPath = path.join(os.homedir(), '.gitu', 'credentials.json');
  const credentials = {
    authToken: token,
    savedAt: new Date().toISOString()
  };
  fs.writeFileSync(credentialsPath, JSON.stringify(credentials, null, 2));
  console.log(`💾 Auth token saved to ${credentialsPath}`);
}
```

## Flutter App Implementation Example

```dart
// QR Scanner Screen
class GituQRScannerScreen extends StatefulWidget {
  @override
  _GituQRScannerScreenState createState() => _GituQRScannerScreenState();
}

class _GituQRScannerScreenState extends State<GituQRScannerScreen> {
  final QRViewController? _controller = null;

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      // Parse QR data: notebookllm://gitu/qr-auth?session=xxx&device=xxx&name=xxx
      final uri = Uri.parse(scanData.code!);
      
      if (uri.scheme == 'notebookllm' && uri.host == 'gitu' && uri.path == '/qr-auth') {
        final sessionId = uri.queryParameters['session'];
        final deviceName = uri.queryParameters['name'];

        if (sessionId != null) {
          // Show confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Link Terminal?'),
              content: Text('Link terminal "$deviceName" to your account?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Confirm'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await _confirmAuthentication(sessionId);
          } else {
            await _rejectAuthentication(sessionId);
          }
        }
      }
    });
  }

  Future<void> _confirmAuthentication(String sessionId) async {
    try {
      // First, notify that QR was scanned
      await apiService.post('/api/gitu/terminal/qr-scan', {
        'sessionId': sessionId,
      });

      // Then, confirm authentication
      await apiService.post('/api/gitu/terminal/qr-confirm', {
        'sessionId': sessionId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terminal linked successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to link terminal: $e')),
      );
    }
  }

  Future<void> _rejectAuthentication(String sessionId) async {
    try {
      await apiService.post('/api/gitu/terminal/qr-reject', {
        'sessionId': sessionId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication rejected')),
      );
    } catch (e) {
      print('Failed to reject authentication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: QRView(
        key: GlobalKey(debugLabel: 'QR'),
        onQRViewCreated: _onQRViewCreated,
      ),
    );
  }
}
```

## Security Considerations

1. **Session Expiry**: QR codes expire after 2 minutes to prevent replay attacks
2. **One-Time Use**: Each QR session can only be used once
3. **User Confirmation**: User must explicitly confirm authentication in Flutter app
4. **JWT Tokens**: Auth tokens are signed JWTs with 90-day expiry
5. **Device Tracking**: Each device is tracked and can be unlinked by user

## Error Handling

### Connection Errors

- **4001**: Missing deviceId or deviceName
- **4000**: Internal server error

### Session Errors

- **Session not found**: QR session expired or doesn't exist
- **Session expired**: QR code expired (2 minutes)
- **Session already used**: QR code was already scanned and authenticated
- **User ID mismatch**: Different user tried to confirm authentication

## Testing

Run the test script:

```bash
cd backend
npx tsx src/scripts/test-qr-auth-websocket.ts
```

This will:
1. Connect to the WebSocket
2. Receive QR code data
3. Display instructions for completing authentication
4. Wait for status updates

To complete the test, you'll need to:
1. Use a valid JWT token
2. Call the HTTP endpoints with the session ID

## Monitoring

The service logs all important events:

- `[Gitu QR Auth] Terminal connected: <deviceName> (<deviceId>), session: <sessionId>`
- `[Gitu QR Auth] QR scanned for session <sessionId> by user <userId>`
- `[Gitu QR Auth] Authentication completed for session <sessionId>`
- `[Gitu QR Auth] Session expired: <sessionId>`
- `[Gitu QR Auth] Cleaned up N expired sessions`

## Troubleshooting

### QR Code Not Displaying

- Check WebSocket connection is established
- Verify deviceId and deviceName are provided
- Check server logs for connection errors

### Authentication Not Completing

- Verify user is logged in to Flutter app
- Check JWT token is valid
- Verify session ID matches between QR code and HTTP requests
- Check session hasn't expired (2 minutes)

### Connection Closes Immediately

- Check query parameters are properly URL-encoded
- Verify WebSocket server is running
- Check for firewall/proxy issues

## Next Steps

1. Implement terminal CLI command: `gitu auth --qr`
2. Implement Flutter QR scanner screen
3. Add QR code display in terminal
4. Test end-to-end flow
5. Add error recovery and retry logic
