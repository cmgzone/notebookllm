import pool from '../config/database.js';

async function run() {
    const client = await pool.connect();
    try {
        // Check subscription plans
        const plans = await client.query('SELECT * FROM subscription_plans');
        console.log('Plans:', plans.rows.length);
        console.log(JSON.stringify(plans.rows, null, 2));

        // Check user subscriptions
        const subs = await client.query(`
            SELECT us.*, sp.name as plan_name, u.email
            FROM user_subscriptions us
            JOIN subscription_plans sp ON us.plan_id = sp.id
            JOIN users u ON us.user_id = u.id
        `);
        console.log('\nUser Subscriptions:', subs.rows.length);
        console.log(JSON.stringify(subs.rows, null, 2));

        // Check credit packages
        const packages = await client.query('SELECT * FROM credit_packages WHERE is_active = true');
        console.log('\nCredit Packages:', packages.rows.length);
        console.log(JSON.stringify(packages.rows, null, 2));
    } catch (error: any) {
        console.error('Error:', error.message);
    } finally {
        client.release();
        await pool.end();
    }
}

run();
