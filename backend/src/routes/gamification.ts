import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';
import { clearUserAnalyticsCache } from '../services/cacheService.js';

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
                    notebooks_created, sources_added, quizzes_completed, flashcards_reviewed, 
                    study_time_minutes, perfect_quizzes, tutor_sessions_completed, chat_messages_sent,
                    deep_research_completed, voice_mode_used, mindmaps_created, features_used)
                 VALUES ($1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '{}') 
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
            'flashcards_reviewed', 'study_time_minutes', 'perfect_quizzes',
            'tutor_sessions_completed', 'chat_messages_sent', 'deep_research_completed',
            'voice_mode_used', 'mindmaps_created', 'features_used', 'last_active_date'
        ];

        if (!allowedFields.includes(field)) {
            return res.status(400).json({ error: `Invalid field: ${field}` });
        }

        // Ensure user has stats record
        await pool.query(
            `INSERT INTO user_stats (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
            [req.userId]
        );

        let query: string;
        let params: any[];

        if (increment !== undefined) {
            query = `UPDATE user_stats SET ${field} = COALESCE(${field}, 0) + $2, updated_at = NOW() WHERE user_id = $1 RETURNING *`;
            params = [req.userId, increment];
        } else {
            query = `UPDATE user_stats SET ${field} = $2, updated_at = NOW() WHERE user_id = $1 RETURNING *`;
            params = [req.userId, value];
        }

        const result = await pool.query(query, params);
        await clearUserAnalyticsCache(req.userId!);
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

        if (result.rows.length === 0) {
            // Generate challenges for today
            const generated = generateDailyChallenges(req.userId!, today);
            const results: any[] = [];

            for (const ch of generated) {
                const insertResult = await pool.query(
                    `INSERT INTO daily_challenges (id, user_id, type, title, description, target_value, current_value, is_completed, xp_reward, date)
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                     RETURNING *`,
                    [ch.id, ch.user_id, ch.type, ch.title, ch.description, ch.target_value, ch.current_value, ch.is_completed, ch.xp_reward, ch.date]
                );
                results.push(insertResult.rows[0]);
            }
            return res.json({ success: true, challenges: results });
        }

        res.json({ success: true, challenges: result.rows });
    } catch (error) {
        console.error('Get challenges error:', error);
        res.status(500).json({ error: 'Failed to fetch challenges' });
    }
});

function generateDailyChallenges(userId: string, date: string): any[] {
    const types = [
        'reviewFlashcards', 'completeQuiz', 'addSource', 'chatWithAI',
        'tutorSession', 'createMindmap', 'perfectQuiz', 'studyTime',
        'deepResearch', 'voiceMode'
    ];

    // Shuffle and pick 3
    const shuffled = types.sort(() => 0.5 - Math.random());
    const selected = shuffled.slice(0, 3);

    return selected.map(type => createChallenge(type, date, userId));
}

function createChallenge(type: string, date: string, userId: string): any {
    const id = uuidv4();
    let title = '';
    let description = '';
    let targetValue = 1;
    let xpReward = 10;

    const randomCount = (options: number[]) => options[Math.floor(Math.random() * options.length)];

    switch (type) {
        case 'reviewFlashcards':
            targetValue = randomCount([10, 15, 20, 25]);
            title = 'Flashcard Review';
            description = `Review ${targetValue} flashcards`;
            xpReward = targetValue * 2;
            break;
        case 'completeQuiz':
            targetValue = randomCount([1, 2, 3]);
            title = 'Quiz Time';
            description = `Complete ${targetValue} quiz${targetValue > 1 ? 'zes' : ''}`;
            xpReward = targetValue * 25;
            break;
        case 'addSource':
            title = 'Knowledge Builder';
            description = 'Add a new source to any notebook';
            xpReward = 30;
            break;
        case 'chatWithAI':
            targetValue = randomCount([5, 10, 15]);
            title = 'AI Conversation';
            description = `Send ${targetValue} messages to AI`;
            xpReward = targetValue * 3;
            break;
        case 'tutorSession':
            title = 'Tutor Time';
            description = 'Complete a tutor session';
            xpReward = 50;
            break;
        case 'createMindmap':
            title = 'Mind Mapper';
            description = 'Create a mind map';
            xpReward = 40;
            break;
        case 'perfectQuiz':
            title = 'Perfectionist';
            description = 'Get 100% on any quiz';
            xpReward = 75;
            break;
        case 'studyTime':
            targetValue = randomCount([15, 30, 45]);
            title = 'Study Session';
            description = `Study for ${targetValue} minutes`;
            xpReward = targetValue;
            break;
        case 'deepResearch':
            title = 'Deep Dive';
            description = 'Complete a deep research session';
            xpReward = 60;
            break;
        case 'voiceMode':
            title = 'Voice Activated';
            description = 'Use voice mode';
            xpReward = 25;
            break;
    }

    return {
        id, user_id: userId, type, title, description,
        target_value: targetValue, current_value: 0,
        is_completed: false, xp_reward: xpReward, date
    };
}

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
