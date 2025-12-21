import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get media content (binary)
router.get('/:sourceId', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceId } = req.params;

        // Verify ownership via notebook
        const result = await pool.query(
            `SELECT s.media_data, s.type FROM sources s
             INNER JOIN notebooks n ON s.notebook_id = n.id
             WHERE s.id = $1 AND n.user_id = $2`,
            [sourceId, req.userId]
        );

        if (result.rows.length === 0 || !result.rows[0].media_data) {
            return res.status(404).json({ error: 'Media not found' });
        }

        const type = result.rows[0].type;
        let contentType = 'application/octet-stream';
        if (type === 'image') contentType = 'image/png'; // Defaulting for simple binary BYTEA
        if (type === 'audio') contentType = 'audio/mpeg';
        if (type === 'video') contentType = 'video/mp4';

        res.setHeader('Content-Type', contentType);
        res.send(result.rows[0].media_data);
    } catch (error) {
        console.error('Get media error:', error);
        res.status(500).json({ error: 'Failed to fetch media' });
    }
});

// Get user media size stats
router.get('/stats/size', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query('SELECT get_user_media_size($1) as size', [req.userId]);
        res.json({ success: true, size: parseInt(result.rows[0].size || '0') });
    } catch (error) {
        console.error('Get media stats error:', error);
        res.status(500).json({ error: 'Failed to fetch media statistics' });
    }
});

export default router;
