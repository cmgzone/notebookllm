-- Add mime_type column to sources table
-- This column is needed for proper content type handling in ingestion

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

-- Add comment for documentation
COMMENT ON COLUMN sources.mime_type IS 'MIME type of the source content for proper processing';