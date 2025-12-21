import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get related sources
router.get('/:sourceId', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceId } = req.params;
        const result = await pool.query('SELECT * FROM get_related_sources($1)', [sourceId]);
        res.json({ success: true, sources: result.rows });
    } catch (error) {
        console.error('Get related sources error:', error);
        res.status(500).json({ error: 'Failed to fetch related sources' });
    }
});

export default router;
