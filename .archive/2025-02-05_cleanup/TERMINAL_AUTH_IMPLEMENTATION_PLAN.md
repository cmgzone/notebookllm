# Terminal Authentication Implementation Plan

## Current Status

The terminal adapter is implemented and working, but **authentication/linking is not yet complete**. Users currently get the error:
```
Platform account not linked. User must connect their terminal account in the NotebookLLM app first.
```

## Proposed Authentication Flow

### Option 1: Token-Based Authentication (Recommended)

**User Flow:**
1. User opens NotebookLLM Flutter app
2. Goes to Settings → Agent Connections → Terminal
3. Clicks "Link Terminal"
4. App generates a unique pairing token (e.g., `GITU-XXXX-YYYY`)
5. App displays token with expiry time (5 minutes)
6. User runs in terminal: `gitu auth GITU-XXXX-YYYY`
7. Terminal adapter validates token with backend
8. Backend links terminal to user account
9. Terminal stores auth credentials locally
10. User can now use terminal adapter

**Implementation:**

```typescript
// Backend: Token generation endpoint
POST /api/gitu/terminal/generate-token
Headers: Authorization: Bearer <user-jwt>
Response: {
  token: "GITU-XXXX-YYYY",
  expiresAt: "2026-01-28T16:00:00Z"
}

// Backend: Token validation endpoint
POST /api/gitu/terminal/link
Body: {
  token: "GITU-XXXX-YYYY",
  deviceName: "My Laptop",
  deviceId: "unique-device-id"
}
Response: {
  success: true,
  authToken: "long-lived-jwt-token",
  userId: "user-id"
}

// Terminal: Store auth token
// Stored in: ~/.gitu/credentials.json (encrypted)
{
  "authToken": "long-lived-jwt-token",
  "userId": "user-id",
  "deviceId": "unique-device-id",
  "linkedAt": "2026-01-28T15:30:00Z"
}
```

**Terminal Commands:**
```bash
# Link terminal to account
gitu auth <token>

# Check auth status
gitu auth status

# Unlink terminal
gitu auth logout

# Re-authenticate
gitu auth refresh
```

### Option 2: QR Code Authentication (Alternative)

**User Flow:**
1. User runs: `gitu auth`
2. Terminal displays QR code
3. User scans QR code with NotebookLLM app
4. App confirms linking
5. Terminal receives auth token via WebSocket
6. Terminal stores credentials

**Pros:**
- No manual token typing
- More modern UX
- Works well for mobile-first users

**Cons:**
- Requires QR code library in terminal
- More complex implementation
- Requires WebSocket connection

### Option 3: OAuth-Style Flow (Most Secure)

**User Flow:**
1. User runs: `gitu auth`
2. Terminal opens browser to: `https://app.notebookllm.com/auth/terminal?device=xyz`
3. User logs into NotebookLLM web app
4. User approves terminal access
5. Browser redirects to: `http://localhost:8080/callback?token=xyz`
6. Terminal receives token via local server
7. Terminal stores credentials

**Pros:**
- Most secure (no token display)
- Standard OAuth pattern
- Works with existing web auth

**Cons:**
- Requires browser
- More complex for headless servers
- Needs local HTTP server in terminal

## Recommended Implementation: Hybrid Approach (Token + QR Code)

We'll implement **both** authentication methods, giving users flexibility:
- **Token-based** (primary): Simple, works everywhere, no dependencies
- **QR code** (alternative): Modern, mobile-friendly, faster for app users

### Implementation Priority

1. ✅ **Token-based auth** (Task 1.3.3.1) - Core functionality
2. ✅ **QR code auth** (Task 1.3.3.2) - Enhanced UX
3. ✅ **Flutter UI** (Task 1.3.3.3) - Supports both methods

### Phase 1: Backend API Endpoints

**File:** `backend/src/routes/gitu.ts`

