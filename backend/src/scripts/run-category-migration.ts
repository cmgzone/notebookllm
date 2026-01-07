
import pool from '../config/database.js';

async function runMigration() {
    const client = await pool.connect();

    try {
        console.log('🔧 Running category migration...');

        await client.query('BEGIN');

        // Add category column
        await client.query(`
      ALTER TABLE notebooks ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'General'
    `);
        console.log('✅ Added category column to notebooks');

        // Update existing notebooks
        await client.query(`
      UPDATE notebooks SET category = 'General' WHERE category IS NULL
    `);
        console.log('✅ Updated existing notebooks with default category');

        await client.query('COMMIT');
        console.log('✅ Migration completed successfully!');

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

runMigration().catch(console.error);
