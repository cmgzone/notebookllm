import express, { type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get all tags for the authenticated user
router.get('/', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM tags WHERE user_id = $1 ORDER BY name ASC',
            [req.userId]
        );
        res.json({ success: true, tags: result.rows });
    } catch (error) {
        console.error('Get tags error:', error);
        res.status(500).json({ error: 'Failed to fetch tags' });
    }
});

// Get tags for a specific notebook
router.get('/notebook/:notebookId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;

        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        const result = await pool.query(
            `SELECT t.* FROM tags t
             INNER JOIN notebook_tags nt ON t.id = nt.tag_id
             WHERE nt.notebook_id = $1
             ORDER BY t.name ASC`,
            [notebookId]
        );

        res.json({ success: true, tags: result.rows });
    } catch (error) {
        console.error('Get notebook tags error:', error);
        res.status(500).json({ error: 'Failed to fetch tags' });
    }
});

// Get popular tags
router.get('/popular', async (req: AuthRequest, res: Response) => {
    try {
        const limit = parseInt(req.query.limit as string) || 10;
        
        const result = await pool.query(
            `SELECT t.*, 
                    (SELECT COUNT(*) FROM source_tags st WHERE st.tag_id = t.id) as usage_count
             FROM tags t
             WHERE t.user_id = $1
             ORDER BY usage_count DESC, t.name ASC
             LIMIT $2`,
            [req.userId, limit]
        );

        res.json({ success: true, tags: result.rows });
    } catch (error) {
        console.error('Get popular tags error:', error);
        res.status(500).json({ error: 'Failed to fetch popular tags' });
    }
});

// Create a new tag
router.post('/', async (req: AuthRequest, res: Response) => {
    try {
        const { name, color } = req.body;

        if (!name || !color) {
            return res.status(400).json({ error: 'name and color are required' });
        }

        const id = uuidv4();
        const result = await pool.query(
            `INSERT INTO tags (id, user_id, name, color, created_at)
             VALUES ($1, $2, $3, $4, NOW())
             RETURNING *`,
            [id, req.userId, name, color]
        );

        res.status(201).json({ success: true, tag: result.rows[0] });
    } catch (error) {
        console.error('Create tag error:', error);
        res.status(500).json({ error: 'Failed to create tag' });
    }
});

// Update a tag
router.put('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { name, color } = req.body;

        const updates: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        if (name !== undefined) {
            updates.push(`name = $${paramIndex++}`);
            values.push(name);
        }
        if (color !== undefined) {
            updates.push(`color = $${paramIndex++}`);
            values.push(color);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        values.push(id, req.userId);

        const result = await pool.query(
            `UPDATE tags SET ${updates.join(', ')}
             WHERE id = $${paramIndex++} AND user_id = $${paramIndex}
             RETURNING *`,
            values
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Tag not found' });
        }

        res.json({ success: true, tag: result.rows[0] });
    } catch (error) {
        console.error('Update tag error:', error);
        res.status(500).json({ error: 'Failed to update tag' });
    }
});

// Delete a tag
router.delete('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            'DELETE FROM tags WHERE id = $1 AND user_id = $2 RETURNING id',
            [id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Tag not found' });
        }

        res.json({ success: true, message: 'Tag deleted' });
    } catch (error) {
        console.error('Delete tag error:', error);
        res.status(500).json({ error: 'Failed to delete tag' });
    }
});

// Add tag to notebook
router.post('/notebook/:notebookId/tag/:tagId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, tagId } = req.params;

        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        const tagResult = await pool.query(
            'SELECT id FROM tags WHERE id = $1 AND user_id = $2',
            [tagId, req.userId]
        );

        if (tagResult.rows.length === 0) {
            return res.status(404).json({ error: 'Tag not found' });
        }

        await pool.query(
            'INSERT INTO notebook_tags (notebook_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [notebookId, tagId]
        );

        res.json({ success: true, message: 'Tag added to notebook' });
    } catch (error) {
        console.error('Add tag to notebook error:', error);
        res.status(500).json({ error: 'Failed to add tag to notebook' });
    }
});

// Remove tag from notebook
router.delete('/notebook/:notebookId/tag/:tagId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, tagId } = req.params;

        await pool.query(
            'DELETE FROM notebook_tags WHERE notebook_id = $1 AND tag_id = $2',
            [notebookId, tagId]
        );

        res.json({ success: true, message: 'Tag removed from notebook' });
    } catch (error) {
        console.error('Remove tag from notebook error:', error);
        res.status(500).json({ error: 'Failed to remove tag from notebook' });
    }
});

// Add tag to source
router.post('/source/:sourceId/tag/:tagId', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceId, tagId } = req.params;

        await pool.query(
            'INSERT INTO source_tags (source_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [sourceId, tagId]
        );

        res.json({ success: true, added: true });
    } catch (error) {
        console.error('Add tag to source error:', error);
        res.status(500).json({ error: 'Failed to add tag to source' });
    }
});

// Remove tag from source
router.delete('/source/:sourceId/tag/:tagId', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceId, tagId } = req.params;

        await pool.query(
            'DELETE FROM source_tags WHERE source_id = $1 AND tag_id = $2',
            [sourceId, tagId]
        );

        res.json({ success: true, removed: true });
    } catch (error) {
        console.error('Remove tag from source error:', error);
        res.status(500).json({ error: 'Failed to remove tag from source' });
    }
});

export default router;
