import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        await client.query(`
            ALTER TABLE onboarding_screens 
            ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'auto_awesome'
        `);
        console.log('✅ Added icon_name column to onboarding_screens');
    } catch (error) {
        console.error('Error:', error);
    } finally {
        client.release();
        await pool.end();
    }
}

run();
