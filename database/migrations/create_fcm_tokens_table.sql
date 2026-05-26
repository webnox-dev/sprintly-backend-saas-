-- Migration: Create FCM Tokens table if not exists
-- Run this on your PostgreSQL database to add FCM token support

-- ============================================
-- FCM TOKENS TABLE (Firebase Cloud Messaging)
-- Supports multiple devices per user
-- ============================================
CREATE TABLE IF NOT EXISTS fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('Admin', 'Employee')
    ),
    fcm_token TEXT NOT NULL,
    jwt_token TEXT,
    device_type VARCHAR(20) DEFAULT 'unknown',
    device_name VARCHAR(255),
    platform VARCHAR(20) DEFAULT 'unknown',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_fcm_token UNIQUE (fcm_token)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens (user_id);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_type ON fcm_tokens (user_type);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON fcm_tokens (is_active);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_jwt_token ON fcm_tokens (jwt_token)
WHERE
    jwt_token IS NOT NULL;

-- Add jwt_token column to existing tables (CREATE TABLE IF NOT EXISTS skips existing tables)
ALTER TABLE fcm_tokens ADD COLUMN IF NOT EXISTS jwt_token TEXT;

-- Add FCM token columns to admins table (direct token storage)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'fcm_token') THEN
        ALTER TABLE admins ADD COLUMN fcm_token TEXT;

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE
        table_name = 'admins'
        AND column_name = 'fcm_token_updated_at'
) THEN
ALTER TABLE admins
ADD COLUMN fcm_token_updated_at TIMESTAMPTZ;

END IF;

END $$;

-- Add FCM token columns to employees table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'fcm_token') THEN
        ALTER TABLE employees ADD COLUMN fcm_token TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'fcm_token_updated_at') THEN
        ALTER TABLE employees ADD COLUMN fcm_token_updated_at TIMESTAMPTZ;
    END IF;
END $$;

-- Create or replace trigger function for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger for fcm_tokens table
DROP TRIGGER IF EXISTS trigger_update_fcm_tokens_updated_at ON fcm_tokens;

CREATE TRIGGER trigger_update_fcm_tokens_updated_at 
    BEFORE UPDATE ON fcm_tokens 
    FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

-- Add comment to table
COMMENT ON TABLE fcm_tokens IS 'Firebase Cloud Messaging tokens for push notifications - supports multiple devices per user';

-- Success message
SELECT 'FCM tokens migration completed successfully' AS status;