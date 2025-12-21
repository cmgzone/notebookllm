import express, { type Request, type Response, type Router } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router: Router = express.Router();

// Seed default plans and create tables - PUBLIC for initial setup
router.get('/seed-defaults', async (req: Request, res: Response) => {
    try {
        console.log('[SEED] Starting seed process...');

        // 1. Create Tables
        await pool.query(`
            CREATE TABLE IF NOT EXISTS subscription_plans (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits_per_month INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_free_plan BOOLEAN DEFAULT false,
                is_active BOOLEAN DEFAULT true,
                features JSONB DEFAULT '[]',
                created_at TIMESTAMPTZ DEFAULT NOW()
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
        console.log('[SEED] Tables created (if not exist)');

        // 2. Seed Plans
        const plans = await pool.query('SELECT COUNT(*) FROM subscription_plans');
        if (parseInt(plans.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, features) VALUES
                ('Free', 50, 0, true, '["Basic features", "50 credits/month"]'),
                ('Pro', 1000, 9.99, false, '["Advanced features", "1000 credits/month", "Priority support"]'),
                ('Ultra', 5000, 29.99, false, '["All features", "5000 credits/month", "VIP support", "Early access"]')
            `);
            console.log('[SEED] Default plans inserted');
        }

        // 3. Seed Credit Packages
        const packages = await pool.query('SELECT COUNT(*) FROM credit_packages');
        if (parseInt(packages.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO credit_packages (name, credits, price) VALUES
                ('Small Pack', 100, 1.99),
                ('Medium Pack', 500, 4.99),
                ('Large Pack', 2000, 15.99)
            `);
            console.log('[SEED] Default credit packages inserted');
        }

        res.json({ success: true, message: 'Database seeded successfully' });
    } catch (error) {
        console.error('Seed error:', error);
        res.status(500).json({ error: 'Seeding failed: ' + error });
    }
});

// All subscription routes require authentication
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
            // Lazy provisioning: Create free subscription if none exists
            console.log(`[SUB] No subscription found for user ${userId}, attempting auto-provisioning`);

            const planResult = await pool.query(`
                SELECT id, credits_per_month FROM subscription_plans 
                WHERE is_free_plan = TRUE 
                LIMIT 1
            `);

            if (planResult.rows.length > 0) {
                const freePlan = planResult.rows[0];
                console.log(`[SUB] Found free plan ${freePlan.id}, creating subscription`);

                await pool.query(`
                  INSERT INTO user_subscriptions (
                    user_id, plan_id, current_credits, 
                    last_renewal_date, next_renewal_date
                  )
                  VALUES (
                    $1, $2, $3,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 month'
                  )
                `, [userId, freePlan.id, freePlan.credits_per_month]);

                // Fetch the newly created subscription with details
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

                console.log(`[SUB] Subscription created successfully`);
                return res.json({ subscription: newResult.rows[0] });
            }

            console.log(`[SUB] No free plan found, returning null`);
            return res.json({ subscription: null });
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
        const userId = req.userId!;

        const result = await pool.query(`
      SELECT current_credits, credits_consumed_this_month 
      FROM user_subscriptions 
      WHERE user_id = $1
    `, [userId]);

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
        const userId = req.userId!;
        const limit = parseInt(req.query.limit as string) || 50;

        const result = await pool.query(`
      SELECT * FROM credit_transactions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2
    `, [userId, limit]);

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
        const userId = req.userId!;
        const { amount, feature, metadata } = req.body;

        if (!amount || amount <= 0) {
            return res.status(400).json({ error: 'Invalid amount' });
        }

        // Get current balance
        const subResult = await pool.query(`
      SELECT current_credits FROM user_subscriptions WHERE user_id = $1
    `, [userId]);

        if (subResult.rows.length === 0 || subResult.rows[0].current_credits < amount) {
            return res.json({ success: false, error: 'Insufficient credits' });
        }

        const newBalance = subResult.rows[0].current_credits - amount;

        // Deduct credits
        await pool.query(`
      UPDATE user_subscriptions
      SET current_credits = $1,
          credits_consumed_this_month = credits_consumed_this_month + $2,
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $3
    `, [newBalance, amount, userId]);

        // Log transaction
        await pool.query(`
      INSERT INTO credit_transactions 
      (user_id, amount, transaction_type, description, balance_after, metadata)
      VALUES ($1, $2, 'consumption', $3, $4, $5)
    `, [userId, -amount, `Used ${amount} credits for ${feature}`, newBalance, metadata ? JSON.stringify(metadata) : null]);

        res.json({ success: true, newBalance });
    } catch (error) {
        console.error('Error consuming credits:', error);
        res.status(500).json({ error: 'Failed to consume credits' });
    }
});

// Create subscription for user (if they don't have one)
router.post('/create', async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId!;

        // Check if subscription exists
        const existing = await pool.query(
            'SELECT id FROM user_subscriptions WHERE user_id = $1',
            [userId]
        );

        if (existing.rows.length > 0) {
            return res.json({ message: 'Subscription already exists' });
        }

        // Get free plan
        const planResult = await pool.query(`
      SELECT id, credits_per_month FROM subscription_plans 
      WHERE is_free_plan = TRUE 
      LIMIT 1
    `);

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'No free plan available' });
        }

        const freePlan = planResult.rows[0];

        // Create subscription
        await pool.query(`
      INSERT INTO user_subscriptions (
        user_id, plan_id, current_credits, 
        last_renewal_date, next_renewal_date
      )
      VALUES (
        $1, $2, $3,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 month'
      )
    `, [userId, freePlan.id, freePlan.credits_per_month]);

        res.json({ message: 'Subscription created', planId: freePlan.id });
    } catch (error) {
        console.error('Error creating subscription:', error);
        res.status(500).json({ error: 'Failed to create subscription' });
    }
});

// Upgrade plan
router.post('/upgrade', async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId!;
        const { planId, transactionId } = req.body;

        // Get new plan
        const planResult = await pool.query(
            'SELECT * FROM subscription_plans WHERE id = $1 AND is_active = true',
            [planId]
        );

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'Plan not found or inactive' });
        }

        const newPlan = planResult.rows[0];

        // Get current subscription
        const subResult = await pool.query(
            'SELECT * FROM user_subscriptions WHERE user_id = $1',
            [userId]
        );

        if (subResult.rows.length === 0) {
            return res.status(404).json({ error: 'No subscription found' });
        }

        const currentSub = subResult.rows[0];
        const newBalance = currentSub.current_credits + newPlan.credits_per_month;

        // Update subscription
        await pool.query(`
      UPDATE user_subscriptions
      SET plan_id = $1,
          current_credits = $2,
          credits_consumed_this_month = 0,
          last_renewal_date = CURRENT_TIMESTAMP,
          next_renewal_date = CURRENT_TIMESTAMP + INTERVAL '1 month',
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $3
    `, [planId, newBalance, userId]);

        // Log transaction
        await pool.query(`
      INSERT INTO credit_transactions 
      (user_id, amount, transaction_type, description, balance_after, metadata)
      VALUES ($1, $2, 'plan_upgrade', $3, $4, $5)
    `, [
            userId,
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

// Seed default plans and create tables
router.get('/seed-defaults', async (req: AuthRequest, res: Response) => {
    try {
        console.log('[SEED] Starting seed process...');

        // 1. Create Tables
        await pool.query(`
            CREATE TABLE IF NOT EXISTS subscription_plans (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                credits_per_month INTEGER NOT NULL,
                price DECIMAL NOT NULL,
                is_free_plan BOOLEAN DEFAULT false,
                is_active BOOLEAN DEFAULT true,
                features JSONB DEFAULT '[]',
                created_at TIMESTAMPTZ DEFAULT NOW()
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
        console.log('[SEED] Tables created (if not exist)');

        // 2. Seed Plans
        const plans = await pool.query('SELECT COUNT(*) FROM subscription_plans');
        if (parseInt(plans.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, features) VALUES
                ('Free', 50, 0, true, '["Basic features", "50 credits/month"]'),
                ('Pro', 1000, 9.99, false, '["Advanced features", "1000 credits/month", "Priority support"]'),
                ('Ultra', 5000, 29.99, false, '["All features", "5000 credits/month", "VIP support", "Early access"]')
            `);
            console.log('[SEED] Default plans inserted');
        }

        // 3. Seed Credit Packages
        const packages = await pool.query('SELECT COUNT(*) FROM credit_packages');
        if (parseInt(packages.rows[0].count) === 0) {
            await pool.query(`
                INSERT INTO credit_packages (name, credits, price) VALUES
                ('Small Pack', 100, 1.99),
                ('Medium Pack', 500, 4.99),
                ('Large Pack', 2000, 15.99)
            `);
            console.log('[SEED] Default credit packages inserted');
        }

        res.json({ success: true, message: 'Database seeded successfully' });
    } catch (error) {
        console.error('Seed error:', error);
        res.status(500).json({ error: 'Seeding failed: ' + error });
    }
});

export default router;
