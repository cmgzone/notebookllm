import express, { type Request, type Response, type Router } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router: Router = express.Router();

// Get payment configuration - PUBLIC endpoint for Flutter app
// Returns PayPal/Stripe config from environment variables
router.get('/payment-config', async (_req: Request, res: Response) => {
    try {
        const config: any = {
            paypal: {
                configured: !!(process.env.PAYPAL_CLIENT_ID && process.env.PAYPAL_SECRET),
                clientId: process.env.PAYPAL_CLIENT_ID || null,
                secretKey: process.env.PAYPAL_SECRET || null,
                sandboxMode: process.env.PAYPAL_SANDBOX_MODE !== 'false',
            },
            stripe: {
                configured: !!(process.env.STRIPE_PUBLISHABLE_KEY && process.env.STRIPE_SECRET_KEY),
                publishableKey: process.env.STRIPE_PUBLISHABLE_KEY || null,
                secretKey: process.env.STRIPE_SECRET_KEY || null,
                testMode: process.env.STRIPE_TEST_MODE !== 'false',
            }
        };

        console.log('[PAYMENT] Config request - PayPal configured:', config.paypal.configured, ', Stripe configured:', config.stripe.configured);

        res.json({ success: true, config });
    } catch (error) {
        console.error('Error fetching payment config:', error);
        res.status(500).json({ error: 'Failed to fetch payment config' });
    }
});

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

// Get all active subscription plans - PUBLIC
router.get('/plans', async (req: Request, res: Response) => {
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

// Get credit packages - PUBLIC
router.get('/packages', async (req: Request, res: Response) => {
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

// Create Stripe Checkout Session (requires auth)
router.post('/create-checkout-session', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
        const { planId } = req.body;
        const userId = req.userId!;

        if (!planId) {
            return res.status(400).json({ error: 'Plan ID is required' });
        }

        // Get the plan details
        const planResult = await pool.query(
            'SELECT * FROM subscription_plans WHERE id = $1 AND is_active = true',
            [planId]
        );

        if (planResult.rows.length === 0) {
            return res.status(404).json({ error: 'Plan not found' });
        }

        const plan = planResult.rows[0];

        // Check if Stripe is configured
        const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
        if (!stripeSecretKey) {
            return res.status(500).json({ error: 'Stripe is not configured' });
        }

        // Dynamic import of Stripe
        const Stripe = (await import('stripe')).default;
        const stripe = new Stripe(stripeSecretKey);

        // Determine the success and cancel URLs
        const baseUrl = process.env.WEB_APP_URL || 'http://localhost:3001';

        // Create a Stripe Checkout Session
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            mode: 'subscription',
            line_items: [
                {
                    price_data: {
                        currency: 'usd',
                        product_data: {
                            name: `${plan.name} Plan`,
                            description: plan.description || `${plan.credits_per_month} credits per month`,
                        },
                        unit_amount: Math.round(parseFloat(plan.price) * 100), // Convert to cents
                        recurring: {
                            interval: 'month',
                        },
                    },
                    quantity: 1,
                },
            ],
            success_url: `${baseUrl}/plans/success?session_id={CHECKOUT_SESSION_ID}&plan_id=${planId}`,
            cancel_url: `${baseUrl}/plans?cancelled=true`,
            metadata: {
                userId: userId,
                planId: planId,
            },
            client_reference_id: userId,
        });

        console.log(`[STRIPE] Created checkout session ${session.id} for user ${userId}, plan ${plan.name}`);

        res.json({
            sessionId: session.id,
            url: session.url
        });
    } catch (error: any) {
        console.error('Stripe checkout error:', error);
        res.status(500).json({ error: 'Failed to create checkout session: ' + error.message });
    }
});

