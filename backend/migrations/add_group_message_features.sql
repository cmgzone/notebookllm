-- Group Message Features: edits, deletes, reactions, pins

-- Add edit/delete metadata to group messages
ALTER TABLE group_messages
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_by TEXT;

CREATE INDEX IF NOT EXISTS idx_group_messages_deleted ON group_messages(is_deleted);

-- Reactions (one reaction per user per message)
CREATE TABLE IF NOT EXISTS group_message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction_type VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_message_reactions_message ON group_message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_group_message_reactions_user ON group_message_reactions(user_id);

-- Pins
CREATE TABLE IF NOT EXISTS group_message_pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id TEXT NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
  pinned_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pinned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_group_message_pins_group ON group_message_pins(group_id);
