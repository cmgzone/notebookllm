import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
router.use(authenticateToken);

// ==================== FLASHCARDS ====================

// Get all flashcard decks
router.get('/flashcards/decks', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT fd.*, 
                    (SELECT COUNT(*) FROM flashcards WHERE deck_id = fd.id) as card_count
             FROM flashcard_decks fd 
             WHERE fd.user_id = $1 
             ORDER BY fd.updated_at DESC`,
            [req.userId]
        );
        res.json({ success: true, decks: result.rows });
    } catch (error) {
        console.error('Get flashcard decks error:', error);
        res.status(500).json({ error: 'Failed to fetch decks' });
    }
});

// Create flashcard deck
router.post('/flashcards/decks', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, sourceId, title } = req.body;
        const deckId = id || uuidv4();
        
        const result = await pool.query(
            `INSERT INTO flashcard_decks (id, user_id, notebook_id, source_id, title)
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING *`,
            [deckId, req.userId, notebookId, sourceId, title]
        );
        
        res.status(201).json({ success: true, deck: result.rows[0] });
    } catch (error) {
        console.error('Create flashcard deck error:', error);
        res.status(500).json({ error: 'Failed to create deck' });
    }
});

// Get flashcards for a deck
router.get('/flashcards/decks/:deckId', async (req: AuthRequest, res: Response) => {
    try {
        const { deckId } = req.params;
        const result = await pool.query(
            'SELECT * FROM flashcards WHERE deck_id = $1 ORDER BY created_at ASC',
            [deckId]
        );
        res.json({ success: true, flashcards: result.rows });
    } catch (error) {
        console.error('Get flashcards error:', error);
        res.status(500).json({ error: 'Failed to fetch flashcards' });
    }
});

// Batch sync flashcards
router.post('/flashcards/batch', async (req: AuthRequest, res: Response) => {
    try {
        const { deckId, flashcards } = req.body;
        
        if (!deckId || !flashcards) {
            return res.status(400).json({ error: 'deckId and flashcards required' });
        }

        const results: any[] = [];
        for (const fc of flashcards) {
            const id = fc.id || uuidv4();
            const result = await pool.query(
                `INSERT INTO flashcards (id, deck_id, question, answer, difficulty)
                 VALUES ($1, $2, $3, $4, $5)
                 ON CONFLICT (id) DO UPDATE SET question = $3, answer = $4, difficulty = $5
                 RETURNING *`,
                [id, deckId, fc.question, fc.answer, fc.difficulty || 'medium']
            );
            results.push(result.rows[0]);
        }

        // Update deck timestamp
        await pool.query(
            'UPDATE flashcard_decks SET updated_at = NOW() WHERE id = $1',
            [deckId]
        );

        res.json({ success: true, flashcards: results });
    } catch (error) {
        console.error('Batch sync flashcards error:', error);
        res.status(500).json({ error: 'Failed to sync flashcards' });
    }
});

// Delete flashcard deck
router.delete('/flashcards/decks/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        await pool.query(
            'DELETE FROM flashcard_decks WHERE id = $1 AND user_id = $2',
            [id, req.userId]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Delete flashcard deck error:', error);
        res.status(500).json({ error: 'Failed to delete deck' });
    }
});

// Update flashcard progress
router.post('/flashcards/:id/progress', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { wasCorrect } = req.body;

        await pool.query(
            `UPDATE flashcards 
             SET times_reviewed = times_reviewed + 1,
                 times_correct = CASE WHEN $2 = true THEN times_correct + 1 ELSE times_correct END,
                 last_reviewed_at = NOW(),
                 next_review_at = NOW() + (interval '1 day' * (times_correct + 1))
             WHERE id = $1`,
            [id, wasCorrect]
        );

        // Update user stats
        await pool.query(
            `UPDATE user_stats SET flashcards_reviewed = flashcards_reviewed + 1, updated_at = NOW() 
             WHERE user_id = (SELECT user_id FROM flashcard_decks fd 
                              JOIN flashcards f ON f.deck_id = fd.id WHERE f.id = $1)`,
            [id]
        );

        res.json({ success: true });
    } catch (error) {
        console.error('Update flashcard progress error:', error);
        res.status(500).json({ error: 'Failed to update progress' });
    }
});

// ==================== QUIZZES ====================

// Get all quizzes
router.get('/quizzes', async (req: AuthRequest, res: Response) => {
    try {
        const quizzesResult = await pool.query(
            `SELECT q.* FROM quizzes q 
             WHERE q.user_id = $1 
             ORDER BY q.updated_at DESC`,
            [req.userId]
        );
        
        // Fetch questions for each quiz
        const quizzes = await Promise.all(quizzesResult.rows.map(async (quiz) => {
            const questionsResult = await pool.query(
                'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY created_at ASC',
                [quiz.id]
            );
            return {
                ...quiz,
                questions: questionsResult.rows
            };
        }));
        
        res.json({ success: true, quizzes });
    } catch (error) {
        console.error('Get quizzes error:', error);
        res.status(500).json({ error: 'Failed to fetch quizzes' });
    }
});

// Create quiz
router.post('/quizzes', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, sourceId, title, questions } = req.body;
        const quizId = id || uuidv4();

        await pool.query('BEGIN');

        const quizRes = await pool.query(
            `INSERT INTO quizzes (id, user_id, notebook_id, source_id, title)
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [quizId, req.userId, notebookId, sourceId, title]
        );

        if (questions && Array.isArray(questions)) {
            for (const q of questions) {
                const qId = q.id || uuidv4();
                await pool.query(
                    `INSERT INTO quiz_questions (id, quiz_id, question, options, correct_option_index, explanation)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [qId, quizId, q.question, JSON.stringify(q.options), q.correctOptionIndex, q.explanation]
                );
            }
        }

        await pool.query('COMMIT');
        res.status(201).json({ success: true, quiz: quizRes.rows[0] });
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Create quiz error:', error);
        res.status(500).json({ error: 'Failed to create quiz' });
    }
});

// Get quiz details with questions
router.get('/quizzes/:id', async (req: AuthRequest, res: Response) => {
    try {
        const quiz = await pool.query(
            'SELECT * FROM quizzes WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );

        if (quiz.rows.length === 0) {
            return res.status(404).json({ error: 'Quiz not found' });
        }

        const questions = await pool.query(
            'SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY created_at ASC',
            [req.params.id]
        );

        res.json({ success: true, quiz: quiz.rows[0], questions: questions.rows });
    } catch (error) {
        console.error('Get quiz error:', error);
        res.status(500).json({ error: 'Failed to fetch quiz' });
    }
});

// Delete quiz
router.delete('/quizzes/:id', async (req: AuthRequest, res: Response) => {
    try {
        await pool.query(
            'DELETE FROM quizzes WHERE id = $1 AND user_id = $2',
            [req.params.id, req.userId]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Delete quiz error:', error);
        res.status(500).json({ error: 'Failed to delete quiz' });
    }
});

// Record quiz attempt
router.post('/quizzes/:id/attempt', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { score, total } = req.body;

        await pool.query(
            `UPDATE quizzes 
             SET times_attempted = times_attempted + 1,
                 last_score = $2,
                 best_score = GREATEST(COALESCE(best_score, 0), $2),
                 last_attempted_at = NOW(),
                 updated_at = NOW()
             WHERE id = $1 AND user_id = $3`,
            [id, score, req.userId]
        );

        // Update user stats
        await pool.query(
            `UPDATE user_stats SET quizzes_completed = quizzes_completed + 1, updated_at = NOW() 
             WHERE user_id = $1`,
            [req.userId]
        );

        res.json({ success: true });
    } catch (error) {
        console.error('Record quiz attempt error:', error);
        res.status(500).json({ error: 'Failed to record quiz attempt' });
    }
});

// ==================== MIND MAPS ====================

// Get all mind maps
router.get('/mindmaps', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM mind_maps WHERE user_id = $1 ORDER BY updated_at DESC',
            [req.userId]
        );
        res.json({ success: true, mindMaps: result.rows });
    } catch (error) {
        console.error('Get mind maps error:', error);
        res.status(500).json({ error: 'Failed to fetch mind maps' });
    }
});

// Save mind map
router.post('/mindmaps', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, sourceId, title, rootNode, textContent } = req.body;
        const mmId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO mind_maps (id, user_id, notebook_id, source_id, title, root_node, text_content)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (id) DO UPDATE SET root_node = $6, text_content = $7, updated_at = NOW()
             RETURNING *`,
            [mmId, req.userId, notebookId, sourceId, title, JSON.stringify(rootNode), textContent]
        );

        res.json({ success: true, mindMap: result.rows[0] });
    } catch (error) {
        console.error('Save mind map error:', error);
        res.status(500).json({ error: 'Failed to save mind map' });
    }
});

// ==================== INFOGRAPHICS ====================

// Get all infographics
router.get('/infographics', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM infographics WHERE user_id = $1 ORDER BY created_at DESC',
            [req.userId]
        );
        res.json({ success: true, infographics: result.rows });
    } catch (error) {
        console.error('Get infographics error:', error);
        res.status(500).json({ error: 'Failed to fetch infographics' });
    }
});

// Save infographic
router.post('/infographics', async (req: AuthRequest, res: Response) => {
    try {
        const { id, notebookId, sourceId, title, imageUrl, imageBase64, style } = req.body;
        const infoId = id || uuidv4();

        const result = await pool.query(
            `INSERT INTO infographics (id, user_id, notebook_id, source_id, title, image_url, image_base64, style)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
             RETURNING *`,
            [infoId, req.userId, notebookId, sourceId, title, imageUrl, imageBase64, style]
        );

        res.json({ success: true, infographic: result.rows[0] });
    } catch (error) {
        console.error('Save infographic error:', error);
        res.status(500).json({ error: 'Failed to save infographic' });
    }
});

export default router;
