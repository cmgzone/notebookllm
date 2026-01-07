import pool from '../config/database.js';
import { friendService } from '../services/friendService.js';
import { studyGroupService } from '../services/studyGroupService.js';
import { activityFeedService } from '../services/activityFeedService.js';
import { leaderboardService } from '../services/leaderboardService.js';

async function testSocialAPI() {
  try {
    // Get a test user ID
    const userResult = await pool.query('SELECT id FROM users LIMIT 1');
    if (userResult.rows.length === 0) {
      console.log('No users found in database');
      return;
    }
    
    const testUserId = userResult.rows[0].id;
    console.log('Testing with user ID:', testUserId);
    
    // Test friends service
    console.log('\n--- Testing Friends Service ---');
    const friends = await friendService.getFriends(testUserId);
    console.log('Friends:', friends.length);
    
    const pendingRequests = await friendService.getPendingRequests(testUserId);
    console.log('Pending requests:', pendingRequests.length);
    
    // Test study groups service
    console.log('\n--- Testing Study Groups Service ---');
    const groups = await studyGroupService.getUserGroups(testUserId);
    console.log('Groups:', groups.length);
    
    const invitations = await studyGroupService.getUserPendingInvitations(testUserId);
    console.log('Invitations:', invitations.length);
    
    // Test activity feed service
    console.log('\n--- Testing Activity Feed Service ---');
    const activities = await activityFeedService.getFeed(testUserId, { limit: 10 });
    console.log('Activities:', activities.length);
    
    // Test leaderboard service
    console.log('\n--- Testing Leaderboard Service ---');
    const leaderboard = await leaderboardService.getGlobalLeaderboard('weekly', 'xp', 10);
    console.log('Leaderboard entries:', leaderboard.length);
    
    const userRank = await leaderboardService.getUserRank(testUserId, 'weekly', 'xp');
    console.log('User rank:', userRank);
    
    console.log('\n✅ All social services working correctly!');
    
  } catch (error) {
    console.error('Error testing social API:', error);
  } finally {
    await pool.end();
  }
}

testSocialAPI();