// Stripe Webhook for payment confirmation
router.post('/webhook/stripe', express.raw({ type: 'application/json' }), async (req: Request, res: Response) => {
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!stripeSecretKey) {
        return res.status(500).json({ error: 'Stripe not configured' });
    }

    try {
        const Stripe = (await import('stripe')).default;
        const stripe = new Stripe(stripeSecretKey);

        let event;

        if (webhookSecret) {
            const sig = req.headers['stripe-signature'] as string;
            event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
        } else {
            // For testing without webhook secret
            event = req.body;
        }

        if (event.type === 'checkout.session.completed') {
            const session = event.data.object;
            const userId = session.metadata?.userId || session.client_reference_id;
            const planId = session.metadata?.planId;

            if (userId && planId) {
                // Get the plan
                const planResult = await pool.query(
                    'SELECT * FROM subscription_plans WHERE id = $1',
                    [planId]
                );

                if (planResult.rows.length > 0) {
                    const plan = planResult.rows[0];

                    // Update user subscription
                    const subResult = await pool.query(
                        'SELECT * FROM user_subscriptions WHERE user_id = $1',
                        [userId]
                    );

                    const currentCredits = subResult.rows[0]?.current_credits || 0;
                    const newBalance = currentCredits + plan.credits_per_month;

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

                    // Record transaction
                    await pool.query(`
                        INSERT INTO credit_transactions 
                        (user_id, amount, transaction_type, description, balance_after, metadata)
                        VALUES ($1, $2, 'plan_upgrade', $3, $4, $5)
                    `, [
                        userId,
                        plan.credits_per_month,
                        `Upgraded to ${plan.name} via Stripe`,
                        newBalance,
                        JSON.stringify({
                            stripe_session_id: session.id,
                            plan_id: planId
                        })
                    ]);

                    console.log(`[STRIPE WEBHOOK] Successfully upgraded user ${userId} to ${plan.name}`);
                }
            }
        }

        res.json({ received: true });
    } catch (error: any) {
        console.error('Stripe webhook error:', error);
        res.status(400).json({ error: 'Webhook error: ' + error.message });
    }
});

// Protected routes
router.use(authenticateToken);

// Get current user's subscription
router.get('/me', async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId!;
        console.log(`[SUB] Fetching subscription for user: ${userId}`);

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
            console.log(`[SUB] No subscription found, auto-provisioning for user ${userId}`);

            // First check all available plans
            const allPlans = await pool.query(`SELECT id, name, is_free_plan, credits_per_month FROM subscription_plans`);
            console.log(`[SUB] Available plans:`, allPlans.rows);

            let freePlanResult = await pool.query(
                `SELECT id, credits_per_month FROM subscription_plans WHERE is_free_plan = TRUE LIMIT 1`
            );

            if (freePlanResult.rows.length === 0) {
                console.log(`[SUB] No free plan found, creating one...`);
                // Create free plan if it doesn't exist
                freePlanResult = await pool.query(`
                    INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, is_active) 
                    VALUES ('Free', 50, 0, true, true)
                    RETURNING id, credits_per_month
                `);
                console.log(`[SUB] Created free plan:`, freePlanResult.rows[0]);
            }

            console.log(`[SUB] Using free plan: ${freePlanResult.rows[0].id} with ${freePlanResult.rows[0].credits_per_month} credits`);

            try {
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
                console.log(`[SUB] Successfully created subscription for user ${userId}`);
            } catch (insertError: any) {
                console.error(`[SUB] Error inserting subscription:`, insertError.message);
                // Check if it's a duplicate key error (subscription already exists)
                if (insertError.code === '23505') {
                    console.log(`[SUB] Subscription already exists, fetching it...`);
                } else {
                    throw insertError;
                }
            }

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

            console.log(`[SUB] Returning subscription:`, newResult.rows[0]);
            return res.json({ subscription: newResult.rows[0] });
        }

        console.log(`[SUB] Found existing subscription for user ${userId}:`, result.rows[0]);
        res.json({ subscription: result.rows[0] });
    } catch (error: any) {
        console.error('Error fetching subscription:', error.message, error.stack);
        res.status(500).json({ error: 'Failed to fetch subscription: ' + error.message });
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
        const userId = req.userId!;
        console.log(`[SUB] Creating subscription for user: ${userId}`);

        const existing = await pool.query(
            'SELECT id FROM user_subscriptions WHERE user_id = $1',
            [userId]
        );

        if (existing.rows.length > 0) {
            console.log(`[SUB] Subscription already exists for user ${userId}`);
            return res.json({ message: 'Subscription already exists' });
        }

        const planResult = await pool.query(`
            SELECT id, credits_per_month FROM subscription_plans 
            WHERE is_free_plan = TRUE 
            LIMIT 1
        `);

        console.log(`[SUB] Free plan query result:`, planResult.rows);

        if (planResult.rows.length === 0) {
            console.log(`[SUB] No free plan found!`);
            return res.status(404).json({ error: 'No free plan available' });
        }

        const freePlan = planResult.rows[0];
        console.log(`[SUB] Using free plan: ${freePlan.id} with ${freePlan.credits_per_month} credits`);

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

        console.log(`[SUB] Successfully created subscription for user ${userId}`);
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
