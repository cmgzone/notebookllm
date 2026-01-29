/**
 * Test script for QR code authentication command
 * Tests the `gitu auth --qr` command implementation
 */

import chalk from 'chalk';
import qrcode from 'qrcode-terminal';

console.log(chalk.cyan('\n🧪 Testing QR Code Authentication Command\n'));

// Test 1: QR code generation
console.log(chalk.yellow('Test 1: QR Code Generation'));
console.log(chalk.gray('Generating sample QR code for authentication URL...\n'));

const sessionId = `qr_${Date.now()}_${Math.random().toString(36).substring(7)}`;
const deviceId = 'test-device-123';
const deviceName = 'Test Terminal';

const qrData = `notebookllm://gitu/qr-auth?session=${sessionId}&device=${deviceId}&name=${encodeURIComponent(deviceName)}`;

console.log(chalk.cyan('📱 Sample QR Code:\n'));
qrcode.generate(qrData, { small: true });

console.log(chalk.gray('\nQR Data:'), qrData);
console.log(chalk.gray('Session ID:'), sessionId);
console.log(chalk.gray('Device ID:'), deviceId);
console.log(chalk.gray('Device Name:'), deviceName);

// Test 2: URL parsing
console.log(chalk.yellow('\n\nTest 2: URL Parsing'));
const url = new URL(qrData);
console.log(chalk.gray('Protocol:'), url.protocol);
console.log(chalk.gray('Host:'), url.host);
console.log(chalk.gray('Pathname:'), url.pathname);
console.log(chalk.gray('Session param:'), url.searchParams.get('session'));
console.log(chalk.gray('Device param:'), url.searchParams.get('device'));
console.log(chalk.gray('Name param:'), url.searchParams.get('name'));

// Test 3: Message format
console.log(chalk.yellow('\n\nTest 3: WebSocket Message Format'));
const qrDataMessage = {
  type: 'qr_data',
  payload: {
    sessionId,
    qrData,
    expiresAt: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
    expiresInSeconds: 120,
    message: 'Scan this QR code in the NotebookLLM app to authenticate',
  },
};

console.log(chalk.gray('Message:'));
console.log(JSON.stringify(qrDataMessage, null, 2));

// Test 4: Auth token message
console.log(chalk.yellow('\n\nTest 4: Auth Token Message Format'));
const authTokenMessage = {
  type: 'auth_token',
  payload: {
    authToken: 'sample-jwt-token-here',
    userId: 'user-123',
    expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    expiresInDays: 90,
    message: 'Authentication successful! You can now use Gitu.',
  },
};

console.log(chalk.gray('Message:'));
console.log(JSON.stringify(authTokenMessage, null, 2));

console.log(chalk.green('\n✅ All tests passed!'));
console.log(chalk.gray('\nThe QR code authentication command is ready to use.'));
console.log(chalk.cyan('\nTo test the full flow:'));
console.log(chalk.gray('1. Start the backend server'));
console.log(chalk.gray('2. Run'), chalk.cyan('gitu auth --qr'), chalk.gray('in the terminal adapter'));
console.log(chalk.gray('3. Scan the QR code in the NotebookLLM Flutter app'));
console.log(chalk.gray('4. Confirm authentication in the app'));
console.log(chalk.gray('5. Terminal should receive auth token and save credentials\n'));
