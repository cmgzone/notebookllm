-- Fix for Gitu Memories Schema (Missing columns)
DO $$
BEGIN
    -- Add verification_required if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_memories' AND column_name='verification_required') THEN
        ALTER TABLE gitu_memories ADD COLUMN verification_required BOOLEAN DEFAULT false;
    END IF;

    -- Add tags if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_memories' AND column_name='tags') THEN
        ALTER TABLE gitu_memories ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;

    -- Add last_confirmed_by_user if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_memories' AND column_name='last_confirmed_by_user') THEN
        ALTER TABLE gitu_memories ADD COLUMN last_confirmed_by_user TIMESTAMPTZ;
    END IF;

    -- Add access_count if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_memories' AND column_name='access_count') THEN
        ALTER TABLE gitu_memories ADD COLUMN access_count INTEGER DEFAULT 0;
    END IF;
    
    -- Add last_accessed_at if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gitu_memories' AND column_name='last_accessed_at') THEN
        ALTER TABLE gitu_memories ADD COLUMN last_accessed_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;
