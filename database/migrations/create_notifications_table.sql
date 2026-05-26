-- Migration: Create Notifications table for in-app notifications
-- Run this on your PostgreSQL database to add local notifications support

-- ============================================
-- NOTIFICATIONS TABLE (In-App Notifications)
-- Stores all local notifications for admins and employees
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('Admin', 'Employee')
    ),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    -- Related entity references
    related_entity_type VARCHAR(50), -- 'admin', 'employee', 'project', 'task', 'leave', 'permission', 'wfh', 'announcement', 'chat', 'celebration'
    related_entity_id VARCHAR(100),
    -- Additional data
    data JSONB DEFAULT '{}'::jsonb,
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_type ON notifications (user_type);

CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications (is_read);

CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications (notification_type);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications (user_id, user_type, is_read)
WHERE
    is_read = FALSE;

-- Add comment to table
COMMENT ON TABLE notifications IS 'In-app notifications for admins and employees - supports local notification display';

-- Success message
SELECT 'Notifications table migration completed successfully' AS status;