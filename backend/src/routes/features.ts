import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
router.use(authenticateToken);

// ===========================================
// TUTOR SESSIONS
// ===========================================

router.get('/tutor/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM tutor_sessions WHERE user_id = $1 ORDER BY updated_at DESC',
            [req.userId]
        );
        res.json({ success: true, sessions: result.rows });
    } catch (error) {
        console.error('Error fetching tutor sessions:', error);
        res.status(500).json({ error: 'Failed to fetch tutor sessions' });
    }
});

router.post('/tutor/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, sourceId, topic, style, difficulty, exchanges, summary, totalScore, exchangeCount } = req.body;
        const sessionId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO tutor_sessions (id, user_id, notebook_id, source_id, topic, style, difficulty, exchanges, summary, total_score, exchange_count)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
             ON CONFLICT (id) DO UPDATE SET 
                exchanges = $8, summary = $9, total_score = $10, exchange_count = $11, updated_at = NOW()
             RETURNING *`,
            [sessionId, req.userId, notebookId, sourceId, topic, style || 'socratic', difficulty || 'adaptive',
                JSON.stringify(exchanges || []), summary, totalScore || 0, exchangeCount || 0]
        );
        res.json({ success: true, session: result.rows[0] });
    } catch (error) {
        console.error('Error saving tutor session:', error);
        res.status(500).json({ error: 'Failed to save tutor session' });
    }
});

router.put('/tutor/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { exchanges, summary, totalScore, exchangeCount } = req.body;

        const result = await pool.query(
            `UPDATE tutor_sessions SET 
                exchanges = COALESCE($3, exchanges),
                summary = COALESCE($4, summary),
                total_score = COALESCE($5, total_score),
                exchange_count = COALESCE($6, exchange_count),
                updated_at = NOW()
             WHERE id = $1 AND user_id = $2 RETURNING *`,
            [id, req.userId, JSON.stringify(exchanges), summary, totalScore, exchangeCount]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Session not found' });
        }
        res.json({ success: true, session: result.rows[0] });
    } catch (error) {
        console.error('Error updating tutor session:', error);
        res.status(500).json({ error: 'Failed to update tutor session' });
    }
});

router.delete('/tutor/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query('DELETE FROM tutor_sessions WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting tutor session:', error);
        res.status(500).json({ error: 'Failed to delete tutor session' });
    }
});

// ===========================================
// LANGUAGE LEARNING SESSIONS
// ===========================================

router.get('/language/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM language_sessions WHERE user_id = $1 ORDER BY updated_at DESC',
            [req.userId]
        );
        res.json({ success: true, sessions: result.rows });
    } catch (error) {
        console.error('Error fetching language sessions:', error);
        res.status(500).json({ error: 'Failed to fetch language sessions' });
    }
});

router.post('/language/sessions', async (req: AuthRequest, res: Response) => {
    try {
        const { id, targetLanguage, nativeLanguage, proficiency, topic, messages } = req.body;
        const sessionId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO language_sessions (id, user_id, target_language, native_language, proficiency, topic, messages)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (id) DO UPDATE SET messages = $7, updated_at = NOW()
             RETURNING *`,
            [sessionId, req.userId, targetLanguage, nativeLanguage || 'English', proficiency || 'beginner', topic, JSON.stringify(messages || [])]
        );
        res.json({ success: true, session: result.rows[0] });
    } catch (error) {
        console.error('Error saving language session:', error);
        res.status(500).json({ error: 'Failed to save language session' });
    }
});

router.put('/language/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { messages } = req.body;

        const result = await pool.query(
            `UPDATE language_sessions SET messages = $3, updated_at = NOW()
             WHERE id = $1 AND user_id = $2 RETURNING *`,
            [id, req.userId, JSON.stringify(messages)]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Session not found' });
        }
        res.json({ success: true, session: result.rows[0] });
    } catch (error) {
        console.error('Error updating language session:', error);
        res.status(500).json({ error: 'Failed to update language session' });
    }
});

router.delete('/language/sessions/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query('DELETE FROM language_sessions WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting language session:', error);
        res.status(500).json({ error: 'Failed to delete language session' });
    }
});

// ===========================================
// STORIES
// ===========================================

router.get('/stories', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM stories WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, stories: result.rows });
    } catch (error) {
        console.error('Error fetching stories:', error);
        res.status(500).json({ error: 'Failed to fetch stories' });
    }
});

