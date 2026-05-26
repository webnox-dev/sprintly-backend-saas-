-- Salary Calculation Module: salary_ranges + salary_components
-- Created: 2026-02-26

CREATE TABLE IF NOT EXISTS salary_ranges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    range_name VARCHAR(100),
    salary_start NUMERIC(12, 2) NOT NULL,
    salary_end NUMERIC(12, 2) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(20),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_salary_range CHECK (salary_end >= salary_start)
);

CREATE TABLE IF NOT EXISTS salary_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    salary_range_id UUID NOT NULL REFERENCES salary_ranges (id) ON DELETE CASCADE,
    component_type VARCHAR(20) NOT NULL CHECK (
        component_type IN ('earning', 'deduction')
    ),
    component_name VARCHAR(100) NOT NULL,
    percentage NUMERIC(6, 2) NOT NULL,
    calculated_amount NUMERIC(12, 2) NOT NULL,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_salary_components_range ON salary_components (salary_range_id);

CREATE INDEX IF NOT EXISTS idx_salary_components_type ON salary_components (component_type);