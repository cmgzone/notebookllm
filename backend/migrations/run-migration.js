import pkg from 'pg';
const { Pool } = pkg;
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Try multiple .env paths
const envPaths = [
    path.join(__dirname, '../../.env'),
    path.join(__dirname, '../.env'),
    path.join(process.cwd(), '.env'),
];

let envLoaded = false;
for (const envPath of envPaths) {
    if (fs.existsSync(envPath)) {
        console.log(`📁 Loading environment from: ${envPath}`);
        dotenv.config({ path: envPath });
        envLoaded = true;
        break;
    }
}

if (!envLoaded) {
    console.log('⚠️  No .env file found, using system environment variables');
}

async function runMigration() {
    if (!process.env.DATABASE_URL) {
        console.error('❌ DATABASE_URL not found in environment variables');
        console.error('\nPlease set DATABASE_URL in one of these locations:');
        envPaths.forEach(p => console.error(`  - ${p}`));
        console.error('\nOr run: export DATABASE_URL="your_neon_connection_string"');
        process.exit(1);
    }

    console.log('🔗 Connecting to database...');
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
    });

    try {
        console.log('🔄 Running social sharing migration...\n');

        const migrationSQL = fs.readFileSync(
            path.join(__dirname, 'add_social_sharing_columns.sql'),
            'utf8'
        );

        await pool.query(migrationSQL);

        console.log('✅ Migration completed successfully!\n');
        console.log('Added the following columns:');
        console.log('  📊 Notebooks: view_count, share_count, is_public, is_locked, category');
        console.log('  📊 Plans: view_count, share_count, is_public');
        console.log('  🚀 Created performance indexes\n');

        // Verify the migration
        const verifyNotebooks = await pool.query(`
      SELECT column_name, data_type, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'notebooks' 
        AND column_name IN ('view_count', 'share_count', 'is_public', 'is_locked')
      ORDER BY column_name;
    `);

        const verifyPlans = await pool.query(`
      SELECT column_name, data_type, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'plans' 
        AND column_name IN ('view_count', 'share_count', 'is_public')
      ORDER BY column_name;
    `);

        console.log('✅ Verification Results:\n');
        console.log('Notebooks table:');
        verifyNotebooks.rows.forEach(row => {
            console.log(`  - ${row.column_name} (${row.data_type}): default = ${row.column_default}`);
        });

        console.log('\nPlans table:');
        verifyPlans.rows.forEach(row => {
            console.log(`  - ${row.column_name} (${row.data_type}): default = ${row.column_default}`);
        });

        await pool.end();
        console.log('\n✅ Database connection closed');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        console.error(error);
        await pool.end();
        process.exit(1);
    }
}

runMigration();
