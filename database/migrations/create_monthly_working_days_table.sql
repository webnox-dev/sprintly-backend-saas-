-- ===========================================================================
-- Migration: Create Monthly Working Days Table
-- Date: 2026-02-24
-- Description: Creates table for managing working days per month/year.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS monthly_working_days (
    working_days_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    month INT NOT NULL CHECK (
        month >= 1
        AND month <= 12
    ),
    year INT NOT NULL CHECK (year >= 2000),
    working_days DOUBLE PRECISION NOT NULL CHECK (working_days >= 0),
    total_days INT NOT NULL CHECK (
        total_days >= 1
        AND total_days <= 31
    ),
    remarks TEXT,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (month, year)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_monthly_working_days_year_month ON monthly_working_days (year DESC, month DESC);