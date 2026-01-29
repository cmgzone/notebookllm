import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load environment variables
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

import { terminalAdapter } from '../adapters/terminalAdapter.js';
import pool from '../config/database.js';

async function main() {
  console.log('Starting Gitu Terminal CLI...');

  // Test database connection
  try {
    await pool.query('SELECT NOW()');
  } catch (error) {
    console.error('❌ Failed to connect to database. Make sure the backend is configured correctly.');
    console.error(error);
    process.exit(1);
  }

  // Initialize adapter
  await terminalAdapter.initialize({
    prompt: 'Gitu> ',
    historySize: 100,
    colorOutput: true
  });

  // Start REPL
  terminalAdapter.startREPL();
}

main().catch(console.error);
