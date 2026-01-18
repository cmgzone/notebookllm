import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import {
    performDeepResearch,
    getResearchHistory,
    getResearchSession
} from '../controllers/deepResearchController.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * POST /api/research/deep
 * Perform deep research with streaming updates
 * 
 * Body:
 * - query: Research query (required)
 * - notebookId: Optional notebook to associate with
 * - maxResults: Max search results (default: 10)
 * - includeImages: Include image results (default: true)
 * 
 * Returns: SSE stream of research progress
 */
router.post('/deep', performDeepResearch);

/**
 * GET /api/research/history
 * Get research session history
 * 
 * Query:
 * - notebookId: Filter by notebook (optional)
 * - limit: Results per page (default: 50)
 * - offset: Pagination offset (default: 0)
 */
router.get('/history', getResearchHistory);

/**
 * GET /api/research/session/:sessionId
 * Get specific research session with all sources
 */
router.get('/session/:sessionId', getResearchSession);

export default router;
