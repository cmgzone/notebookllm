/**
 * Mobile QR Auth Flow Test Script
 * 
 * This script simulates the complete QR authentication flow
 * to verify all components work correctly before mobile testing.
 * 
 * Usage:
 *   npm run test:qr-mobile
 *   or
 *   npx tsx backend/src/scripts/test-qr-auth-mobile.ts
 */

import WebSocket from 'ws';
import axios from 'axios';
import chalk from 'chalk';

// Configuration
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const WS_URL = BACKEND_URL.replace('http', 'ws');
const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL || 'test@example.com';
const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD || 'testpassword123';

interface TestResult {
  name: string;
  passed: boolean;
  duration: number;
  error?: string;
}

const results: TestResult[] = [];

// Helper function to run a test
async function runTest(
  name: string,
  testFn: () => Promise<void>
): Promise<void> {
  const startTime = Date.now();
  console.log(chalk.blue(`\n🧪 Running: ${name}`));

  try {
    await testFn();
    const duration = Date.now() - startTime;
    results.push({ name, passed: true, duration });
    console.log(chalk.green(`✅ PASSED (${duration}ms)`));
  } catch (error: any) {
    const duration = Date.now() - startTime;
    results.push({ name, passed: false, duration, error: error.message });
    console.log(chalk.red(`❌ FAILED (${duration}ms)`));
    console.log(chalk.red(`   Error: ${error.message}`));
  }
}

// Helper function to login and get auth token
async function loginUser(): Promise<string> {
  try {
    const response = await axios.post(`${BACKEND_URL}/api/auth/login`, {
      email: TEST_USER_EMAIL,
      password: TEST_USER_PASSWORD,
    });
    return response.data.accessToken ?? response.data.token;
  } catch (error: any) {
    throw new Error(`Login failed: ${error.response?.data?.error || error.message}`);
  }
}

// Test 1: WebSocket Connection
async function testWebSocketConnection(): Promise<void> {
  return new Promise((resolve, reject) => {
    const deviceId = `test-device-${Date.now()}`;
    const deviceName = 'Test Mobile Device';
    const wsUrl = `${WS_URL}/api/gitu/terminal/qr-auth?deviceId=${deviceId}&deviceName=${encodeURIComponent(deviceName)}`;

    const ws = new WebSocket(wsUrl);
    let sessionId: string | null = null;

    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('WebSocket connection timeout'));
    }, 10000);

    ws.on('open', () => {
      console.log(chalk.gray('   WebSocket connected'));
    });

    ws.on('message', (data: Buffer) => {
      try {
        const message = JSON.parse(data.toString());
        console.log(chalk.gray(`   Received: ${message.type}`));

        if (message.type === 'qr_data') {
          sessionId = message.payload.sessionId;
          console.log(chalk.gray(`   Session ID: ${sessionId}`));
          clearTimeout(timeout);
          ws.close();
          resolve();
        }
      } catch (error: any) {
        clearTimeout(timeout);
        ws.close();
        reject(new Error(`Failed to parse message: ${error.message}`));
      }
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(`WebSocket error: ${error.message}`));
    });

    ws.on('close', () => {
      clearTimeout(timeout);
      if (!sessionId) {
        reject(new Error('WebSocket closed without receiving QR data'));
      }
    });
  });
}

// Test 2: QR Code Generation
async function testQRCodeGeneration(): Promise<string> {
  return new Promise((resolve, reject) => {
    const deviceId = `test-device-${Date.now()}`;
    const deviceName = 'Test Mobile Device';
    const wsUrl = `${WS_URL}/api/gitu/terminal/qr-auth?deviceId=${deviceId}&deviceName=${encodeURIComponent(deviceName)}`;

    const ws = new WebSocket(wsUrl);
    let sessionId: string | null = null;

    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('QR code generation timeout'));
    }, 10000);

    ws.on('message', (data: Buffer) => {
      try {
        const message = JSON.parse(data.toString());

        if (message.type === 'qr_data') {
          const { sessionId: sid, qrData, expiresInSeconds } = message.payload;

          if (!sid || !qrData || !expiresInSeconds) {
            throw new Error('Missing required QR data fields');
          }

          if (expiresInSeconds !== 120) {
            throw new Error(`Expected 120 seconds expiry, got ${expiresInSeconds}`);
          }

          if (!qrData.startsWith('notebookllm://gitu/qr-auth')) {
            throw new Error(`Invalid QR data format: ${qrData}`);
          }

          sessionId = sid;
          console.log(chalk.gray(`   QR Data: ${qrData}`));
          console.log(chalk.gray(`   Expires in: ${expiresInSeconds}s`));

          clearTimeout(timeout);
          ws.close();
          resolve(sessionId!);
        }
      } catch (error: any) {
        clearTimeout(timeout);
        ws.close();
        reject(error);
      }
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(`WebSocket error: ${error.message}`));
    });
  });
}

