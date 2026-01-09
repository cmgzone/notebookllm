import { socialSharingService } from '../services/socialSharingService.js';
import pool from '../config/database.js';

async function testPublicNotebookApi() {
  console.log('Testing public notebook API...\n');
  
  try {
    // Test with a known public notebook ID
    const notebookId = '23f5a2a0-2b4e-4038-a7f4-d28284530e0f';
    
    console.log(`Testing getPublicNotebookDetails for ID: ${notebookId}`);
    
    const result = await socialSharingService.getPublicNotebookDetails(notebookId);
    
    if (result) {
      console.log('\n✅ SUCCESS! Notebook found:');
      console.log(`  Title: ${result.notebook.title}`);
      console.log(`  Owner: ${result.owner.username}`);
      console.log(`  Sources: ${result.sources.length}`);
      console.log(`  is_public: ${result.notebook.is_public}`);
      console.log(`  is_locked: ${result.notebook.is_locked}`);
    } else {
      console.log('\n❌ FAILED: Notebook not found');
      
      // Debug: Check if notebook exists at all
      const debugResult = await pool.query(`
        SELECT id, title, is_public, is_locked 
        FROM notebooks 
        WHERE id = $1
      `, [notebookId]);
      
      if (debugResult.rows.length > 0) {
        console.log('\nDebug - Notebook exists in DB:');
        console.log(debugResult.rows[0]);
      } else {
        console.log('\nDebug - Notebook does NOT exist in DB');
      }
    }

    // Also test with the second notebook
    const notebookId2 = 'b31b548d-cf6d-4eaf-a89c-1e832111e8f4';
    console.log(`\n\nTesting getPublicNotebookDetails for ID: ${notebookId2}`);
    
    const result2 = await socialSharingService.getPublicNotebookDetails(notebookId2);
    
    if (result2) {
      console.log('\n✅ SUCCESS! Notebook found:');
      console.log(`  Title: ${result2.notebook.title}`);
      console.log(`  Owner: ${result2.owner.username}`);
      console.log(`  Sources: ${result2.sources.length}`);
    } else {
      console.log('\n❌ FAILED: Notebook not found');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

testPublicNotebookApi();
