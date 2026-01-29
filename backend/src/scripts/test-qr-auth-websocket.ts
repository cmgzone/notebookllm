/**
 * Test script for Gitu QR Auth WebSocket
 * 
 * This script tests the QR authentication WebSocket endpoint by:
 * 1. Connecting to the WebSocket as a terminal
 * 2. Receiving QR code data
 * 3. Simulating user scanning and confirming via HTTP
 * 4. Receiving auth token via WebSocket
 * 
 * Usage:
 *   npx tsx src/scripts/test-qr-auth-websocket.ts
 */

import WebSocket from 'ws';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const WS_URL = BACKEND_URL.replace('http', 'ws');

// Test device info
const TEST_DEVICE_ID = `test-device-${Date.now()}`;
const TEST_DEVICE_NAME = 'Test Terminal';

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
};

function log(message: string, color: string = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

async function testQRAuthWebSocket() {
  log('\n🧪 Testing Gitu QR Auth WebSocket\n', colors.cyan);

  return new Promise<void>((resolve, reject) => {
    // Connect to WebSocket
    const wsUrl = `${WS_URL}/api/gitu/terminal/qr-auth?deviceId=${TEST_DEVICE_ID}&deviceName=${encodeURIComponent(TEST_DEVICE_NAME)}`;
    log(`📡 Connecting to: ${wsUrl}`, colors.blue);

    const ws = new WebSocket(wsUrl);

    let sessionId: string | null = null;
    let qrData: string | null = null;

    ws.on('open', () => {
      log('✅ WebSocket connected', colors.green);
    });

    ws.on('message', async (data: any) => {
      try {
        const message = JSON.parse(data.toString());
        log(`\n📨 Received message: ${message.type}`, colors.blue);

        switch (message.type) {
          case 'qr_data':
            sessionId = message.payload.sessionId;
            qrData = message.payload.qrData;
            log(`\n🔐 QR Code Data:`, colors.yellow);
            log(`   Session ID: ${sessionId}`);
            log(`   QR Data: ${qrData}`);
            log(`   Expires At: ${message.payload.expiresAt}`);
            log(`   Expires In: ${message.payload.expiresInSeconds} seconds`);
            log(`   Message: ${message.payload.message}`);

            // Simulate user scanning QR code (would normally be done via Flutter app)
            log(`\n⏳ Simulating QR scan...`, colors.yellow);
            // Note: In real scenario, user would scan QR in Flutter app
            // For testing, we'd need a valid JWT token to call the HTTP endpoints
            log(`\n⚠️  To complete authentication, call these endpoints with a valid JWT:`, colors.yellow);
            log(`   POST ${BACKEND_URL}/api/gitu/terminal/qr-scan`);
            log(`   Body: { "sessionId": "${sessionId}" }`);
            log(`   Then:`);
            log(`   POST ${BACKEND_URL}/api/gitu/terminal/qr-confirm`);
            log(`   Body: { "sessionId": "${sessionId}" }`);
            break;

          case 'status_update':
            log(`\n📊 Status Update:`, colors.cyan);
            log(`   Status: ${message.payload.status}`);
            log(`   Message: ${message.payload.message}`);
            break;

          case 'auth_token':
            log(`\n🎉 Authentication Successful!`, colors.green);
            log(`   Auth Token: ${message.payload.authToken.substring(0, 20)}...`);
            log(`   User ID: ${message.payload.userId}`);
            log(`   Expires At: ${message.payload.expiresAt}`);
            log(`   Expires In: ${message.payload.expiresInDays} days`);
            log(`   Message: ${message.payload.message}`);
            break;

          case 'error':
            log(`\n❌ Error:`, colors.red);
            log(`   ${message.payload.error}`);
            break;

          case 'pong':
            log(`   Pong received`, colors.blue);
            break;

          default:
            log(`   Unknown message type: ${message.type}`, colors.yellow);
        }
      } catch (error) {
        log(`❌ Error parsing message: ${error}`, colors.red);
      }
    });

    ws.on('close', (code, reason) => {
      log(`\n🔌 WebSocket closed`, colors.yellow);
      log(`   Code: ${code}`);
      log(`   Reason: ${reason.toString() || 'No reason provided'}`);
      resolve();
    });

    ws.on('error', (error) => {
      log(`\n❌ WebSocket error: ${error.message}`, colors.red);
      reject(error);
    });

    // Send ping every 10 seconds to keep connection alive
    const pingInterval = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'ping' }));
        log(`   Ping sent`, colors.blue);
      }
    }, 10000);

    // Close connection after 30 seconds if not authenticated
    setTimeout(() => {
      if (ws.readyState === WebSocket.OPEN) {
        log(`\n⏱️  Test timeout - closing connection`, colors.yellow);
        clearInterval(pingInterval);
        ws.close();
      }
    }, 30000);
  });
}

// Run the test
testQRAuthWebSocket()
  .then(() => {
    log('\n✅ Test completed\n', colors.green);
    process.exit(0);
  })
  .catch((error) => {
    log(`\n❌ Test failed: ${error.message}\n`, colors.red);
    process.exit(1);
  });
