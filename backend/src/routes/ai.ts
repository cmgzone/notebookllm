import express, { type Request, type Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import {
    generateWithGemini,
    generateWithOpenRouter,
    generateSummary,
    generateQuestions,
    type ChatMessage
} from '../services/aiService.js';
import pool from '../config/database.js';

const router = express.Router();
router.use(authenticateToken);

// Chat completion endpoint
router.post('/chat', async (req: AuthRequest, res: Response) => {
    try {
        const { messages, provider = 'gemini', model } = req.body;

        if (!messages || !Array.isArray(messages)) {
            return res.status(400).json({ error: 'messages array is required' });
        }

        let response: string;
        if (provider === 'openrouter') {
            response = await generateWithOpenRouter(messages, model);
        } else {
            response = await generateWithGemini(messages, model);
        }

        res.json({ success: true, response });
    } catch (error: any) {
        console.error('Chat error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate response' });
    }
});

// Generate summary for content
router.post('/summary', async (req: AuthRequest, res: Response) => {
    try {
        const { content, provider = 'gemini' } = req.body;

        if (!content) {
            return res.status(400).json({ error: 'content is required' });
        }

        const summary = await generateSummary(content, provider);

        res.json({ success: true, summary });
    } catch (error: any) {
        console.error('Summary error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate summary' });
    }
});

// Generate questions for notebook
router.post('/questions', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, count = 5 } = req.body;

        if (!notebookId) {
            return res.status(400).json({ error: 'notebookId is required' });
        }

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id, title FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        // Get sources content
        const sourcesResult = await pool.query(
            `SELECT title, content FROM sources WHERE notebook_id = $1 LIMIT 10`,
            [notebookId]
        );

        const content = sourcesResult.rows
            .map(s => `${s.title}: ${s.content || ''}`)
            .join('\n\n')
            .substring(0, 5000); // Limit content length

        const questions = await generateQuestions(content, count);

        res.json({ success: true, questions });
    } catch (error: any) {
        console.error('Questions error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate questions' });
    }
});

// Generate notebook summary
router.post('/notebook-summary', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.body;

        if (!notebookId) {
            return res.status(400).json({ error: 'notebookId is required' });
        }

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        // Get all chunks for the notebook
        const chunksResult = await pool.query(
            `SELECT c.content_text FROM chunks c
       INNER JOIN sources s ON c.source_id = s.id
       WHERE s.notebook_id = $1
       ORDER BY c.chunk_index ASC
       LIMIT 100`,
            [notebookId]
        );

        const content = chunksResult.rows
            .map(c => c.content_text)
            .join(' ')
            .substring(0, 10000); // Limit content length

        const summary = await generateSummary(content);

        res.json({ success: true, summary });
    } catch (error: any) {
        console.error('Notebook summary error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate notebook summary' });
    }
});

export default router;
