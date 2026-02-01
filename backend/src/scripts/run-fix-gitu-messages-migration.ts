
import fs from 'fs';
import path from 'path';
import pool from '../config/database.js';

async function runMigration() {
    const client = await pool.connect();
    try {
        console.log('🚀 Starting Fix Migration...');
        const sqlPath = path.join(process.cwd(), 'migrations', 'fix_gitu_messages_schema.sql');
        console.log(`📖 Reading SQL from: ${sqlPath}`);

        if (!fs.existsSync(sqlPath)) {
            throw new Error(`Migration file not found at ${sqlPath}`);
        }

        const sql = fs.readFileSync(sqlPath, 'utf8');

        await client.query('BEGIN');
        await client.query(sql);
        await client.query('COMMIT');

        console.log('✅ Migration completed successfully.');
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', error);
        process.exit(1);
    } finally {
        client.release();
        await pool.end();
    }
}

runMigration();
