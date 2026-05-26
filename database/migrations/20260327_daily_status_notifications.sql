-- Create daily_status_notifications table to track admin email notifications for late/absent employees
CREATE TABLE IF NOT EXISTS daily_status_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_date DATE NOT NULL UNIQUE,
    is_email_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_daily_status_notifications_date ON daily_status_notifications (notification_date);
