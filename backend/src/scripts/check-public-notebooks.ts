import pool from '../config/database.js';

async function checkPublicNotebooks() {
  console.log('Checking public notebooks...\n');
  
  try {
    // Check all notebooks with their public/locked status
    const result = await pool.query(`
      SELECT 
        n.id, 
        n.title, 
        n.is_public, 
        n.is_locked,
        n.share_count,
        u.display_name as owner
      FROM notebooks n
      JOIN users u ON u.id = n.user_id
      ORDER BY n.share_count DESC, n.created_at DESC
      LIMIT 20
    `);

    console.log('Recent notebooks:');
    console.log('='.repeat(100));
    
    for (const row of result.rows) {
      const status: string[] = [];
      if (row.is_public) status.push('PUBLIC');
      else status.push('PRIVATE');
      if (row.is_locked) status.push('LOCKED');
      
      console.log(`ID: ${row.id}`);
      console.log(`  Title: ${row.title}`);
      console.log(`  Owner: ${row.owner}`);
      console.log(`  Status: ${status.join(', ')}`);
      console.log(`  Share Count: ${row.share_count || 0}`);
      console.log('');
    }

    // Count notebooks by status
    const countResult = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE is_public = true AND is_locked = false) as discoverable,
        COUNT(*) FILTER (WHERE is_public = true AND is_locked = true) as public_locked,
        COUNT(*) FILTER (WHERE is_public = false) as private,
        COUNT(*) as total
      FROM notebooks
    `);

    console.log('\nNotebook counts:');
    console.log(`  Discoverable (public + unlocked): ${countResult.rows[0].discoverable}`);
    console.log(`  Public but locked: ${countResult.rows[0].public_locked}`);
    console.log(`  Private: ${countResult.rows[0].private}`);
    console.log(`  Total: ${countResult.rows[0].total}`);

    // Check shared_content table
    const sharedResult = await pool.query(`
      SELECT 
        sc.content_id,
        sc.content_type,
        n.title,
        n.is_public,
        n.is_locked
      FROM shared_content sc
      LEFT JOIN notebooks n ON n.id = sc.content_id::text
      WHERE sc.content_type = 'notebook'
      LIMIT 10
    `);

    console.log('\n\nShared notebooks in shared_content table:');
    console.log('='.repeat(100));
    for (const row of sharedResult.rows) {
      console.log(`Content ID: ${row.content_id}`);
      console.log(`  Title: ${row.title || 'NOT FOUND'}`);
      console.log(`  is_public: ${row.is_public}`);
      console.log(`  is_locked: ${row.is_locked}`);
      console.log('');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

checkPublicNotebooks();
