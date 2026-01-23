import pool from '../config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
    try {
        console.log('Running default AI model migration...');
        
        const migrationPath = path.join(__dirname, '../../migrations/add_default_ai_model.sql');
        const sql = fs.readFileSync(migrationPath, 'utf8');
        
        await pool.query(sql);
        
        console.log('✅ Default AI model migration completed successfully');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    }
}

runMigration();
