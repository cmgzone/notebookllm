import express, { type Request, type Response, type Router } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router: Router = express.Router();

// Seed default plans - PUBLIC endpoint for initial setup
router.get('/seed-defaults', async (req: Request, res: Response) => {
    try {
        console.log('[SEED] Starting seed process...');

        // Create tables if not exist
        await pool.query(`
            CREATE TABLE IF NOT EXISTS subscription_plans (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                description TEXT,
                credits_per_month INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_free_plan BOOLEAN DEFAULT false,
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS user_subscriptions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                plan_id UUID REFERENCES subscription_plans(id),
                current_credits INTEGER DEFAULT 0,
                credits_consumed_this_month INTEGER DEFAULT 0,
                last_renewal_date TIMESTAMPTZ,
                next_renewal_date TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(user_id)
            );

            CREATE TABLE IF NOT EXISTS credit_transactions (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                amount INTEGER NOT NULL,
                transaction_type TEXT NOT NULL,
                description TEXT,
                balance_after INTEGER,
                metadata JSONB,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );

            CREATE TABLE IF NOT EXISTS credit_packages (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
        `);

        // Seed plans
        const plans = await pool.query('SELECT COUNT(*) FROM subscription_plans');
        if (parseInt(plans.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, description) VALUES
                ('Free', 50, 0, true, 'Basic features, 50 credits/month, 5 notebooks'),
                ('Pro', 1000, 9.99, false, 'Advanced features, 1000 credits/month, Unlimited notebooks, Priority support'),
                ('Ultra', 5000, 29.99, false, 'All features, 5000 credits/month, Unlimited everything, VIP support, Early access')
            `);
        }

        // Seed packages
        const packages = await pool.query('SELECT COUNT(*) FROM credit_packages');
        if (parseInt(packages.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO credit_packages (name, credits, price) VALUES
                ('Starter Pack', 100, 1.99),
                ('Value Pack', 500, 7.99),
                ('Pro Pack', 2000, 24.99),
                ('Ultimate Pack', 10000, 99.99)
            `);
        }

        res.json({ success: true, message: 'Database seeded successfully' });
    } catch (error) {
        console.error('Seed error:', error);
        res.status(500).json({ error: 'Seeding failed: ' + error });
    }
});

// Protected routes
router.use(authenticateToken);

// Get current user's subscription
router.get('/me', async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId!;

        const result = await pool.query(`
            SELECT 
                us.*,
                sp.name as plan_name,
                sp.credits_per_month,
                sp.price as plan_price,
                sp.is_free_plan
            FROM user_subscriptions us
            JOIN subscription_plans sp ON us.plan_id = sp.id
            WHERE us.user_id = $1
        `, [userId]);

        if (result.rows.length === 0) {
            // Auto-provision free subscription
            console.log(`[SUB] Auto-provisioning subscription for user ${userId}`);

            let freePlanResult = await pool.query(
                `SELECT id, credits_per_month FROM subscription_plans WHERE is_free_plan = TRUE LIMIT 1`
            );

            if (freePlanResult.rows.length === 0) {
                // Create free plan if it doesn't exist
                freePlanResult = await pool.query(`
                    INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, is_active) 
                    VALUES ('Free', 50, 0, true, true)
                    RETURNING id, credits_per_month
                `);
            }

            await pool.query(`
                INSERT INTO user_subscriptions (
                    user_id, plan_id, current_credits, 
                    last_renewal_date, next_renewal_date
                )
                VALUES (
                    $1, $2, $3,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 month'
                )
            `, [userId, freePlanResult.rows[0].id, freePlanResult.rows[0].credits_per_month]);

            // Fetch the newly created subscription
            const newResult = await pool.query(`
                SELECT 
                    us.*,
                    sp.name as plan_name,
                    sp.credits_per_month,
                    sp.price as plan_price,
                    sp.is_free_plan
                FROM user_subscriptions us
                JOIN subscription_plans sp ON us.plan_id = sp.id
                WHERE us.user_id = $1
            `, [userId]);

            return res.json({ subscription: newResult.rows[0] });
        }

        res.json({ subscription: result.rows[0] });
    } catch (error) {
        console.error('Error fetching subscription:', error);
        res.status(500).json({ error: 'Failed to fetch subscription' });
    }
});