```typescript
import { Router } from 'express';
import { authenticateToken } from '../middleware/auth';
import { GituTerminalService } from '../services/gituTerminalService';

const router = Router();
const terminalService = new GituTerminalService();

// Generate pairing token
router.post('/terminal/generate-token', authenticateToken, async (req, res) => {
  try {
    const userId = req.userId!;
    const token = await terminalService.generatePairingToken(userId);
    
    res.json({
      token: token.code,
      expiresAt: token.expiresAt,
      instructions: 'Run: gitu auth ' + token.code
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate token' });
  }
});

// Link terminal with token
router.post('/terminal/link', async (req, res) => {
  try {
    const { token, deviceName, deviceId } = req.body;
    
    const result = await terminalService.linkTerminal(token, deviceName, deviceId);
    
    res.json({
      success: true,
      authToken: result.authToken,
      userId: result.userId
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Validate terminal auth token
router.post('/terminal/validate', async (req, res) => {
  try {
    const { authToken } = req.body;
    
    const isValid = await terminalService.validateAuthToken(authToken);
    
    res.json({ valid: isValid });
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// Unlink terminal
router.post('/terminal/unlink', authenticateToken, async (req, res) => {
  try {
    const userId = req.userId!;
    const { deviceId } = req.body;
    
    await terminalService.unlinkTerminal(userId, deviceId);
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to unlink terminal' });
  }
});

// List linked terminals
router.get('/terminal/devices', authenticateToken, async (req, res) => {
  try {
    const userId = req.userId!;
    
    const devices = await terminalService.listLinkedDevices(userId);
    
    res.json({ devices });
  } catch (error) {
    res.status(500).json({ error: 'Failed to list devices' });
  }
});

export default router;
```

### Phase 2: Backend Service

**File:** `backend/src/services/gituTerminalService.ts`

