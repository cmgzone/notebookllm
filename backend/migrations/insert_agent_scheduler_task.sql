-- Automatically insert a scheduled task for agent processing when a new user is created
CREATE OR REPLACE FUNCTION create_user_agent_task()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO gitu_scheduled_tasks (
        id, 
        user_id, 
        name, 
        action, 
        cron, 
        enabled, 
        trigger
    )
    VALUES (
        gen_random_uuid(),
        NEW.id,
        'Process Autonomous Agents',
        'agents.processQueue',
        '* * * * *', -- Run every minute
        true,
        'cron'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on new user creation
DROP TRIGGER IF EXISTS trigger_create_user_agent_task ON users;
CREATE TRIGGER trigger_create_user_agent_task
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_agent_task();

-- Backfill for existing users who don't have this task
INSERT INTO gitu_scheduled_tasks (id, user_id, name, action, cron, enabled, trigger)
SELECT 
    gen_random_uuid(),
    id,
    'Process Autonomous Agents',
    'agents.processQueue',
    '* * * * *',
    true,
    'cron'
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM gitu_scheduled_tasks t 
    WHERE t.user_id = u.id AND t.action = 'agents.processQueue'
);
