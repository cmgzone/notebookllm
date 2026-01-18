import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import { extractYouTubeContent } from '../controllers/youtubeController.js';
import { extractWebContent } from '../controllers/webContentController.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * POST /api/content/extract-youtube
 * Extract content from a YouTube video
 * 
 * Body:
 * - url: YouTube URL (required)
 * - videoId: Direct video ID (optional)
 */
router.post('/extract-youtube', extractYouTubeContent);

/**
 * POST /api/content/extract-web
 * Extract content from a web URL
 * 
 * Body:
 * - url: Web URL (required)
 */
router.post('/extract-web', extractWebContent);

export default router;
