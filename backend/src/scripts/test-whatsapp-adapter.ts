import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load environment variables
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import pool from '../config/database.js';

async function main() {
    console.log('Starting WhatsApp Adapter Test...');

    // Test database connection
    try {
        await pool.query('SELECT NOW()');
        console.log('✅ Database connected');
    } catch (error) {
        console.error('❌ Database connection failed', error);
        process.exit(1);
    }

    // Initialize adapter
    // This will print the QR code in the terminal
    await whatsappAdapter.initialize({
        printQRInTerminal: true
    });

    console.log('✅ WhatsApp Adapter initialized. Scan the QR code above.');
    
    // Keep the process running
    process.stdin.resume();
}

main().catch(console.error);
