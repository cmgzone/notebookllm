import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get user statistics
router.get('/user-stats', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query('SELECT get_user_stats($1) as stats', [req.userId]);
        res.json({ success: true, stats: result.rows[0].stats });
    } catch (error) {
        console.error('Get user stats error:', error);
        res.status(500).json({ error: 'Failed to fetch user statistics' });
    }
});

// Get notebook analytics
router.get('/notebook/:notebookId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;
        const result = await pool.query('SELECT get_notebook_analytics($1) as analytics', [notebookId]);
        res.json({ success: true, analytics: result.rows[0].analytics });
    } catch (error) {
        console.error('Get notebook analytics error:', error);
        res.status(500).json({ error: 'Failed to fetch notebook analytics' });
    }
});

export default router;
