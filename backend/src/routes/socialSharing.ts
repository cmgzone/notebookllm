import express, { type Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { socialSharingService } from '../services/socialSharingService.js';

const router = express.Router();
router.use(authenticateToken);

// =====================================================
// Share Content to Social Feed
// =====================================================
router.post('/share', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { contentType, contentId, caption, isPublic } = req.body;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    if (!['notebook', 'plan'].includes(contentType)) {
      return res.status(400).json({ error: 'contentType must be notebook or plan' });
    }

    const shared = await socialSharingService.shareContent({
      userId,
      contentType,
      contentId,
      caption,
      isPublic
    });

    res.json({ success: true, shared });
  } catch (error: any) {
    console.error('Share content error:', error);
    res.status(500).json({ error: error.message || 'Failed to share content' });
  }
});

// =====================================================
// Get Social Feed (Shared Content)
// =====================================================
router.get('/feed', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { limit, offset, contentType } = req.query;

    const feed = await socialSharingService.getSocialFeed(userId, {
      limit: limit ? parseInt(limit as string) : 20,
      offset: offset ? parseInt(offset as string) : 0,
      contentType: contentType as 'notebook' | 'plan' | 'all' | undefined
    });

    res.json({ success: true, feed });
  } catch (error: any) {
    console.error('Get social feed error:', error);
    res.status(500).json({ error: 'Failed to get social feed' });
  }
});

// =====================================================
// Discover Public Notebooks
// =====================================================
router.get('/discover/notebooks', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { limit, offset, search, category, sortBy } = req.query;

    const notebooks = await socialSharingService.discoverNotebooks(userId, {
      limit: limit ? parseInt(limit as string) : 20,
      offset: offset ? parseInt(offset as string) : 0,
      search: search as string,
      category: category as string,
      sortBy: sortBy as 'recent' | 'popular' | 'views'
    });

    res.json({ success: true, notebooks });
  } catch (error: any) {
    console.error('Discover notebooks error:', error);
    res.status(500).json({ error: 'Failed to discover notebooks' });
  }
});

// =====================================================
// Discover Public Plans
// =====================================================
router.get('/discover/plans', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { limit, offset, search, status, sortBy } = req.query;

    const plans = await socialSharingService.discoverPlans(userId, {
      limit: limit ? parseInt(limit as string) : 20,
      offset: offset ? parseInt(offset as string) : 0,
      search: search as string,
      status: status as string,
      sortBy: sortBy as 'recent' | 'popular' | 'views'
    });

    res.json({ success: true, plans });
  } catch (error: any) {
    console.error('Discover plans error:', error);
    res.status(500).json({ error: 'Failed to discover plans' });
  }
});

// =====================================================
// Set Notebook Public/Private
// =====================================================
router.patch('/notebooks/:id/visibility', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { id } = req.params;
    const { isPublic } = req.body;

    if (typeof isPublic !== 'boolean') {
      return res.status(400).json({ error: 'isPublic must be a boolean' });
    }

    await socialSharingService.setNotebookPublic(id, userId, isPublic);
    res.json({ success: true, isPublic });
  } catch (error: any) {
    console.error('Set notebook visibility error:', error);
    res.status(500).json({ error: error.message || 'Failed to update visibility' });
  }
});

// =====================================================
// Set Notebook Lock
// =====================================================
router.patch('/notebooks/:id/lock', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { id } = req.params;
    const { isLocked } = req.body;

    if (typeof isLocked !== 'boolean') {
      return res.status(400).json({ error: 'isLocked must be a boolean' });
    }

    await socialSharingService.setNotebookLocked(id, userId, isLocked);
    res.json({ success: true, isLocked });
  } catch (error: any) {
    console.error('Set notebook lock error:', error);
    res.status(500).json({ error: error.message || 'Failed to update lock status' });
  }
});

// =====================================================
// Set Plan Public/Private
// =====================================================
router.patch('/plans/:id/visibility', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { id } = req.params;
    const { isPublic } = req.body;

    if (typeof isPublic !== 'boolean') {
      return res.status(400).json({ error: 'isPublic must be a boolean' });
    }

    await socialSharingService.setPlanPublic(id, userId, isPublic);
    res.json({ success: true, isPublic });
  } catch (error: any) {
    console.error('Set plan visibility error:', error);
    res.status(500).json({ error: error.message || 'Failed to update visibility' });
  }
});

// =====================================================
// Record View
// =====================================================
router.post('/view', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    const { contentType, contentId } = req.body;
    const viewerIp = req.ip;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    const recorded = await socialSharingService.recordView(contentType, contentId, userId, viewerIp);
    res.json({ success: true, recorded });
  } catch (error: any) {
    console.error('Record view error:', error);
    res.status(500).json({ error: 'Failed to record view' });
  }
});

