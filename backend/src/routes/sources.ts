import express, { type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Get all sources for a notebook
router.get('/notebook/:notebookId', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.params;

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        const result = await pool.query(
            'SELECT * FROM sources WHERE notebook_id = $1 ORDER BY created_at DESC',
            [notebookId]
        );

        res.json({ success: true, sources: result.rows });
    } catch (error) {
        console.error('Get sources error:', error);
        res.status(500).json({ error: 'Failed to fetch sources' });
    }
});

// Get a single source
router.get('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2`,
            [id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Source not found' });
        }

        res.json({ success: true, source: result.rows[0] });
    } catch (error) {
        console.error('Get source error:', error);
        res.status(500).json({ error: 'Failed to fetch source' });
    }
});

// Create a new source
router.post('/', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, type, title, content, url } = req.body;

        if (!notebookId || !type || !title) {
            return res.status(400).json({ error: 'notebookId, type, and title are required' });
        }

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        const id = uuidv4();
        const result = await pool.query(
            `INSERT INTO sources (id, notebook_id, type, title, content, url, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
       RETURNING *`,
            [id, notebookId, type, title, content || null, url || null]
        );

        // Update notebook's updated_at
        await pool.query(
            'UPDATE notebooks SET updated_at = NOW() WHERE id = $1',
            [notebookId]
        );

        res.status(201).json({ success: true, source: result.rows[0] });
    } catch (error) {
        console.error('Create source error:', error);
        res.status(500).json({ error: 'Failed to create source' });
    }
});

// Update a source
router.put('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { title, content, url } = req.body;

        const updates: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        if (title !== undefined) {
            updates.push(`title = $${paramIndex++}`);
            values.push(title);
        }
        if (content !== undefined) {
            updates.push(`content = $${paramIndex++}`);
            values.push(content);
        }
        if (url !== undefined) {
            updates.push(`url = $${paramIndex++}`);
            values.push(url);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        updates.push(`updated_at = NOW()`);
        values.push(id, req.userId);

        const result = await pool.query(
            `UPDATE sources s SET ${updates.join(', ')}
       FROM notebooks n
       WHERE s.id = $${paramIndex++} AND s.notebook_id = n.id AND n.user_id = $${paramIndex++}
       RETURNING s.*`,
            values
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Source not found' });
        }

        res.json({ success: true, source: result.rows[0] });
    } catch (error) {
        console.error('Update source error:', error);
        res.status(500).json({ error: 'Failed to update source' });
    }
});

// Delete a source
router.delete('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `DELETE FROM sources s
       USING notebooks n
       WHERE s.id = $1 AND s.notebook_id = n.id AND n.user_id = $2
       RETURNING s.id`,
            [id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Source not found' });
        }

        res.json({ success: true, message: 'Source deleted' });
    } catch (error) {
        console.error('Delete source error:', error);
        res.status(500).json({ error: 'Failed to delete source' });
    }
});

// Bulk operations
router.post('/bulk/delete', async (req: AuthRequest, res: Response) => {
    try {
        const { ids } = req.body;
        if (!ids || !ids.length) return res.status(400).json({ error: 'IDs required' });
        const result = await pool.query('SELECT bulk_delete_sources($1) as count', [ids]);
        res.json({ success: true, count: result.rows[0].count });
    } catch (error) {
        console.error('Bulk delete error:', error);
        res.status(500).json({ error: 'Failed to delete sources' });
    }
});

router.post('/bulk/move', async (req: AuthRequest, res: Response) => {
    try {
        const { ids, targetNotebookId } = req.body;
        if (!ids || !targetNotebookId) return res.status(400).json({ error: 'Missing parameters' });
        const result = await pool.query('SELECT bulk_move_sources($1, $2) as count', [ids, targetNotebookId]);
        res.json({ success: true, count: result.rows[0].count });
    } catch (error) {
        console.error('Bulk move error:', error);
        res.status(500).json({ error: 'Failed to move sources' });
    }
});

router.post('/bulk/tags/add', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceIds, tagIds } = req.body;
        const result = await pool.query('SELECT bulk_add_tags($1, $2) as count', [sourceIds, tagIds]);
        res.json({ success: true, count: result.rows[0].count });
    } catch (error) {
        res.status(500).json({ error: 'Failed to add tags' });
    }
});

router.post('/bulk/tags/remove', async (req: AuthRequest, res: Response) => {
    try {
        const { sourceIds, tagIds } = req.body;
        const result = await pool.query('SELECT bulk_remove_tags($1, $2) as count', [sourceIds, tagIds]);
        res.json({ success: true, count: result.rows[0].count });
    } catch (error) {
        res.status(500).json({ error: 'Failed to remove tags' });
    }
});

// Search sources
router.post('/search', async (req: AuthRequest, res: Response) => {
    try {
        const { query, limit } = req.body;
        const result = await pool.query('SELECT * FROM search_sources($1, $2, $3)', [req.userId, query, limit || 20]);
        res.json({ success: true, sources: result.rows });
    } catch (error) {
        console.error('Search sources error:', error);
        res.status(500).json({ error: 'Search failed' });
    }
});

export default router;
