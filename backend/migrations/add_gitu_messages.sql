-- Migration: Add Gitu Messages Table for Persistent Conversational Memory
-- Design Requirement: Section 4 (Conversational Memory)

-- ==================== GITU MESSAGES TABLE ====================
-- Stores chat history for Gitu Assistant across platforms (web, terminal, whatsapp, telegram)

CREATE TABLE IF NOT EXISTS gitu_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id TEXT, -- Optional session group identifier
    platform TEXT NOT NULL, -- 'web', 'terminal', 'whatsapp', 'telegram', 'flutter', 'email'
    platform_user_id TEXT, -- platform-specific user identifier
    role TEXT NOT NULL, -- 'user', 'assistant', 'system'
    content JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_message_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal', 'web'))
);

-- ==================== INDEXES FOR PERFORMANCE ====================

-- Index for fetching history by session
CREATE INDEX IF NOT EXISTS idx_gitu_messages_session ON gitu_messages(session_id);

-- Index for fetching recent history by user and platform
CREATE INDEX IF NOT EXISTS idx_gitu_messages_user_platform ON gitu_messages(user_id, platform);

-- Index for time-based cleanup or sorting
CREATE INDEX IF NOT EXISTS idx_gitu_messages_timestamp ON gitu_messages(timestamp);

-- Partial index for active sessions per user
CREATE INDEX IF NOT EXISTS idx_gitu_messages_active_sessions ON gitu_messages(user_id, session_id)
WHERE session_id IS NOT NULL;

SELECT 'Gitu messages table created successfully!' as status;
