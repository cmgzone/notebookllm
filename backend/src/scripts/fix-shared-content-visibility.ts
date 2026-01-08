import pool from '../config/database.js';

async function fixSharedContentVisibility() {
  console.log('Fixing shared content visibility...\n');

  try {
    // Fix existing shared notebooks to be public
    // notebooks.id is TEXT, shared_content.content_id is UUID
    const notebooksResult = await pool.query(`
      UPDATE notebooks n
      SET is_public = true, updated_at = NOW()
      FROM shared_content sc
      WHERE sc.content_id::text = n.id 
        AND sc.content_type = 'notebook'
        AND sc.is_public = true
        AND n.is_public = false
      RETURNING n.id, n.title
    `);
    
    console.log(`Updated ${notebooksResult.rowCount} notebooks to public:`);
    notebooksResult.rows.forEach(row => {
      console.log(`  - ${row.title} (${row.id})`);
    });

    // Fix existing shared plans to be public
    // plans.id is UUID, shared_content.content_id is UUID - should match directly
    const plansResult = await pool.query(`
      UPDATE plans p
      SET is_public = true, updated_at = NOW()
      FROM shared_content sc
      WHERE sc.content_id = p.id 
        AND sc.content_type = 'plan'
        AND sc.is_public = true
        AND p.is_public = false
      RETURNING p.id, p.title
    `);
    
    console.log(`\nUpdated ${plansResult.rowCount} plans to public:`);
    plansResult.rows.forEach(row => {
      console.log(`  - ${row.title} (${row.id})`);
    });

    // Show current stats
    const stats = await pool.query(`
      SELECT 
        (SELECT COUNT(*) FROM notebooks WHERE is_public = true) as public_notebooks,
        (SELECT COUNT(*) FROM plans WHERE is_public = true) as public_plans,
        (SELECT COUNT(*) FROM shared_content WHERE content_type = 'notebook') as shared_notebooks,
        (SELECT COUNT(*) FROM shared_content WHERE content_type = 'plan') as shared_plans
    `);
    
    console.log('\n--- Current Stats ---');
    console.log(`Public notebooks: ${stats.rows[0].public_notebooks}`);
    console.log(`Public plans: ${stats.rows[0].public_plans}`);
    console.log(`Shared notebook entries: ${stats.rows[0].shared_notebooks}`);
    console.log(`Shared plan entries: ${stats.rows[0].shared_plans}`);

    console.log('\n✅ Done! Shared content should now appear in Discover.');
  } catch (error) {
    console.error('Error fixing shared content visibility:', error);
  } finally {
    await pool.end();
  }
}

fixSharedContentVisibility();
