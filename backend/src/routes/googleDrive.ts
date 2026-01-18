import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import { extractGoogleDriveContent } from '../controllers/googleDriveController.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * POST /api/google-drive/extract
 * Extract content from a Google Drive file
 * 
 * Body:
 * - url: Google Drive URL (required)
 * - fileId: Direct file ID (optional, extracted from URL if not provided)
 */
router.post('/extract', extractGoogleDriveContent);

export default router;
