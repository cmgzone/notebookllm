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
            `SELECT rs.*, 
                    (SELECT COUNT(*) FROM research_sources WHERE session_id = rs.id) as source_count
             FROM research_sessions rs 
             WHERE rs.user_id = $1 
             ORDER BY rs.created_at DESC`,
            [req.userId]
        );
        res.json({ success: true, sessions: result.rows });
    } catch (error) {
        console.error('Get research sessions error:', error);
        res.status(500).json({ error: 'Failed to fetch research history' });
    }
});

// Get single research session with sources
router.get('/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        const session = await pool.query(
            'SELECT * FROM research_sessions WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );

        if (session.rows.length === 0) {
            return res.status(404).json({ error: 'Session not found' });
        }

        const sources = await pool.query(
            'SELECT * FROM research_sources WHERE session_id = $1 ORDER BY created_at ASC',
            [req.params.id]
        );

        res.json({ 
            success: true, 
            session: session.rows[0],
            sources: sources.rows
        });
    } catch (error) {
        console.error('Get research session error:', error);
        res.status(500).json({ error: 'Failed to fetch research session' });
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
             VALUES ($1, $2, $3, $4, $5) 
             ON CONFLICT (id) DO UPDATE SET report = $5
             RETURNING *`,
            [sessionId, req.userId, notebookId, query, report]
        );

        // Insert sources if provided
        if (sources && Array.isArray(sources)) {
            // Clear existing sources for this session if updating
            await pool.query('DELETE FROM research_sources WHERE session_id = $1', [sessionId]);

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

// Delete research session
router.delete('/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query(
            'DELETE FROM research_sessions WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Delete research session error:', error);
        res.status(500).json({ error: 'Failed to delete research session' });
    }
});

export default router;
