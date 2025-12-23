import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
router.use(authenticateToken);

// Get user stats
router.get('/stats', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM user_stats WHERE user_id = $1',
            [req.userId]
        );

        if (result.rows.length === 0) {
            // Initialize stats for new user
            const initResult = await pool.query(
                `INSERT INTO user_stats (user_id, total_xp, level, current_streak, longest_streak, 
                    notebooks_created, sources_added, quizzes_completed, flashcards_reviewed, study_time_minutes)
                 VALUES ($1, 0, 1, 0, 0, 0, 0, 0, 0, 0) 
                 RETURNING *`,
                [req.userId]
            );
            return res.json({ success: true, stats: initResult.rows[0] });
        }

        res.json({ success: true, stats: result.rows[0] });
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ error: 'Failed to fetch user stats' });
    }
});

// Track activity (generic increment/set)
router.post('/track', async (req: AuthRequest, res: Response) => {
    try {
        const { field, increment, value } = req.body;

        // Validate field name to prevent SQL injection
        const allowedFields = [
            'total_xp', 'level', 'current_streak', 'longest_streak',
            'notebooks_created', 'sources_added', 'quizzes_completed',
            'flashcards_reviewed', 'study_time_minutes'
        ];

        if (!allowedFields.includes(field)) {
            return res.status(400).json({ error: 'Invalid field' });
        }

        // Ensure user has stats record
        await pool.query(
            `INSERT INTO user_stats (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
            [req.userId]
        );

        let query: string;
        let params: any[];

        if (increment !== undefined) {
            query = `UPDATE user_stats SET ${field} = ${field} + $2, updated_at = NOW() WHERE user_id = $1 RETURNING *`;
            params = [req.userId, increment];
        } else {
            query = `UPDATE user_stats SET ${field} = $2, updated_at = NOW() WHERE user_id = $1 RETURNING *`;
            params = [req.userId, value];
        }

        const result = await pool.query(query, params);
        res.json({ success: true, stats: result.rows[0] });
    } catch (error) {
        console.error('Track activity error:', error);
        res.status(500).json({ error: 'Failed to track activity' });
    }
});

// Get achievements
router.get('/achievements', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM achievements WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, achievements: result.rows });
    } catch (error) {
        console.error('Get achievements error:', error);
        res.status(500).json({ error: 'Failed to fetch achievements' });
    }
});

// Update achievement progress
router.post('/achievements/progress', async (req: AuthRequest, res: Response) => {
    try {
        const { achievementId, value, isUnlocked } = req.body;
        const id = uuidv4();

        const result = await pool.query(
            `INSERT INTO achievements (id, user_id, achievement_id, current_value, is_unlocked, unlocked_at)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (user_id, achievement_id) 
             DO UPDATE SET 
                current_value = $4,
                is_unlocked = $5,
                unlocked_at = CASE WHEN $5 = true AND achievements.is_unlocked = false THEN $6 ELSE achievements.unlocked_at END
             RETURNING *`,
            [id, req.userId, achievementId, value, isUnlocked, isUnlocked ? new Date() : null]
        );

        res.json({ success: true, achievement: result.rows[0] });
    } catch (error) {
        console.error('Update achievement error:', error);
        res.status(500).json({ error: 'Failed to update achievement' });
    }
});

// Get daily challenges
router.get('/challenges', async (req: AuthRequest, res: Response) => {
    try {
        const today = new Date().toISOString().split('T')[0];
        const result = await pool.query(
            'SELECT * FROM daily_challenges WHERE user_id = $1 AND date = $2',
            [req.userId, today]
        );
        res.json({ success: true, challenges: result.rows });
    } catch (error) {
        console.error('Get challenges error:', error);
        res.status(500).json({ error: 'Failed to fetch challenges' });
    }
});

// Batch update challenges
router.post('/challenges/batch', async (req: AuthRequest, res: Response) => {
    try {
        const { challenges } = req.body;
        
        if (!challenges || !Array.isArray(challenges)) {
            return res.status(400).json({ error: 'challenges array required' });
        }

        const results: any[] = [];

        for (const ch of challenges) {
            const id = uuidv4();
            const result = await pool.query(
                `INSERT INTO daily_challenges (id, user_id, type, title, description, target_value, current_value, is_completed, xp_reward, date)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                 ON CONFLICT (user_id, type, date) DO UPDATE SET 
                    current_value = $7, 
                    is_completed = $8
                 RETURNING *`,
                [id, req.userId, ch.type, ch.title, ch.description, ch.targetValue, ch.currentValue, ch.isCompleted, ch.xpReward, ch.date]
            );
            results.push(result.rows[0]);
        }

        res.json({ success: true, challenges: results });
    } catch (error) {
        console.error('Batch update challenges error:', error);
        res.status(500).json({ error: 'Failed to update challenges' });
    }
});

export default router;
