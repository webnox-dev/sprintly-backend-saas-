-- Add status to chat_user_presence table
ALTER TABLE chat_user_presence
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'offline';