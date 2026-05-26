-- Migration: Add is_starred and is_pinned columns to chat_messages for global visibility
-- When a user stars or pins a message, it should be visible to all participants

-- Add is_starred column to chat_messages (global, not per-user)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_starred'
    ) THEN
        ALTER TABLE chat_messages ADD COLUMN is_starred BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_starred column to chat_messages';
    END IF;
END $$;

-- Add is_pinned column to chat_messages (global, not per-conversation single pin)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_pinned'
    ) THEN
        ALTER TABLE chat_messages ADD COLUMN is_pinned BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_pinned column to chat_messages';
    END IF;
END $$;

-- Create indexes for efficient filtering
CREATE INDEX IF NOT EXISTS idx_chat_messages_starred ON chat_messages (conversation_id, is_starred)
WHERE
    is_starred = TRUE;

CREATE INDEX IF NOT EXISTS idx_chat_messages_pinned ON chat_messages (conversation_id, is_pinned)
WHERE
    is_pinned = TRUE;

-- Note: The existing chat_starred_messages table and chat_conversations.pinned_message_id
-- can be deprecated in favor of these new columns for global visibility