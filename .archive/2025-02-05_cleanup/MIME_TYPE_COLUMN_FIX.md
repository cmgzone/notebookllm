# MIME Type Column Fix

## Problem
Your ingestion service is failing with:
```
error: column "mime_type" does not exist
```

This happens because the `sources` table is missing the `mime_type` column that the ingestion controller expects.

## Quick Fix

### Option 1: Run SQL directly in your database
Execute this SQL in your database console:

```sql
-- Add mime_type column to sources table
ALTER TABLE sources 
ADD COLUMN IF NOT EXISTS mime_type TEXT;

-- Add some common mime types for existing sources based on type
UPDATE sources 
SET mime_type = CASE 
    WHEN type = 'pdf' THEN 'application/pdf'
    WHEN type = 'text' THEN 'text/plain'
    WHEN type = 'url' THEN 'text/html'
    WHEN type = 'youtube' THEN 'video/youtube'
    WHEN type = 'google_drive' THEN 'application/octet-stream'
    ELSE 'text/plain'
END
WHERE mime_type IS NULL;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_sources_mime_type ON sources(mime_type);
```

### Option 2: Use the PowerShell script
Run this command from your project root:
```powershell
.\scripts\fix-mime-type-column.ps1
```

### Option 3: Manual database update
1. Connect to your Neon database
2. Run the SQL from `fix_mime_type_now.sql`

## Verification
After running the fix, verify with:
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sources' AND column_name = 'mime_type';
```

You should see:
```
column_name | data_type | is_nullable
mime_type   | text      | YES
```

## What This Fixes
- ✅ Ingestion service will work properly
- ✅ File uploads will process correctly  
- ✅ Content type detection will work
- ✅ RAG (Retrieval Augmented Generation) will function

## Root Cause
The migration file `backend/migrations/add_mime_type_column.sql` exists but wasn't executed during database setup. This fix ensures the column is added and populated with appropriate MIME types for existing sources.