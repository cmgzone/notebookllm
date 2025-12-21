import pool from '../config/database.js';

const migrate = async () => {
    try {
        console.log('Starting migration...');

        // Check if columns exist, if not add them
        await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email_verified') THEN
          ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='two_factor_enabled') THEN
          ALTER TABLE users ADD COLUMN two_factor_enabled BOOLEAN DEFAULT FALSE;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='two_factor_secret') THEN
          ALTER TABLE users ADD COLUMN two_factor_secret TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='reset_token') THEN
          ALTER TABLE users ADD COLUMN reset_token TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='reset_token_expiry') THEN
          ALTER TABLE users ADD COLUMN reset_token_expiry TIMESTAMP;
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
