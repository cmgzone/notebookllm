import pool from '../config/database.js';

async function checkNotebooks() {
  try {
    console.log('🔍 Checking notebooks in database...\n');

    // Check if notebooks table exists
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'notebooks'
      );
    `);
    
    if (!tableCheck.rows[0].exists) {
      console.log('❌ Notebooks table does not exist!');
      console.log('Run migrations to create the table.');
      process.exit(1);
    }
    
    console.log('✅ Notebooks table exists\n');

    // Get all notebooks
    const notebooks = await pool.query(`
      SELECT 
        n.id, 
        n.user_id, 
        n.title, 
        n.description,
        n.created_at, 
        n.updated_at,
        u.email as user_email,
        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count
      FROM notebooks n
      LEFT JOIN users u ON n.user_id = u.id
      ORDER BY n.created_at DESC
      LIMIT 20
    `);

    console.log(`📚 Found ${notebooks.rows.length} notebooks:\n`);
    
    if (notebooks.rows.length === 0) {
      console.log('No notebooks found in database.');
      console.log('\nPossible issues:');
      console.log('1. No notebooks have been created yet');
      console.log('2. Notebooks are being created but not saved');
      console.log('3. User authentication issue - notebooks saved with wrong user_id');
    } else {
      notebooks.rows.forEach((nb, i) => {
        console.log(`${i + 1}. "${nb.title}"`);
        console.log(`   ID: ${nb.id}`);
        console.log(`   User: ${nb.user_email || nb.user_id}`);
        console.log(`   Sources: ${nb.source_count}`);
        console.log(`   Created: ${nb.created_at}`);
        console.log('');
      });
    }

    // Check users table
    const users = await pool.query(`
      SELECT id, email, created_at 
      FROM users 
      ORDER BY created_at DESC 
      LIMIT 5
    `);
    
    console.log(`\n👥 Recent users (${users.rows.length}):`);
    users.rows.forEach(u => {
      console.log(`   - ${u.email} (${u.id})`);
    });

    // Check for orphaned notebooks (user doesn't exist)
    const orphaned = await pool.query(`
      SELECT n.id, n.title, n.user_id
      FROM notebooks n
      LEFT JOIN users u ON n.user_id = u.id
      WHERE u.id IS NULL
    `);
    
    if (orphaned.rows.length > 0) {
      console.log(`\n⚠️ Found ${orphaned.rows.length} orphaned notebooks (user deleted):`);
      orphaned.rows.forEach(nb => {
        console.log(`   - "${nb.title}" (user_id: ${nb.user_id})`);
      });
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error checking notebooks:', error);
    process.exit(1);
  }
}

checkNotebooks();
