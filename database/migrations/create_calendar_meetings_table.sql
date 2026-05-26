-- ============================================
-- CALENDAR MEETINGS TABLE MIGRATION
-- Creates the calendar_meetings table for scheduling meetings
-- ============================================

CREATE TABLE IF NOT EXISTS calendar_meetings (
    meeting_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    meeting_name VARCHAR(255) NOT NULL,
    meeting_description TEXT,
    -- Host (Admin who scheduled)
    host_id VARCHAR(50) NOT NULL,
    host_name VARCHAR(255),
    host_email VARCHAR(255),
    host_img TEXT,
    -- Venue (predefined locations)
    meeting_venue VARCHAR(255) NOT NULL,
    -- Date & Time
    meeting_date DATE NOT NULL,
    meeting_start_time TIME NOT NULL,
    meeting_end_time TIME NOT NULL,
    total_duration VARCHAR(50),
    -- Participants (JSONB array of {user_id, user_type, user_name, user_email, user_img})
    meeting_members JSONB DEFAULT '[]'::jsonb,
    -- Accepted members (JSONB array of user_ids who accepted)
    meeting_accepted_members JSONB DEFAULT '[]'::jsonb,
    -- Declined members (JSONB array of user_ids who declined)
    meeting_declined_members JSONB DEFAULT '[]'::jsonb,
    -- Google Meet Link (auto-generated or manual)
    gmeet_link TEXT,
    -- Meeting Status
    meeting_status VARCHAR(50) DEFAULT 'scheduled',
    -- Reminder tracking (JSONB: {"15min": true, "10min": true, "5min": false, "2min": false})
    reminders_sent JSONB DEFAULT '{"15min": false, "10min": false, "5min": false, "2min": false}'::jsonb,
    -- Audit
    created_by VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_calendar_meetings_host_id ON calendar_meetings (host_id);

CREATE INDEX IF NOT EXISTS idx_calendar_meetings_date ON calendar_meetings (meeting_date);

CREATE INDEX IF NOT EXISTS idx_calendar_meetings_status ON calendar_meetings (meeting_status);

CREATE INDEX IF NOT EXISTS idx_calendar_meetings_created_at ON calendar_meetings (created_at DESC);

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_update_calendar_meetings_updated_at ON calendar_meetings;

CREATE TRIGGER trigger_update_calendar_meetings_updated_at
    BEFORE UPDATE ON calendar_meetings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE calendar_meetings IS 'Calendar meetings with host, venue, participants, acceptance tracking, and reminder status';