import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
router.use(authenticateToken);

// Get all ebook projects
router.get('/', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT ep.*, 
                    (SELECT COUNT(*) FROM ebook_chapters WHERE project_id = ep.id) as chapter_count
             FROM ebook_projects ep 
             WHERE ep.user_id = $1 
             ORDER BY ep.updated_at DESC`,
            [req.userId]
        );
        res.json({ success: true, projects: result.rows });
    } catch (error) {
        console.error('Get ebook projects error:', error);
        res.status(500).json({ error: 'Failed to fetch ebook projects' });
    }
});

// Get single ebook project
router.get('/:id', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM ebook_projects WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Project not found' });
        }

        res.json({ success: true, project: result.rows[0] });
    } catch (error) {
        console.error('Get ebook project error:', error);
        res.status(500).json({ error: 'Failed to fetch ebook project' });
    }
});

// Create/Update project
router.post('/', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, title, topic, targetAudience, branding, selectedModel, status, coverImage } = req.body;
        const projectId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO ebook_projects (id, user_id, notebook_id, title, topic, target_audience, branding, selected_model, status, cover_image)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             ON CONFLICT (id) DO UPDATE SET 
                title = $4, topic = $5, target_audience = $6, branding = $7, 
                selected_model = $8, status = $9, cover_image = $10, updated_at = NOW()
             RETURNING *`,
            [projectId, req.userId, notebookId, title, topic, targetAudience, 
             branding ? JSON.stringify(branding) : null, selectedModel, status || 'draft', coverImage]
        );
        res.json({ success: true, project: result.rows[0] });
    } catch (error) {
        console.error('Save ebook error:', error);
        res.status(500).json({ error: 'Failed to save ebook project' });
    }
});

// Delete project
router.delete('/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query(
            'DELETE FROM ebook_projects WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Delete ebook project error:', error);
        res.status(500).json({ error: 'Failed to delete ebook project' });
    }
});

// Get chapters for a project
router.get('/:projectId/chapters', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM ebook_chapters WHERE project_id = $1 ORDER BY chapter_order ASC',
            [req.params.projectId]
        );
        res.json({ success: true, chapters: result.rows });
    } catch (error) {
        console.error('Get chapters error:', error);
        res.status(500).json({ error: 'Failed to fetch chapters' });
    }
});

// Batch sync chapters
router.post('/:projectId/chapters/batch', async (req: AuthRequest, res: Response) => {
    try {
        const { chapters } = req.body;
        const { projectId } = req.params;

        if (!chapters || !Array.isArray(chapters)) {
            return res.status(400).json({ error: 'chapters array required' });
        }

        const results = [];

        await pool.query('BEGIN');
        for (const ch of chapters) {
            const id = ch.id || uuidv4();
            const result = await pool.query(
                `INSERT INTO ebook_chapters (id, project_id, title, content, chapter_order, status)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT (id) DO UPDATE SET 
                    title = $3, content = $4, chapter_order = $5, status = $6, updated_at = NOW()
                 RETURNING *`,
                [id, projectId, ch.title, ch.content, ch.chapterOrder || ch.chapter_order, ch.status || 'draft']
            );
            results.push(result.rows[0]);
        }

        // Update project timestamp
        await pool.query(
            'UPDATE ebook_projects SET updated_at = NOW() WHERE id = $1',
            [projectId]
        );

        await pool.query('COMMIT');
        res.json({ success: true, chapters: results });
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Sync chapters error:', error);
        res.status(500).json({ error: 'Failed to sync chapters' });
    }
});

export default router;