// Test 3: QR Scan Endpoint
async function testQRScanEndpoint(): Promise<{ sessionId: string; authToken: string }> {
  const authToken = await loginUser();
  const sessionId = await testQRCodeGeneration();

  try {
    const response = await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-scan`,
      { sessionId },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );

    if (!response.data.success) {
      throw new Error('QR scan endpoint returned success: false');
    }

    console.log(chalk.gray(`   Scan successful: ${response.data.message}`));
    return { sessionId, authToken };
  } catch (error: any) {
    throw new Error(`QR scan failed: ${error.response?.data?.error || error.message}`);
  }
}

// Test 4: QR Confirm Endpoint
async function testQRConfirmEndpoint(): Promise<void> {
  const { sessionId, authToken } = await testQRScanEndpoint();

  // Wait a bit to simulate user confirmation
  await new Promise(resolve => setTimeout(resolve, 1000));

  try {
    const response = await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-confirm`,
      { sessionId },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );

    if (!response.data.success) {
      throw new Error('QR confirm endpoint returned success: false');
    }

    console.log(chalk.gray(`   Confirmation successful: ${response.data.message}`));
  } catch (error: any) {
    throw new Error(`QR confirm failed: ${error.response?.data?.error || error.message}`);
  }
}

// Test 5: Complete Flow with WebSocket
async function testCompleteFlow(): Promise<void> {
  const authToken = await loginUser();
  const deviceId = `test-device-${Date.now()}`;
  const deviceName = 'Test Mobile Device';
  const wsUrl = `${WS_URL}/api/gitu/terminal/qr-auth?deviceId=${deviceId}&deviceName=${encodeURIComponent(deviceName)}`;

  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    let sessionId: string | null = null;
    let receivedAuthToken = false;

    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('Complete flow timeout'));
    }, 15000);

    ws.on('message', async (data: Buffer) => {
      try {
        const message = JSON.parse(data.toString());
        console.log(chalk.gray(`   Terminal received: ${message.type}`));

        if (message.type === 'qr_data') {
          sessionId = message.payload.sessionId;
          console.log(chalk.gray(`   Session ID: ${sessionId}`));

          // Simulate mobile app scanning QR code
          await axios.post(
            `${BACKEND_URL}/api/gitu/terminal/qr-scan`,
            { sessionId },
            { headers: { Authorization: `Bearer ${authToken}` } }
          );
          console.log(chalk.gray('   Mobile app scanned QR code'));

          // Wait a bit, then confirm
          setTimeout(async () => {
            await axios.post(
              `${BACKEND_URL}/api/gitu/terminal/qr-confirm`,
              { sessionId },
              { headers: { Authorization: `Bearer ${authToken}` } }
            );
            console.log(chalk.gray('   Mobile app confirmed authentication'));
          }, 1000);
        } else if (message.type === 'status_update') {
          console.log(chalk.gray(`   Status: ${message.payload.status}`));
        } else if (message.type === 'auth_token') {
          const { authToken: terminalToken, expiresInDays } = message.payload;

          if (!terminalToken) {
            throw new Error('No auth token received');
          }

          console.log(chalk.gray(`   Auth token received (expires in ${expiresInDays} days)`));
          receivedAuthToken = true;
          clearTimeout(timeout);
          ws.close();
          resolve();
        }
      } catch (error: any) {
        clearTimeout(timeout);
        ws.close();
        reject(error);
      }
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(`WebSocket error: ${error.message}`));
    });

    ws.on('close', () => {
      clearTimeout(timeout);
      if (!receivedAuthToken) {
        reject(new Error('WebSocket closed without receiving auth token'));
      }
    });
  });
}

// Test 6: Session Expiry
async function testSessionExpiry(): Promise<void> {
  const sessionId = await testQRCodeGeneration();

  // Wait for session to expire (2 minutes + buffer)
  console.log(chalk.gray('   Waiting for session to expire (this will take 2+ minutes)...'));
  await new Promise(resolve => setTimeout(resolve, 125000)); // 2 minutes 5 seconds

  const authToken = await loginUser();

  try {
    await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-scan`,
      { sessionId },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    throw new Error('Expected session to be expired, but scan succeeded');
  } catch (error: any) {
    if (error.response?.status === 404 && error.response?.data?.error?.includes('expired')) {
      console.log(chalk.gray('   Session correctly expired'));
    } else {
      throw new Error(`Unexpected error: ${error.response?.data?.error || error.message}`);
    }
  }
}

// Test 7: Invalid Session ID
async function testInvalidSessionId(): Promise<void> {
  const authToken = await loginUser();
  const invalidSessionId = 'invalid-session-id';

  try {
    await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-scan`,
      { sessionId: invalidSessionId },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );
    throw new Error('Expected invalid session to fail, but scan succeeded');
  } catch (error: any) {
    if (error.response?.status === 404) {
      console.log(chalk.gray('   Invalid session correctly rejected'));
    } else {
      throw new Error(`Unexpected error: ${error.response?.data?.error || error.message}`);
    }
  }
}

