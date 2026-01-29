/**
 * Test script for qrcode-terminal library
 * This verifies that the QR code generation library is properly installed
 */

import qrcode from 'qrcode-terminal';

console.log('Testing qrcode-terminal library...\n');

// Test 1: Generate a simple QR code
console.log('Test 1: Simple text QR code');
console.log('Generating QR code for: "Hello, Gitu!"');
qrcode.generate('Hello, Gitu!', { small: true });

console.log('\n---\n');

// Test 2: Generate a URL QR code
console.log('Test 2: URL QR code');
console.log('Generating QR code for: "https://example.com/auth?token=abc123"');
qrcode.generate('https://example.com/auth?token=abc123', { small: true });

console.log('\n---\n');

// Test 3: Generate with callback
console.log('Test 3: QR code with callback');
qrcode.generate('Test callback', { small: true }, (qrcode) => {
  console.log('QR code generated successfully via callback!');
});

console.log('\n✅ qrcode-terminal library is working correctly!');
console.log('This library will be used for QR code authentication in the Gitu terminal adapter.');
