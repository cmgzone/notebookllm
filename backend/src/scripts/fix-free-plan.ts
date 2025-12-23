import pool, { initializeDatabase } from '../config/database.js';

async function fixFreePlan() {
    await initializeDatabase();
    
    console.log('Checking subscription plans...');
    
    // Check current plans
    const plans = await pool.query('SELECT * FROM subscription_plans');
    console.log('Current plans:', plans.rows);
    
    // Check if any plan has is_free_plan = true
    const freePlan = await pool.query('SELECT * FROM subscription_plans WHERE is_free_plan = TRUE');
    console.log('Free plans:', freePlan.rows);
    
    if (freePlan.rows.length === 0) {
        console.log('No free plan found! Updating the cheapest plan to be free...');
        
        // Find the plan with price = 0 or the cheapest one
        const cheapest = await pool.query(`
            SELECT id, name FROM subscription_plans 
            WHERE price = 0 OR name ILIKE '%free%'
            ORDER BY price ASC
            LIMIT 1
        `);
        
        if (cheapest.rows.length > 0) {
            await pool.query(`
                UPDATE subscription_plans 
                SET is_free_plan = TRUE 
                WHERE id = $1
            `, [cheapest.rows[0].id]);
            console.log(`Updated plan "${cheapest.rows[0].name}" to be the free plan`);
        } else {
            // Create a new free plan
            await pool.query(`
                INSERT INTO subscription_plans (name, credits_per_month, price, is_free_plan, is_active)
                VALUES ('Free', 50, 0, TRUE, TRUE)
            `);
            console.log('Created new Free plan');
        }
    }
    
    // Check user subscriptions
    const subs = await pool.query(`
        SELECT us.*, u.email, sp.name as plan_name
        FROM user_subscriptions us
        JOIN users u ON us.user_id = u.id
        JOIN subscription_plans sp ON us.plan_id = sp.id
    `);
    console.log('User subscriptions:', subs.rows);
    
    // Check if zonecmg@gmail.com has a subscription
    const targetUser = await pool.query(`
        SELECT u.id, u.email, us.id as sub_id
        FROM users u
        LEFT JOIN user_subscriptions us ON u.id = us.user_id
        WHERE u.email = 'zonecmg@gmail.com'
    `);
    console.log('Target user (zonecmg@gmail.com):', targetUser.rows);
    
    if (targetUser.rows.length > 0 && !targetUser.rows[0].sub_id) {
        console.log('User has no subscription, creating one...');
        
        const freePlanId = (await pool.query(`
            SELECT id, credits_per_month FROM subscription_plans WHERE is_free_plan = TRUE LIMIT 1
        `)).rows[0];
        
        if (freePlanId) {
            await pool.query(`
                INSERT INTO user_subscriptions (user_id, plan_id, current_credits, last_renewal_date, next_renewal_date)
                VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '1 month')
            `, [targetUser.rows[0].id, freePlanId.id, freePlanId.credits_per_month]);
            console.log('Created subscription for zonecmg@gmail.com');
        }
    }
    
    console.log('Done!');
    process.exit(0);
}

fixFreePlan().catch(err => {
    console.error('Error:', err);
    process.exit(1);
});