// Test 8: Unauthorized Access
async function testUnauthorizedAccess(): Promise<void> {
  const sessionId = await testQRCodeGeneration();

  try {
    await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-scan`,
      { sessionId }
      // No auth token
    );
    throw new Error('Expected unauthorized request to fail, but scan succeeded');
  } catch (error: any) {
    if (error.response?.status === 401) {
      console.log(chalk.gray('   Unauthorized access correctly rejected'));
    } else {
      throw new Error(`Unexpected error: ${error.response?.data?.error || error.message}`);
    }
  }
}

// Test 9: QR Reject Endpoint
async function testQRRejectEndpoint(): Promise<void> {
  const { sessionId, authToken } = await testQRScanEndpoint();

  try {
    const response = await axios.post(
      `${BACKEND_URL}/api/gitu/terminal/qr-reject`,
      { sessionId },
      { headers: { Authorization: `Bearer ${authToken}` } }
    );

    if (!response.data.success) {
      throw new Error('QR reject endpoint returned success: false');
    }

    console.log(chalk.gray(`   Rejection successful: ${response.data.message}`));
  } catch (error: any) {
    throw new Error(`QR reject failed: ${error.response?.data?.error || error.message}`);
  }
}

// Test 10: Device Listing After QR Auth
async function testDeviceListingAfterQRAuth(): Promise<void> {
  // Complete a full auth flow first
  await testCompleteFlow();

  // Wait a bit for database to update
  await new Promise(resolve => setTimeout(resolve, 2000));

  const authToken = await loginUser();

  try {
    const response = await axios.get(
      `${BACKEND_URL}/api/gitu/terminal/devices`,
      { headers: { Authorization: `Bearer ${authToken}` } }
    );

    const devices = response.data.devices;

    if (!Array.isArray(devices)) {
      throw new Error('Expected devices to be an array');
    }

    if (devices.length === 0) {
      throw new Error('Expected at least one device after QR auth');
    }

    const latestDevice = devices[devices.length - 1];
    console.log(chalk.gray(`   Found device: ${latestDevice.deviceName}`));
    console.log(chalk.gray(`   Device ID: ${latestDevice.deviceId}`));
  } catch (error: any) {
    throw new Error(`Device listing failed: ${error.response?.data?.error || error.message}`);
  }
}

// Main test runner
async function main() {
  console.log(chalk.bold.cyan('\n🚀 Gitu QR Auth Mobile Testing\n'));
  console.log(chalk.gray(`Backend URL: ${BACKEND_URL}`));
  console.log(chalk.gray(`WebSocket URL: ${WS_URL}`));
  console.log(chalk.gray(`Test User: ${TEST_USER_EMAIL}\n`));

  // Run tests
  await runTest('1. WebSocket Connection', testWebSocketConnection);
  await runTest('2. QR Code Generation', async () => { await testQRCodeGeneration(); });
  await runTest('3. QR Scan Endpoint', async () => { await testQRScanEndpoint(); });
  await runTest('4. QR Confirm Endpoint', testQRConfirmEndpoint);
  await runTest('5. Complete Flow with WebSocket', testCompleteFlow);
  await runTest('6. Invalid Session ID', testInvalidSessionId);
  await runTest('7. Unauthorized Access', testUnauthorizedAccess);
  await runTest('8. QR Reject Endpoint', testQRRejectEndpoint);
  await runTest('9. Device Listing After QR Auth', testDeviceListingAfterQRAuth);

  // Optional: Run session expiry test (takes 2+ minutes)
  const runExpiryTest = process.argv.includes('--with-expiry');
  if (runExpiryTest) {
    await runTest('10. Session Expiry (2+ minutes)', testSessionExpiry);
  } else {
    console.log(chalk.yellow('\n⏭️  Skipping session expiry test (use --with-expiry to run)'));
  }

  // Print summary
  console.log(chalk.bold.cyan('\n📊 Test Summary\n'));

  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed).length;
  const total = results.length;

  results.forEach(result => {
    const icon = result.passed ? chalk.green('✅') : chalk.red('❌');
    const duration = chalk.gray(`(${result.duration}ms)`);
    console.log(`${icon} ${result.name} ${duration}`);
    if (result.error) {
      console.log(chalk.red(`   ${result.error}`));
    }
  });

  console.log(chalk.bold(`\nTotal: ${total} | Passed: ${chalk.green(passed)} | Failed: ${chalk.red(failed)}`));

  if (failed > 0) {
    console.log(chalk.red('\n❌ Some tests failed. Please fix the issues before mobile testing.'));
    process.exit(1);
  } else {
    console.log(chalk.green('\n✅ All tests passed! Ready for mobile testing.'));
    process.exit(0);
  }
}

// Run tests
main().catch(error => {
  console.error(chalk.red('\n💥 Fatal error:'), error);
  process.exit(1);
});
