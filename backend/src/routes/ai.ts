import express, { type Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import {
    generateWithGemini,
    generateWithOpenRouter,
    streamWithGemini,
    streamWithOpenRouter,
    generateSummary,
    generateQuestions,
    type ChatMessage
} from '../services/aiService.js';
import pool from '../config/database.js';

const router = express.Router();

// Helper function to check if user has premium access
async function userHasPremiumAccess(userId: string): Promise<boolean> {
    try {
        const result = await pool.query(`
            SELECT sp.is_free_plan
            FROM user_subscriptions us
            JOIN subscription_plans sp ON us.plan_id = sp.id
            WHERE us.user_id = $1
        `, [userId]);

        if (result.rows.length === 0) {
            return false; // No subscription = no premium access
        }

        // User has premium access if they're NOT on the free plan
        return !result.rows[0].is_free_plan;
    } catch (error) {
        console.error('Error checking premium access:', error);
        return false;
    }
}

// List available AI models with access control
router.get('/models', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId;

        // Get user's subscription status
        const hasPremiumAccess = userId ? await userHasPremiumAccess(userId) : false;

        const result = await pool.query(
            'SELECT id, name, model_id, provider, description, context_window, is_active, is_premium FROM ai_models WHERE is_active = true ORDER BY provider, name'
        );

        // Add can_access field to each model based on user's subscription
        const modelsWithAccess = result.rows.map(model => ({
            ...model,
            can_access: !model.is_premium || hasPremiumAccess
        }));

        res.json({
            success: true,
            models: modelsWithAccess,
            has_premium_access: hasPremiumAccess
        });
    } catch (error) {
        console.error('Error listing AI models:', error);
        res.status(500).json({ error: 'Failed to list AI models' });
    }
});

router.use(authenticateToken);

// Chat completion endpoint with premium model validation
router.post('/chat', async (req: AuthRequest, res: Response) => {
    try {
        let { messages, provider = 'gemini', model } = req.body;

        console.log(`[AI Chat] Received request - provider: ${provider}, model: ${model}`);

        // Auto-detect provider ONLY if provider is not explicitly set to 'gemini'
        // If model contains '/', it's definitely OpenRouter (or compatible).
        // Also check for common OpenRouter prefixes.
        if (provider !== 'gemini' && model && (model.includes('/') || model.startsWith('gpt-') || model.startsWith('claude-') || model.startsWith('meta-'))) {
            provider = 'openrouter';
            console.log(`[AI Chat] Auto-detected OpenRouter provider for model: ${model}`);
        }
        
        // Force Gemini provider for Gemini models
        if (model && model.toLowerCase().startsWith('gemini')) {
            provider = 'gemini';
            console.log(`[AI Chat] Forcing Gemini provider for model: ${model}`);
        }

        if (!messages || !Array.isArray(messages)) {
            return res.status(400).json({ error: 'messages array is required' });
        }

        // Check if the requested model is premium and if user has access
        let maxTokens = 4096;
        if (model) {
            const modelResult = await pool.query(
                'SELECT is_premium, context_window FROM ai_models WHERE model_id = $1 AND is_active = true',
                [model]
            );

            if (modelResult.rows.length > 0) {
                const modelData = modelResult.rows[0];

                // Calculate max output tokens from context window
                if (modelData.context_window) {
                    maxTokens = Math.min(Math.floor(modelData.context_window / 4), 131072);
                    if (maxTokens < 2000) maxTokens = 2000;
                }

                if (modelData.is_premium) {
                    const hasPremiumAccess = await userHasPremiumAccess(req.userId!);
                    if (!hasPremiumAccess) {
                        return res.status(403).json({
                            error: 'Premium model access required',
                            message: 'This model is only available to paid subscribers. Please upgrade your plan to access premium AI models.',
                            upgrade_required: true
                        });
                    }
                }
            }
        }

        let response: string;
        if (provider === 'openrouter') {
            response = await generateWithOpenRouter(messages, model, maxTokens);
        } else {
            response = await generateWithGemini(messages, model);
        }

        res.json({ success: true, response });
    } catch (error: any) {
        console.error('Chat error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate response' });
    }
});

