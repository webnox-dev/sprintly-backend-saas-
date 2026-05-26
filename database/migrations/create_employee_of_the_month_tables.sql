-- Migration: Employee of the Month module
-- Tables: daily points rollup, monthly rankings cache, winner history
-- Run this on your PostgreSQL database before using EOM APIs

-- ============================================
-- EOM POINTS CONFIG (optional - default weights)
-- ============================================
CREATE TABLE IF NOT EXISTS eom_points_config (
    config_key VARCHAR(50) PRIMARY KEY DEFAULT 'default',
    points_per_task_completed_on_time NUMERIC(10, 2) NOT NULL DEFAULT 10.00,
    points_per_task_completed_late NUMERIC(10, 2) NOT NULL DEFAULT 5.00,
    points_deduction_per_redo NUMERIC(10, 2) NOT NULL DEFAULT 5.00,
    points_per_day_attendance_ok NUMERIC(10, 2) NOT NULL DEFAULT 5.00,
    points_deduction_per_late_punch NUMERIC(10, 2) NOT NULL DEFAULT 2.00,
    points_deduction_per_early_out NUMERIC(10, 2) NOT NULL DEFAULT 2.00,
    points_deduction_per_short_hours NUMERIC(10, 2) NOT NULL DEFAULT 2.00,
    punch_in_deadline_time TIME DEFAULT '09:00',
    punch_out_deadline_time TIME DEFAULT '18:00',
    min_work_hours NUMERIC(4, 2) DEFAULT 9.00,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO eom_points_config (
    config_key,
    points_per_task_completed_on_time,
    points_per_task_completed_late,
    points_deduction_per_redo,
    points_per_day_attendance_ok,
    points_deduction_per_late_punch,
    points_deduction_per_early_out,
    points_deduction_per_short_hours
) VALUES ('default', 10.00, 5.00, 5.00, 5.00, 2.00, 2.00, 2.00)
ON CONFLICT (config_key) DO NOTHING;

-- ============================================
-- EMPLOYEE EOM POINTS DAILY
-- One row per employee per calendar day (precomputed)
-- ============================================
CREATE TABLE IF NOT EXISTS employee_eom_points_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id VARCHAR(50) NOT NULL,
    points_date DATE NOT NULL,
    month SMALLINT NOT NULL,
    year SMALLINT NOT NULL,
    task_points NUMERIC(10, 2) NOT NULL DEFAULT 0,
    attendance_points NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_points NUMERIC(10, 2) NOT NULL DEFAULT 0,
    breakdown JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_eom_daily_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE,
    CONSTRAINT uq_eom_daily_employee_date UNIQUE (employee_id, points_date)
);

CREATE INDEX IF NOT EXISTS idx_eom_daily_employee_month_year ON employee_eom_points_daily (employee_id, month, year);
CREATE INDEX IF NOT EXISTS idx_eom_daily_points_date ON employee_eom_points_daily (points_date);
CREATE INDEX IF NOT EXISTS idx_eom_daily_month_year ON employee_eom_points_daily (month, year);

COMMENT ON TABLE employee_eom_points_daily IS 'Precomputed daily points per employee for Employee of the Month; do not recalc on API call';

-- ============================================
-- EMPLOYEE MONTHLY RANKINGS
-- Cached total points and rank per employee per month
-- ============================================
CREATE TABLE IF NOT EXISTS employee_monthly_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id VARCHAR(50) NOT NULL,
    month SMALLINT NOT NULL,
    year SMALLINT NOT NULL,
    total_points NUMERIC(10, 2) NOT NULL DEFAULT 0,
    rank SMALLINT NOT NULL,
    task_summary JSONB DEFAULT '{}'::jsonb,
    attendance_summary JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_eom_rankings_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE,
    CONSTRAINT uq_eom_rankings_employee_month UNIQUE (employee_id, month, year)
);

CREATE INDEX IF NOT EXISTS idx_eom_rankings_month_year ON employee_monthly_rankings (month, year);
CREATE INDEX IF NOT EXISTS idx_eom_rankings_employee ON employee_monthly_rankings (employee_id);
CREATE INDEX IF NOT EXISTS idx_eom_rankings_rank ON employee_monthly_rankings (month, year, rank);

COMMENT ON TABLE employee_monthly_rankings IS 'Cached monthly rankings; filled by monthly EOM job';

-- ============================================
-- EMPLOYEE OF THE MONTH (Winner history)
-- ============================================
CREATE TABLE IF NOT EXISTS employee_of_the_month (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id VARCHAR(50) NOT NULL,
    month SMALLINT NOT NULL,
    year SMALLINT NOT NULL,
    total_points NUMERIC(10, 2) NOT NULL,
    rank SMALLINT NOT NULL DEFAULT 1,
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    certificate_email_sent_at TIMESTAMPTZ,
    CONSTRAINT fk_eom_winner_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE,
    CONSTRAINT uq_eom_winner_month_year UNIQUE (month, year)
);

CREATE INDEX IF NOT EXISTS idx_eom_winner_month_year ON employee_of_the_month (month, year);
CREATE INDEX IF NOT EXISTS idx_eom_winner_employee ON employee_of_the_month (employee_id);

COMMENT ON TABLE employee_of_the_month IS 'Employee of the Month winner per month; one row per month';

SELECT 'Employee of the Month tables migration completed successfully' AS status;
