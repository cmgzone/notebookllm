import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get related sources based on content similarity
router.get('/:sourceId', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceId } = req.params;
        const limit = parseInt(req.query.limit as string) || 5;

        // Get the source and its notebook
        const sourceResult = await pool.query(
            `SELECT s.*, n.user_id FROM sources s
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE s.id = $1`,
            [sourceId]
        );

        if (sourceResult.rows.length === 0) {
            return res.status(404).json({ error: 'Source not found' });
        }

        const source = sourceResult.rows[0];

        // Verify ownership
        if (source.user_id !== req.userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Find related sources based on:
        // 1. Same notebook (highest priority)
        // 2. Same type
        // 3. Similar title words
        // 4. Shared tags

        const relatedResult = await pool.query(
            `SELECT DISTINCT s.id, s.notebook_id, s.type, s.title, s.url, s.created_at,
                    n.title as notebook_title,
                    CASE 
                        WHEN s.notebook_id = $2 THEN 3
                        WHEN s.type = $3 THEN 2
                        ELSE 1
                    END as relevance_score
             FROM sources s
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE n.user_id = $1 
               AND s.id != $4
               AND (
                   s.notebook_id = $2
                   OR s.type = $3
                   OR EXISTS (
                       SELECT 1 FROM source_tags st1
                       INNER JOIN source_tags st2 ON st1.tag_id = st2.tag_id
                       WHERE st1.source_id = $4 AND st2.source_id = s.id
                   )
               )
             ORDER BY relevance_score DESC, s.created_at DESC
             LIMIT $5`,
            [req.userId, source.notebook_id, source.type, sourceId, limit]
        );

        res.json({ success: true, sources: relatedResult.rows });
    } catch (error) {
        console.error('Get related sources error:', error);
        res.status(500).json({ error: 'Failed to fetch related sources' });
    }
});

// Get recommended notebooks based on user activity
router.get('/notebooks/suggested', async (req: AuthRequest, res: Response) => {
    try {
        const limit = parseInt(req.query.limit as string) || 5;

        // Get notebooks with most recent activity
        const result = await pool.query(
            `SELECT n.*, 
                    (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count,
                    (SELECT MAX(created_at) FROM sources WHERE notebook_id = n.id) as last_source_added
             FROM notebooks n
             WHERE n.user_id = $1
             ORDER BY n.updated_at DESC
             LIMIT $2`,
            [req.userId, limit]
        );

        res.json({ success: true, notebooks: result.rows });
    } catch (error) {
        console.error('Get suggested notebooks error:', error);
        res.status(500).json({ error: 'Failed to fetch suggested notebooks' });
    }
});

// Get study recommendations
router.get('/study/next', async (req: AuthRequest, res: Response) => {
    try {
        const recommendations: Array<{
            type: string;
            title: string;
            count: number;
            items: any[];
        }> = [];

        // Check for flashcards due for review
        const flashcardsResult = await pool.query(
            `SELECT f.*, fd.title as deck_title
             FROM flashcards f
             INNER JOIN flashcard_decks fd ON f.deck_id = fd.id
             WHERE fd.user_id = $1 
               AND (f.next_review_at IS NULL OR f.next_review_at <= NOW())
             ORDER BY f.next_review_at ASC NULLS FIRST
             LIMIT 5`,
            [req.userId]
        );

        if (flashcardsResult.rows.length > 0) {
            recommendations.push({
                type: 'flashcards',
                title: 'Flashcards due for review',
                count: flashcardsResult.rows.length,
                items: flashcardsResult.rows
            });
        }

        // Check for quizzes not attempted recently
        const quizzesResult = await pool.query(
            `SELECT q.*, n.title as notebook_title
             FROM quizzes q
             LEFT JOIN notebooks n ON q.notebook_id = n.id
             WHERE q.user_id = $1 
               AND (q.last_attempted_at IS NULL OR q.last_attempted_at < NOW() - INTERVAL '7 days')
             ORDER BY q.last_attempted_at ASC NULLS FIRST
             LIMIT 3`,
            [req.userId]
        );

        if (quizzesResult.rows.length > 0) {
            recommendations.push({
                type: 'quizzes',
                title: 'Quizzes to practice',
                count: quizzesResult.rows.length,
                items: quizzesResult.rows
            });
        }

        // Check for notebooks without study materials
        const notebooksResult = await pool.query(
            `SELECT n.*, 
                    (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count
             FROM notebooks n
             WHERE n.user_id = $1
               AND NOT EXISTS (SELECT 1 FROM quizzes WHERE notebook_id = n.id)
               AND NOT EXISTS (SELECT 1 FROM flashcard_decks WHERE notebook_id = n.id)
               AND (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) > 0
             ORDER BY n.updated_at DESC
             LIMIT 3`,
            [req.userId]
        );

        if (notebooksResult.rows.length > 0) {
            recommendations.push({
                type: 'create_study_materials',
                title: 'Create study materials for these notebooks',
                count: notebooksResult.rows.length,
                items: notebooksResult.rows
            });
        }

        res.json({ success: true, recommendations });
    } catch (error) {
        console.error('Get study recommendations error:', error);
        res.status(500).json({ error: 'Failed to fetch study recommendations' });
    }
});

export default router;