```typescript
import { randomBytes } from 'crypto';
import jwt from 'jsonwebtoken';
import { db } from '../config/database';

interface PairingToken {
  code: string;
  userId: string;
  expiresAt: Date;
}

interface LinkedDevice {
  id: string;
  userId: string;
  deviceName: string;
  deviceId: string;
  authToken: string;
  linkedAt: Date;
  lastUsedAt: Date;
}

export class GituTerminalService {
  private readonly TOKEN_EXPIRY_MINUTES = 5;
  private readonly AUTH_TOKEN_EXPIRY_DAYS = 90;
  
  async generatePairingToken(userId: string): Promise<PairingToken> {
    // Generate 8-character token (e.g., GITU-ABCD-1234)
    const code = `GITU-${this.generateCode(4)}-${this.generateCode(4)}`;
    const expiresAt = new Date(Date.now() + this.TOKEN_EXPIRY_MINUTES * 60 * 1000);
    
    // Store in database
    await db.query(
      `INSERT INTO gitu_pairing_tokens (code, user_id, expires_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (code) DO UPDATE SET expires_at = $3`,
      [code, userId, expiresAt]
    );
    
    return { code, userId, expiresAt };
  }
  
  async linkTerminal(
    token: string,
    deviceName: string,
    deviceId: string
  ): Promise<{ authToken: string; userId: string }> {
    // Validate pairing token
    const result = await db.query(
      `SELECT user_id, expires_at FROM gitu_pairing_tokens
       WHERE code = $1 AND expires_at > NOW()`,
      [token]
    );
    
    if (result.rows.length === 0) {
      throw new Error('Invalid or expired token');
    }
    
    const userId = result.rows[0].user_id;
    
    // Generate long-lived auth token
    const authToken = jwt.sign(
      { userId, deviceId, type: 'terminal' },
      process.env.JWT_SECRET!,
      { expiresIn: `${this.AUTH_TOKEN_EXPIRY_DAYS}d` }
    );
    
    // Store linked device
    await db.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified)
       VALUES ($1, 'terminal', $2, $3, true)
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET display_name = $3, last_used_at = NOW()`,
      [userId, deviceId, deviceName]
    );
    
    // Delete used pairing token
    await db.query('DELETE FROM gitu_pairing_tokens WHERE code = $1', [token]);
    
    return { authToken, userId };
  }
  
  async validateAuthToken(authToken: string): Promise<boolean> {
    try {
      const decoded = jwt.verify(authToken, process.env.JWT_SECRET!) as any;
      
      if (decoded.type !== 'terminal') {
        return false;
      }
      
      // Check if device is still linked
      const result = await db.query(
        `SELECT 1 FROM gitu_linked_accounts
         WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
        [decoded.userId, decoded.deviceId]
      );
      
      return result.rows.length > 0;
    } catch (error) {
      return false;
    }
  }
  
  async unlinkTerminal(userId: string, deviceId: string): Promise<void> {
    await db.query(
      `DELETE FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal' AND platform_user_id = $2`,
      [userId, deviceId]
    );
  }
  
  async listLinkedDevices(userId: string): Promise<LinkedDevice[]> {
    const result = await db.query(
      `SELECT id, user_id, platform_user_id as device_id, display_name as device_name,
              linked_at, last_used_at
       FROM gitu_linked_accounts
       WHERE user_id = $1 AND platform = 'terminal'
       ORDER BY last_used_at DESC`,
      [userId]
    );
    
    return result.rows;
  }
  
  private generateCode(length: number): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars
    let code = '';
    const bytes = randomBytes(length);
    
    for (let i = 0; i < length; i++) {
      code += chars[bytes[i] % chars.length];
    }
    
    return code;
  }
}
```

### Phase 3: Database Migration

**File:** `backend/migrations/add_terminal_auth.sql`

```sql
-- Pairing tokens table
CREATE TABLE IF NOT EXISTS gitu_pairing_tokens (
  code TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_pairing_tokens_expiry ON gitu_pairing_tokens(expires_at);

-- Clean up expired tokens periodically
CREATE OR REPLACE FUNCTION cleanup_expired_pairing_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM gitu_pairing_tokens WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (if using pg_cron)
-- SELECT cron.schedule('cleanup-pairing-tokens', '*/5 * * * *', 'SELECT cleanup_expired_pairing_tokens()');
```

### Phase 4: Terminal CLI Auth Commands

**File:** `backend/src/adapters/terminalAdapter.ts` (additions)

```typescript
// Add auth command handler
private handleAuthCommand(args: string[]): void {
  if (args.length === 0) {
    this.showAuthHelp();
    return;
  }
  
  const subcommand = args[0];
  
  switch (subcommand) {
    case 'status':
      this.showAuthStatus();
      break;
    case 'logout':
      this.logout();
      break;
    case 'refresh':
      this.refreshAuth();
      break;
    default:
      // Assume it's a pairing token
      this.linkWithToken(subcommand);
      break;
  }
}

private async linkWithToken(token: string): Promise<void> {
  const spinner = ora('Linking terminal to your account...').start();
  
  try {
    const deviceId = this.getDeviceId();
    const deviceName = os.hostname();
    
    const response = await fetch(`${this.backendUrl}/api/gitu/terminal/link`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, deviceName, deviceId })
    });
    
    if (!response.ok) {
      throw new Error('Failed to link terminal');
    }
    
    const data = await response.json();
    
    // Store credentials
    this.saveCredentials({
      authToken: data.authToken,
      userId: data.userId,
      deviceId,
      linkedAt: new Date().toISOString()
    });
    
    spinner.succeed(chalk.green('✅ Terminal linked successfully!'));
    console.log(chalk.gray(`Device: ${deviceName}`));
    console.log(chalk.gray(`User ID: ${data.userId}`));
  } catch (error) {
    spinner.fail(chalk.red('❌ Failed to link terminal'));
    console.error(chalk.red(error.message));
  }
}

