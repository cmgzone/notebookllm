import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import {
    generateEmbedding,
    searchEmbeddings,
    storeEmbeddings
} from '../controllers/embeddingController.js';
import { processSource } from '../controllers/ingestionController.js';

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

/**
 * POST /api/embeddings/generate
 * Generate embedding for text
 */
router.post('/embeddings/generate', generateEmbedding);

/**
 * POST /api/embeddings/search
 * Semantic search over sources
 */
router.post('/embeddings/search', searchEmbeddings);

/**
 * POST /api/embeddings/store
 * Store embeddings in bulk (internal use mostly)
 */
router.post('/embeddings/store', storeEmbeddings);

/**
 * POST /api/ingestion/process
 * Process a source: chunk -> embed -> store
 */
router.post('/ingestion/process', processSource);

export default router;
