-- Step 1: Check if the user exists in the database
SELECT id, email, display_name, role, is_active 
FROM users 
WHERE email = 'cmgtrend@gmail.com';

-- If the above returns NO ROWS, the user doesn't exist. Run this:
INSERT INTO users (id, email, display_name, role, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'cmgtrend@gmail.com',
    'Admin',
    'admin',
    TRUE,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO UPDATE 
SET role = 'admin', is_active = TRUE;

-- If the above returns a row, but role is NOT 'admin', run this:
UPDATE users 
SET role = 'admin', is_active = TRUE 
WHERE email = 'cmgtrend@gmail.com';

-- Step 2: Verify the admin user now exists
SELECT id, email, display_name, role, is_active 
FROM users 
WHERE email = 'cmgtrend@gmail.com' AND role = 'admin';

-- This should return one row with role = 'admin'
