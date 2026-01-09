import pool from '../config/database.js';

async function migrate() {
    try {
        console.log('Adding cover_url column to users table...');
        await pool.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS cover_url text
    `);
        console.log('Successfully added cover_url column');
    } catch (error) {
        console.error('Migration failed:', error);
    } finally {
        await pool.end();
    }
}

migrate();
