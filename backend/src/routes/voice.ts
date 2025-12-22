import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, requireAdmin, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();

// Public endpoint - list available voice models (authenticated users)
router.get('/models', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT id, name, voice_id, provider, gender, language, description, is_active, is_premium 
             FROM voice_models WHERE is_active = true ORDER BY provider, name`
        );
        res.json({ success: true, voices: result.rows });
    } catch (error) {
        console.error('Error listing voice models:', error);
        res.status(500).json({ error: 'Failed to list voice models' });
    }
});

// Get voices by provider
router.get('/models/:provider', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { provider } = req.params;
        const result = await pool.query(
            `SELECT id, name, voice_id, provider, gender, language, description, is_active, is_premium 
             FROM voice_models WHERE provider = $1 AND is_active = true ORDER BY name`,
            [provider]
        );
        res.json({ success: true, voices: result.rows });
    } catch (error) {
        console.error('Error listing voice models by provider:', error);
        res.status(500).json({ error: 'Failed to list voice models' });
    }
});

// Admin endpoints for managing voice models
router.post('/models', authenticateToken, requireAdmin, async (req: AuthRequest, res: Response) => {
    try {
        const { name, voiceId, provider, gender, language, description, isActive, isPremium } = req.body;

        const result = await pool.query(`
            INSERT INTO voice_models (name, voice_id, provider, gender, language, description, is_active, is_premium)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
        `, [name, voiceId, provider, gender || 'neutral', language || 'en-US', description, isActive ?? true, isPremium ?? false]);

        res.json({ success: true, voice: result.rows[0] });
    } catch (error) {
        console.error('Error adding voice model:', error);
        res.status(500).json({ error: 'Failed to add voice model' });
    }
});

router.put('/models/:id', authenticateToken, requireAdmin, async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { name, voiceId, provider, gender, language, description, isActive, isPremium } = req.body;

        const result = await pool.query(`
            UPDATE voice_models SET
                name = $1, voice_id = $2, provider = $3, gender = $4, language = $5,
                description = $6, is_active = $7, is_premium = $8, updated_at = NOW()
            WHERE id = $9
            RETURNING *
        `, [name, voiceId, provider, gender, language, description, isActive, isPremium, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Voice model not found' });
        }

        res.json({ success: true, voice: result.rows[0] });
    } catch (error) {
        console.error('Error updating voice model:', error);
        res.status(500).json({ error: 'Failed to update voice model' });
    }
});

router.delete('/models/:id', authenticateToken, requireAdmin, async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'DELETE FROM voice_models WHERE id = $1 RETURNING id',
            [req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Voice model not found' });
        }

        res.json({ success: true, message: 'Voice model deleted' });
    } catch (error) {
        console.error('Error deleting voice model:', error);
        res.status(500).json({ error: 'Failed to delete voice model' });
    }
});

export default router;
