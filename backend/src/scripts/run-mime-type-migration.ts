#!/usr/bin/env tsx

import { readFileSync } from 'fs';
import { join } from 'path';
import pool from '../config/database.js';

async function runMimeTypeMigration() {
    console.log('🔧 Running mime_type column migration...');
    
    try {
        // Read the migration file
        const migrationPath = join(process.cwd(), 'migrations', 'add_mime_type_column.sql');
        const migrationSQL = readFileSync(migrationPath, 'utf8');
        
        // Execute the migration
        await pool.query(migrationSQL);
        
        console.log('✅ mime_type column migration completed successfully');
        
        // Verify the column exists
        const result = await pool.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'sources' AND column_name = 'mime_type'
        `);
        
        if (result.rows.length > 0) {
            console.log('✅ Verified: mime_type column exists');
            console.log('Column details:', result.rows[0]);
        } else {
            console.log('❌ Warning: mime_type column not found after migration');
        }
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    runMimeTypeMigration().catch(console.error);
}

export { runMimeTypeMigration };