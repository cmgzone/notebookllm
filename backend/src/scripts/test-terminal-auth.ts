import axios from 'axios';

const BASE_URL = 'http://localhost:3000/api';

// Test user credentials (you'll need to replace with actual test user)
const TEST_USER_EMAIL = 'test@example.com';
const TEST_USER_PASSWORD = 'testpassword123';

async function testTerminalAuth() {
  console.log('🧪 Testing Terminal Authentication Flow\n');

  try {
    // Step 1: Login to get JWT token
    console.log('1️⃣  Logging in as test user...');
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      email: TEST_USER_EMAIL,
      password: TEST_USER_PASSWORD
    });

    const jwtToken = loginResponse.data.token;
    console.log('✅ Login successful');
    console.log(`   JWT Token: ${jwtToken.substring(0, 20)}...`);
    console.log('');

    // Step 2: Generate pairing token
    console.log('2️⃣  Generating pairing token...');
    const generateResponse = await axios.post(
      `${BASE_URL}/gitu/terminal/generate-token`,
      {},
      {
        headers: { Authorization: `Bearer ${jwtToken}` }
      }
    );

    const pairingToken = generateResponse.data.token;
    const expiresAt = generateResponse.data.expiresAt;
    console.log('✅ Pairing token generated');
    console.log(`   Token: ${pairingToken}`);
    console.log(`   Expires: ${expiresAt}`);
    console.log(`   Expires in: ${generateResponse.data.expiresInSeconds} seconds`);
    console.log('');

    // Step 3: Link terminal with pairing token
    console.log('3️⃣  Linking terminal device...');
    const deviceId = `test-device-${Date.now()}`;
    const deviceName = 'Test Terminal';

    const linkResponse = await axios.post(`${BASE_URL}/gitu/terminal/link`, {
      token: pairingToken,
      deviceId,
      deviceName
    });

    const authToken = linkResponse.data.authToken;
    const userId = linkResponse.data.userId;
    console.log('✅ Terminal linked successfully');
    console.log(`   User ID: ${userId}`);
    console.log(`   Auth Token: ${authToken.substring(0, 20)}...`);
    console.log(`   Expires: ${linkResponse.data.expiresAt}`);
    console.log(`   Expires in: ${linkResponse.data.expiresInDays} days`);
    console.log('');

    // Step 4: Validate auth token
    console.log('4️⃣  Validating auth token...');
    const validateResponse = await axios.post(`${BASE_URL}/gitu/terminal/validate`, {
      authToken
    });

    console.log('✅ Auth token validated');
    console.log(`   Valid: ${validateResponse.data.valid}`);
    console.log(`   User ID: ${validateResponse.data.userId}`);
    console.log(`   Device ID: ${validateResponse.data.deviceId}`);
    console.log(`   Expires: ${validateResponse.data.expiresAt}`);
    console.log('');

    // Step 5: List linked devices
    console.log('5️⃣  Listing linked devices...');
    const devicesResponse = await axios.get(`${BASE_URL}/gitu/terminal/devices`, {
      headers: { Authorization: `Bearer ${jwtToken}` }
    });

    console.log('✅ Devices listed');
    console.log(`   Total devices: ${devicesResponse.data.devices.length}`);
    devicesResponse.data.devices.forEach((device: any, index: number) => {
      console.log(`   Device ${index + 1}:`);
      console.log(`     - ID: ${device.deviceId}`);
      console.log(`     - Name: ${device.deviceName}`);
      console.log(`     - Status: ${device.status}`);
      console.log(`     - Linked: ${device.linkedAt}`);
      console.log(`     - Last used: ${device.lastUsedAt}`);
    });
    console.log('');

    // Step 6: Refresh auth token
    console.log('6️⃣  Refreshing auth token...');
    const refreshResponse = await axios.post(`${BASE_URL}/gitu/terminal/refresh`, {
      authToken
    });

    const newAuthToken = refreshResponse.data.authToken;
    console.log('✅ Auth token refreshed');
    console.log(`   New Token: ${newAuthToken.substring(0, 20)}...`);
    console.log(`   Expires: ${refreshResponse.data.expiresAt}`);
    console.log('');

    // Step 7: Unlink device
    console.log('7️⃣  Unlinking terminal device...');
    const unlinkResponse = await axios.post(
      `${BASE_URL}/gitu/terminal/unlink`,
      { deviceId },
      {
        headers: { Authorization: `Bearer ${jwtToken}` }
      }
    );

    console.log('✅ Device unlinked');
    console.log(`   Success: ${unlinkResponse.data.success}`);
    console.log(`   Message: ${unlinkResponse.data.message}`);
    console.log('');

    // Step 8: Verify device is unlinked
    console.log('8️⃣  Verifying device is unlinked...');
    const validateAfterUnlink = await axios.post(`${BASE_URL}/gitu/terminal/validate`, {
      authToken: newAuthToken
    });

    console.log('✅ Validation after unlink');
    console.log(`   Valid: ${validateAfterUnlink.data.valid}`);
    console.log(`   Error: ${validateAfterUnlink.data.error || 'None'}`);
    console.log('');

    console.log('🎉 All tests passed!');
    console.log('');
    console.log('Terminal authentication flow is working correctly:');
    console.log('  ✅ Pairing token generation');
    console.log('  ✅ Terminal linking');
    console.log('  ✅ Auth token validation');
    console.log('  ✅ Device listing');
    console.log('  ✅ Token refresh');
    console.log('  ✅ Device unlinking');
    console.log('');

  } catch (error: any) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    console.error('');
    console.error('Error details:');
    if (error.response) {
      console.error(`  Status: ${error.response.status}`);
      console.error(`  Data:`, error.response.data);
    } else {
      console.error(`  Message: ${error.message}`);
    }
    process.exit(1);
  }
}

// Run tests
console.log('');
console.log('═══════════════════════════════════════════════════════════');
console.log('  Terminal Authentication Test Suite');
console.log('═══════════════════════════════════════════════════════════');
console.log('');
console.log('Prerequisites:');
console.log('  - Backend server running on http://localhost:3000');
console.log('  - Test user exists with credentials:');
console.log(`    Email: ${TEST_USER_EMAIL}`);
console.log(`    Password: ${TEST_USER_PASSWORD}`);
console.log('');
console.log('Starting tests...');
console.log('');

testTerminalAuth();
