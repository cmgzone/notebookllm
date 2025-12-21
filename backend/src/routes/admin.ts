import express, { type Request, type Response, type Router } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router: Router = express.Router();

// All admin routes require authentication
router.use(authenticateToken);

// ============================================================================
// AI MODELS
// ============================================================================

// List all AI models
router.get('/models', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM ai_models ORDER BY provider, name'
        );
        res.json({ models: result.rows });
    } catch (error) {
        console.error('Error listing models:', error);
        res.status(500).json({ error: 'Failed to list models' });
    }
});

// Add new AI model
router.post('/models', async (req: AuthRequest, res: Response) => {
    try {
        const { name, modelId, provider, description, costInput, costOutput, contextWindow, isActive, isPremium } = req.body;

        const result = await pool.query(`
      INSERT INTO ai_models (
        name, model_id, provider, description, 
        cost_input, cost_output, context_window, 
        is_active, is_premium
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `, [name, modelId, provider, description, costInput || 0, costOutput || 0, contextWindow || 0, isActive ?? true, isPremium ?? false]);

        res.json({ model: result.rows[0] });
    } catch (error) {
        console.error('Error adding model:', error);
        res.status(500).json({ error: 'Failed to add model' });
    }
});

// Update AI model
router.put('/models/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { name, modelId, provider, description, costInput, costOutput, contextWindow, isActive, isPremium } = req.body;

        const result = await pool.query(`
      UPDATE ai_models SET
        name = $1,
        model_id = $2,
        provider = $3,
        description = $4,
        cost_input = $5,
        cost_output = $6,
        context_window = $7,
        is_active = $8,
        is_premium = $9,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $10
      RETURNING *
    `, [name, modelId, provider, description, costInput, costOutput, contextWindow, isActive, isPremium, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Model not found' });
        }

        res.json({ model: result.rows[0] });
    } catch (error) {
        console.error('Error updating model:', error);
        res.status(500).json({ error: 'Failed to update model' });
    }
});

// Delete AI model
router.delete('/models/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM ai_models WHERE id = $1 RETURNING id',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Model not found' });
        }

        res.json({ message: 'Model deleted' });
    } catch (error) {
        console.error('Error deleting model:', error);
        res.status(500).json({ error: 'Failed to delete model' });
    }
});

// ============================================================================
// API KEYS / CREDENTIALS
// ============================================================================

// List all API keys (names only, not values)
router.get('/api-keys', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT service_name, description, updated_at FROM api_keys ORDER BY service_name'
        );
        res.json({ apiKeys: result.rows });
    } catch (error) {
        console.error('Error listing API keys:', error);
        res.status(500).json({ error: 'Failed to list API keys' });
    }
});

// Set/update API key
router.post('/api-keys', async (req: AuthRequest, res: Response) => {
    try {
        const { service, apiKey, description } = req.body;

        await pool.query(`
      INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
      ON CONFLICT (service_name) 
      DO UPDATE SET encrypted_value = $2, description = $3, updated_at = CURRENT_TIMESTAMP
    `, [service, apiKey, description]);

        res.json({ message: 'API key saved' });
    } catch (error) {
        console.error('Error saving API key:', error);
        res.status(500).json({ error: 'Failed to save API key' });
    }
});

// Delete API key
router.delete('/api-keys/:service', async (req: AuthRequest, res: Response) => {
    try {
        const { service } = req.params;

        await pool.query('DELETE FROM api_keys WHERE service_name = $1', [service]);

        res.json({ message: 'API key deleted' });
    } catch (error) {
        console.error('Error deleting API key:', error);
        res.status(500).json({ error: 'Failed to delete API key' });
    }
});

// ============================================================================
// SUBSCRIPTION PLANS (Admin management)
// ============================================================================

// List all plans with subscriber counts
router.get('/plans', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(`
      SELECT 
        sp.*,
        COUNT(us.id) as subscriber_count
      FROM subscription_plans sp
      LEFT JOIN user_subscriptions us ON sp.id = us.plan_id
      GROUP BY sp.id
      ORDER BY sp.price ASC
    `);
        res.json({ plans: result.rows });
    } catch (error) {
        console.error('Error listing plans:', error);
        res.status(500).json({ error: 'Failed to list plans' });
    }
});

// Update plan
router.put('/plans/:id', async (req: AuthRequest, res: Response) => {
    try {
        const { id } = req.params;
        const { name, description, creditsPerMonth, price, isActive } = req.body;

        const updates: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        if (name !== undefined) {
            updates.push(`name = $${paramIndex++}`);
            values.push(name);
        }
        if (description !== undefined) {
            updates.push(`description = $${paramIndex++}`);
            values.push(description);
        }
        if (creditsPerMonth !== undefined) {
            updates.push(`credits_per_month = $${paramIndex++}`);
            values.push(creditsPerMonth);
        }
        if (price !== undefined) {
            updates.push(`price = $${paramIndex++}`);
            values.push(price);
        }
        if (isActive !== undefined) {
            updates.push(`is_active = $${paramIndex++}`);
            values.push(isActive);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No updates provided' });
        }

        updates.push('updated_at = CURRENT_TIMESTAMP');
        values.push(id);

        const result = await pool.query(
            `UPDATE subscription_plans SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
            values
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Plan not found' });
        }

        res.json({ plan: result.rows[0] });
    } catch (error) {
        console.error('Error updating plan:', error);
        res.status(500).json({ error: 'Failed to update plan' });
    }
});

// ============================================================================
// CONTENT MANAGEMENT
// ============================================================================

// Get onboarding screens
router.get('/onboarding', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT * FROM onboarding_screens ORDER BY order_index ASC'
        );
        res.json({ screens: result.rows });
    } catch (error) {
        console.error('Error fetching onboarding:', error);
        res.status(500).json({ error: 'Failed to fetch onboarding screens' });
    }
});

// Update onboarding screens
router.put('/onboarding', async (req: AuthRequest, res: Response) => {
    try {
        const { screens } = req.body;

        // Clear existing and insert new
        await pool.query('DELETE FROM onboarding_screens');

        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            await pool.query(`
        INSERT INTO onboarding_screens (title, description, image_url, order_index)
        VALUES ($1, $2, $3, $4)
      `, [screen.title, screen.description, screen.imageUrl, i]);
        }

        res.json({ message: 'Onboarding screens updated' });
    } catch (error) {
        console.error('Error updating onboarding:', error);
        res.status(500).json({ error: 'Failed to update onboarding screens' });
    }
});

// Get privacy policy
router.get('/privacy-policy', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(
            'SELECT content FROM app_settings WHERE key = $1',
            ['privacy_policy']
        );
        res.json({ content: result.rows[0]?.content || null });
    } catch (error) {
        console.error('Error fetching privacy policy:', error);
        res.status(500).json({ error: 'Failed to fetch privacy policy' });
    }
});

// Update privacy policy
router.put('/privacy-policy', async (req: AuthRequest, res: Response) => {
    try {
        const { content } = req.body;

        await pool.query(`
      INSERT INTO app_settings (key, content, updated_at)
      VALUES ('privacy_policy', $1, CURRENT_TIMESTAMP)
      ON CONFLICT (key) 
      DO UPDATE SET content = $1, updated_at = CURRENT_TIMESTAMP
    `, [content]);

        res.json({ message: 'Privacy policy updated' });
    } catch (error) {
        console.error('Error updating privacy policy:', error);
        res.status(500).json({ error: 'Failed to update privacy policy' });
    }
});

export default router;
