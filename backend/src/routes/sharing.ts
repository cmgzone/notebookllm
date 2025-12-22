import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';

const router = express.Router();

// Create share token (Needs Auth)
router.post('/create', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, accessLevel, expiresInDays } = req.body;

        // Check ownership
        const ownerCheck = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (ownerCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Generate unique share token
        const shareToken = crypto.randomBytes(32).toString('hex');
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + (expiresInDays || 7));

        const result = await pool.query(
            `INSERT INTO notebook_shares (notebook_id, share_token, access_level, expires_at)
             VALUES ($1, $2, $3, $4)
             RETURNING *`,
            [notebookId, shareToken, accessLevel || 'read', expiresAt]
        );

        res.json({ 
            success: true, 
            share: {
                token: shareToken,
                accessLevel: result.rows[0].access_level,
                expiresAt: result.rows[0].expires_at
            }
        });
    } catch (error) {
        console.error('Create share token error:', error);
        res.status(500).json({ error: 'Failed to create share token' });
    }
});

// Validate share token (Public)
router.get('/validate/:token', async (req, res: Response) => {
    try {
        const { token } = req.params;

        const result = await pool.query(
            `SELECT ns.*, n.title as notebook_title, n.description as notebook_description
             FROM notebook_shares ns
             INNER JOIN notebooks n ON ns.notebook_id = n.id
             WHERE ns.share_token = $1 AND (ns.expires_at IS NULL OR ns.expires_at > NOW())`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.json({ 
                success: true, 
                validation: { valid: false, reason: 'Invalid or expired token' }
            });
        }

        const share = result.rows[0];
        res.json({ 
            success: true, 
            validation: {
                valid: true,
                notebookId: share.notebook_id,
                notebookTitle: share.notebook_title,
                notebookDescription: share.notebook_description,
                accessLevel: share.access_level,
                expiresAt: share.expires_at
            }
        });
    } catch (error) {
        console.error('Validate share token error:', error);
        res.status(500).json({ error: 'Failed to validate share token' });
    }
});

// List shares for a notebook (Needs Auth)
router.get('/list/:notebookId', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;

        // Verify ownership
        const ownerCheck = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (ownerCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const result = await pool.query(
            `SELECT id, share_token, access_level, expires_at, created_at
             FROM notebook_shares 
             WHERE notebook_id = $1
             ORDER BY created_at DESC`,
            [notebookId]
        );

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

        // Verify ownership
        const ownerCheck = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (ownerCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const result = await pool.query(
            'DELETE FROM notebook_shares WHERE notebook_id = $1 AND share_token = $2 RETURNING id',
            [notebookId, token]
        );

        res.json({ success: true, revoked: result.rowCount > 0 });
    } catch (error) {
        console.error('Revoke share error:', error);
        res.status(500).json({ error: 'Failed to revoke share' });
    }
});

// Get shared notebook content (Public with valid token)
router.get('/content/:token', async (req, res: Response) => {
    try {
        const { token } = req.params;

        // Validate token
        const shareResult = await pool.query(
            `SELECT ns.*, n.id as notebook_id
             FROM notebook_shares ns
             INNER JOIN notebooks n ON ns.notebook_id = n.id
             WHERE ns.share_token = $1 AND (ns.expires_at IS NULL OR ns.expires_at > NOW())`,
            [token]
        );

        if (shareResult.rows.length === 0) {
            return res.status(403).json({ error: 'Invalid or expired share token' });
        }

        const notebookId = shareResult.rows[0].notebook_id;

        // Get notebook
        const notebook = await pool.query(
            'SELECT id, title, description, cover_image, created_at FROM notebooks WHERE id = $1',
            [notebookId]
        );

        // Get sources (without media data for performance)
        const sources = await pool.query(
            'SELECT id, type, title, content, url, created_at FROM sources WHERE notebook_id = $1',
            [notebookId]
        );

        res.json({
            success: true,
            notebook: notebook.rows[0],
            sources: sources.rows
        });
    } catch (error) {
        console.error('Get shared content error:', error);
        res.status(500).json({ error: 'Failed to get shared content' });
    }
});

export default router;
