/**
 * Test script for Terminal CLI Adapter
 * 
 * This script demonstrates how to use the Terminal CLI adapter for Gitu.
 * It initializes the adapter and starts the REPL interface.
 * 
 * Usage:
 *   npx tsx src/scripts/test-terminal-adapter.ts <user-id>
 * 
 * Example:
 *   npx tsx src/scripts/test-terminal-adapter.ts test-user-123
 */

import { terminalAdapter } from '../adapters/terminalAdapter.js';
import { IncomingMessage } from '../services/gituMessageGateway.js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

/**
 * Main function to test the terminal adapter
 */
async function main() {
  // Get user ID from command line arguments
  const userId = process.argv[2];

  if (!userId) {
    console.error('❌ Error: User ID is required');
    console.log('\nUsage: npx tsx src/scripts/test-terminal-adapter.ts <user-id>');
    console.log('Example: npx tsx src/scripts/test-terminal-adapter.ts test-user-123');
    process.exit(1);
  }

  try {
    console.log(`\n🚀 Initializing Terminal CLI Adapter for user: ${userId}\n`);

    // Initialize the adapter
    await terminalAdapter.initialize({
      userId,
      colorOutput: true,
      historySize: 100,
    });

    // Register message handler
    terminalAdapter.onCommand(async (message: IncomingMessage) => {
      console.log('\n📨 Message received:', {
        id: message.id,
        userId: message.userId,
        platform: message.platform,
        text: message.content.text,
        timestamp: message.timestamp,
      });

      // Simulate AI response (in production, this would call the AI service)
      setTimeout(() => {
        terminalAdapter.sendResponse(
          `I received your message: "${message.content.text}"\n\n` +
          `This is a test response. In production, I would process your request ` +
          `using AI and provide a helpful answer.`
        );
      }, 1000);
    });

    // Start the REPL
    console.log('✅ Terminal adapter initialized successfully!\n');
    terminalAdapter.startREPL();

  } catch (error) {
    console.error('❌ Error initializing terminal adapter:', error);
    process.exit(1);
  }
}

// Run the main function
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
