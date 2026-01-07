import express, { type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get all notebooks for the authenticated user
router.get('/', async (req: AuthRequest, res: Response) => {
    try {
        console.log(`[Notebooks] GET / - userId: ${req.userId}`);

        // First try with agent session info, fall back to simple query if agent_sessions table doesn't exist
        let result;
        try {
            result = await pool.query(
                `SELECT n.*, 
                        COALESCE(n.is_agent_notebook, false) as is_agent_notebook,
                        n.agent_session_id,
                        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count,
                        (SELECT agent_name FROM agent_sessions WHERE id = n.agent_session_id) as agent_name,
                        (SELECT agent_identifier FROM agent_sessions WHERE id = n.agent_session_id) as agent_identifier,
                        (SELECT status FROM agent_sessions WHERE id = n.agent_session_id) as agent_status
                 FROM notebooks n 
                 WHERE n.user_id = $1 
                 ORDER BY n.updated_at DESC`,
                [req.userId]
            );
        } catch (subqueryError: any) {
            // If agent_sessions table doesn't exist, use simpler query
            console.log('Falling back to simple notebooks query:', subqueryError.message);
            result = await pool.query(
                `SELECT n.*, 
                        COALESCE(n.is_agent_notebook, false) as is_agent_notebook,
                        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count
                 FROM notebooks n 
                 WHERE n.user_id = $1 
                 ORDER BY n.updated_at DESC`,
                [req.userId]
            );
        }

        console.log(`[Notebooks] Found ${result.rows.length} notebooks for user ${req.userId}`);
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
            `SELECT n.*, 
                    (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count
             FROM notebooks n 
             WHERE n.id = $1 AND n.user_id = $2`,
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
        const { title, description, coverImage, category } = req.body;

        console.log(`[Notebooks] POST / - userId: ${req.userId}, title: ${title}`);

        if (!title) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const id = uuidv4();
        const result = await pool.query(
            `INSERT INTO notebooks (id, user_id, title, description, cover_image, category, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
             RETURNING *`,
            [id, req.userId, title, description || null, coverImage || null, category || 'General']
        );

        console.log(`[Notebooks] Created notebook ${id} for user ${req.userId}`);

        // Update user stats (ignore errors if table doesn't exist)
        try {
            await pool.query(
                `INSERT INTO user_stats (user_id, notebooks_created) 
                 VALUES ($1, 1)
                 ON CONFLICT (user_id) 
                 DO UPDATE SET notebooks_created = user_stats.notebooks_created + 1, updated_at = NOW()`,
                [req.userId]
            );
        } catch (statsError) {
            console.log('Could not update user stats:', statsError);
        }

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
        if (req.body.category !== undefined) {
            updates.push(`category = $${paramIndex++}`);
            values.push(req.body.category);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        updates.push('updated_at = NOW()');
        values.push(id, req.userId);

        const idParamIndex = paramIndex++;
        const userIdParamIndex = paramIndex;

        const result = await pool.query(
            `UPDATE notebooks SET ${updates.join(', ')} 
             WHERE id = $${idParamIndex} AND user_id = $${userIdParamIndex}
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