// Get all active subscription plans
router.get('/plans', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(`
            SELECT * FROM subscription_plans 
            WHERE is_active = true 
            ORDER BY price ASC
        `);
        res.json({ plans: result.rows });
    } catch (error) {
        console.error('Error fetching plans:', error);
        res.status(500).json({ error: 'Failed to fetch plans' });
    }
});

// Get credit balance
router.get('/credits', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(`
            SELECT current_credits, credits_consumed_this_month 
            FROM user_subscriptions 
            WHERE user_id = $1
        `, [req.userId]);

        if (result.rows.length === 0) {
            return res.json({ credits: 0, consumed: 0 });
        }

        res.json({
            credits: result.rows[0].current_credits,
            consumed: result.rows[0].credits_consumed_this_month
        });
    } catch (error) {
        console.error('Error fetching credits:', error);
        res.status(500).json({ error: 'Failed to fetch credits' });
    }
});

// Get credit transaction history
router.get('/transactions', async (req: AuthRequest, res: Response) => {
    try {
        const limit = parseInt(req.query.limit as string) || 50;

        const result = await pool.query(`
            SELECT * FROM credit_transactions
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT $2
        `, [req.userId, limit]);

        res.json({ transactions: result.rows });
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({ error: 'Failed to fetch transactions' });
    }
});

// Get credit packages
router.get('/packages', async (req: AuthRequest, res: Response) => {
    try {
        const result = await pool.query(`
            SELECT * FROM credit_packages
            WHERE is_active = true
            ORDER BY price ASC
        `);
        res.json({ packages: result.rows });
    } catch (error) {
        console.error('Error fetching packages:', error);
        res.status(500).json({ error: 'Failed to fetch packages' });
    }
});

// Consume credits
router.post('/consume', async (req: AuthRequest, res: Response) => {
    try {
        const { amount, feature, metadata } = req.body;

        if (!amount || amount <= 0) {
            return res.status(400).json({ error: 'Invalid amount' });
        }

        const subResult = await pool.query(`
            SELECT current_credits FROM user_subscriptions WHERE user_id = $1
        `, [req.userId]);

        if (subResult.rows.length === 0 || subResult.rows[0].current_credits < amount) {
            return res.json({ success: false, error: 'Insufficient credits' });
        }

        const newBalance = subResult.rows[0].current_credits - amount;

        await pool.query(`
            UPDATE user_subscriptions
            SET current_credits = $1,
                credits_consumed_this_month = credits_consumed_this_month + $2,
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = $3
        `, [newBalance, amount, req.userId]);

        await pool.query(`
            INSERT INTO credit_transactions 
            (user_id, amount, transaction_type, description, balance_after, metadata)
            VALUES ($1, $2, 'consumption', $3, $4, $5)
        `, [req.userId, -amount, `Used ${amount} credits for ${feature}`, newBalance, metadata ? JSON.stringify(metadata) : null]);

        res.json({ success: true, newBalance });
    } catch (error) {
        console.error('Error consuming credits:', error);
        res.status(500).json({ error: 'Failed to consume credits' });
    }
});

// Create subscription for user
router.post('/create', async (req: AuthRequest, res: Response) => {
    try {
        const existing = await pool.query(
            'SELECT id FROM user_subscriptions WHERE user_id = $1',
            [req.userId]
        );

        if (existing.rows.length > 0) {
            return res.json({ message: 'Subscription already exists' });
        }

        const planResult = await pool.query(`
            SELECT id, credits_per_month FROM subscription_plans 
            WHERE is_free_plan = TRUE 
            LIMIT 1
        `);

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'No free plan available' });
        }

        const freePlan = planResult.rows[0];

        await pool.query(`
            INSERT INTO user_subscriptions (
                user_id, plan_id, current_credits, 
                last_renewal_date, next_renewal_date
            )
            VALUES (
                $1, $2, $3,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 month'
            )
        `, [req.userId, freePlan.id, freePlan.credits_per_month]);

        res.json({ message: 'Subscription created', planId: freePlan.id });
    } catch (error) {
        console.error('Error creating subscription:', error);
        res.status(500).json({ error: 'Failed to create subscription' });
    }
});

