import pool from '../src/config/database.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
    try {
        console.log('🔄 Running social sharing migration...');

        const migrationSQL = fs.readFileSync(
            path.join(__dirname, 'add_social_sharing_columns.sql'),
            'utf8'
        );

        await pool.query(migrationSQL);

        console.log('✅ Migration completed successfully!');
        console.log('   - Added view_count to notebooks');
        console.log('   - Added share_count to notebooks');
        console.log('   - Added is_public to notebooks');
        console.log('   - Added is_locked to notebooks');
        console.log('   - Added category to notebooks');
        console.log('   - Added view_count to plans');
        console.log('   - Added share_count to plans');
        console.log('   - Added is_public to plans');
        console.log('   - Created performance indexes');

        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        console.error(error);
        process.exit(1);
    }
}

runMigration();