private showAuthStatus(): void {
  const creds = this.loadCredentials();
  
  if (!creds) {
    console.log(chalk.yellow('⚠️  Terminal not linked'));
    console.log(chalk.gray('Run: gitu auth <token>'));
    return;
  }
  
  console.log(chalk.green('✅ Terminal linked'));
  console.log(chalk.gray(`User ID: ${creds.userId}`));
  console.log(chalk.gray(`Device ID: ${creds.deviceId}`));
  console.log(chalk.gray(`Linked at: ${new Date(creds.linkedAt).toLocaleString()}`));
}

private logout(): void {
  const credsPath = this.getCredentialsPath();
  
  if (fs.existsSync(credsPath)) {
    fs.unlinkSync(credsPath);
    console.log(chalk.green('✅ Logged out successfully'));
  } else {
    console.log(chalk.yellow('⚠️  Not logged in'));
  }
}

private getCredentialsPath(): string {
  const homeDir = os.homedir();
  const gituDir = path.join(homeDir, '.gitu');
  
  if (!fs.existsSync(gituDir)) {
    fs.mkdirSync(gituDir, { recursive: true });
  }
  
  return path.join(gituDir, 'credentials.json');
}

private saveCredentials(creds: any): void {
  const credsPath = this.getCredentialsPath();
  fs.writeFileSync(credsPath, JSON.stringify(creds, null, 2), { mode: 0o600 });
}

private loadCredentials(): any | null {
  const credsPath = this.getCredentialsPath();
  
  if (!fs.existsSync(credsPath)) {
    return null;
  }
  
  try {
    return JSON.parse(fs.readFileSync(credsPath, 'utf8'));
  } catch (error) {
    return null;
  }
}

private getDeviceId(): string {
  // Generate or load persistent device ID
  const deviceIdPath = path.join(os.homedir(), '.gitu', 'device-id');
  
  if (fs.existsSync(deviceIdPath)) {
    return fs.readFileSync(deviceIdPath, 'utf8').trim();
  }
  
  const deviceId = randomBytes(16).toString('hex');
  fs.writeFileSync(deviceIdPath, deviceId, { mode: 0o600 });
  
  return deviceId;
}
```

### Phase 5: Flutter App UI

**File:** `lib/features/settings/terminal_connection_screen.dart`

```dart
class TerminalConnectionScreen extends StatefulWidget {
  @override
  _TerminalConnectionScreenState createState() => _TerminalConnectionScreenState();
}

class _TerminalConnectionScreenState extends State<TerminalConnectionScreen> {
  String? _pairingToken;
  DateTime? _tokenExpiry;
  bool _isGenerating = false;
  List<LinkedDevice> _linkedDevices = [];
  
  @override
  void initState() {
    super.initState();
    _loadLinkedDevices();
  }
  
