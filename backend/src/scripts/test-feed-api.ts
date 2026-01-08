import { activityFeedService } from '../services/activityFeedService.js';
import pool from '../config/database.js';

async function test() {
  // Test with cmgmerlin's user ID
  const userId = '724ddba6-1b10-48f8-a284-afcb90b9559b';
  
  console.log(`Testing feed for user: ${userId}\n`);
  
  const feed = await activityFeedService.getFeed(userId, { limit: 20, offset: 0 });
  
  console.log(`Feed returned ${feed.length} activities:`);
  feed.forEach((a, i) => {
    console.log(`  ${i + 1}. [${a.activity_type}] ${a.title}`);
    console.log(`     User: ${a.username} (${a.user_id})`);
    console.log(`     Reactions: ${a.reaction_count}`);
  });
  
  await pool.end();
}

test();
