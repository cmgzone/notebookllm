import fs from 'fs';
import path from 'path';
import pool from '../config/database.js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Starting Gitu Upgrade migration...\n');
    
    await client.query('BEGIN');

    const migrationsDir = path.join(__dirname, '../../migrations');
    const files = [
      'update_gitu_platforms.sql',
      'add_gitu_agents.sql',
      'update_plugins_mcp.sql',
      'insert_agent_scheduler_task.sql'
    ];

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      if (fs.existsSync(filePath)) {
        console.log(`📝 Running ${file}...`);
        const sql = fs.readFileSync(filePath, 'utf8');
        await client.query(sql);
        console.log(`✅ ${file} executed successfully`);
      } else {
        console.warn(`⚠️  Warning: ${file} not found at ${filePath}`);
      }
    }
    
    await client.query('COMMIT');
    console.log('\n🎉 Gitu Upgrade migration completed successfully!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