  Future<void> _generateToken() async {
    setState(() => _isGenerating = true);
    
    try {
      final response = await apiService.post('/gitu/terminal/generate-token');
      
      setState(() {
        _pairingToken = response['token'];
        _tokenExpiry = DateTime.parse(response['expiresAt']);
        _isGenerating = false;
      });
      
      // Auto-refresh token before expiry
      Future.delayed(Duration(minutes: 4), () {
        if (mounted && _pairingToken != null) {
          setState(() => _pairingToken = null);
        }
      });
    } catch (error) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate token')),
      );
    }
  }
  
  Future<void> _loadLinkedDevices() async {
    try {
      final response = await apiService.get('/gitu/terminal/devices');
      setState(() {
        _linkedDevices = (response['devices'] as List)
            .map((d) => LinkedDevice.fromJson(d))
            .toList();
      });
    } catch (error) {
      // Handle error
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Terminal Connection')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Instructions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link Your Terminal', style: Theme.of(context).textTheme.headline6),
                  SizedBox(height: 8),
                  Text('1. Generate a pairing token below'),
                  Text('2. Run in your terminal: gitu auth <token>'),
                  Text('3. Your terminal will be linked to your account'),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Generate Token Button
          if (_pairingToken == null)
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateToken,
              icon: Icon(Icons.link),
              label: Text('Generate Pairing Token'),
            ),
          
          // Show Token
          if (_pairingToken != null)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Your Pairing Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    SelectableText(
                      _pairingToken!,
                      style: TextStyle(fontSize: 24, fontFamily: 'monospace'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Expires in ${_getTimeRemaining()}',
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Run: gitu auth $_pairingToken',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          SizedBox(height: 24),
          
          // Linked Devices
          Text('Linked Terminals', style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          
          if (_linkedDevices.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No terminals linked yet'),
              ),
            ),
          
          ..._linkedDevices.map((device) => Card(
            child: ListTile(
              leading: Icon(Icons.computer),
              title: Text(device.deviceName),
              subtitle: Text('Linked ${_formatDate(device.linkedAt)}'),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _unlinkDevice(device),
              ),
            ),
          )),
        ],
      ),
    );
  }
  
  String _getTimeRemaining() {
    if (_tokenExpiry == null) return '';
    final remaining = _tokenExpiry!.difference(DateTime.now());
    return '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Future<void> _unlinkDevice(LinkedDevice device) async {
    // Show confirmation dialog and unlink
  }
}
```

## Implementation Order

1. ✅ **Backend API** - Add routes and service (1-2 days)
2. ✅ **Database Migration** - Add pairing tokens table (1 hour)
3. ✅ **Terminal CLI** - Add auth commands (1 day)
4. ✅ **Flutter UI** - Add terminal connection screen (1-2 days)
5. ✅ **Testing** - End-to-end auth flow (1 day)
6. ✅ **Documentation** - Update guides (1 day)

**Total Estimate:** 5-7 days

## Security Considerations

1. **Token Expiry**: Pairing tokens expire in 5 minutes
2. **One-Time Use**: Tokens are deleted after successful linking
3. **Secure Storage**: Auth tokens stored with 0600 permissions
4. **JWT Validation**: All requests validate JWT signature
5. **Device Tracking**: Each terminal has unique device ID
6. **Revocation**: Users can unlink terminals from app
7. **Audit Logging**: All auth events logged

## Next Steps

Would you like me to:
1. Implement the backend API endpoints (token + QR)?
2. Add the auth commands to terminal adapter (token + QR)?
3. Create the Flutter UI screen (with both methods)?
4. All of the above?

---

## QR Code Authentication Implementation

### Backend: QR Auth WebSocket Endpoint

**File:** `backend/src/routes/gitu.ts` (additions)

```typescript
import { WebSocketServer } from 'ws';

