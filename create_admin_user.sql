-- Create Admin User Script
-- Run this in your Neon SQL console to create an admin user

-- Option 1: Update an existing user to be an admin
-- Replace 'your@email.com' with your actual email address
UPDATE users 
SET role = 'admin', is_active = TRUE 
WHERE email = 'your@email.com';

-- Option 2: Insert a new admin user (if the email doesn't exist)
-- Replace the values with your desired admin credentials
INSERT INTO users (id, email, display_name, role, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'admin@example.com',
    'Admin User',
    'admin',
    TRUE,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO UPDATE 
SET role = 'admin', is_active = TRUE;

-- Verify the admin user was created/updated
SELECT id, email, display_name, role, is_active 
FROM users 
WHERE role = 'admin';
