import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        // Check app_settings table
        const tableCheck = await client.query(`
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'app_settings'
        `);
        console.log('app_settings columns:', tableCheck.rows);

        // Try to query it
        const data = await client.query("SELECT * FROM app_settings WHERE key = 'privacy_policy'");
        console.log('Privacy policy data:', data.rows);
    } catch (error: any) {
        console.error('Error:', error.message);
        
        // Create the table if it doesn't exist
        console.log('Creating app_settings table...');
        await client.query(`
            CREATE TABLE IF NOT EXISTS app_settings (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                key TEXT UNIQUE NOT NULL,
                content TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            )
        `);
        console.log('Table created!');
    } finally {
        client.release();
        await pool.end();
    }
}

run();
