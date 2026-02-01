-- Migration: Add Gitu Messages Table for Persistent Conversational Memory
-- Design Requirement: Section 4 (Conversational Memory)

-- ==================== GITU MESSAGES TABLE ====================
-- Stores chat history for Gitu Assistant across platforms (web, cli, whatsapp, telegram)

CREATE TABLE IF NOT EXISTS gitu_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id TEXT, -- Optional session group identifier
    platform TEXT NOT NULL, -- 'web', 'cli', 'whatsapp', 'telegram'
    platform_user_id TEXT, -- platform-specific user identifier
    role TEXT NOT NULL, -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==================== INDEXES FOR PERFORMANCE ====================

-- Index for fetching history by session
CREATE INDEX IF NOT EXISTS idx_gitu_messages_session ON gitu_messages(session_id);

-- Index for fetching recent history by user and platform
CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_platform ON gitu_messages(user_id, platform);

-- Index for time-based cleanup or sorting
CREATE INDEX IF NOT EXISTS idx_gitu_messages_created ON gitu_messages(created_at);

-- Partial index for active sessions per user
CREATE INDEX IF NOT EXISTS idx_gitu_messages_active_sessions ON gitu_messages(user_id, session_id)
WHERE session_id IS NOT NULL;

SELECT 'Gitu messages table created successfully!' as status;
