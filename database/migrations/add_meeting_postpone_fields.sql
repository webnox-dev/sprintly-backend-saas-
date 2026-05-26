-- ============================================
-- ADD MEETING POSTPONE FIELDS MIGRATION
-- Adds columns for postponement tracking
-- ============================================

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS postpone_reason TEXT;

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS original_date DATE;

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS original_start_time TIME;

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS original_end_time TIME;

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS postponed_by VARCHAR(255);

ALTER TABLE calendar_meetings
ADD COLUMN IF NOT EXISTS postponed_at TIMESTAMP;