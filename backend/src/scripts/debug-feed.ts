import pool from '../config/database.js';
import { friendService } from '../services/friendService.js';

async function debug() {
  console.log('Debugging activity feed...\n');
  
  // Get the activity
  const activities = await pool.query('SELECT * FROM activities');
  console.log('Activities:');
  activities.rows.forEach(a => {
    console.log(`  - ${a.title} by user ${a.user_id}`);
  });
  
  // Get friendships
  const friendships = await pool.query('SELECT * FROM friendships WHERE status = $1', ['accepted']);
  console.log('\nFriendships:');
  friendships.rows.forEach(f => {
    console.log(`  - ${f.user_id} <-> ${f.friend_id}`);
  });
  
  // Get users
  const users = await pool.query('SELECT id, display_name FROM users');
  console.log('\nUsers:');
  users.rows.forEach(u => {
    console.log(`  - ${u.id}: ${u.display_name}`);
  });
  
  // Test getFriendIds for each user
  console.log('\nFriend IDs for each user:');
  for (const user of users.rows) {
    const friendIds = await friendService.getFriendIds(user.id);
    console.log(`  ${user.display_name}: [${friendIds.join(', ')}]`);
  }
  
  // Check if activity user is in any friendship
  if (activities.rows.length > 0) {
    const activityUserId = activities.rows[0].user_id;
    console.log(`\nActivity was created by: ${activityUserId}`);
    
    const userInFriendship = friendships.rows.some(
      f => f.user_id === activityUserId || f.friend_id === activityUserId
    );
    console.log(`User is in a friendship: ${userInFriendship}`);
  }
  
  await pool.end();
}

debug();
