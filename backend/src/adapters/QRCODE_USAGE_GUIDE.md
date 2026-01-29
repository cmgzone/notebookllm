# QR Code Terminal Usage Guide

## Overview

The `qrcode-terminal` library has been installed to support QR code authentication for the Gitu terminal adapter. This allows users to scan a QR code in their terminal to authenticate their terminal session with the NotebookLLM Flutter app.

## Installation

✅ **Already installed!**

```bash
npm install qrcode-terminal
npm install --save-dev @types/qrcode-terminal
```

## Basic Usage

### Import the library

```typescript
import qrcode from 'qrcode-terminal';
```

### Generate a simple QR code

```typescript
// Small size (recommended for terminal)
qrcode.generate('Hello, World!', { small: true });

// Regular size
qrcode.generate('Hello, World!');
```

### Generate QR code with callback

```typescript
qrcode.generate('https://example.com', { small: true }, (qrcode) => {
  console.log('QR code generated!');
  // You can capture the QR code string here if needed
});
```

## Usage in Gitu Terminal Authentication

### Example: QR Code Authentication Flow

```typescript
import qrcode from 'qrcode-terminal';
import { v4 as uuidv4 } from 'uuid';

/**
 * Generate a QR code for terminal authentication
 */
async function generateAuthQRCode(userId: string): Promise<string> {
  // Generate a unique session ID
  const sessionId = uuidv4();
  
  // Create authentication URL
  const authUrl = `https://app.notebookllm.com/gitu/auth?session=${sessionId}&user=${userId}`;
  
  console.log('\n📱 Scan this QR code with your NotebookLLM app to authenticate:\n');
  
  // Generate QR code in terminal
  qrcode.generate(authUrl, { small: true });
  
  console.log('\nWaiting for authentication...');
  console.log('QR code expires in 2 minutes.\n');
  
  return sessionId;
}

/**
 * Display QR code for pairing token
 */
function displayPairingTokenQR(pairingToken: string): void {
  const authUrl = `gitu://auth?token=${pairingToken}`;
  
  console.log('\n╔════════════════════════════════════════╗');
  console.log('║  Scan QR Code to Link Terminal         ║');
  console.log('╚════════════════════════════════════════╝\n');
  
  qrcode.generate(authUrl, { small: true });
  
  console.log('\nAlternatively, enter this code in the app:');
  console.log(`\n  ${pairingToken}\n`);
  console.log('Code expires in 5 minutes.');
}
```

## Options

### Size Options

```typescript
// Small size (better for terminal)
qrcode.generate(text, { small: true });

// Regular size
qrcode.generate(text, { small: false });
```

### Error Correction Level

The library uses a default error correction level that works well for most use cases.

## Integration with Terminal Adapter

The QR code functionality will be integrated into the terminal adapter for the following commands:

1. **`gitu auth --qr`** - Display QR code for authentication
2. **`gitu link`** - Show QR code to link terminal with app
3. **`gitu pair`** - Generate pairing token with QR code

## Testing

Run the test script to verify the installation:

```bash
npx tsx src/scripts/test-qrcode-terminal.ts
```

## Best Practices

1. **Always use small size** - Terminal windows have limited space
2. **Add context** - Display instructions above/below the QR code
3. **Set expiry times** - QR codes for auth should expire quickly (2-5 minutes)
4. **Provide alternatives** - Always show the token/URL as text too
5. **Clear display** - Add spacing and borders for better visibility

## Example Output

```
╔════════════════════════════════════════╗
║  Scan QR Code to Link Terminal         ║
╚════════════════════════════════════════╝

▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄ ██ █ ▄▄▄▄▄ █
█ █   █ █ █▄▀▄█ █   █ █
█ █▄▄▄█ █▄▄▄███ █▄▄▄█ █
█▄▄▄▄▄▄▄█▄▀ █▄█▄▄▄▄▄▄▄█
█▄   ▀█▄█▄█ █▀ █▀▄  █ █
███▀██ ▄  █▄█ ▄█▄▀▀█ ▄█
██▄█▄▄█▄▄ ▀▀ ██▄▄▀█▀█ █
█ ▄▄▄▄▄ ██ ▄▀▀▀█▀▄▀▀███
█ █   █ █▀▄▀▄▀▄█▄▄   ██
█ █▄▄▄█ █  ▄█▄▀▀ ▀█▄█▀█
█▄▄▄▄▄▄▄█▄▄█▄██▄▄██▄███

Alternatively, enter this code in the app:

  ABC-123-XYZ

Code expires in 5 minutes.
```

## Resources

- [qrcode-terminal on npm](https://www.npmjs.com/package/qrcode-terminal)
- [GitHub Repository](https://github.com/gtanner/qrcode-terminal)

## Next Steps

This library is now ready to be integrated into:
- Task 1.3.3.2: QR Code Authentication (Alternative Method)
- Terminal adapter authentication commands
- Gitu terminal service
