/**
 * End-to-End Test for Terminal Authentication Flow
 * 
 * This script tests the complete authentication flow:
 * 1. Generate pairing token
 * 2. Link terminal with token
 * 3. Validate auth token
 * 4. Refresh auth token
 * 5. Unlink terminal
 */

import { gituTerminalService } from '../services/gituTerminalService.js';
import pool from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';
import chalk from 'chalk';

async function testEndToEndAuthFlow() {
  console.log(chalk.bold.cyan('\n🧪 Terminal Authentication End-to-End Test\n'));

  let testUserId: string | null = null;
  const deviceId = `test-device-${Date.now()}`;
  const deviceName = 'Test Device E2E';

  try {
    // Step 1: Create test user
    console.log(chalk.yellow('Step 1: Creating test user...'));
    testUserId = uuidv4();
    const email = `test-e2e-${testUserId}@example.com`;
    
    await pool.query(
      `INSERT INTO users (id, email, password_hash)
       VALUES ($1, $2, $3)`,
      [testUserId, email, 'test-hash']
    );
    console.log(chalk.green('✓ Test user created:', testUserId));

    // Step 2: Generate pairing token
    console.log(chalk.yellow('\nStep 2: Generating pairing token...'));
    const pairingToken = await gituTerminalService.generatePairingToken(testUserId);
    console.log(chalk.green('✓ Pairing token generated:', pairingToken.code));
    console.log(chalk.gray('  Expires in:', pairingToken.expiresInSeconds, 'seconds'));

    // Step 3: Link terminal with pairing token
    console.log(chalk.yellow('\nStep 3: Linking terminal with pairing token...'));
    const linkResult = await gituTerminalService.linkTerminal(
      pairingToken.code,
      deviceId,
      deviceName
    );
    console.log(chalk.green('✓ Terminal linked successfully'));
    console.log(chalk.gray('  Auth token length:', linkResult.authToken.length));
    console.log(chalk.gray('  Expires in:', linkResult.expiresInDays, 'days'));

    // Step 4: Validate auth token
    console.log(chalk.yellow('\nStep 4: Validating auth token...'));
    const validation = await gituTerminalService.validateAuthToken(linkResult.authToken);
    if (!validation.valid) {
      throw new Error(`Token validation failed: ${validation.error}`);
    }
    console.log(chalk.green('✓ Auth token is valid'));
    console.log(chalk.gray('  User ID:', validation.userId));
    console.log(chalk.gray('  Device ID:', validation.deviceId));

    // Step 5: List linked devices
    console.log(chalk.yellow('\nStep 5: Listing linked devices...'));
    const devices = await gituTerminalService.listLinkedDevices(testUserId);
    console.log(chalk.green('✓ Found', devices.length, 'linked device(s)'));
    devices.forEach(device => {
      console.log(chalk.gray('  -', device.deviceName, `(${device.deviceId})`));
    });

    // Step 6: Refresh auth token
    console.log(chalk.yellow('\nStep 6: Refreshing auth token...'));
    // Wait 1 second to ensure different timestamp
    await new Promise(resolve => setTimeout(resolve, 1000));
    const refreshResult = await gituTerminalService.refreshAuthToken(linkResult.authToken);
    console.log(chalk.green('✓ Auth token refreshed'));
    console.log(chalk.gray('  New token length:', refreshResult.authToken.length));
    console.log(chalk.gray('  Token changed:', refreshResult.authToken !== linkResult.authToken));

    // Step 7: Validate refreshed token
    console.log(chalk.yellow('\nStep 7: Validating refreshed token...'));
    const refreshValidation = await gituTerminalService.validateAuthToken(refreshResult.authToken);
    if (!refreshValidation.valid) {
      throw new Error(`Refreshed token validation failed: ${refreshValidation.error}`);
    }
    console.log(chalk.green('✓ Refreshed token is valid'));

    // Step 8: Test invalid token
    console.log(chalk.yellow('\nStep 8: Testing invalid token...'));
    const invalidValidation = await gituTerminalService.validateAuthToken('invalid-token');
    if (invalidValidation.valid) {
      throw new Error('Invalid token was incorrectly validated as valid');
    }
    console.log(chalk.green('✓ Invalid token correctly rejected'));
    console.log(chalk.gray('  Error:', invalidValidation.error));

    // Step 9: Unlink terminal
    console.log(chalk.yellow('\nStep 9: Unlinking terminal...'));
    await gituTerminalService.unlinkTerminal(testUserId, deviceId);
    console.log(chalk.green('✓ Terminal unlinked'));

    // Step 10: Verify device is unlinked
    console.log(chalk.yellow('\nStep 10: Verifying device is unlinked...'));
    const devicesAfterUnlink = await gituTerminalService.listLinkedDevices(testUserId);
    const stillLinked = devicesAfterUnlink.find(d => d.deviceId === deviceId);
    if (stillLinked) {
      throw new Error('Device still appears in linked devices list');
    }
    console.log(chalk.green('✓ Device successfully unlinked'));

    // Step 11: Test token after unlink
    console.log(chalk.yellow('\nStep 11: Testing token after unlink...'));
    const unlinkedValidation = await gituTerminalService.validateAuthToken(refreshResult.authToken);
    if (unlinkedValidation.valid) {
      throw new Error('Token should be invalid after device unlink');
    }
    console.log(chalk.green('✓ Token correctly invalidated after unlink'));
    console.log(chalk.gray('  Error:', unlinkedValidation.error));

    // Success!
    console.log(chalk.bold.green('\n✅ All tests passed! Authentication flow works end-to-end.\n'));

  } catch (error) {
    console.error(chalk.bold.red('\n❌ Test failed:'), (error as Error).message);
    console.error(chalk.gray((error as Error).stack));
    process.exit(1);
  } finally {
    // Cleanup
    if (testUserId) {
      console.log(chalk.gray('\nCleaning up test data...'));
      await pool.query('DELETE FROM gitu_linked_accounts WHERE user_id = $1', [testUserId]);
      await pool.query('DELETE FROM gitu_pairing_tokens WHERE user_id = $1', [testUserId]);
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
      console.log(chalk.gray('✓ Cleanup complete'));
    }
    await pool.end();
  }
}

// Run the test
testEndToEndAuthFlow().catch(error => {
  console.error(chalk.red('Unhandled error:'), error);
  process.exit(1);
});
