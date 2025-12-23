import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        // Add features column if missing
        await client.query(`
            ALTER TABLE subscription_plans 
            ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '[]'
        `);
        console.log('✅ Added features column to subscription_plans');

        // Add status column to user_subscriptions if missing
        await client.query(`
            ALTER TABLE user_subscriptions 
            ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active'
        `);
        console.log('✅ Added status column to user_subscriptions');

        // Create subscription for zonecmg@gmail.com if missing
        const userCheck = await client.query(`
            SELECT u.id FROM users u 
            LEFT JOIN user_subscriptions us ON u.id = us.user_id
            WHERE u.email = 'zonecmg@gmail.com' AND us.id IS NULL
        `);

        if (userCheck.rows.length > 0) {
            const userId = userCheck.rows[0].id;
            const freePlan = await client.query(`
                SELECT id, credits_per_month FROM subscription_plans WHERE is_free_plan = true LIMIT 1
            `);
            
            if (freePlan.rows.length > 0) {
                await client.query(`
                    INSERT INTO user_subscriptions (user_id, plan_id, current_credits, status, last_renewal_date, next_renewal_date)
                    VALUES ($1, $2, $3, 'active', NOW(), NOW() + INTERVAL '1 month')
                `, [userId, freePlan.rows[0].id, freePlan.rows[0].credits_per_month]);
                console.log('✅ Created subscription for zonecmg@gmail.com');
            }
        } else {
            console.log('ℹ️ zonecmg@gmail.com already has a subscription or user not found');
        }

        // Verify
        const result = await client.query(`
            SELECT u.email, us.current_credits, sp.name as plan_name
            FROM users u
            LEFT JOIN user_subscriptions us ON u.id = us.user_id
            LEFT JOIN subscription_plans sp ON us.plan_id = sp.id
            WHERE u.email = 'zonecmg@gmail.com'
        `);
        console.log('\nUser subscription:', result.rows[0]);

    } catch (error: any) {
        console.error('Error:', error.message);
    } finally {
        client.release();
        await pool.end();
    }
}

run();
