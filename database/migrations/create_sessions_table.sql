-- Migration: Create Sessions table for JWT management
-- Run this on your PostgreSQL database

-- ============================================
-- SESSIONS TABLE (JWT-Based Session Management)
-- Tracks active login sessions per user/device
-- ============================================
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('Admin', 'Employee')
    ),
    jwt_token TEXT NOT NULL,
    device_name VARCHAR(255) DEFAULT 'Unknown',
    platform VARCHAR(20) DEFAULT 'Unknown',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_user_type ON sessions (user_type);

CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions (is_active);

CREATE INDEX IF NOT EXISTS idx_sessions_jwt_token ON sessions (jwt_token);

-- Trigger for auto-updating updated_at
-- This function might already exist from other tables
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trigger_update_sessions_updated_at ON sessions;

CREATE TRIGGER trigger_update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sessions IS 'JWT-based login sessions for session management and remote logout';