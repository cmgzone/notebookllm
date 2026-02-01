
import pool from '../config/database.js';

async function debugScheduler() {
    console.log('🔍 Inspecting Gitu Scheduled Tasks...');
    try {
        const res = await pool.query('SELECT * FROM gitu_scheduled_tasks');
        console.log(`Found ${res.rows.length} tasks.`);
        res.rows.forEach((row, i) => {
            console.log(`\n[Task ${i + 1}] ID: ${row.id}`);
            console.log('Action (raw):', row.action);
            console.log('Action type:', typeof row.action);
            console.log('Trigger:', row.trigger);
        });
    } catch (e) {
        console.error('Error querying tasks:', e);
    } finally {
        await pool.end();
    }
}

debugScheduler();