router.post('/stories', async (req: AuthRequest, res: Response) => {
    try {
        const { id, title, summary, coverImage, genre, tone, isFiction, sources, chapters, characters } = req.body;
        const storyId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO stories (id, user_id, title, summary, cover_image, genre, tone, is_fiction, sources, chapters, characters)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
             ON CONFLICT (id) DO UPDATE SET 
                title = $3, summary = $4, cover_image = $5, chapters = $10, updated_at = NOW()
             RETURNING *`,
            [storyId, req.userId, title, summary, coverImage, genre, tone, isFiction || false,
                JSON.stringify(sources || []), JSON.stringify(chapters || []), JSON.stringify(characters || [])]
        );
        res.json({ success: true, story: result.rows[0] });
    } catch (error) {
        console.error('Error saving story:', error);
        res.status(500).json({ error: 'Failed to save story' });
    }
});

router.delete('/stories/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query('DELETE FROM stories WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting story:', error);
        res.status(500).json({ error: 'Failed to delete story' });
    }
});

// ===========================================
// MEAL PLANNER
// ===========================================

router.get('/meals/plans', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM meal_plans WHERE user_id = $1 ORDER BY week_start DESC',
            [req.userId]
        );
        res.json({ success: true, plans: result.rows });
    } catch (error) {
        console.error('Error fetching meal plans:', error);
        res.status(500).json({ error: 'Failed to fetch meal plans' });
    }
});

router.post('/meals/plans', async (req: AuthRequest, res: Response) => {
    try {
        const { id, weekStart, days } = req.body;
        const planId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO meal_plans (id, user_id, week_start, days)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (user_id, week_start) DO UPDATE SET days = $4, updated_at = NOW()
             RETURNING *`,
            [planId, req.userId, weekStart, JSON.stringify(days || [])]
        );
        res.json({ success: true, plan: result.rows[0] });
    } catch (error) {
        console.error('Error saving meal plan:', error);
        res.status(500).json({ error: 'Failed to save meal plan' });
    }
});

router.get('/meals/saved', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM saved_meals WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, meals: result.rows });
    } catch (error) {
        console.error('Error fetching saved meals:', error);
        res.status(500).json({ error: 'Failed to fetch saved meals' });
    }
});

router.post('/meals/saved', async (req: AuthRequest, res: Response) => {
    try {
        const { id, name, description, mealType, calories, protein, carbs, fat, fiber, ingredients, instructions, prepTime, imageUrl } = req.body;
        const mealId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO saved_meals (id, user_id, name, description, meal_type, calories, protein, carbs, fat, fiber, ingredients, instructions, prep_time, image_url)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
             RETURNING *`,
            [mealId, req.userId, name, description, mealType, calories, protein, carbs, fat, fiber,
                JSON.stringify(ingredients || []), instructions, prepTime, imageUrl]
        );
        res.json({ success: true, meal: result.rows[0] });
    } catch (error) {
        console.error('Error saving meal:', error);
        res.status(500).json({ error: 'Failed to save meal' });
    }
});

router.delete('/meals/saved/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query('DELETE FROM saved_meals WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting saved meal:', error);
        res.status(500).json({ error: 'Failed to delete saved meal' });
    }
});

// ===========================================
// AUDIO OVERVIEWS
// ===========================================

router.get('/audio/overviews', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM audio_overviews WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, overviews: result.rows });
    } catch (error) {
        console.error('Error fetching audio overviews:', error);
        res.status(500).json({ error: 'Failed to fetch audio overviews' });
    }
});

router.post('/audio/overviews', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, title, audioPath, durationSeconds, voiceProvider, voiceId, format, segments } = req.body;
        const overviewId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO audio_overviews (id, user_id, notebook_id, title, audio_path, duration_seconds, voice_provider, voice_id, format, segments)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             ON CONFLICT (id) DO UPDATE SET audio_path = $5, duration_seconds = $6, segments = $10
             RETURNING *`,
            [overviewId, req.userId, notebookId, title, audioPath, durationSeconds, voiceProvider, voiceId, format || 'podcast', JSON.stringify(segments || [])]
        );
        res.json({ success: true, overview: result.rows[0] });
    } catch (error) {
        console.error('Error saving audio overview:', error);
        res.status(500).json({ error: 'Failed to save audio overview' });
    }
});

router.delete('/audio/overviews/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query('DELETE FROM audio_overviews WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting audio overview:', error);
        res.status(500).json({ error: 'Failed to delete audio overview' });
    }
});

export default router;
