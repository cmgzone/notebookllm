import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        // Check data with sort_order
        const data = await client.query('SELECT * FROM onboarding_screens ORDER BY sort_order ASC');
        console.log('Data count:', data.rows.length);
        console.log('Data:', JSON.stringify(data.rows, null, 2));
    } catch (error) {
        console.error('Error:', error);
    } finally {
        client.release();
        await pool.end();
    }
}

run();
