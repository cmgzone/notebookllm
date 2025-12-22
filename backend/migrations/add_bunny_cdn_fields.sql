-- Migration: Add Bunny.net CDN fields to sources table
-- Run this migration to enable CDN storage for media files

-- Add CDN-related columns to sources table
ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_path TEXT;
ALTER TABLE sources ADD COLUMN IF NOT EXISTS media_size BIGINT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_sources_media_url ON sources(media_url) WHERE media_url IS NOT NULL;

-- Create media_uploads table to track direct uploads (user_id as TEXT to match existing schema)
CREATE TABLE IF NOT EXISTS media_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    path TEXT NOT NULL,
    url TEXT NOT NULL,
    filename TEXT NOT NULL,
    type TEXT DEFAULT 'file',
    size BIGINT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_uploads_user ON media_uploads(user_id);
CREATE INDEX IF NOT EXISTS idx_media_uploads_path ON media_uploads(path);

-- Add comment for documentation
COMMENT ON COLUMN sources.media_url IS 'CDN URL for the media file (Bunny.net)';
COMMENT ON COLUMN sources.media_path IS 'Storage path on CDN for deletion';
COMMENT ON COLUMN sources.media_size IS 'Size of media file in bytes';