// Stream chat completion endpoint (SSE) with premium model validation
router.post('/chat/stream', async (req: AuthRequest, res: Response) => {
    try {
        let { messages, provider = 'gemini', model } = req.body;

        console.log(`[AI Stream] Received request - provider: ${provider}, model: ${model}`);

        // Auto-detect provider ONLY if provider is not explicitly set to 'gemini'
        // If model contains '/', it's definitely OpenRouter.
        if (provider !== 'gemini' && model && (model.includes('/') || model.startsWith('gpt-') || model.startsWith('claude-') || model.startsWith('meta-'))) {
            provider = 'openrouter';
            console.log(`[AI Stream] Auto-detected OpenRouter provider for model: ${model}`);
        }
        
        // Force Gemini provider for Gemini models
        if (model && model.toLowerCase().startsWith('gemini')) {
            provider = 'gemini';
            console.log(`[AI Stream] Forcing Gemini provider for model: ${model}`);
        }

        if (!messages || !Array.isArray(messages)) {
            return res.status(400).json({ error: 'messages array is required' });
        }

        // Check if the requested model is premium and if user has access
        let maxTokens = 4096;
        if (model) {
            const modelResult = await pool.query(
                'SELECT is_premium, context_window FROM ai_models WHERE model_id = $1 AND is_active = true',
                [model]
            );

            if (modelResult.rows.length > 0) {
                const modelData = modelResult.rows[0];

                // Calculate max output tokens from context window
                if (modelData.context_window) {
                    maxTokens = Math.min(Math.floor(modelData.context_window / 4), 131072);
                    if (maxTokens < 2000) maxTokens = 2000;
                }

                if (modelData.is_premium) {
                    const hasPremiumAccess = await userHasPremiumAccess(req.userId!);
                    if (!hasPremiumAccess) {
                        return res.status(403).json({
                            error: 'Premium model access required',
                            message: 'This model is only available to paid subscribers. Please upgrade your plan to access premium AI models.',
                            upgrade_required: true
                        });
                    }
                }
            }
        }

        // Set up SSE headers
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.flushHeaders();

        let generator;
        if (provider === 'openrouter') {
            generator = streamWithOpenRouter(messages, model, maxTokens);
        } else {
            generator = streamWithGemini(messages, model);
        }

        for await (const chunk of generator) {
            // Send chunk as data event
            // Properly escape newlines for SSE
            const payload = JSON.stringify({ text: chunk });
            res.write(`data: ${payload}\n\n`);
        }

        res.write('data: [DONE]\n\n');
        res.end();
    } catch (error: any) {
        console.error('Streaming error:', error);
        // If headers already sent, we can't send JSON error, just end stream with error data?
        if (!res.headersSent) {
            res.status(500).json({ error: error.message || 'Failed to stream response' });
        } else {
            res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
            res.end();
        }
    }
});

// Generate summary for content
router.post('/summary', async (req: AuthRequest, res: Response) => {
    try {
        const { content, provider = 'gemini' } = req.body;

        if (!content) {
            return res.status(400).json({ error: 'content is required' });
        }

        const summary = await generateSummary(content, provider);

        res.json({ success: true, summary });
    } catch (error: any) {
        console.error('Summary error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate summary' });
    }
});

// Generate questions for notebook
router.post('/questions', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId, count = 5 } = req.body;

        if (!notebookId) {
            return res.status(400).json({ error: 'notebookId is required' });
        }

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id, title FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        // Get sources content
        const sourcesResult = await pool.query(
            `SELECT title, content FROM sources WHERE notebook_id = $1 LIMIT 10`,
            [notebookId]
        );

        const content = sourcesResult.rows
            .map(s => `${s.title}: ${s.content || ''}`)
            .join('\n\n')
            .substring(0, 500000);

        const questions = await generateQuestions(content, count);

        res.json({ success: true, questions });
    } catch (error: any) {
        console.error('Questions error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate questions' });
    }
});

// Generate notebook summary
router.post('/notebook-summary', async (req: AuthRequest, res: Response) => {
    try {
        const { notebookId } = req.body;

        if (!notebookId) {
            return res.status(400).json({ error: 'notebookId is required' });
        }

        // Verify notebook belongs to user
        const notebookResult = await pool.query(
            'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
            [notebookId, req.userId]
        );

        if (notebookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Notebook not found' });
        }

        // Get all chunks for the notebook
        const chunksResult = await pool.query(
            `SELECT c.content_text FROM chunks c
             INNER JOIN sources s ON c.source_id = s.id
             WHERE s.notebook_id = $1
             ORDER BY c.chunk_index ASC
             LIMIT 100`,
            [notebookId]
        );

        let content = '';
        if (chunksResult.rows.length > 0) {
            content = chunksResult.rows
                .map(c => c.content_text)
                .join(' ')
                .substring(0, 500000);
        } else {
            // Fall back to sources content
            const sourcesResult = await pool.query(
                `SELECT title, content FROM sources WHERE notebook_id = $1`,
                [notebookId]
            );
            content = sourcesResult.rows
                .map(s => `${s.title}: ${s.content || ''}`)
                .join('\n\n')
                .substring(0, 500000);
        }

        const summary = await generateSummary(content);

        res.json({ success: true, summary });
    } catch (error: any) {
        console.error('Notebook summary error:', error);
        res.status(500).json({ error: error.message || 'Failed to generate notebook summary' });
    }
});

// Chat persistence
router.get('/chat/history', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId;
        const { notebookId } = req.query;

        let query = 'SELECT * FROM chat_messages WHERE user_id = $1';
        const params: any[] = [userId];

        if (notebookId) {
            query += ' AND notebook_id = $2';
            params.push(notebookId);
        } else {
            query += ' AND notebook_id IS NULL';
        }

        query += ' ORDER BY created_at ASC';

        const result = await pool.query(query, params);
        res.json({ messages: result.rows });
    } catch (error) {
        console.error('Error fetching chat history:', error);
        res.status(500).json({ error: 'Failed to fetch chat history' });
    }
});

router.post('/chat/message', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId;
        const { notebookId, role, content } = req.body;

        if (!content || !role) {
            return res.status(400).json({ error: 'Content and role are required' });
        }

        const result = await pool.query(
            'INSERT INTO chat_messages (user_id, notebook_id, role, content) VALUES ($1, $2, $3, $4) RETURNING *',
            [userId, notebookId || null, role, content]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error saving chat message:', error);
        res.status(500).json({ error: 'Failed to save chat message' });
    }
});

export default router;
