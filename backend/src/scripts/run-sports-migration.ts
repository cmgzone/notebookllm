import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pool from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function runMigration() {
    const client = await pool.connect();
    try {
        console.log('🚀 Running sports social migration...');
        
        const migrationPath = join(__dirname, '../../migrations/add_sports_social.sql');
        const sql = readFileSync(migrationPath, 'utf-8');
        
        await client.query(sql);
        
        console.log('✅ Sports social tables created successfully!');
        console.log('Tables created:');
        console.log('  - sports_predictions');
        console.log('  - sports_user_stats');
        console.log('  - sports_tipsters');
        console.log('  - sports_tipster_followers');
        console.log('  - sports_favorite_teams');
        console.log('  - sports_bankroll');
        console.log('  - sports_betting_slips');
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

runMigration().catch(console.error);
