import pool from '../config/database.js';
import { friendService } from '../services/friendService.js';

async function testFindFriends() {
  try {
    // Get all users first
    const usersResult = await pool.query('SELECT id, display_name, email FROM users LIMIT 10');
    console.log('Users in database:');
    usersResult.rows.forEach(user => {
      console.log(`  - ${user.display_name || 'No name'} (${user.email}) - ID: ${user.id}`);
    });
    
    if (usersResult.rows.length < 2) {
      console.log('\nNot enough users to test friend search. Need at least 2 users.');
      return;
    }
    
    const testUser = usersResult.rows[0];
    console.log(`\nTesting search as user: ${testUser.display_name || testUser.email}`);
    
    // Test searching for other users
    const searchQuery = usersResult.rows[1].display_name?.substring(0, 3) || 
                        usersResult.rows[1].email.substring(0, 3);
    console.log(`\nSearching for: "${searchQuery}"`);
    
    const searchResults = await friendService.searchUsers(searchQuery, testUser.id);
    console.log(`Found ${searchResults.length} users:`);
    searchResults.forEach(user => {
      console.log(`  - ${user.username} (${user.email})`);
    });
    
    // Test searching by email
    console.log('\nSearching by email pattern...');
    const emailSearch = await friendService.searchUsers('@', testUser.id, 5);
    console.log(`Found ${emailSearch.length} users with @ in email/name:`);
    emailSearch.forEach(user => {
      console.log(`  - ${user.username} (${user.email})`);
    });
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await pool.end();
  }
}

testFindFriends();
