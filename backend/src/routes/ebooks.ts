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
            'SELECT * FROM ebook_projects WHERE user_id = $1 ORDER BY updated_at DESC',
            [req.userId]
        );
        res.json({ success: true, projects: result.rows });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch ebook projects' });
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
             ON CONFLICT (id) DO UPDATE SET title = $4, topic = $5, target_audience = $6, branding = $7, selected_model = $8, status = $9, cover_image = $10, updated_at = NOW()
             RETURNING *`,
            [projectId, req.userId, notebookId, title, topic, targetAudience, branding, selectedModel, status, coverImage]
        );
        res.json({ success: true, project: result.rows[0] });
    } catch (error) {
        console.error('Save ebook error:', error);
        res.status(500).json({ error: 'Failed to save ebook project' });
    }
});

// Chapters
router.get('/:projectId/chapters', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM ebook_chapters WHERE project_id = $1 ORDER BY chapter_order ASC',
            [req.params.projectId]
        );
        res.json({ success: true, chapters: result.rows });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch chapters' });
    }
});

router.post('/:projectId/chapters/batch', async (req: AuthRequest, res: Response) => {
    try {
        const { chapters } = req.body;
        const results = [];

        await pool.query('BEGIN');
        for (const ch of chapters) {
            const id = ch.id || uuidv4();
            const res = await pool.query(
                `INSERT INTO ebook_chapters (id, project_id, title, content, chapter_order, status)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT (id) DO UPDATE SET title = $3, content = $4, chapter_order = $5, status = $6, updated_at = NOW()
                 RETURNING *`,
                [id, req.params.projectId, ch.title, ch.content, ch.chapterOrder, ch.status]
            );
            results.push(res.rows[0]);
        }
        await pool.query('COMMIT');

        res.json({ success: true, chapters: results });
    } catch (error) {
        await pool.query('ROLLBACK');
        res.status(500).json({ error: 'Failed to sync chapters' });
    }
});

export default router;
