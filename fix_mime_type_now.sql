-- Quick fix for mime_type column issue
-- Run this directly in your database

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

-- Verify the column was added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sources' AND column_name = 'mime_type';