import pool from '../config/database.js';
import { activityFeedService } from '../services/activityFeedService.js';

async function test() {
  console.log('Testing feed for all users...\n');
  
  // Get all users
  const users = await pool.query('SELECT id, display_name FROM users ORDER BY display_name');
  
  for (const user of users.rows) {
    const feed = await activityFeedService.getFeed(user.id, { limit: 10 });
    if (feed.length > 0) {
      console.log(`✅ ${user.display_name} (${user.id}): ${feed.length} activities`);
    } else {
      console.log(`❌ ${user.display_name}: No activities`);
    }
  }
  
  await pool.end();
}

test();
