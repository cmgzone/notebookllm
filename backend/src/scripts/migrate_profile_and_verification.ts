import pool from '../config/database.js';

const migrate = async () => {
    try {
        console.log('Starting migration (Avatar & Verification)...');

        await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='avatar_url') THEN
          ALTER TABLE users ADD COLUMN avatar_url TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='verification_token') THEN
          ALTER TABLE users ADD COLUMN verification_token TEXT;
        END IF;
      END $$;
    `);

        console.log('Migration completed successfully.');
    } catch (error) {
        console.error('Migration failed:', error);
    } finally {
        process.exit();
    }
};

migrate();
