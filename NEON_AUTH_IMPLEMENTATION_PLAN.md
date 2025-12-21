# Neon Authorize Implementation Plan

Based on your request to "add Neon Auth", the best approach for your architecture (Flutter + Firebase + Neon) is to use **Neon Authorize**.

## What is Neon Authorize?
Neon Authorize allows you to secure your database using **Row-Level Security (RLS)**. Instead of using a single shared password for your app (which is insecure), your app will send the **Firebase User ID Token (JWT)** to Neon. Neon validates this token and allows the user to access *only* their own data.

## Architecture
1.  **App**: Authenticates with Firebase Auth.
2.  **App**: Gets a JWT (ID Token) from Firebase.
3.  **App**: Connects to Neon using the JWT as the password/token.
4.  **Neon**: Validates the JWT against Firebase's public keys.
5.  **Postgres**: Enforces RLS policies (e.g., `WHERE user_id = auth.user_id()`).

## Step 1: Configure Neon Console (You must do this)
You need to enable Neon Authorize in your Neon Console:
1.  Go to the **Neon Console**.
2.  Navigate to **Settings** > **Authorize** (or Authentication).
3.  Add a new **Authentication Provider**.
4.  Select **Firebase**.
5.  Enter your **Firebase Project ID** (found in your `.env` as `FIREBASE_PROJECT_ID`).
6.  Neon will give you a **JWKS URL** (usually auto-configured for Firebase).

## Step 2: Database Setup (SQL)
You need to run the following SQL to enable RLS and create policies. I have created a file `neon_auth_setup.sql` with these commands.

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebook_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_credentials ENABLE ROW LEVEL SECURITY;

-- Create the authenticated role (if not exists)
-- Note: Neon Authorize usually maps the JWT to a role named 'authenticated' or similar.
-- Check your Neon Authorize settings for the specific role name.
-- DO NOT RUN THIS if Neon manages the role for you.

-- Create Policies

-- Users: Can view/edit their own profile
CREATE POLICY "Users can manage own profile" ON users
  USING (id = auth.user_id())
  WITH CHECK (id = auth.user_id());

-- Notebooks: Can manage own notebooks
CREATE POLICY "Users can manage own notebooks" ON notebooks
  USING (user_id = auth.user_id())
  WITH CHECK (user_id = auth.user_id());

-- Sources: Can manage sources in their notebooks
CREATE POLICY "Users can manage own sources" ON sources
  USING (notebook_id IN (SELECT id FROM notebooks WHERE user_id = auth.user_id()))
  WITH CHECK (notebook_id IN (SELECT id FROM notebooks WHERE user_id = auth.user_id()));

-- ... (Policies for other tables are in the SQL file)
```

## Step 3: Flutter Code Changes
I will modify the `NeonDatabaseService` to:
1.  Accept a `getAuthToken` callback or function.
2.  When connecting, fetch the current Firebase ID Token.
3.  Use this token as the password for the Postgres connection.

## Next Steps
1.  **Review** the `neon_auth_setup.sql` file I am creating.
2.  **Run** the SQL in your Neon Console SQL Editor.
3.  **Configure** the Provider in Neon Console.
4.  **Let me know** when you are ready for me to update the Flutter code to use the JWT tokens.
