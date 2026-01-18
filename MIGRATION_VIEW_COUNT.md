# Database Migration: Add View Count Support

## Issue
The `view_count` column is missing from the `notebooks` and `plans` tables, causing view counts to not display on public pages.

## Solution
Run the following SQL migration on your Neon database:

```sql
-- Add social sharing columns to notebooks and plans
BEGIN;

-- Add columns to notebooks table
ALTER TABLE notebooks 
  ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS category TEXT;

-- Add columns to plans table
ALTER TABLE plans 
  ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notebooks_is_public ON notebooks(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_notebooks_view_count ON notebooks(view_count DESC);
CREATE INDEX IF NOT EXISTS idx_plans_is_public ON plans(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_plans_view_count ON plans(view_count DESC);

COMMIT;
```

## How to Run

### Option 1: Via Neon Console (Recommended)
1. Go to https://neon.tech
2. Select your project
3. Click "SQL Editor"
4. Paste the SQL above
5. Click "Run"

### Option 2: Via psql
```bash
psql $DATABASE_URL < backend/migrations/add_social_sharing_columns.sql
```

### Option 3: Via Backend Code
Create an endpoint or script to run the migration programmatically.

## Verification

After running the migration, verify with:
```sql
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'notebooks' 
  AND column_name IN ('view_count', 'share_count', 'is_public', 'is_locked');
```

Expected output:
- view_count | integer | 0
- share_count | integer | 0  
- is_public | boolean | false
- is_locked | boolean | false

## Impact
Once migrated, view counts will:
- ✅ Display correctly on public notebook/plan pages
- ✅ Increment when users visit public links
- ✅ Be visible to content owners in analytics
