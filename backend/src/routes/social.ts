import { Router, type Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { friendService } from '../services/friendService.js';
import { studyGroupService } from '../services/studyGroupService.js';
import { activityFeedService } from '../services/activityFeedService.js';
import { leaderboardService } from '../services/leaderboardService.js';

const router = Router();

// All routes require authentication
router.use(authenticateToken);

// ============================================
// FRIENDS
// ============================================

// Search users
router.get('/users/search', async (req: AuthRequest, res: Response) => {
  try {
    const { q } = req.query;
    if (!q || typeof q !== 'string') {
      return res.status(400).json({ error: 'Search query required' });
    }
    const users = await friendService.searchUsers(q, req.userId!);
    res.json({ users });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get friends list
router.get('/friends', async (req: AuthRequest, res: Response) => {
  try {
    const friends = await friendService.getFriends(req.userId!);
    res.json({ friends });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get pending friend requests
router.get('/friends/requests', async (req: AuthRequest, res: Response) => {
  try {
    const [received, sent] = await Promise.all([
      friendService.getPendingRequests(req.userId!),
      friendService.getSentRequests(req.userId!)
    ]);
    res.json({ received, sent });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Send friend request
router.post('/friends/request', async (req: AuthRequest, res: Response) => {
  try {
    const { friendId } = req.body;
    const request = await friendService.sendFriendRequest(req.userId!, friendId);
    res.json({ request });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Accept friend request
router.post('/friends/accept/:id', async (req: AuthRequest, res: Response) => {
  try {
    const friendship = await friendService.acceptFriendRequest(req.params.id, req.userId!);
    res.json({ friendship });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Decline friend request
router.post('/friends/decline/:id', async (req: AuthRequest, res: Response) => {
  try {
    await friendService.declineFriendRequest(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Remove friend
router.delete('/friends/:id', async (req: AuthRequest, res: Response) => {
  try {
    await friendService.removeFriend(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// ============================================
// STUDY GROUPS
// ============================================

// Get pending group invitations (must be before :id routes)
router.get('/groups/invitations/pending', async (req: AuthRequest, res: Response) => {
  try {
    const invitations = await studyGroupService.getUserPendingInvitations(req.userId!);
    res.json({ invitations });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Accept group invitation
router.post('/groups/invitations/:id/accept', async (req: AuthRequest, res: Response) => {
  try {
    await studyGroupService.acceptInvitation(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Get user's groups
router.get('/groups', async (req: AuthRequest, res: Response) => {
  try {
    const groups = await studyGroupService.getUserGroups(req.userId!);
    res.json({ groups });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Create group
router.post('/groups', async (req: AuthRequest, res: Response) => {
  try {
    const { name, description, icon, isPublic } = req.body;
    const group = await studyGroupService.createGroup({
      name,
      description,
      icon,
      isPublic,
      ownerId: req.userId!
    });
    res.json({ group });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Get group details
router.get('/groups/:id', async (req: AuthRequest, res: Response) => {
  try {
    const group = await studyGroupService.getGroup(req.params.id, req.userId!);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }
    res.json({ group });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Update group
router.put('/groups/:id', async (req: AuthRequest, res: Response) => {
  try {
    const group = await studyGroupService.updateGroup(req.params.id, req.userId!, req.body);
    res.json({ group });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Delete group
router.delete('/groups/:id', async (req: AuthRequest, res: Response) => {
  try {
    await studyGroupService.deleteGroup(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Get group members
router.get('/groups/:id/members', async (req: AuthRequest, res: Response) => {
  try {
    const members = await studyGroupService.getMembers(req.params.id);
    res.json({ members });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Invite user to group
router.post('/groups/:id/invite', async (req: AuthRequest, res: Response) => {
  try {
    const { userId } = req.body;
    const invitation = await studyGroupService.inviteUser(req.params.id, userId, req.userId!);
    res.json({ invitation });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Leave group
router.post('/groups/:id/leave', async (req: AuthRequest, res: Response) => {
  try {
    await studyGroupService.leaveGroup(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Get pending group invitations
router.get('/groups/invitations/pending', async (req: AuthRequest, res: Response) => {
  try {
    const invitations = await studyGroupService.getUserPendingInvitations(req.userId!);
    res.json({ invitations });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Accept group invitation
router.post('/groups/invitations/:id/accept', async (req: AuthRequest, res: Response) => {
  try {
    await studyGroupService.acceptInvitation(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// Study sessions
router.post('/groups/:id/sessions', async (req: AuthRequest, res: Response) => {
  try {
    const { title, description, scheduledAt, durationMinutes, meetingUrl } = req.body;
    const session = await studyGroupService.createSession({
      groupId: req.params.id,
      title,
      description,
      scheduledAt: new Date(scheduledAt),
      durationMinutes,
      meetingUrl,
      createdBy: req.userId!
    });
    res.json({ session });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/groups/:id/sessions', async (req: AuthRequest, res: Response) => {
  try {
    const upcoming = req.query.upcoming !== 'false';
    const sessions = await studyGroupService.getGroupSessions(req.params.id, upcoming);
    res.json({ sessions });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Share notebook with group
router.post('/groups/:id/notebooks', async (req: AuthRequest, res: Response) => {
  try {
    const { notebookId, permission } = req.body;
    const share = await studyGroupService.shareNotebookWithGroup(
      notebookId, req.params.id, req.userId!, permission
    );
    res.json({ share });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/groups/:id/notebooks', async (req: AuthRequest, res: Response) => {
  try {
    const notebooks = await studyGroupService.getGroupSharedNotebooks(req.params.id);
    res.json({ notebooks });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// ACTIVITY FEED
// ============================================

router.get('/feed', async (req: AuthRequest, res: Response) => {
  try {
    const { limit, offset, filter } = req.query;
    const activities = await activityFeedService.getFeed(req.userId!, {
      limit: limit ? parseInt(limit as string) : undefined,
      offset: offset ? parseInt(offset as string) : undefined,
      filter: filter as any
    });
    res.json({ activities });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/users/:id/activities', async (req: AuthRequest, res: Response) => {
  try {
    const activities = await activityFeedService.getUserActivities(
      req.params.id, req.userId!
    );
    res.json({ activities });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/activities/:id/react', async (req: AuthRequest, res: Response) => {
  try {
    const { reactionType } = req.body;
    const reaction = await activityFeedService.addReaction(
      req.params.id, req.userId!, reactionType || 'like'
    );
    res.json({ reaction });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

router.delete('/activities/:id/react', async (req: AuthRequest, res: Response) => {
  try {
    await activityFeedService.removeReaction(req.params.id, req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// ============================================
// LEADERBOARD
// ============================================

router.get('/leaderboard', async (req: AuthRequest, res: Response) => {
  try {
    const { type, period, metric, limit } = req.query;
    const leaderboardType = type as string || 'global';
    const leaderboardPeriod = (period as any) || 'weekly';
    const leaderboardMetric = (metric as any) || 'xp';
    const leaderboardLimit = limit ? parseInt(limit as string) : 50;

    let leaderboard;
    if (leaderboardType === 'friends') {
      leaderboard = await leaderboardService.getFriendsLeaderboard(
        req.userId!, leaderboardPeriod, leaderboardMetric, leaderboardLimit
      );
    } else {
      leaderboard = await leaderboardService.getGlobalLeaderboard(
        leaderboardPeriod, leaderboardMetric, leaderboardLimit
      );
    }

    const userRank = await leaderboardService.getUserRank(
      req.userId!, leaderboardPeriod, leaderboardMetric
    );

    res.json({ leaderboard, userRank });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
