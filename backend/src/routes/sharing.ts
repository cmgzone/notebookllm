import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();

// Publicly accessible if token is valid (some methods)
// router.use(authenticateToken); // We'll apply it per route

// Create share token (Needs Auth)
router.post('/create', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, accessLevel, expiresInDays } = req.body;

        // Check ownership
        const ownerCheck = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );
        if (ownerCheck.rows.length === 0) return res.status(403).json({ error: 'Access denied' });

        const result = await pool.query(
            'SELECT create_share_token($1, $2, $3) as share',
            [notebookId, accessLevel || 'read', expiresInDays || 7]
        );
        res.json({ success: true, share: result.rows[0].share });
    } catch (error) {
        console.error('Create share token error:', error);
        res.status(500).json({ error: 'Failed to create share token' });
    }
});

// Validate share token (Public)
router.get('/validate/:token', async (req, res: Response) => {
    try {
        const { token } = req.params;
        const result = await pool.query('SELECT validate_share_token($1) as validation', [token]);
        res.json({ success: true, validation: result.rows[0].validation });
    } catch (error) {
        console.error('Validate share token error:', error);
        res.status(500).json({ error: 'Failed to validate share token' });
    }
});

// List shares for a notebook (Needs Auth)
router.get('/list/:notebookId', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;
        const result = await pool.query('SELECT * FROM list_shares($1)', [notebookId]);
        res.json({ success: true, shares: result.rows });
    } catch (error) {
        console.error('List shares error:', error);
        res.status(500).json({ error: 'Failed to list shares' });
    }
});

// Revoke share (Needs Auth)
router.delete('/revoke/:notebookId/:token', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, token } = req.params;
        const result = await pool.query('SELECT revoke_share($1, $2) as revoked', [notebookId, token]);
        res.json({ success: true, revoked: result.rows[0].revoked });
    } catch (error) {
        console.error('Revoke share error:', error);
        res.status(500).json({ error: 'Failed to revoke share' });
    }
});

export default router;
