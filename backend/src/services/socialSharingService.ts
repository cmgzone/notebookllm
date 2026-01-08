import pool from '../config/database.js';
import { activityFeedService } from './activityFeedService.js';

export interface SharedContent {
  id: string;
  userId: string;
  contentType: 'notebook' | 'plan';
  contentId: string;
  caption?: string;
  isPublic: boolean;
  viewCount: number;
  createdAt: Date;
  // Joined fields
  username?: string;
  avatarUrl?: string;
  contentTitle?: string;
  contentDescription?: string;
  likeCount?: number;
  saveCount?: number;
  userLiked?: boolean;
  userSaved?: boolean;
}

export interface DiscoverableNotebook {
  id: string;
  userId: string;
  title: string;
  description?: string;
  coverImage?: string;
  category?: string;
  sourceCount: number;
  viewCount: number;
  shareCount: number;
  isPublic: boolean;
  isLocked: boolean;
  createdAt: Date;
  username?: string;
  avatarUrl?: string;
  likeCount?: number;
  userLiked?: boolean;
}

export interface DiscoverablePlan {
  id: string;
  userId: string;
  title: string;
  description?: string;
  status: string;
  viewCount: number;
  shareCount: number;
  isPublic: boolean;
  taskCount: number;
  completionPercentage: number;
  createdAt: Date;
  username?: string;
  avatarUrl?: string;
  likeCount?: number;
  userLiked?: boolean;
}

