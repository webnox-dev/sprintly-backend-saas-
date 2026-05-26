-- ===========================================================================
-- Migration: Add Device and Location info to Sessions table
-- Date: 2026-02-24
-- Description: Adds columns for IP address, location, browser, and main device status.
-- ===========================================================================

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS ip_address VARCHAR(50);

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS city VARCHAR(100);

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS state VARCHAR(100);

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS country VARCHAR(100);

ALTER TABLE sessions ADD COLUMN IF NOT EXISTS browser VARCHAR(255);

ALTER TABLE sessions
ADD COLUMN IF NOT EXISTS is_main_device BOOLEAN DEFAULT FALSE;

-- Add index for main device lookup
CREATE INDEX IF NOT EXISTS idx_sessions_main_device ON sessions (user_id, is_main_device)
WHERE
    is_main_device = true;

COMMENT ON COLUMN sessions.ip_address IS 'IP address of the client device';

COMMENT ON COLUMN sessions.city IS 'City from IP geolocation';

COMMENT ON COLUMN sessions.state IS 'State/Region from IP geolocation';

COMMENT ON COLUMN sessions.country IS 'Country from IP geolocation';

COMMENT ON COLUMN sessions.browser IS 'Browser/User-Agent summary';

COMMENT ON COLUMN sessions.is_main_device IS 'Whether this is the designated primary/main device';