// =====================================================
// Get View Stats
// =====================================================
router.get('/stats/:contentType/:contentId', async (req: AuthRequest, res: Response) => {
  try {
    const { contentType, contentId } = req.params;

    const stats = await socialSharingService.getViewStats(contentType, contentId);
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Get view stats error:', error);
    res.status(500).json({ error: 'Failed to get view stats' });
  }
});

// =====================================================
// Like Content
// =====================================================
router.post('/like', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { contentType, contentId } = req.body;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    await socialSharingService.likeContent(contentType, contentId, userId);
    res.json({ success: true });
  } catch (error: any) {
    console.error('Like content error:', error);
    res.status(500).json({ error: 'Failed to like content' });
  }
});

// =====================================================
// Unlike Content
// =====================================================
router.delete('/like', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { contentType, contentId } = req.body;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    await socialSharingService.unlikeContent(contentType, contentId, userId);
    res.json({ success: true });
  } catch (error: any) {
    console.error('Unlike content error:', error);
    res.status(500).json({ error: 'Failed to unlike content' });
  }
});

// =====================================================
// Save Content (Bookmark)
// =====================================================
router.post('/save', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { contentType, contentId } = req.body;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    await socialSharingService.saveContent(contentType, contentId, userId);
    res.json({ success: true });
  } catch (error: any) {
    console.error('Save content error:', error);
    res.status(500).json({ error: 'Failed to save content' });
  }
});

// =====================================================
// Unsave Content
// =====================================================
router.delete('/save', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { contentType, contentId } = req.body;

    if (!contentType || !contentId) {
      return res.status(400).json({ error: 'contentType and contentId are required' });
    }

    await socialSharingService.unsaveContent(contentType, contentId, userId);
    res.json({ success: true });
  } catch (error: any) {
    console.error('Unsave content error:', error);
    res.status(500).json({ error: 'Failed to unsave content' });
  }
});

// =====================================================
// Get Saved Content
// =====================================================
router.get('/saved', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { limit, offset, contentType } = req.query;

    const saved = await socialSharingService.getSavedContent(userId, {
      limit: limit ? parseInt(limit as string) : 20,
      offset: offset ? parseInt(offset as string) : 0,
      contentType: contentType as string
    });

    res.json({ success: true, saved });
  } catch (error: any) {
    console.error('Get saved content error:', error);
    res.status(500).json({ error: 'Failed to get saved content' });
  }
});

// =====================================================
// Get User Content Stats
// =====================================================
router.get('/my-stats', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const stats = await socialSharingService.getUserContentStats(userId);
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Get user stats error:', error);
    res.status(500).json({ error: 'Failed to get user stats' });
  }
});

// =====================================================
// Get Public Notebook Details with Sources
// =====================================================
router.get('/public/notebooks/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const viewerId = req.userId; // Optional - user may not be logged in

    const details = await socialSharingService.getPublicNotebookDetails(id, viewerId);
    
    if (!details) {
      return res.status(404).json({ error: 'Notebook not found or not public' });
    }

    res.json({ success: true, ...details });
  } catch (error: any) {
    console.error('Get public notebook details error:', error);
    res.status(500).json({ error: 'Failed to get notebook details' });
  }
});

// =====================================================
// Get Public Source Details
// =====================================================
router.get('/public/sources/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const viewerId = req.userId;

    const source = await socialSharingService.getPublicSourceDetails(id, viewerId);
    
    if (!source) {
      return res.status(404).json({ error: 'Source not found or not public' });
    }

    res.json({ success: true, source });
  } catch (error: any) {
    console.error('Get public source details error:', error);
    res.status(500).json({ error: 'Failed to get source details' });
  }
});

// =====================================================
// Fork Notebook (Copy to User's Account)
// =====================================================
router.post('/fork/notebook/:id', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized - login required to fork' });

    const { id } = req.params;
    const { newTitle, includeSources } = req.body;

    const result = await socialSharingService.forkNotebook(id, userId, {
      newTitle,
      includeSources: includeSources !== false // Default to true
    });

    res.json({ 
      success: true, 
      notebook: result.notebook,
      sourcesCopied: result.sourcesCopied,
      message: `Notebook forked successfully with ${result.sourcesCopied} sources`
    });
  } catch (error: any) {
    console.error('Fork notebook error:', error);
    res.status(500).json({ error: error.message || 'Failed to fork notebook' });
  }
});

export default router;
