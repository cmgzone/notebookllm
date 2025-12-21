import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
router.use(authenticateToken);

// Get research history
router.get('/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM research_sessions WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, sessions: result.rows });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch research history' });
    }
});

// Save research session
router.post('/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, query, report, sources } = req.body;
        const sessionId = id || uuidv4();

        await pool.query('BEGIN');
        const sessionRes = await pool.query(
            `INSERT INTO research_sessions (id, user_id, notebook_id, query, report)
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [sessionId, req.userId, notebookId, query, report]
        );

        if (sources && Array.isArray(sources)) {
            for (const s of sources) {
                const sId = uuidv4();
                await pool.query(
                    `INSERT INTO research_sources (id, session_id, title, url, content, snippet)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [sId, sessionId, s.title, s.url, s.content, s.snippet]
                );
            }
        }

        await pool.query('COMMIT');
        res.status(201).json({ success: true, session: sessionRes.rows[0] });
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Save research session error:', error);
        res.status(500).json({ error: 'Failed to save research session' });
    }
});

export default router;