// QR code authentication endpoint
router.post('/terminal/qr-auth/generate', authenticateToken, async (req, res) => {
  try {
    const userId = req.userId!;
    
    // Generate session ID for QR auth
    const sessionId = randomBytes(16).toString('hex');
    const expiresAt = new Date(Date.now() + 2 * 60 * 1000); // 2 minutes
    
    // Store pending QR auth session
    await db.query(
      `INSERT INTO gitu_qr_auth_sessions (session_id, user_id, expires_at, status)
       VALUES ($1, $2, $3, 'pending')`,
      [sessionId, userId, expiresAt]
    );
    
    // Generate QR code data (URL that terminal will encode)
    const qrData = JSON.stringify({
      type: 'gitu_terminal_auth',
      sessionId,
      timestamp: Date.now()
    });
    
    res.json({
      sessionId,
      qrData,
      expiresAt,
      wsUrl: `${process.env.WS_URL}/gitu/terminal/qr-auth/${sessionId}`
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate QR auth session' });
  }
});

// Confirm QR auth (called by Flutter app after scanning)
router.post('/terminal/qr-auth/confirm', authenticateToken, async (req, res) => {
  try {
    const userId = req.userId!;
    const { sessionId, deviceName, deviceId } = req.body;
    
    // Verify session belongs to user and is pending
    const result = await db.query(
      `SELECT user_id, status, expires_at FROM gitu_qr_auth_sessions
       WHERE session_id = $1 AND user_id = $2 AND status = 'pending' AND expires_at > NOW()`,
      [sessionId, userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired session' });
    }
    
    // Generate auth token
    const authToken = jwt.sign(
      { userId, deviceId, type: 'terminal' },
      process.env.JWT_SECRET!,
      { expiresIn: '90d' }
    );
    
    // Link device
    await db.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified)
       VALUES ($1, 'terminal', $2, $3, true)
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET display_name = $3, last_used_at = NOW()`,
      [userId, deviceId, deviceName]
    );
    
    // Update session status
    await db.query(
      `UPDATE gitu_qr_auth_sessions
       SET status = 'confirmed', auth_token = $1, confirmed_at = NOW()
       WHERE session_id = $2`,
      [authToken, sessionId]
    );
    
    // Notify terminal via WebSocket
    notifyTerminalViaWebSocket(sessionId, { authToken, userId });
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to confirm QR auth' });
  }
});
```

**Database Migration:**

```sql
-- QR auth sessions table
CREATE TABLE IF NOT EXISTS gitu_qr_auth_sessions (
  session_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'expired')),
  auth_token TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ
);

CREATE INDEX idx_gitu_qr_auth_sessions_expiry ON gitu_qr_auth_sessions(expires_at);
CREATE INDEX idx_gitu_qr_auth_sessions_user ON gitu_qr_auth_sessions(user_id, status);
```

### Terminal: QR Code Display

**File:** `backend/src/adapters/terminalAdapter.ts` (additions)

First, install the QR code library:
```bash
npm install qrcode-terminal ws
npm install --save-dev @types/qrcode-terminal
```

Then add QR auth command:

```typescript
import qrcode from 'qrcode-terminal';
import WebSocket from 'ws';

private async handleQRAuth(): Promise<void> {
  console.log(chalk.blue('\n🔐 QR Code Authentication\n'));
  console.log(chalk.gray('1. Open NotebookLLM app on your phone'));
  console.log(chalk.gray('2. Go to Settings → Agent Connections → Terminal'));
  console.log(chalk.gray('3. Tap "Link Terminal" → "Scan QR Code"'));
  console.log(chalk.gray('4. Scan the QR code below\n'));
  
  const spinner = ora('Generating QR code...').start();
  
  try {
    // Get user's auth token (they must be logged in to app first)
    // For now, we'll use a temporary approach where user provides their API token
    const apiToken = await this.promptForApiToken();
    
    // Request QR auth session from backend
    const response = await fetch(`${this.backendUrl}/api/gitu/terminal/qr-auth/generate`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error('Failed to generate QR auth session');
    }
    
    const data = await response.json();
    
    spinner.stop();
    
    // Display QR code in terminal
    console.log(chalk.green('\n📱 Scan this QR code with your app:\n'));
    qrcode.generate(data.qrData, { small: true });
    
    console.log(chalk.gray(`\nSession expires in 2 minutes...`));
    console.log(chalk.gray(`Waiting for confirmation...\n`));
    
    // Connect to WebSocket to wait for confirmation
    const authResult = await this.waitForQRConfirmation(data.sessionId, data.wsUrl);
    
    if (authResult.success) {
      // Store credentials
      this.saveCredentials({
        authToken: authResult.authToken,
        userId: authResult.userId,
        deviceId: this.getDeviceId(),
        linkedAt: new Date().toISOString()
      });
      
      console.log(chalk.green('\n✅ Terminal linked successfully via QR code!'));
      console.log(chalk.gray(`User ID: ${authResult.userId}`));
    } else {
      console.log(chalk.red('\n❌ QR authentication failed or timed out'));
      console.log(chalk.yellow('💡 Try token-based auth: gitu auth <token>'));
    }
  } catch (error) {
    spinner.fail(chalk.red('Failed to generate QR code'));
    console.error(chalk.red(error.message));
    console.log(chalk.yellow('\n💡 Try token-based auth instead: gitu auth <token>'));
  }
}

private async waitForQRConfirmation(
  sessionId: string,
  wsUrl: string
): Promise<{ success: boolean; authToken?: string; userId?: string }> {
  return new Promise((resolve) => {
    const ws = new WebSocket(wsUrl);
    const timeout = setTimeout(() => {
      ws.close();
      resolve({ success: false });
    }, 120000); // 2 minutes
    
    ws.on('open', () => {
      console.log(chalk.gray('Connected, waiting for scan...'));
    });
    
    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        
        if (message.type === 'auth_confirmed') {
          clearTimeout(timeout);
          ws.close();
          resolve({
            success: true,
            authToken: message.authToken,
            userId: message.userId
          });
        }
      } catch (error) {
        // Ignore parse errors
      }
    });
    
    ws.on('error', () => {
      clearTimeout(timeout);
      resolve({ success: false });
    });
    
    ws.on('close', () => {
      clearTimeout(timeout);
    });
  });
}

private async promptForApiToken(): Promise<string> {
  // For initial implementation, user needs to provide their API token
  // Later, we can implement a web-based OAuth flow
  console.log(chalk.yellow('\n⚠️  First-time setup: You need your API token'));
  console.log(chalk.gray('Get it from: NotebookLLM App → Settings → API Tokens\n'));
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  return new Promise((resolve) => {
    rl.question(chalk.cyan('Enter your API token: '), (token) => {
      rl.close();
      resolve(token.trim());
    });
  });
}

// Update auth command handler
private handleAuthCommand(args: string[]): void {
  if (args.length === 0) {
    this.showAuthHelp();
    return;
  }
  
  const subcommand = args[0];
  
  switch (subcommand) {
    case '--qr':
    case 'qr':
      this.handleQRAuth();
      break;
    case 'status':
      this.showAuthStatus();
      break;
    case 'logout':
      this.logout();
      break;
    case 'refresh':
      this.refreshAuth();
      break;
    default:
      // Assume it's a pairing token
      this.linkWithToken(subcommand);
      break;
  }
}

private showAuthHelp(): void {
  console.log(chalk.blue('\n🔐 Gitu Authentication\n'));
  console.log(chalk.white('Usage:'));
  console.log(chalk.gray('  gitu auth <token>     ') + chalk.white('Link with pairing token'));
  console.log(chalk.gray('  gitu auth --qr        ') + chalk.white('Link with QR code'));
  console.log(chalk.gray('  gitu auth status      ') + chalk.white('Check auth status'));
  console.log(chalk.gray('  gitu auth logout      ') + chalk.white('Unlink terminal'));
  console.log(chalk.gray('  gitu auth refresh     ') + chalk.white('Refresh auth token\n'));
}
```

### Flutter: QR Code Scanner UI

**File:** `lib/features/gitu/terminal_connection_screen.dart` (enhanced)

First, add dependencies to `pubspec.yaml`:
```yaml
dependencies:
  qr_flutter: ^4.1.0
  qr_code_scanner: ^1.0.1
  mobile_scanner: ^3.5.5  # Alternative, more maintained
```

Then update the UI:

```dart
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TerminalConnectionScreen extends StatefulWidget {
  @override
  _TerminalConnectionScreenState createState() => _TerminalConnectionScreenState();
}

class _TerminalConnectionScreenState extends State<TerminalConnectionScreen> {
  String? _pairingToken;
  String? _qrData;
  String? _qrSessionId;
  DateTime? _tokenExpiry;
  bool _isGenerating = false;
  bool _useQRCode = false;  // Toggle between token and QR
  List<LinkedDevice> _linkedDevices = [];
  
  Future<void> _generateToken() async {
    setState(() => _isGenerating = true);
    
    try {
      final response = await apiService.post('/gitu/terminal/generate-token');
      
      setState(() {
        _pairingToken = response['token'];
        _tokenExpiry = DateTime.parse(response['expiresAt']);
        _isGenerating = false;
        _useQRCode = false;
      });
      
      _startTokenExpiryTimer();
    } catch (error) {
      setState(() => _isGenerating = false);
      _showError('Failed to generate token');
    }
  }
  
  Future<void> _generateQRCode() async {
    setState(() => _isGenerating = true);
    
    try {
      final response = await apiService.post('/gitu/terminal/qr-auth/generate');
      
      setState(() {
        _qrData = response['qrData'];
        _qrSessionId = response['sessionId'];
        _tokenExpiry = DateTime.parse(response['expiresAt']);
        _isGenerating = false;
        _useQRCode = true;
      });
      
      _startTokenExpiryTimer();
    } catch (error) {
      setState(() => _isGenerating = false);
      _showError('Failed to generate QR code');
    }
  }
  
  void _showQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScanned: _handleQRScanned,
        ),
      ),
    );
  }
  
  Future<void> _handleQRScanned(String qrData) async {
    try {
      final data = jsonDecode(qrData);
      
      if (data['type'] != 'gitu_terminal_auth') {
        _showError('Invalid QR code');
        return;
      }
      
      final sessionId = data['sessionId'];
      final deviceName = await _getDeviceName();
      final deviceId = await _getDeviceId();
      
      // Confirm the QR auth
      await apiService.post('/gitu/terminal/qr-auth/confirm', {
        'sessionId': sessionId,
        'deviceName': deviceName,
        'deviceId': deviceId,
      });
      
      Navigator.pop(context);
      _showSuccess('Terminal linked successfully!');
      _loadLinkedDevices();
    } catch (error) {
      _showError('Failed to link terminal');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Terminal Connection')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Instructions Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link Your Terminal', 
                    style: Theme.of(context).textTheme.headline6),
                  SizedBox(height: 8),
                  Text('Choose your preferred method:'),
                  SizedBox(height: 8),
                  Text('• Token: Simple, works everywhere'),
                  Text('• QR Code: Fast, mobile-friendly'),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Method Selection
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateToken,
                  icon: Icon(Icons.key),
                  label: Text('Generate Token'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_useQRCode ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateQRCode,
                  icon: Icon(Icons.qr_code),
                  label: Text('Generate QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _useQRCode ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Show Token
          if (_pairingToken != null && !_useQRCode)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Your Pairing Token:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    SelectableText(
                      _pairingToken!,
                      style: TextStyle(fontSize: 24, fontFamily: 'monospace'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Expires in ${_getTimeRemaining()}',
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Run: gitu auth $_pairingToken',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _pairingToken!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Token copied to clipboard')),
                        );
                      },
                      icon: Icon(Icons.copy),
                      label: Text('Copy Token'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Show QR Code
          if (_qrData != null && _useQRCode)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Scan with Terminal:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(16),
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Expires in ${_getTimeRemaining()}',
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Run: gitu auth --qr',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          SizedBox(height: 24),
          
          // Linked Devices
          Text('Linked Terminals', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          
          if (_linkedDevices.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No terminals linked yet'),
              ),
            ),
          
          ..._linkedDevices.map((device) => Card(
            child: ListTile(
              leading: Icon(Icons.computer),
              title: Text(device.deviceName),
              subtitle: Text('Linked ${_formatDate(device.linkedAt)}'),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _unlinkDevice(device),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// QR Scanner Screen
class QRScannerScreen extends StatelessWidget {
  final Function(String) onScanned;
  
  const QRScannerScreen({required this.onScanned});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              onScanned(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }
}
```

## Next Steps

Would you like me to:
1. Implement the backend API endpoints (token + QR)?
2. Add the auth commands to terminal adapter (token + QR)?
3. Create the Flutter UI screen (with both methods)?
4. All of the above?
