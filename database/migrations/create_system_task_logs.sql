-- ============================================
-- SYSTEM TASK LOGS TABLE
-- Tracks background tasks like celebration checks to avoid duplicates
-- ============================================
CREATE TABLE IF NOT EXISTS system_task_logs (
    task_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_name VARCHAR(100) NOT NULL,
    run_date DATE NOT NULL,
    run_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'success',
    details TEXT,
    UNIQUE (task_name, run_date)
);

CREATE INDEX IF NOT EXISTS idx_system_task_logs_name_date ON system_task_logs (task_name, run_date);