-- TeamSync: Reactions, Pin, Star migration
-- Run this after main schema

-- Chat Message Reactions
CREATE TABLE IF NOT EXISTS chat_message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    reaction VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (message_id, user_id, user_type)
);

CREATE INDEX IF NOT EXISTS idx_chat_message_reactions_message ON chat_message_reactions (message_id);

-- Pinned message per conversation
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'pinned_message_id'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN pinned_message_id UUID REFERENCES chat_messages (id) ON DELETE SET NULL;
        RAISE NOTICE 'Added pinned_message_id to chat_conversations';
    END IF;
END $$;

-- Starred messages (per user)
CREATE TABLE IF NOT EXISTS chat_starred_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    message_id UUID NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, user_type, message_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_starred_messages_user ON chat_starred_messages (user_id, user_type);
CREATE INDEX IF NOT EXISTS idx_chat_starred_messages_message ON chat_starred_messages (message_id);
