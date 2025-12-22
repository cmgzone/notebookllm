import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        const result = await client.query('SELECT id, email, display_name, role, is_active, created_at FROM users LIMIT 10');
        console.log('Users count:', result.rows.length);
        console.log('Users:', JSON.stringify(result.rows, null, 2));
    } catch (error: any) {
        console.error('Error:', error.message);
    } finally {
        client.release();
        await pool.end();
    }
}

run();
