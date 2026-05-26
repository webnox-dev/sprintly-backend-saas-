-- Migration: Add chat_theme_id to chat_conversations for shared theme across participants
-- This allows conversation participants to share a common chat theme

DO $$
BEGIN
    -- Add chat_theme_id column to chat_conversations if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'chat_theme_id'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN chat_theme_id VARCHAR(50) DEFAULT 'default_blue';
        RAISE NOTICE 'Added chat_theme_id column to chat_conversations';
    END IF;
END $$;

-- Add a comment explaining the column
COMMENT ON COLUMN chat_conversations.chat_theme_id IS 'The selected chat theme ID for this conversation (e.g., default_blue, midnight_purple, ocean_teal, sunset_orange, forest_green)';