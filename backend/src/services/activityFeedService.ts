import pool from '../config/database.js';
import { friendService } from './friendService.js';

export type ActivityType = 
  | 'achievement_unlocked' 
  | 'quiz_completed' 
  | 'flashcard_deck_completed'
  | 'notebook_created' 
  | 'notebook_shared' 
  | 'study_streak' 
  | 'level_up'
  | 'joined_group' 
  | 'study_session_completed' 
  | 'friend_added'
  // New content-rich activity types
  | 'source_shared'
  | 'plan_shared'
  | 'podcast_generated'
  | 'research_completed'
  | 'image_uploaded'
  | 'ebook_created'
  | 'project_started'
  | 'mindmap_created'
  | 'infographic_created'
  | 'story_created';

export interface Activity {
  id: string;
  userId: string;
  activityType: ActivityType;
  title: string;
  description?: string;
  metadata: Record<string, any>;
  referenceId?: string;
  referenceType?: string;
  isPublic: boolean;
  createdAt: Date;
  username?: string;
  avatarUrl?: string;
  reactionCount?: number;
  userReaction?: string;
}

export const activityFeedService = {
  async createActivity(data: {
    userId: string;
    activityType: ActivityType;
    title: string;
    description?: string;
    metadata?: Record<string, any>;
    referenceId?: string;
    referenceType?: string;
    isPublic?: boolean;
  }) {
    const result = await pool.query(`
      INSERT INTO activities (user_id, activity_type, title, description, metadata, reference_id, reference_type, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [
      data.userId, 
      data.activityType, 
      data.title, 
      data.description,
      JSON.stringify(data.metadata || {}),
      data.referenceId,
      data.referenceType,
      data.isPublic ?? true
    ]);
    return result.rows[0];
  },

  async getFeed(userId: string, options: { limit?: number; offset?: number; filter?: ActivityType } = {}) {
    const { limit = 50, offset = 0, filter } = options;
    
    // Get friend IDs
    const friendIds = await friendService.getFriendIds(userId);
    const allUserIds = [userId, ...friendIds];

    const result = await pool.query(`
      SELECT 
        a.*,
        u.display_name as username,
        u.avatar_url,
        (SELECT COUNT(*) FROM activity_reactions WHERE activity_id = a.id) as reaction_count,
        (SELECT reaction_type FROM activity_reactions WHERE activity_id = a.id AND user_id = $1) as user_reaction
      FROM activities a
      JOIN users u ON u.id = a.user_id
      WHERE a.user_id = ANY($2)
        AND a.is_public = true
        ${filter ? 'AND a.activity_type = $5' : ''}
      ORDER BY a.created_at DESC
      LIMIT $3 OFFSET $4
    `, filter 
      ? [userId, allUserIds, limit, offset, filter]
      : [userId, allUserIds, limit, offset]
    );
    return result.rows;
  },


  async getUserActivities(userId: string, viewerId: string, limit = 20) {
    const areFriends = await friendService.areFriends(userId, viewerId);
    
    const result = await pool.query(`
      SELECT 
        a.*,
        u.display_name as username,
        u.avatar_url,
        (SELECT COUNT(*) FROM activity_reactions WHERE activity_id = a.id) as reaction_count,
        (SELECT reaction_type FROM activity_reactions WHERE activity_id = a.id AND user_id = $3) as user_reaction
      FROM activities a
      JOIN users u ON u.id = a.user_id
      WHERE a.user_id = $1
        AND (a.is_public = true OR $1 = $3 OR $4 = true)
      ORDER BY a.created_at DESC
      LIMIT $2
    `, [userId, limit, viewerId, areFriends]);
    return result.rows;
  },

  async addReaction(activityId: string, userId: string, reactionType: string) {
    const result = await pool.query(`
      INSERT INTO activity_reactions (activity_id, user_id, reaction_type)
      VALUES ($1, $2, $3)
      ON CONFLICT (activity_id, user_id) 
      DO UPDATE SET reaction_type = $3
      RETURNING *
    `, [activityId, userId, reactionType]);
    return result.rows[0];
  },

  async removeReaction(activityId: string, userId: string) {
    await pool.query(`
      DELETE FROM activity_reactions WHERE activity_id = $1 AND user_id = $2
    `, [activityId, userId]);
    return { success: true };
  },

  async getActivityReactions(activityId: string) {
    const result = await pool.query(`
      SELECT r.*, u.display_name as username, u.avatar_url
      FROM activity_reactions r
      JOIN users u ON u.id = r.user_id
      WHERE r.activity_id = $1
      ORDER BY r.created_at DESC
    `, [activityId]);
    return result.rows;
  },

  // Helper to create common activities
  async logAchievement(userId: string, achievementName: string, achievementId: string) {
    return this.createActivity({
      userId,
      activityType: 'achievement_unlocked',
      title: `Unlocked achievement: ${achievementName}`,
      referenceId: achievementId,
      referenceType: 'achievement',
      metadata: { achievementName }
    });
  },

  async logQuizCompleted(userId: string, quizTitle: string, score: number, quizId: string) {
    return this.createActivity({
      userId,
      activityType: 'quiz_completed',
      title: `Completed quiz: ${quizTitle}`,
      description: `Scored ${score}%`,
      referenceId: quizId,
      referenceType: 'quiz',
      metadata: { quizTitle, score }
    });
  },

  async logNotebookCreated(userId: string, notebookTitle: string, notebookId: string) {
    return this.createActivity({
      userId,
      activityType: 'notebook_created',
      title: `Created notebook: ${notebookTitle}`,
      referenceId: notebookId,
      referenceType: 'notebook',
      metadata: { notebookTitle }
    });
  },

  async logStudyStreak(userId: string, streakDays: number) {
    return this.createActivity({
      userId,
      activityType: 'study_streak',
      title: `${streakDays} day study streak! 🔥`,
      metadata: { streakDays }
    });
  },

  async logLevelUp(userId: string, newLevel: number) {
    return this.createActivity({
      userId,
      activityType: 'level_up',
      title: `Reached level ${newLevel}! 🎉`,
      metadata: { level: newLevel }
    });
  },

  // New content-rich activity helpers
  async logSourceShared(userId: string, sourceTitle: string, sourceId: string, sourceType: string) {
    return this.createActivity({
      userId,
      activityType: 'source_shared',
      title: `Shared a ${sourceType}: ${sourceTitle}`,
      referenceId: sourceId,
      referenceType: 'source',
      metadata: { sourceTitle, sourceType }
    });
  },

  async logPlanShared(userId: string, planTitle: string, planId: string, category?: string) {
    return this.createActivity({
      userId,
      activityType: 'plan_shared',
      title: `Shared project plan: ${planTitle}`,
      description: category ? `Category: ${category}` : undefined,
      referenceId: planId,
      referenceType: 'plan',
      metadata: { planTitle, category }
    });
  },

  async logPodcastGenerated(userId: string, podcastTitle: string, podcastId: string, duration?: number) {
    return this.createActivity({
      userId,
      activityType: 'podcast_generated',
      title: `Generated podcast: ${podcastTitle}`,
      description: duration ? `Duration: ${Math.round(duration / 60)} minutes` : undefined,
      referenceId: podcastId,
      referenceType: 'podcast',
      metadata: { podcastTitle, duration }
    });
  },

  async logResearchCompleted(userId: string, topic: string, researchId: string) {
    return this.createActivity({
      userId,
      activityType: 'research_completed',
      title: `Completed deep research: ${topic}`,
      referenceId: researchId,
      referenceType: 'research',
      metadata: { topic }
    });
  },

  async logImageUploaded(userId: string, imageCount: number, notebookId?: string) {
    return this.createActivity({
      userId,
      activityType: 'image_uploaded',
      title: `Uploaded ${imageCount} image${imageCount > 1 ? 's' : ''}`,
      referenceId: notebookId,
      referenceType: 'notebook',
      metadata: { imageCount }
    });
  },

  async logEbookCreated(userId: string, ebookTitle: string, ebookId: string) {
    return this.createActivity({
      userId,
      activityType: 'ebook_created',
      title: `Created ebook: ${ebookTitle}`,
      referenceId: ebookId,
      referenceType: 'ebook',
      metadata: { ebookTitle }
    });
  },

  async logProjectStarted(userId: string, projectTitle: string, projectId: string, category: string) {
    return this.createActivity({
      userId,
      activityType: 'project_started',
      title: `Started new ${category} project: ${projectTitle}`,
      referenceId: projectId,
      referenceType: 'project',
      metadata: { projectTitle, category }
    });
  },

  async logMindmapCreated(userId: string, mindmapTitle: string, mindmapId: string) {
    return this.createActivity({
      userId,
      activityType: 'mindmap_created',
      title: `Created mind map: ${mindmapTitle}`,
      referenceId: mindmapId,
      referenceType: 'mindmap',
      metadata: { mindmapTitle }
    });
  },

  async logInfographicCreated(userId: string, infographicTitle: string, infographicId: string) {
    return this.createActivity({
      userId,
      activityType: 'infographic_created',
      title: `Created infographic: ${infographicTitle}`,
      referenceId: infographicId,
      referenceType: 'infographic',
      metadata: { infographicTitle }
    });
  },

  async logStoryCreated(userId: string, storyTitle: string, storyId: string) {
    return this.createActivity({
      userId,
      activityType: 'story_created',
      title: `Created story: ${storyTitle}`,
      referenceId: storyId,
      referenceType: 'story',
      metadata: { storyTitle }
    });
  }
};
