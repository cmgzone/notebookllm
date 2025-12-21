import express, { type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();

// All routes are protected
router.use(authenticateToken);

// Get all notebooks for the authenticated user
router.get('/', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM notebooks WHERE user_id = $1 ORDER BY updated_at DESC',
            [req.userId]
        );
        res.json({ success: true, notebooks: result.rows });
    } catch (error) {
        console.error('Get notebooks error:', error);
        res.status(500).json({ error: 'Failed to fetch notebooks' });
    }
});

// Get a single notebook
router.get('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            'SELECT * FROM notebooks WHERE id = $1 AND user_id = $2',
            [id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        res.json({ success: true, notebook: result.rows[0] });
    } catch (error) {
        console.error('Get notebook error:', error);
        res.status(500).json({ error: 'Failed to fetch notebook' });
    }
});

// Create a new notebook
router.post('/', async (req: AuthRequest, res: Response) => {
    try {
        const { title, description, coverImage } = req.body;

        if (!title) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const id = uuidv4();
        const result = await pool.query(
            `INSERT INTO notebooks (id, user_id, title, description, cover_image, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       RETURNING *`,
            [id, req.userId, title, description || null, coverImage || null]
        );

        res.status(201).json({ success: true, notebook: result.rows[0] });
    } catch (error) {
        console.error('Create notebook error:', error);
        res.status(500).json({ error: 'Failed to create notebook' });
    }
});

// Update a notebook
router.put('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { title, description, coverImage } = req.body;

        const updates: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        if (title !== undefined) {
            updates.push(`title = $${paramIndex++}`);
            values.push(title);
        }
        if (description !== undefined) {
            updates.push(`description = $${paramIndex++}`);
            values.push(description);
        }
        if (coverImage !== undefined) {
            updates.push(`cover_image = $${paramIndex++}`);
            values.push(coverImage);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        updates.push(`updated_at = NOW()`);
        values.push(id, req.userId);

        const result = await pool.query(
            `UPDATE notebooks SET ${updates.join(', ')} 
       WHERE id = $${paramIndex++} AND user_id = $${paramIndex++}
       RETURNING *`,
            values
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        res.json({ success: true, notebook: result.rows[0] });
    } catch (error) {
        console.error('Update notebook error:', error);
        res.status(500).json({ error: 'Failed to update notebook' });
    }
});

// Delete a notebook
router.delete('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            'DELETE FROM notebooks WHERE id = $1 AND user_id = $2 RETURNING id',
            [id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        res.json({ success: true, message: 'Notebook deleted' });
    } catch (error) {
        console.error('Delete notebook error:', error);
        res.status(500).json({ error: 'Failed to delete notebook' });
    }
});

export default router;
