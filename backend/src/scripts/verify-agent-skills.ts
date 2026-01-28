import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

async function verifyAgentSkills() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined
  });

  try {
    console.log('🔍 Verifying agent skills tables...\n');

    // Check agent_skills table structure
    const skillsColumns = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'agent_skills'
      ORDER BY ordinal_position;
    `);

    console.log('📋 agent_skills table structure:');
    skillsColumns.rows.forEach(col => {
      console.log(`  ${col.column_name}: ${col.data_type} ${col.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
    });

    // Check skill_catalog table structure
    const catalogColumns = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'skill_catalog'
      ORDER BY ordinal_position;
    `);

    console.log('\n📋 skill_catalog table structure:');
    catalogColumns.rows.forEach(col => {
      console.log(`  ${col.column_name}: ${col.data_type} ${col.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
    });

    // Check indexes
    const indexes = await pool.query(`
      SELECT tablename, indexname, indexdef
      FROM pg_indexes
      WHERE tablename IN ('agent_skills', 'skill_catalog')
      ORDER BY tablename, indexname;
    `);

    console.log('\n🔑 Indexes:');
    indexes.rows.forEach(idx => {
      console.log(`  ${idx.tablename}.${idx.indexname}`);
    });

    // Check skill catalog entries
    const catalogEntries = await pool.query(`
      SELECT id, slug, name, description, is_active
      FROM skill_catalog
      ORDER BY created_at;
    `);

    console.log('\n🎯 Skill Catalog Entries:');
    catalogEntries.rows.forEach(skill => {
      console.log(`\n  ✓ ${skill.slug}`);
      console.log(`    Name: ${skill.name}`);
      console.log(`    Description: ${skill.description}`);
      console.log(`    Status: ${skill.is_active ? '✅ Active' : '❌ Inactive'}`);
    });

    console.log(`\n📊 Total catalog skills: ${catalogEntries.rows.length}`);

    // Check triggers
    const triggers = await pool.query(`
      SELECT trigger_name, event_manipulation, event_object_table
      FROM information_schema.triggers
      WHERE event_object_table IN ('agent_skills', 'skill_catalog')
      ORDER BY event_object_table, trigger_name;
    `);

    console.log('\n⚡ Triggers:');
    triggers.rows.forEach(trigger => {
      console.log(`  ${trigger.event_object_table}.${trigger.trigger_name} (${trigger.event_manipulation})`);
    });

    console.log('\n✅ Verification complete!');

  } catch (error) {
    console.error('❌ Verification failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

verifyAgentSkills().catch(console.error);