// Add credits after purchase (PayPal/Stripe)
router.post('/add-credits', async (req: AuthRequest, res: Response) => {
    try {
        const { amount, packageId, transactionId, paymentMethod } = req.body;

        if (!amount || amount <= 0) {
            return res.status(400).json({ error: 'Invalid credit amount' });
        }

        if (!transactionId) {
            return res.status(400).json({ error: 'Transaction ID is required' });
        }

        // Check for duplicate transaction
        const existingTx = await pool.query(
            `SELECT id FROM credit_transactions WHERE metadata->>'transaction_id' = $1`,
            [transactionId]
        );

        if (existingTx.rows.length > 0) {
            return res.status(409).json({ error: 'Transaction already processed' });
        }

        // Get current subscription
        const subResult = await pool.query(
            'SELECT current_credits FROM user_subscriptions WHERE user_id = $1',
            [req.userId]
        );

        if (subResult.rows.length === 0) {
            return res.status(404).json({ error: 'No subscription found. Please create one first.' });
        }

        const currentCredits = subResult.rows[0].current_credits;
        const newBalance = currentCredits + amount;

        // Update credits
        await pool.query(`
            UPDATE user_subscriptions
            SET current_credits = $1, updated_at = CURRENT_TIMESTAMP
            WHERE user_id = $2
        `, [newBalance, req.userId]);

        // Record transaction
        await pool.query(`
            INSERT INTO credit_transactions 
            (user_id, amount, transaction_type, description, balance_after, metadata)
            VALUES ($1, $2, 'purchase', $3, $4, $5)
        `, [
            req.userId,
            amount,
            `Purchased ${amount} credits`,
            newBalance,
            JSON.stringify({
                package_id: packageId,
                transaction_id: transactionId,
                payment_method: paymentMethod || 'paypal'
            })
        ]);

        console.log(`[CREDITS] Added ${amount} credits for user ${req.userId}. New balance: ${newBalance}`);

        res.json({ 
            success: true, 
            newBalance,
            message: `Successfully added ${amount} credits`
        });
    } catch (error) {
        console.error('Error adding credits:', error);
        res.status(500).json({ error: 'Failed to add credits' });
    }
});

// Upgrade plan
router.post('/upgrade', async (req: AuthRequest, res: Response) => {
    try {
        const { planId, transactionId } = req.body;

        const planResult = await pool.query(
            'SELECT * FROM subscription_plans WHERE id = $1 AND is_active = true',
            [planId]
        );

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'Plan not found or inactive' });
        }

        const newPlan = planResult.rows[0];

        const subResult = await pool.query(
            'SELECT * FROM user_subscriptions WHERE user_id = $1',
            [req.userId]
        );

        if (subResult.rows.length === 0) {
            return res.status(404).json({ error: 'No subscription found' });
        }

        const currentSub = subResult.rows[0];
        const newBalance = currentSub.current_credits + newPlan.credits_per_month;

        await pool.query(`
            UPDATE user_subscriptions
            SET plan_id = $1,
                current_credits = $2,
                credits_consumed_this_month = 0,
                last_renewal_date = CURRENT_TIMESTAMP,
                next_renewal_date = CURRENT_TIMESTAMP + INTERVAL '1 month',
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = $3
        `, [planId, newBalance, req.userId]);

        await pool.query(`
            INSERT INTO credit_transactions 
            (user_id, amount, transaction_type, description, balance_after, metadata)
            VALUES ($1, $2, 'plan_upgrade', $3, $4, $5)
        `, [
            req.userId,
            newPlan.credits_per_month,
            `Upgraded to ${newPlan.name}`,
            newBalance,
            JSON.stringify({ old_plan_id: currentSub.plan_id, new_plan_id: planId, transaction_id: transactionId })
        ]);

        res.json({ success: true, newBalance });
    } catch (error) {
        console.error('Error upgrading plan:', error);
        res.status(500).json({ error: 'Failed to upgrade plan' });
    }
});

export default router;
