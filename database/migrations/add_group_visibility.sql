-- Migration: Add is_public and invite_code to chat_conversations for group visibility
-- Created: 2026-01-16

-- Add is_public column for public/private groups
ALTER TABLE chat_conversations
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

-- Add invite_code column for join links
ALTER TABLE chat_conversations
ADD COLUMN IF NOT EXISTS invite_code VARCHAR(50) UNIQUE;

-- Create index on invite_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_chat_conversations_invite_code ON chat_conversations (invite_code)
WHERE
    invite_code IS NOT NULL;

-- Create index on is_public for filtering public groups
CREATE INDEX IF NOT EXISTS idx_chat_conversations_is_public ON chat_conversations (is_public)
WHERE
    is_public = TRUE;

-- Add comment for documentation
COMMENT ON COLUMN chat_conversations.is_public IS 'Whether the group is public (anyone can join) or private (admin adds members)';

COMMENT ON COLUMN chat_conversations.invite_code IS 'Unique invite code for joining the group via link';