-- Fix: Use plan's credits_per_month from database (admin-configurable)
-- Run this to update the trigger and existing users

-- 1. Update the trigger to use plan's credits_per_month (fully dynamic)
CREATE OR REPLACE FUNCTION assign_free_plan_to_new_user()
RETURNS TRIGGER AS $$
DECLARE
    free_plan_id TEXT;
    plan_credits INTEGER;
BEGIN
    -- Get the free plan ID and its credits from database
    SELECT id, credits_per_month INTO free_plan_id, plan_credits
    FROM subscription_plans
    WHERE is_free_plan = TRUE
    LIMIT 1;

    -- Create subscription for new user with plan's credits
    IF free_plan_id IS NOT NULL AND plan_credits IS NOT NULL THEN
        INSERT INTO user_subscriptions (
            user_id,
            plan_id,
            current_credits,
            last_renewal_date,
            next_renewal_date
        )
        VALUES (
            NEW.id,
            free_plan_id,
            plan_credits, -- Always use plan's credits_per_month from DB
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP + INTERVAL '1 month'
        )
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to assign free plan to user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS trigger_assign_free_plan ON users;
CREATE TRIGGER trigger_assign_free_plan
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION assign_free_plan_to_new_user();

-- 2. Update ALL existing users to use their plan's credits_per_month
UPDATE user_subscriptions us
SET current_credits = sp.credits_per_month
FROM subscription_plans sp
WHERE us.plan_id = sp.id;

-- 3. Create subscriptions for users who don't have one
INSERT INTO user_subscriptions (user_id, plan_id, current_credits, last_renewal_date, next_renewal_date)
SELECT 
    u.id,
    sp.id,
    sp.credits_per_month,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP + INTERVAL '1 month'
FROM users u
CROSS JOIN (SELECT id, credits_per_month FROM subscription_plans WHERE is_free_plan = TRUE LIMIT 1) sp
WHERE NOT EXISTS (
    SELECT 1 FROM user_subscriptions us WHERE us.user_id = u.id
);

-- 4. Create a function to sync user credits when admin updates plan
CREATE OR REPLACE FUNCTION sync_plan_credits_on_update()
RETURNS TRIGGER AS $$
BEGIN
    -- When a plan's credits_per_month is updated,
    -- update users on that plan who haven't used credits this month
    UPDATE user_subscriptions
    SET current_credits = NEW.credits_per_month
    WHERE plan_id = NEW.id
      AND credits_consumed_this_month = 0
      AND current_credits = OLD.credits_per_month;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for plan updates
DROP TRIGGER IF EXISTS trigger_sync_plan_credits ON subscription_plans;
CREATE TRIGGER trigger_sync_plan_credits
    AFTER UPDATE OF credits_per_month ON subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION sync_plan_credits_on_update();

-- 5. Function to manually reset all users on a plan to new credit amount
CREATE OR REPLACE FUNCTION reset_plan_credits(target_plan_id TEXT)
RETURNS INTEGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    UPDATE user_subscriptions
    SET current_credits = sp.credits_per_month,
        credits_consumed_this_month = 0,
        last_renewal_date = CURRENT_TIMESTAMP,
        next_renewal_date = CURRENT_TIMESTAMP + INTERVAL '1 month'
    FROM subscription_plans sp
    WHERE user_subscriptions.plan_id = sp.id
      AND user_subscriptions.plan_id = target_plan_id;

    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- Verify the fix
SELECT 'Subscription credits fix applied!' AS status;
SELECT
    sp.name as plan_name,
    sp.credits_per_month as plan_credits,
    COUNT(us.id) as user_count
FROM subscription_plans sp
LEFT JOIN user_subscriptions us ON sp.id = us.plan_id
GROUP BY sp.id, sp.name, sp.credits_per_month;
