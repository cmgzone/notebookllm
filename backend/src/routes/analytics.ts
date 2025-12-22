import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get user statistics
router.get('/user-stats', async (req: AuthRequest, res: Response) => {
    try {
        // Get notebook count
        const notebooksResult = await pool.query(
            'SELECT COUNT(*) as count FROM notebooks WHERE user_id = $1',
            [req.userId]
        );

        // Get source count
        const sourcesResult = await pool.query(
            `SELECT COUNT(*) as count FROM sources s
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE n.user_id = $1`,
            [req.userId]
        );

        // Get total chunks
        const chunksResult = await pool.query(
            `SELECT COUNT(*) as count FROM chunks c
             INNER JOIN sources s ON c.source_id = s.id
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE n.user_id = $1`,
            [req.userId]
        );

        // Get quiz stats
        const quizResult = await pool.query(
            'SELECT COUNT(*) as count, SUM(times_attempted) as attempts FROM quizzes WHERE user_id = $1',
            [req.userId]
        );

        // Get flashcard stats
        const flashcardResult = await pool.query(
            `SELECT COUNT(*) as deck_count, 
                    (SELECT COUNT(*) FROM flashcards f 
                     INNER JOIN flashcard_decks fd ON f.deck_id = fd.id 
                     WHERE fd.user_id = $1) as card_count
             FROM flashcard_decks WHERE user_id = $1`,
            [req.userId]
        );

        // Get user stats from gamification
        const userStatsResult = await pool.query(
            'SELECT * FROM user_stats WHERE user_id = $1',
            [req.userId]
        );

        const stats = {
            notebooks: parseInt(notebooksResult.rows[0].count),
            sources: parseInt(sourcesResult.rows[0].count),
            chunks: parseInt(chunksResult.rows[0].count),
            quizzes: parseInt(quizResult.rows[0].count),
            quizAttempts: parseInt(quizResult.rows[0].attempts || 0),
            flashcardDecks: parseInt(flashcardResult.rows[0].deck_count),
            flashcards: parseInt(flashcardResult.rows[0].card_count),
            ...(userStatsResult.rows[0] || {})
        };

        res.json({ success: true, stats });
    } catch (error) {
        console.error('Get user stats error:', error);
        res.status(500).json({ error: 'Failed to fetch user statistics' });
    }
});

// Get notebook analytics
router.get('/notebook/:notebookId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;

        // Verify ownership
        const notebookResult = await pool.query(
            'SELECT * FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        // Get source count by type
        const sourcesByType = await pool.query(
            `SELECT type, COUNT(*) as count 
             FROM sources WHERE notebook_id = $1 
             GROUP BY type`,
            [notebookId]
        );

        // Get total content size
        const contentSize = await pool.query(
            `SELECT SUM(LENGTH(content)) as total_chars 
             FROM sources WHERE notebook_id = $1`,
            [notebookId]
        );

        // Get chunk count
        const chunkCount = await pool.query(
            `SELECT COUNT(*) as count FROM chunks c
             INNER JOIN sources s ON c.source_id = s.id
             WHERE s.notebook_id = $1`,
            [notebookId]
        );

        // Get related study materials
        const quizCount = await pool.query(
            'SELECT COUNT(*) as count FROM quizzes WHERE notebook_id = $1',
            [notebookId]
        );

        const flashcardCount = await pool.query(
            'SELECT COUNT(*) as count FROM flashcard_decks WHERE notebook_id = $1',
            [notebookId]
        );

        const mindMapCount = await pool.query(
            'SELECT COUNT(*) as count FROM mind_maps WHERE notebook_id = $1',
            [notebookId]
        );

        const analytics = {
            notebook: notebookResult.rows[0],
            sourcesByType: sourcesByType.rows,
            totalCharacters: parseInt(contentSize.rows[0].total_chars || 0),
            chunkCount: parseInt(chunkCount.rows[0].count),
            quizCount: parseInt(quizCount.rows[0].count),
            flashcardDeckCount: parseInt(flashcardCount.rows[0].count),
            mindMapCount: parseInt(mindMapCount.rows[0].count)
        };

        res.json({ success: true, analytics });
    } catch (error) {
        console.error('Get notebook analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch notebook analytics' });
    }
});

// Get activity timeline
router.get('/activity', async (req: AuthRequest, res: Response) => {
    try {
        const days = parseInt(req.query.days as string) || 30;

        // Get recent notebooks
        const notebooks = await pool.query(
            `SELECT id, title, 'notebook' as type, created_at 
             FROM notebooks WHERE user_id = $1 AND created_at > NOW() - INTERVAL '${days} days'
             ORDER BY created_at DESC LIMIT 20`,
            [req.userId]
        );

        // Get recent sources
        const sources = await pool.query(
            `SELECT s.id, s.title, 'source' as type, s.created_at 
             FROM sources s
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE n.user_id = $1 AND s.created_at > NOW() - INTERVAL '${days} days'
             ORDER BY s.created_at DESC LIMIT 20`,
            [req.userId]
        );

        // Combine and sort
        const activity = [...notebooks.rows, ...sources.rows]
            .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
            .slice(0, 30);

        res.json({ success: true, activity });
    } catch (error) {
        console.error('Get activity error:', error);
        res.status(500).json({ error: 'Failed to fetch activity' });
    }
});

export default router;
