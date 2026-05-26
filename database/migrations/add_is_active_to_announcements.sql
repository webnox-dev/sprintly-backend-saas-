-- Add is_active column to announcements table
ALTER TABLE announcements
ADD COLUMN IF NOT EXISTS is_active SMALLINT DEFAULT 1;

-- Add index on is_active for faster filtering
CREATE INDEX IF NOT EXISTS idx_announcements_is_active ON announcements (is_active);