export const socialSharingService = {
  // =====================================================
  // Share Content to Social Feed
  // =====================================================
  async shareContent(data: {
    userId: string;
    contentType: 'notebook' | 'plan';
    contentId: string;
    caption?: string;
    isPublic?: boolean;
  }): Promise<SharedContent> {
    const { userId, contentType, contentId, caption, isPublic = true } = data;

    // Verify ownership
    const ownershipCheck = contentType === 'notebook'
      ? await pool.query('SELECT id, title FROM notebooks WHERE id = $1 AND user_id = $2', [contentId, userId])
      : await pool.query('SELECT id, title FROM plans WHERE id = $1 AND user_id = $2', [contentId, userId]);

    if (ownershipCheck.rows.length === 0) {
      throw new Error(`${contentType} not found or not owned by user`);
    }

    const contentTitle = ownershipCheck.rows[0].title;

    // Create shared content entry
    const result = await pool.query(`
      INSERT INTO shared_content (user_id, content_type, content_id, caption, is_public)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `, [userId, contentType, contentId, caption, isPublic]);

    // Update share count AND set is_public on original content
    // This makes the content discoverable in the discover feed
    if (contentType === 'notebook') {
      await pool.query(
        'UPDATE notebooks SET share_count = share_count + 1, is_public = $2, updated_at = NOW() WHERE id = $1', 
        [contentId, isPublic]
      );
    } else {
      await pool.query(
        'UPDATE plans SET share_count = share_count + 1, is_public = $2, updated_at = NOW() WHERE id = $1', 
        [contentId, isPublic]
      );
    }

    // Log activity
    await activityFeedService.createActivity({
      userId,
      activityType: 'content_shared',
      title: `Shared ${contentType}: ${contentTitle}`,
      description: caption,
      referenceId: result.rows[0].id,
      referenceType: 'shared_content',
      metadata: { contentType, contentId, contentTitle },
      isPublic
    });

    return result.rows[0];
  },

  // =====================================================
  // Get Social Feed (Shared Content)
  // =====================================================
  async getSocialFeed(userId: string, options: {
    limit?: number;
    offset?: number;
    contentType?: 'notebook' | 'plan' | 'all';
  } = {}): Promise<SharedContent[]> {
    const { limit = 20, offset = 0, contentType = 'all' } = options;

    const result = await pool.query(`
      SELECT 
        sc.*,
        u.display_name as username,
        u.avatar_url,
        CASE 
          WHEN sc.content_type = 'notebook' THEN (SELECT title FROM notebooks WHERE id = sc.content_id::text)
          WHEN sc.content_type = 'plan' THEN (SELECT title FROM plans WHERE id = sc.content_id)
        END as content_title,
        CASE 
          WHEN sc.content_type = 'notebook' THEN (SELECT description FROM notebooks WHERE id = sc.content_id::text)
          WHEN sc.content_type = 'plan' THEN (SELECT description FROM plans WHERE id = sc.content_id)
        END as content_description,
        (SELECT COUNT(*) FROM content_likes WHERE content_type = 'shared_content' AND content_id = sc.id) as like_count,
        (SELECT COUNT(*) FROM content_saves WHERE content_type = 'shared_content' AND content_id = sc.id) as save_count,
        EXISTS(SELECT 1 FROM content_likes WHERE content_type = 'shared_content' AND content_id = sc.id AND user_id = $1) as user_liked,
        EXISTS(SELECT 1 FROM content_saves WHERE content_type = 'shared_content' AND content_id = sc.id AND user_id = $1) as user_saved
      FROM shared_content sc
      JOIN users u ON u.id = sc.user_id
      WHERE sc.is_public = true
        ${contentType !== 'all' ? 'AND sc.content_type = $4' : ''}
      ORDER BY sc.created_at DESC
      LIMIT $2 OFFSET $3
    `, contentType !== 'all' 
      ? [userId, limit, offset, contentType]
      : [userId, limit, offset]
    );

    return result.rows;
  },

  // =====================================================
  // Discover Public Notebooks
  // =====================================================
  async discoverNotebooks(userId: string, options: {
    limit?: number;
    offset?: number;
    search?: string;
    category?: string;
    sortBy?: 'recent' | 'popular' | 'views';
  } = {}): Promise<DiscoverableNotebook[]> {
    const { limit = 20, offset = 0, search, category, sortBy = 'recent' } = options;

    let orderBy = 'n.created_at DESC';
    if (sortBy === 'popular') orderBy = 'like_count DESC, n.view_count DESC';
    if (sortBy === 'views') orderBy = 'n.view_count DESC';

    const params: any[] = [userId, limit, offset];
    let paramIndex = 4;
    let whereClause = 'WHERE n.is_public = true AND n.is_locked = false';

    if (search) {
      whereClause += ` AND (n.title ILIKE $${paramIndex} OR n.description ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    if (category) {
      whereClause += ` AND n.category = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }

    const result = await pool.query(`
      SELECT 
        n.*,
        u.display_name as username,
        u.avatar_url,
        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count,
        (SELECT COUNT(*) FROM content_likes WHERE content_type = 'notebook' AND content_id::text = n.id) as like_count,
        EXISTS(SELECT 1 FROM content_likes WHERE content_type = 'notebook' AND content_id::text = n.id AND user_id = $1) as user_liked
      FROM notebooks n
      JOIN users u ON u.id = n.user_id
      ${whereClause}
      ORDER BY ${orderBy}
      LIMIT $2 OFFSET $3
    `, params);

    return result.rows;
  },

  // =====================================================
  // Discover Public Plans
  // =====================================================
  async discoverPlans(userId: string, options: {
    limit?: number;
    offset?: number;
    search?: string;
    status?: string;
    sortBy?: 'recent' | 'popular' | 'views';
  } = {}): Promise<DiscoverablePlan[]> {
    const { limit = 20, offset = 0, search, status, sortBy = 'recent' } = options;

    let orderBy = 'p.created_at DESC';
    if (sortBy === 'popular') orderBy = 'like_count DESC, p.view_count DESC';
    if (sortBy === 'views') orderBy = 'p.view_count DESC';

    const params: any[] = [userId, limit, offset];
    let paramIndex = 4;
    let whereClause = 'WHERE p.is_public = true';

    if (search) {
      whereClause += ` AND (p.title ILIKE $${paramIndex} OR p.description ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    if (status) {
      whereClause += ` AND p.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    const result = await pool.query(`
      SELECT 
        p.id, p.user_id, p.title, p.description, p.status, 
        p.view_count, p.share_count, p.is_public, p.created_at,
        u.display_name as username,
        u.avatar_url,
        (SELECT COUNT(*) FROM plan_tasks WHERE plan_id = p.id) as task_count,
        (SELECT COALESCE(
          ROUND(COUNT(*) FILTER (WHERE status = 'completed')::numeric / NULLIF(COUNT(*), 0) * 100),
          0
        ) FROM plan_tasks WHERE plan_id = p.id) as completion_percentage,
        (SELECT COUNT(*) FROM content_likes WHERE content_type = 'plan' AND content_id = p.id) as like_count,
        EXISTS(SELECT 1 FROM content_likes WHERE content_type = 'plan' AND content_id = p.id AND user_id = $1) as user_liked
      FROM plans p
      JOIN users u ON u.id = p.user_id
      ${whereClause}
      ORDER BY ${orderBy}
      LIMIT $2 OFFSET $3
    `, params);

    return result.rows;
  },

  // =====================================================
  // Toggle Notebook Public/Private
  // =====================================================
  async setNotebookPublic(notebookId: string, userId: string, isPublic: boolean): Promise<void> {
    const result = await pool.query(
      'UPDATE notebooks SET is_public = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3 RETURNING id',
      [isPublic, notebookId, userId]
    );
    if (result.rows.length === 0) {
      throw new Error('Notebook not found or not owned by user');
    }
  },

  // =====================================================
  // Toggle Notebook Lock
  // =====================================================
  async setNotebookLocked(notebookId: string, userId: string, isLocked: boolean): Promise<void> {
    const result = await pool.query(
      'UPDATE notebooks SET is_locked = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3 RETURNING id',
      [isLocked, notebookId, userId]
    );
    if (result.rows.length === 0) {
      throw new Error('Notebook not found or not owned by user');
    }
  },

  // =====================================================
  // Toggle Plan Public/Private
  // =====================================================
  async setPlanPublic(planId: string, userId: string, isPublic: boolean): Promise<void> {
    const result = await pool.query(
      'UPDATE plans SET is_public = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3 RETURNING id',
      [isPublic, planId, userId]
    );
    if (result.rows.length === 0) {
      throw new Error('Plan not found or not owned by user');
    }
  },

  // =====================================================
  // Record View
  // =====================================================
  async recordView(contentType: string, contentId: string, viewerId?: string, viewerIp?: string): Promise<boolean> {
    const result = await pool.query(
      'SELECT increment_view_count($1, $2, $3, $4) as recorded',
      [contentType, contentId, viewerId, viewerIp]
    );
    return result.rows[0]?.recorded || false;
  },

  // =====================================================
  // Get View Stats
  // =====================================================
  async getViewStats(contentType: string, contentId: string): Promise<{
    totalViews: number;
    uniqueViewers: number;
    recentViews: number;
  }> {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_views,
        COUNT(DISTINCT viewer_id) as unique_viewers,
        COUNT(*) FILTER (WHERE viewed_at > NOW() - INTERVAL '7 days') as recent_views
      FROM content_views
      WHERE content_type = $1 AND content_id = $2
    `, [contentType, contentId]);

    return {
      totalViews: parseInt(result.rows[0]?.total_views) || 0,
      uniqueViewers: parseInt(result.rows[0]?.unique_viewers) || 0,
      recentViews: parseInt(result.rows[0]?.recent_views) || 0
    };
  },

  // =====================================================
  // Like Content
  // =====================================================
  async likeContent(contentType: string, contentId: string, userId: string): Promise<void> {
    await pool.query(`
      INSERT INTO content_likes (content_type, content_id, user_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (content_type, content_id, user_id) DO NOTHING
    `, [contentType, contentId, userId]);
  },

  // =====================================================
  // Unlike Content
  // =====================================================
  async unlikeContent(contentType: string, contentId: string, userId: string): Promise<void> {
    await pool.query(
      'DELETE FROM content_likes WHERE content_type = $1 AND content_id = $2 AND user_id = $3',
      [contentType, contentId, userId]
    );
  },

  // =====================================================
  // Save Content (Bookmark)
  // =====================================================
  async saveContent(contentType: string, contentId: string, userId: string): Promise<void> {
    await pool.query(`
      INSERT INTO content_saves (content_type, content_id, user_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (content_type, content_id, user_id) DO NOTHING
    `, [contentType, contentId, userId]);
  },

  // =====================================================
  // Unsave Content
  // =====================================================
  async unsaveContent(contentType: string, contentId: string, userId: string): Promise<void> {
    await pool.query(
      'DELETE FROM content_saves WHERE content_type = $1 AND content_id = $2 AND user_id = $3',
      [contentType, contentId, userId]
    );
  },

  // =====================================================
  // Get User's Saved Content
  // =====================================================
  async getSavedContent(userId: string, options: {
    limit?: number;
    offset?: number;
    contentType?: string;
  } = {}): Promise<any[]> {
    const { limit = 20, offset = 0, contentType } = options;

    const result = await pool.query(`
      SELECT 
        cs.*,
        CASE 
          WHEN cs.content_type = 'notebook' THEN (SELECT title FROM notebooks WHERE id = cs.content_id::text)
          WHEN cs.content_type = 'plan' THEN (SELECT title FROM plans WHERE id = cs.content_id)
          WHEN cs.content_type = 'shared_content' THEN (SELECT caption FROM shared_content WHERE id = cs.content_id)
        END as content_title,
        CASE 
          WHEN cs.content_type = 'notebook' THEN (SELECT user_id FROM notebooks WHERE id = cs.content_id::text)
          WHEN cs.content_type = 'plan' THEN (SELECT user_id FROM plans WHERE id = cs.content_id)
          WHEN cs.content_type = 'shared_content' THEN (SELECT user_id FROM shared_content WHERE id = cs.content_id)
        END as owner_id
      FROM content_saves cs
      WHERE cs.user_id = $1
        ${contentType ? 'AND cs.content_type = $4' : ''}
      ORDER BY cs.created_at DESC
      LIMIT $2 OFFSET $3
    `, contentType ? [userId, limit, offset, contentType] : [userId, limit, offset]);

    return result.rows;
  },

  // =====================================================
  // Get User's Own Content Stats
  // =====================================================
  async getUserContentStats(userId: string): Promise<{
    totalNotebooks: number;
    publicNotebooks: number;
    totalPlans: number;
    publicPlans: number;
    totalViews: number;
    totalLikes: number;
    totalShares: number;
  }> {
    const result = await pool.query(`
      SELECT 
        (SELECT COUNT(*) FROM notebooks WHERE user_id = $1) as total_notebooks,
        (SELECT COUNT(*) FROM notebooks WHERE user_id = $1 AND is_public = true) as public_notebooks,
        (SELECT COUNT(*) FROM plans WHERE user_id = $1) as total_plans,
        (SELECT COUNT(*) FROM plans WHERE user_id = $1 AND is_public = true) as public_plans,
        (SELECT COALESCE(SUM(view_count), 0) FROM notebooks WHERE user_id = $1) +
        (SELECT COALESCE(SUM(view_count), 0) FROM plans WHERE user_id = $1) as total_views,
        (SELECT COUNT(*) FROM content_likes cl 
         JOIN notebooks n ON cl.content_id::text = n.id AND cl.content_type = 'notebook' 
         WHERE n.user_id = $1) +
        (SELECT COUNT(*) FROM content_likes cl 
         JOIN plans p ON cl.content_id = p.id AND cl.content_type = 'plan' 
         WHERE p.user_id = $1) as total_likes,
        (SELECT COALESCE(SUM(share_count), 0) FROM notebooks WHERE user_id = $1) +
        (SELECT COALESCE(SUM(share_count), 0) FROM plans WHERE user_id = $1) as total_shares
    `, [userId]);

    const row = result.rows[0];
    return {
      totalNotebooks: parseInt(row?.total_notebooks) || 0,
      publicNotebooks: parseInt(row?.public_notebooks) || 0,
      totalPlans: parseInt(row?.total_plans) || 0,
      publicPlans: parseInt(row?.public_plans) || 0,
      totalViews: parseInt(row?.total_views) || 0,
      totalLikes: parseInt(row?.total_likes) || 0,
      totalShares: parseInt(row?.total_shares) || 0
    };
  },

  // =====================================================
  // Get Public Notebook Details with Sources
  // =====================================================
  async getPublicNotebookDetails(notebookId: string, viewerId?: string): Promise<{
    notebook: any;
    sources: any[];
    owner: any;
  } | null> {
    // Get notebook details
    const notebookResult = await pool.query(`
      SELECT 
        n.*,
        u.display_name as username,
        u.avatar_url,
        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count,
        (SELECT COUNT(*) FROM content_likes WHERE content_type = 'notebook' AND content_id::text = n.id) as like_count,
        ${viewerId ? `EXISTS(SELECT 1 FROM content_likes WHERE content_type = 'notebook' AND content_id::text = n.id AND user_id = $2) as user_liked` : 'false as user_liked'}
      FROM notebooks n
      JOIN users u ON u.id = n.user_id
      WHERE n.id = $1 AND n.is_public = true AND n.is_locked = false
    `, viewerId ? [notebookId, viewerId] : [notebookId]);

    if (notebookResult.rows.length === 0) {
      return null;
    }

    const notebook = notebookResult.rows[0];

    // Get sources (without full content for privacy, just metadata)
    const sourcesResult = await pool.query(`
      SELECT 
        id, notebook_id, title, type, added_at, 
        CASE 
          WHEN type = 'text' THEN LEFT(content, 500) || CASE WHEN LENGTH(content) > 500 THEN '...' ELSE '' END
          ELSE NULL 
        END as content_preview,
        summary,
        thumbnail_url,
        metadata
      FROM sources
      WHERE notebook_id = $1
      ORDER BY added_at DESC
    `, [notebookId]);

    return {
      notebook,
      sources: sourcesResult.rows,
      owner: {
        id: notebook.user_id,
        username: notebook.username,
        avatarUrl: notebook.avatar_url
      }
    };
  },

  // =====================================================
  // Get Public Source Details
  // =====================================================
  async getPublicSourceDetails(sourceId: string, viewerId?: string): Promise<any | null> {
    const result = await pool.query(`
      SELECT 
        s.*,
        n.title as notebook_title,
        n.is_public as notebook_is_public,
        n.is_locked as notebook_is_locked,
        u.display_name as owner_username,
        u.avatar_url as owner_avatar
      FROM sources s
      JOIN notebooks n ON n.id = s.notebook_id
      JOIN users u ON u.id = n.user_id
      WHERE s.id = $1 AND n.is_public = true AND n.is_locked = false
    `, [sourceId]);

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  },

  // =====================================================
  // Fork Notebook (Copy to User's Account)
  // =====================================================
  async forkNotebook(notebookId: string, userId: string, options: {
    newTitle?: string;
    includeSources?: boolean;
  } = {}): Promise<{ notebook: any; sourcesCopied: number }> {
    const { newTitle, includeSources = true } = options;

    // Get original notebook
    const originalResult = await pool.query(`
      SELECT n.*, u.display_name as original_owner
      FROM notebooks n
      JOIN users u ON u.id = n.user_id
      WHERE n.id = $1 AND n.is_public = true AND n.is_locked = false
    `, [notebookId]);

    if (originalResult.rows.length === 0) {
      throw new Error('Notebook not found or not available for forking');
    }

    const original = originalResult.rows[0];

    // Create new notebook
    const title = newTitle || `${original.title} (Fork)`;
    const description = `Forked from ${original.original_owner}'s notebook: ${original.title}`;

    const newNotebookResult = await pool.query(`
      INSERT INTO notebooks (user_id, title, description, category, icon, is_public, metadata)
      VALUES ($1, $2, $3, $4, $5, false, $6)
      RETURNING *
    `, [
      userId, 
      title, 
      description, 
      original.category,
      original.icon,
      JSON.stringify({
        forkedFrom: notebookId,
        originalOwner: original.user_id,
        originalTitle: original.title,
        forkedAt: new Date().toISOString()
      })
    ]);

    const newNotebook = newNotebookResult.rows[0];
    let sourcesCopied = 0;

    // Copy sources if requested
    if (includeSources) {
      const sourcesResult = await pool.query(`
        SELECT * FROM sources WHERE notebook_id = $1
      `, [notebookId]);

      for (const source of sourcesResult.rows) {
        await pool.query(`
          INSERT INTO sources (notebook_id, title, type, content, summary, thumbnail_url, metadata)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
        `, [
          newNotebook.id,
          source.title,
          source.type,
          source.content,
          source.summary,
          source.thumbnail_url,
          JSON.stringify({
            ...source.metadata,
            forkedFrom: source.id,
            originalNotebookId: notebookId
          })
        ]);
        sourcesCopied++;
      }
    }

    // Log activity
    await activityFeedService.createActivity({
      userId,
      activityType: 'notebook_forked',
      title: `Forked notebook: ${original.title}`,
      description: `Created "${title}" from ${original.original_owner}'s notebook`,
      referenceId: newNotebook.id,
      referenceType: 'notebook',
      metadata: { 
        originalNotebookId: notebookId,
        originalOwner: original.user_id,
        sourcesCopied
      },
      isPublic: false
    });

    return { notebook: newNotebook, sourcesCopied };
  }
};
