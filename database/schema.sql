-- ============================================
-- Webnox Sprintly Admin Backend Database Schema (PostgreSQL)
-- Consolidated Full Schema - All Tables
-- Last Updated: 2026-01-14
-- ============================================

-- ============================================
-- PRE-REQUISITE: Remove FK constraints on projects table
-- These allow project_manager_id and project_team_leader_id
-- to reference either employees OR admins
-- ============================================
ALTER TABLE IF EXISTS projects
DROP CONSTRAINT IF EXISTS fk_project_manager;

ALTER TABLE IF EXISTS projects
DROP CONSTRAINT IF EXISTS fk_project_team_leader;

-- ============================================
-- TRIGGERS FUNCTION (Must be created first)
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- ============================================
-- AUTH SCHEMA AND USERS TABLE
-- ============================================
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    encrypted_password TEXT,
    role VARCHAR(50) NOT NULL DEFAULT 'Employee',
    is_active SMALLINT DEFAULT 1,
    reference_id VARCHAR(50),
    otp VARCHAR(10),
    otp_generated_at TIMESTAMPTZ,
    email_confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_by VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_auth_users_email ON auth.users (email);

CREATE INDEX IF NOT EXISTS idx_auth_users_employee_id ON auth.users (employee_id);

CREATE INDEX IF NOT EXISTS idx_auth_users_role ON auth.users (role);

-- ============================================
-- PASSWORD RESET HELPER TABLE (OTP Storage)
-- ============================================
CREATE TABLE IF NOT EXISTS password_reset_helper (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    email VARCHAR(255) NOT NULL UNIQUE,
    otp VARCHAR(10) NOT NULL,
    otp_type VARCHAR(50) DEFAULT 'email_verification',
    is_used BOOLEAN DEFAULT FALSE,
    is_expired BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ DEFAULT (
        CURRENT_TIMESTAMP + INTERVAL '15 minutes'
    ),
    verified_at TIMESTAMPTZ,
    user_type VARCHAR(20) DEFAULT 'Employee'
);

CREATE INDEX IF NOT EXISTS idx_password_reset_email ON password_reset_helper (email);

CREATE INDEX IF NOT EXISTS idx_password_reset_otp ON password_reset_helper (otp);

CREATE INDEX IF NOT EXISTS idx_password_reset_created_at ON password_reset_helper (created_at);

-- Fix for existing tables: Add otp_type and user_type to password_reset_helper if not exists
-- We use direct ALTER TABLE statements which are safer for the migration runner
-- 'IF NOT EXISTS' requires Postgres 9.6+
ALTER TABLE password_reset_helper
ADD COLUMN IF NOT EXISTS otp_type VARCHAR(50) DEFAULT 'email_verification';

ALTER TABLE password_reset_helper
ADD COLUMN IF NOT EXISTS user_type VARCHAR(20) DEFAULT 'Employee';

-- ============================================
-- EMPLOYEES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS employees (
    employee_id VARCHAR(50) PRIMARY KEY,
    employee_uuid UUID DEFAULT gen_random_uuid (),
    employee_name VARCHAR(255) NOT NULL,
    employee_role VARCHAR(100) NOT NULL,
    employee_img TEXT,
    employee_phone_num VARCHAR(20),
    employee_gender VARCHAR(20),
    employee_personal_email VARCHAR(255) NOT NULL,
    employee_company_email VARCHAR(255),
    employee_address TEXT,
    employee_designation VARCHAR(100),
    employee_qualification VARCHAR(255),
    employee_specialization VARCHAR(255),
    employee_dob VARCHAR(20) NOT NULL,
    employee_age INTEGER NOT NULL,
    employee_doj VARCHAR(20) NOT NULL,
    employee_blood_group VARCHAR(10),
    employee_emergency_contact_number VARCHAR(20),
    employee_actual_salary DECIMAL(10, 2) DEFAULT 0.00,
    employee_total_leave_days_in_year DECIMAL(5, 2) DEFAULT 0.00,
    employee_pending_leave_count DECIMAL(5, 2) DEFAULT 0.00,
    status SMALLINT DEFAULT 1,
    changed_by VARCHAR(50),
    changed_at TIMESTAMPTZ,
    employee_doe DATE,
    reason_of_exit TEXT,
    exited_by VARCHAR(50),
    exited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_employees_status ON employees (status);

CREATE INDEX IF NOT EXISTS idx_employees_role ON employees (employee_role);

CREATE INDEX IF NOT EXISTS idx_employees_email ON employees (employee_personal_email);

-- ============================================
-- ADMINS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS admins (
    admin_id VARCHAR(50) PRIMARY KEY,
    admin_uuid UUID DEFAULT gen_random_uuid (),
    admin_name VARCHAR(255) NOT NULL,
    admin_role VARCHAR(100) NOT NULL,
    admin_img TEXT,
    admin_cover_img TEXT,
    admin_phone_num VARCHAR(20),
    admin_gender VARCHAR(20),
    admin_personal_email VARCHAR(255) NOT NULL UNIQUE,
    admin_company_email VARCHAR(255),
    admin_address TEXT,
    admin_designation VARCHAR(100),
    admin_qualification VARCHAR(255),
    admin_dob VARCHAR(20),
    admin_age INTEGER,
    admin_doj VARCHAR(20),
    admin_blood_group VARCHAR(10),
    admin_emergency_contact_number VARCHAR(20),
    admin_actual_salary DECIMAL(10, 2) DEFAULT 0.00,
    admin_total_leave_days_in_year DECIMAL(5, 2) DEFAULT 0.00,
    admin_pending_leave_count DECIMAL(5, 2) DEFAULT 0.00,
    status SMALLINT DEFAULT 1,
    changed_by VARCHAR(50),
    changed_at TIMESTAMPTZ,
    admin_doe DATE,
    reason_of_exit TEXT,
    exited_by VARCHAR(50),
    exited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    access_permissions JSONB DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_admins_email ON admins (admin_personal_email);

CREATE INDEX IF NOT EXISTS idx_admins_status ON admins (status);

-- ============================================
-- EMPLOYEE ATTENDANCE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS employee_attendance (
    attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id TEXT NOT NULL,
    work_date TEXT NOT NULL,
    clock_on_for_the_day TEXT NOT NULL,
    clock_off_for_the_day TEXT,
    clock_on_time TEXT,
    clock_off_time TEXT,
    task_id TEXT,
    worked_hrs DOUBLE PRECISION DEFAULT 0.00,
    session_duration TEXT,
    is_remote_override BOOLEAN DEFAULT FALSE,
    remote_reason TEXT,
    tasks_for_the_day JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT NOT NULL,
    updated_by TEXT NOT NULL,
    CONSTRAINT fk_employee_attendance_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_employee_attendance_employee_id ON employee_attendance (employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_attendance_work_date ON employee_attendance (work_date);

-- Fix for existing tables: Make clock_on_time and clock_off_time nullable (if they exist)
DO $$ 
BEGIN
    -- Add clock_on_time column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employee_attendance' AND column_name = 'clock_on_time') THEN
        ALTER TABLE employee_attendance ADD COLUMN clock_on_time TEXT;

ELSE
-- Make nullable if exists
ALTER TABLE employee_attendance
ALTER COLUMN clock_on_time
DROP NOT NULL;

END IF;

-- Add clock_off_time column if it doesn't exist
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE
        table_name = 'employee_attendance'
        AND column_name = 'clock_off_time'
) THEN
ALTER TABLE employee_attendance
ADD COLUMN clock_off_time TEXT;

ELSE
-- Make nullable if exists
ALTER TABLE employee_attendance
ALTER COLUMN clock_off_time
DROP NOT NULL;

END IF;

-- Add task_id column if it doesn't exist
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE
        table_name = 'employee_attendance'
        AND column_name = 'task_id'
) THEN
ALTER TABLE employee_attendance
ADD COLUMN task_id TEXT;

END IF;

-- Add session_duration column if it doesn't exist
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE
        table_name = 'employee_attendance'
        AND column_name = 'session_duration'
) THEN
ALTER TABLE employee_attendance
ADD COLUMN session_duration TEXT;

END IF;

EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Could not modify employee_attendance columns: %',
SQLERRM;

END $$;

-- ============================================
-- EMPLOYEE REPORTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS employee_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    report_date TEXT NOT NULL,
    employee_id TEXT,
    work_type TEXT,
    total_tasks_count BIGINT,
    total_working_hrs TEXT,
    clock_on_for_the_day TIMESTAMPTZ,
    clock_off_for_the_day TIMESTAMPTZ,
    task_details JSONB,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by TEXT,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_reports_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_employee_reports_created_by FOREIGN KEY (created_by) REFERENCES employees (employee_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_employee_reports_updated_by FOREIGN KEY (updated_by) REFERENCES employees (employee_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Fix for existing tables: Add task_details to employee_reports if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'employee_reports' 
        AND column_name = 'task_details'
    ) THEN
        ALTER TABLE employee_reports ADD COLUMN task_details JSONB;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_employee_reports_employee_id ON employee_reports (employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_reports_report_date ON employee_reports (report_date);

-- ============================================
-- ANNOUNCEMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS announcements (
    announcement_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    announcement_date TIMESTAMPTZ NOT NULL,
    is_active SMALLINT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    created_by VARCHAR(50) NOT NULL,
    updated_by VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON announcements (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_announcements_date ON announcements (announcement_date DESC);

CREATE INDEX IF NOT EXISTS idx_announcements_is_active ON announcements (is_active);

-- ============================================
-- PROJECTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_name VARCHAR(255) NOT NULL,
    project_img TEXT,
    project_description TEXT,
    project_requirements JSONB DEFAULT '[]'::jsonb,
    project_start_date DATE,
    project_end_date DATE,
    project_mvp_date DATE,
    project_status VARCHAR(50) DEFAULT 'NOT_STARTED',
    project_priority_level VARCHAR(50) DEFAULT 'MEDIUM',
    project_type VARCHAR(100),
    project_team_leader_id VARCHAR(50),
    project_manager_id VARCHAR(50),
    project_team_member_ids JSONB DEFAULT '[]'::jsonb,
    project_followed_by_bde_employee_ids JSONB DEFAULT '[]'::jsonb,
    -- Client Details
    client_name VARCHAR(255),
    company_name VARCHAR(255),
    client_type VARCHAR(50) DEFAULT 'Business',
    client_address TEXT,
    client_country VARCHAR(100),
    client_phone VARCHAR(50),
    -- Audit fields
    project_created_by VARCHAR(50),
    project_created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    project_updated_by VARCHAR(50),
    project_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
    -- NOTE: No FK constraints on project_team_leader_id and project_manager_id
    -- because they can reference either employees OR admins table.
    -- Application-level validation handles the existence check.
);

CREATE INDEX IF NOT EXISTS idx_projects_status ON projects (project_status);

CREATE INDEX IF NOT EXISTS idx_projects_priority ON projects (project_priority_level);

CREATE INDEX IF NOT EXISTS idx_projects_name ON projects (project_name);

CREATE INDEX IF NOT EXISTS idx_projects_team_leader ON projects (project_team_leader_id);

CREATE INDEX IF NOT EXISTS idx_projects_manager ON projects (project_manager_id);

-- ============================================
-- PROJECT DOCUMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS project_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL,
    document_name VARCHAR(255) NOT NULL,
    document_url TEXT NOT NULL,
    document_type VARCHAR(100),
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_document_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_project_documents_project_id ON project_documents (project_id);

CREATE INDEX IF NOT EXISTS idx_project_documents_type ON project_documents (document_type);

-- ============================================
-- PROJECT FIGMA URLS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS project_figma_urls (
    figma_url_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL,
    figma_url_name VARCHAR(255) NOT NULL,
    figma_url TEXT NOT NULL,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_figma_url_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_project_figma_urls_project_id ON project_figma_urls (project_id);

-- ============================================
-- PROJECT RELEASES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS project_releases (
    project_release_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL,
    project_release_title VARCHAR(255) NOT NULL,
    project_release_planned_date DATE,
    project_release_actual_date DATE,
    project_release_dev_cutoff_date DATE,
    project_release_qc_cutoff_date DATE,
    project_release_notes TEXT,
    project_release_created_by VARCHAR(50),
    project_release_created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    project_release_updated_by VARCHAR(50),
    project_release_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_release_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_project_releases_project_id ON project_releases (project_id);

CREATE INDEX IF NOT EXISTS idx_project_releases_planned_date ON project_releases (project_release_planned_date);

-- ============================================
-- RELEASE ATTACHMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS release_attachments (
    release_attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_release_id UUID NOT NULL,
    project_id UUID NOT NULL,
    release_attachment_type VARCHAR(100) NOT NULL,
    release_attachment_value TEXT NOT NULL,
    release_attachment_created_by VARCHAR(50),
    release_attachment_created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    release_attachment_updated_by VARCHAR(50),
    release_attachment_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_release_attachment_release FOREIGN KEY (project_release_id) REFERENCES project_releases (project_release_id) ON DELETE CASCADE,
    CONSTRAINT fk_release_attachment_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_release_attachments_project_release_id ON release_attachments (project_release_id);

CREATE INDEX IF NOT EXISTS idx_release_attachments_project_id ON release_attachments (project_id);

-- ============================================
-- PROJECT MILESTONES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS project_milestones (
    project_milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL,
    project_milestone_title VARCHAR(255) NOT NULL,
    project_milestone_achievement_description TEXT,
    project_milestone_created_by VARCHAR(50),
    project_milestone_created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    project_milestone_updated_by VARCHAR(50),
    project_milestone_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_milestone_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_project_milestones_project_id ON project_milestones (project_id);

-- ============================================
-- CLIENT REVIEWS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS client_reviews (
    client_review_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL,
    client_review_comment TEXT NOT NULL,
    client_review_rating INTEGER DEFAULT 0 CHECK (
        client_review_rating >= 0
        AND client_review_rating <= 5
    ),
    client_review_created_by VARCHAR(50),
    client_review_created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    client_review_updated_by VARCHAR(50),
    client_review_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_client_review_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_client_reviews_project_id ON client_reviews (project_id);

CREATE INDEX IF NOT EXISTS idx_client_reviews_rating ON client_reviews (client_review_rating);

-- ============================================
-- PROJECT DISCONTINUATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS project_discontinuations (
    project_discontinuation_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    project_id UUID NOT NULL UNIQUE,
    project_discontinuation_reason TEXT NOT NULL,
    project_discontinuation_by VARCHAR(50) NOT NULL,
    project_discontinuation_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    project_discontinuation_remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_discontinuation_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_project_discontinuations_project_id ON project_discontinuations (project_id);

-- ============================================
-- TASK CARDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS task_cards (
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_name VARCHAR(255) NOT NULL,
    task_description TEXT,
    task_duration VARCHAR(50),
    task_type VARCHAR(50) DEFAULT 'Task',
    priority_level VARCHAR(50) DEFAULT 'Medium',
    project_id UUID,
    project_details JSONB,
    employee_id VARCHAR(50),
    employee_details JSONB,
    workflow_status VARCHAR(50) DEFAULT 'TODO',
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    from_date DATE,
    to_date DATE,
    -- Dev Tracking
    dev_started_at TIMESTAMPTZ,
    dev_completed_at TIMESTAMPTZ,
    total_dev_hours DECIMAL(6, 2) DEFAULT 0.00,
    dev_notes TEXT,
    dev_completed_attachments JSONB DEFAULT '[]'::jsonb,
    -- QC Tracking
    qc_started_at TIMESTAMPTZ,
    qc_completed_at TIMESTAMPTZ,
    qc_total_hours DECIMAL(6, 2) DEFAULT 0.00,
    qc_notes TEXT,
    qc_completed_attachments JSONB DEFAULT '[]'::jsonb,
    -- Attachments
    task_attachments JSONB DEFAULT '[]'::jsonb,
    -- Reassignment fields
    is_task_reassigned BOOLEAN DEFAULT FALSE,
    reassigned_by VARCHAR(50),
    reassigned_on TIMESTAMPTZ,
    reassigned_reason TEXT,
    -- Status
    status_reason TEXT,
    is_deleted BOOLEAN DEFAULT FALSE,
    -- Audit
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_task_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE SET NULL,
    CONSTRAINT fk_task_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_cards_project_id ON task_cards (project_id);

CREATE INDEX IF NOT EXISTS idx_task_cards_employee_id ON task_cards (employee_id);

CREATE INDEX IF NOT EXISTS idx_task_cards_status ON task_cards (workflow_status);

CREATE INDEX IF NOT EXISTS idx_task_cards_deleted ON task_cards (is_deleted);

-- ============================================
-- TASK ATTACHMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS task_attachments (
    attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_id UUID NOT NULL,
    attachment_type VARCHAR(50) DEFAULT 'file',
    title VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_attachment_task FOREIGN KEY (task_id) REFERENCES task_cards (task_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_attachments_task_id ON task_attachments (task_id);

-- ============================================
-- TASK CARD REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS task_card_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_id UUID,
    employee_id VARCHAR(50) NOT NULL,
    project_id UUID,
    task_name VARCHAR(255),
    task_description TEXT,
    task_duration VARCHAR(50),
    task_type VARCHAR(50),
    priority_level VARCHAR(50),
    workflow_status VARCHAR(50) DEFAULT 'TODO',
    from_date DATE,
    to_date DATE,
    task_attachments JSONB DEFAULT '[]'::jsonb,
    project_details JSONB,
    employee_details JSONB,
    requested_by VARCHAR(50) NOT NULL,
    requested_on TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    approved_rejected_by VARCHAR(50),
    approved_rejected_at TIMESTAMPTZ,
    approved_rejected_reason TEXT,
    request_status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_request_task FOREIGN KEY (task_id) REFERENCES task_cards (task_id) ON DELETE CASCADE,
    CONSTRAINT fk_request_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_request_project FOREIGN KEY (project_id) REFERENCES projects (project_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_task_card_requests_status ON task_card_requests (request_status);

CREATE INDEX IF NOT EXISTS idx_task_card_requests_employee ON task_card_requests (employee_id);

CREATE INDEX IF NOT EXISTS idx_task_card_requests_project ON task_card_requests (project_id);

-- ============================================
-- TASK CARD LOGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS task_card_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_id UUID NOT NULL,
    action_name VARCHAR(100) NOT NULL,
    action_description TEXT,
    actioned_by VARCHAR(50) NOT NULL,
    actioned_datetime TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    old_value JSONB,
    new_value JSONB,
    CONSTRAINT fk_log_task FOREIGN KEY (task_id) REFERENCES task_cards (task_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_card_logs_task_id ON task_card_logs (task_id);

CREATE INDEX IF NOT EXISTS idx_task_card_logs_action ON task_card_logs (action_name);

-- ============================================
-- EMPLOYEE TASK TRACKING TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS employee_task_tracking (
    tracking_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    task_id UUID NOT NULL,
    employee_id VARCHAR(50) NOT NULL,
    employee_task_status INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    paused_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    total_hours DECIMAL(6, 2) DEFAULT 0.00,
    session_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tracking_task FOREIGN KEY (task_id) REFERENCES task_cards (task_id) ON DELETE CASCADE,
    CONSTRAINT fk_tracking_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_employee_task_tracking_task_id ON employee_task_tracking (task_id);

CREATE INDEX IF NOT EXISTS idx_employee_task_tracking_employee_id ON employee_task_tracking (employee_id);

-- ============================================
-- TASK CARD TIME TRACKING TABLE
-- Tracks employee time spent on tasks (clock in/out)
-- ============================================
CREATE TABLE IF NOT EXISTS task_card_time_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id VARCHAR(50) NOT NULL REFERENCES employees (employee_id) ON UPDATE CASCADE,
    task_id VARCHAR(100) NOT NULL,
    task_name VARCHAR(255) NOT NULL,
    work_date DATE NOT NULL DEFAULT CURRENT_DATE,
    clock_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    clock_out_time TIMESTAMPTZ,
    duration_minutes INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_tracking_employee ON task_card_time_tracking (employee_id);

CREATE INDEX IF NOT EXISTS idx_time_tracking_task ON task_card_time_tracking (task_id);

CREATE INDEX IF NOT EXISTS idx_time_tracking_date ON task_card_time_tracking (work_date);

CREATE INDEX IF NOT EXISTS idx_time_tracking_active ON task_card_time_tracking (employee_id, clock_out_time)
WHERE
    clock_out_time IS NULL;

COMMENT ON TABLE task_card_time_tracking IS 'Tracks employee time spent working on individual tasks';

-- ============================================
-- TEAM CARDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS team_cards (
    team_card_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    card_name VARCHAR(255) NOT NULL,
    card_type VARCHAR(100) DEFAULT 'Learning Card',
    card_description TEXT,
    team_card_status INTEGER DEFAULT 1,
    team_type VARCHAR(100),
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_team_cards_status ON team_cards (team_card_status);

CREATE INDEX IF NOT EXISTS idx_team_cards_type ON team_cards (card_type);

-- ============================================
-- TEAM CARD USAGE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS team_card_usage (
    usage_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    team_card_id UUID NOT NULL,
    employee_id VARCHAR(50) NOT NULL,
    clock_in TIMESTAMPTZ NOT NULL,
    clock_out TIMESTAMPTZ,
    total_hours DECIMAL(6, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usage_team_card FOREIGN KEY (team_card_id) REFERENCES team_cards (team_card_id) ON DELETE CASCADE,
    CONSTRAINT fk_usage_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_team_card_usage_team_card_id ON team_card_usage (team_card_id);

CREATE INDEX IF NOT EXISTS idx_team_card_usage_employee_id ON team_card_usage (employee_id);

-- ============================================
-- LEAVE ZONE TABLE (Leave Requests)
-- Supports both Employee and Admin requesters
-- ============================================
CREATE TABLE IF NOT EXISTS leave_zone (
    leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id TEXT NOT NULL,
    requester_type VARCHAR(20) NOT NULL DEFAULT 'Employee' CHECK (
        requester_type IN ('Admin', 'Employee')
    ),
    leave_from_date DATE NOT NULL,
    leave_to_date DATE NOT NULL,
    selected_dates JSONB DEFAULT '[]'::jsonb,
    total_leave_days NUMERIC(5, 2) DEFAULT 0,
    leave_type VARCHAR(50),
    leave_status SMALLINT DEFAULT 0, -- 0: Pending, 1: Approved, 2: Rejected
    leave_remarks TEXT,
    is_paid_leave BOOLEAN DEFAULT FALSE,
    is_half_day BOOLEAN DEFAULT FALSE,
    half_day_type VARCHAR(20), -- 'first_half' or 'second_half'
    leave_approval_rejection_remarks TEXT,
    approved_by VARCHAR(50),
    rejected_by VARCHAR(50),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_leave_zone_employee_id ON leave_zone (employee_id);

CREATE INDEX IF NOT EXISTS idx_leave_zone_requester_type ON leave_zone (requester_type);

CREATE INDEX IF NOT EXISTS idx_leave_zone_status ON leave_zone (leave_status);

CREATE INDEX IF NOT EXISTS idx_leave_zone_from_date ON leave_zone (leave_from_date);

CREATE INDEX IF NOT EXISTS idx_leave_zone_to_date ON leave_zone (leave_to_date);

CREATE INDEX IF NOT EXISTS idx_leave_zone_selected_dates ON leave_zone USING gin (selected_dates);

-- ============================================
-- PERMISSIONS TABLE (Permission Requests)
-- Supports both Employee and Admin requesters
-- ============================================
CREATE TABLE IF NOT EXISTS permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id TEXT NOT NULL,
    requester_type VARCHAR(20) NOT NULL DEFAULT 'Employee' CHECK (
        requester_type IN ('Admin', 'Employee')
    ),
    permission_date DATE NOT NULL,
    permission_from_time TIME NOT NULL,
    permission_to_time TIME NOT NULL,
    permission_status SMALLINT DEFAULT 0, -- 0: Pending, 1: Approved, 2: Rejected
    permission_remarks TEXT,
    permission_approval_rejection_remarks TEXT,
    approved_by VARCHAR(50),
    rejected_by VARCHAR(50),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_permissions_employee_id ON permissions (employee_id);

CREATE INDEX IF NOT EXISTS idx_permissions_requester_type ON permissions (requester_type);

CREATE INDEX IF NOT EXISTS idx_permissions_status ON permissions (permission_status);

CREATE INDEX IF NOT EXISTS idx_permissions_date ON permissions (permission_date);

-- ============================================
-- WORK FROM HOME REQUESTS TABLE
-- Supports both Employee and Admin requesters
-- ============================================
CREATE TABLE IF NOT EXISTS work_from_home_requests (
    wfh_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id TEXT NOT NULL,
    requester_type VARCHAR(20) NOT NULL DEFAULT 'Employee' CHECK (
        requester_type IN ('Admin', 'Employee')
    ),
    employee_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INTEGER DEFAULT 1,
    wfh_status SMALLINT DEFAULT 0, -- 0: Pending, 1: Approved, 2: Rejected
    reason TEXT,
    approval_rejection_remarks TEXT,
    approved_by VARCHAR(50),
    rejected_by VARCHAR(50),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wfh_employee_id ON work_from_home_requests (employee_id);

CREATE INDEX IF NOT EXISTS idx_wfh_requester_type ON work_from_home_requests (requester_type);

CREATE INDEX IF NOT EXISTS idx_wfh_status ON work_from_home_requests (wfh_status);

CREATE INDEX IF NOT EXISTS idx_wfh_start_date ON work_from_home_requests (start_date);

CREATE INDEX IF NOT EXISTS idx_wfh_end_date ON work_from_home_requests (end_date);

-- ============================================
-- COMPANY HOLIDAYS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS company_holidays (
    holiday_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    holiday_name VARCHAR(255) NOT NULL,
    from_date TIMESTAMPTZ NOT NULL,
    to_date TIMESTAMPTZ,
    total_days INT NOT NULL DEFAULT 1,
    holiday_remarks TEXT,
    is_optional BOOLEAN DEFAULT FALSE,
    created_by VARCHAR(50),
    updated_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_company_holidays_from_date ON company_holidays (from_date);

-- ============================================
-- EXPENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS expenses (
    expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    expense_name VARCHAR(255),
    expense_trans VARCHAR(50),
    expense_amount NUMERIC(15, 2),
    expense_type VARCHAR(50),
    paid_by VARCHAR(255),
    expense_date TIMESTAMPTZ,
    expense_description TEXT,
    expense_receipts JSONB DEFAULT '[]'::jsonb,
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (expense_date);

-- ============================================
-- ASSETS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    asset_name VARCHAR(255) NOT NULL,
    asset_description TEXT,
    asset_type VARCHAR(50) NOT NULL,
    asset_status VARCHAR(50) NOT NULL,
    asset_model VARCHAR(100) NOT NULL,
    asset_configuration TEXT,
    used_by_employee_id VARCHAR(50),
    serial_number VARCHAR(100) NOT NULL,
    imei_number VARCHAR(100),
    created_by VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_assets_type ON assets (asset_type);

CREATE INDEX IF NOT EXISTS idx_assets_status ON assets (asset_status);

CREATE INDEX IF NOT EXISTS idx_assets_employee ON assets (used_by_employee_id);

-- ============================================
-- TODOS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS todos (
    todo_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    todo_title VARCHAR(255) NOT NULL,
    todo_description TEXT,
    created_by VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    due_date DATE,
    due_time TIME,
    is_reminder_set BOOLEAN DEFAULT FALSE,
    todo_status VARCHAR(50) DEFAULT 'pending',
    todo_priority VARCHAR(50) DEFAULT 'medium'
);

CREATE INDEX IF NOT EXISTS idx_todos_created_by ON todos (created_by);

CREATE INDEX IF NOT EXISTS idx_todos_status ON todos (todo_status);

-- ============================================
-- EMPLOYEE DOCUMENTS TABLE
-- Employee Document Request & Verification Module
-- ============================================

-- Document status enum (created if not exists)
DO $$ BEGIN
    CREATE TYPE document_status_enum AS ENUM ('pending', 'submitted', 'approved', 'rejected');

EXCEPTION WHEN duplicate_object THEN null;

END $$;

CREATE TABLE IF NOT EXISTS employee_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id VARCHAR(50) NOT NULL,
    document_name VARCHAR(100) NOT NULL,
    document_url TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN (
            'pending',
            'submitted',
            'approved',
            'rejected'
        )
    ),
    is_required BOOLEAN DEFAULT FALSE,
    -- Request audit
    requested_by VARCHAR(50) NOT NULL,
    created_by VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    -- Submission audit
    submitted_at TIMESTAMPTZ,
    -- Review audit
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    admin_comments TEXT,
    CONSTRAINT fk_employee_documents_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_employee_documents_employee_id ON employee_documents (employee_id);

CREATE INDEX IF NOT EXISTS idx_employee_documents_status ON employee_documents (status);

CREATE INDEX IF NOT EXISTS idx_employee_documents_requested_by ON employee_documents (requested_by);

CREATE INDEX IF NOT EXISTS idx_employee_documents_document_name ON employee_documents (document_name);

-- Unique constraint to prevent duplicate pending requests for same document
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_pending_document ON employee_documents (employee_id, document_name)
WHERE
    status IN ('pending', 'submitted');

-- ============================================
-- DOCUMENT TYPES TABLE (Reference table for API listing)
-- ============================================
CREATE TABLE IF NOT EXISTS document_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- NOTE: Document types seed data removed.
-- You can insert document types via API or manually if needed.

-- ============================================
-- HELPER FUNCTIONS FOR LEAVE TRACKER
-- ============================================

-- Function to calculate total leave days
CREATE OR REPLACE FUNCTION calculate_leave_days()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.selected_dates IS NOT NULL AND jsonb_array_length(NEW.selected_dates) > 0 THEN
        NEW.total_leave_days = jsonb_array_length(NEW.selected_dates);
    ELSE
        NEW.total_leave_days = (NEW.leave_to_date - NEW.leave_from_date) + 1;
    END IF;
    
    IF NEW.is_half_day = TRUE THEN
        NEW.total_leave_days = 0.5;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate WFH total days
CREATE OR REPLACE FUNCTION calculate_wfh_days()
RETURNS TRIGGER AS $$
BEGIN
    NEW.total_days = (NEW.end_date - NEW.start_date) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================

-- Projects trigger removed - uses project_updated_at column instead of updated_at
DROP TRIGGER IF EXISTS trigger_update_projects_updated_at ON projects;

-- Project Documents
DROP TRIGGER IF EXISTS trigger_update_project_documents_updated_at ON project_documents;

CREATE TRIGGER trigger_update_project_documents_updated_at 
    BEFORE UPDATE ON project_documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Project Figma URLs
DROP TRIGGER IF EXISTS trigger_update_project_figma_urls_updated_at ON project_figma_urls;

CREATE TRIGGER trigger_update_project_figma_urls_updated_at 
    BEFORE UPDATE ON project_figma_urls 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Project Releases trigger removed - uses project_release_updated_at column
DROP TRIGGER IF EXISTS trigger_update_project_releases_updated_at ON project_releases;

-- Release Attachments trigger removed - uses release_attachment_updated_at column
DROP TRIGGER IF EXISTS trigger_update_release_attachments_updated_at ON release_attachments;

-- Project Milestones trigger removed - uses project_milestone_updated_at column
DROP TRIGGER IF EXISTS trigger_update_project_milestones_updated_at ON project_milestones;

-- Client Reviews trigger removed - uses client_review_updated_at column
DROP TRIGGER IF EXISTS trigger_update_client_reviews_updated_at ON client_reviews;

-- Project Discontinuations
DROP TRIGGER IF EXISTS trigger_update_project_discontinuations_updated_at ON project_discontinuations;

CREATE TRIGGER trigger_update_project_discontinuations_updated_at 
    BEFORE UPDATE ON project_discontinuations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Task Cards
DROP TRIGGER IF EXISTS trigger_update_task_cards_updated_at ON task_cards;

CREATE TRIGGER trigger_update_task_cards_updated_at 
    BEFORE UPDATE ON task_cards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Employee Task Tracking
DROP TRIGGER IF EXISTS trigger_update_employee_task_tracking_updated_at ON employee_task_tracking;

CREATE TRIGGER trigger_update_employee_task_tracking_updated_at 
    BEFORE UPDATE ON employee_task_tracking 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Team Cards
DROP TRIGGER IF EXISTS trigger_update_team_cards_updated_at ON team_cards;

CREATE TRIGGER trigger_update_team_cards_updated_at 
    BEFORE UPDATE ON team_cards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Team Card Usage
DROP TRIGGER IF EXISTS trigger_update_team_card_usage_updated_at ON team_card_usage;

CREATE TRIGGER trigger_update_team_card_usage_updated_at 
    BEFORE UPDATE ON team_card_usage 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Task Card Requests
DROP TRIGGER IF EXISTS trigger_update_task_card_requests_updated_at ON task_card_requests;

CREATE TRIGGER trigger_update_task_card_requests_updated_at 
    BEFORE UPDATE ON task_card_requests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Employee Attendance
DROP TRIGGER IF EXISTS trigger_update_employee_attendance_updated_at ON employee_attendance;

CREATE TRIGGER trigger_update_employee_attendance_updated_at 
    BEFORE UPDATE ON employee_attendance 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Employee Reports
DROP TRIGGER IF EXISTS trigger_update_employee_reports_updated_at ON employee_reports;

CREATE TRIGGER trigger_update_employee_reports_updated_at 
    BEFORE UPDATE ON employee_reports 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Leave Zone
DROP TRIGGER IF EXISTS trigger_update_leave_zone_updated_at ON leave_zone;

CREATE TRIGGER trigger_update_leave_zone_updated_at 
    BEFORE UPDATE ON leave_zone 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_calculate_leave_days ON leave_zone;

CREATE TRIGGER trigger_calculate_leave_days
    BEFORE INSERT OR UPDATE ON leave_zone
    FOR EACH ROW EXECUTE FUNCTION calculate_leave_days();

-- Permissions
DROP TRIGGER IF EXISTS trigger_update_permissions_updated_at ON permissions;

CREATE TRIGGER trigger_update_permissions_updated_at 
    BEFORE UPDATE ON permissions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Work From Home
DROP TRIGGER IF EXISTS trigger_update_wfh_updated_at ON work_from_home_requests;

CREATE TRIGGER trigger_update_wfh_updated_at 
    BEFORE UPDATE ON work_from_home_requests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_calculate_wfh_days ON work_from_home_requests;

CREATE TRIGGER trigger_calculate_wfh_days
    BEFORE INSERT OR UPDATE ON work_from_home_requests
    FOR EACH ROW EXECUTE FUNCTION calculate_wfh_days();

-- Company Holidays
DROP TRIGGER IF EXISTS trigger_update_company_holidays_updated_at ON company_holidays;

CREATE TRIGGER trigger_update_company_holidays_updated_at 
    BEFORE UPDATE ON company_holidays 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Expenses
DROP TRIGGER IF EXISTS trigger_update_expenses_updated_at ON expenses;

CREATE TRIGGER trigger_update_expenses_updated_at 
    BEFORE UPDATE ON expenses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Assets
DROP TRIGGER IF EXISTS trigger_update_assets_updated_at ON assets;

CREATE TRIGGER trigger_update_assets_updated_at 
    BEFORE UPDATE ON assets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Todos
DROP TRIGGER IF EXISTS trigger_update_todos_updated_at ON todos;

CREATE TRIGGER trigger_update_todos_updated_at 
    BEFORE UPDATE ON todos 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Announcements
DROP TRIGGER IF EXISTS trigger_update_announcements_updated_at ON announcements;

CREATE TRIGGER trigger_update_announcements_updated_at 
    BEFORE UPDATE ON announcements 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Employee Documents
DROP TRIGGER IF EXISTS trigger_update_employee_documents_updated_at ON employee_documents;

CREATE TRIGGER trigger_update_employee_documents_updated_at 
    BEFORE UPDATE ON employee_documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Task Card Time Tracking
DROP TRIGGER IF EXISTS trigger_update_task_card_time_tracking_updated_at ON task_card_time_tracking;

CREATE TRIGGER trigger_update_task_card_time_tracking_updated_at 
    BEFORE UPDATE ON task_card_time_tracking 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FCM TOKENS TABLE (Firebase Cloud Messaging)
-- Supports multiple devices per user
-- ============================================
CREATE TABLE IF NOT EXISTS fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('Admin', 'Employee')
    ),
    fcm_token TEXT NOT NULL,
    jwt_token TEXT,
    device_type VARCHAR(20) DEFAULT 'unknown',
    device_name VARCHAR(255),
    platform VARCHAR(20) DEFAULT 'unknown',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_fcm_token UNIQUE (fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens (user_id);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_type ON fcm_tokens (user_type);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON fcm_tokens (is_active);

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_jwt_token ON fcm_tokens (jwt_token)
WHERE
    jwt_token IS NOT NULL;

-- Add FCM token column to admins table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'fcm_token') THEN
        ALTER TABLE admins ADD COLUMN fcm_token TEXT;

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE
        table_name = 'admins'
        AND column_name = 'fcm_token_updated_at'
) THEN
ALTER TABLE admins
ADD COLUMN fcm_token_updated_at TIMESTAMPTZ;

END IF;

EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Could not add FCM columns to admins: %',
SQLERRM;

END $$;

-- Add FCM token column to employees table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'fcm_token') THEN
        ALTER TABLE employees ADD COLUMN fcm_token TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'fcm_token_updated_at') THEN
        ALTER TABLE employees ADD COLUMN fcm_token_updated_at TIMESTAMPTZ;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add FCM columns to employees: %', SQLERRM;
END $$;

-- FCM Tokens trigger
DROP TRIGGER IF EXISTS trigger_update_fcm_tokens_updated_at ON fcm_tokens;

CREATE TRIGGER trigger_update_fcm_tokens_updated_at 
    BEFORE UPDATE ON fcm_tokens 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE fcm_tokens IS 'Firebase Cloud Messaging tokens for push notifications - supports multiple devices per user';

-- ============================================
-- TEAMSYNC CHAT TABLES
-- ============================================

-- Chat Conversations Table (supports both 1-on-1 and group chats)
CREATE TABLE IF NOT EXISTS chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    name VARCHAR(255), -- NULL for 1-on-1, set for groups
    description TEXT, -- Group description
    type VARCHAR(20) NOT NULL DEFAULT 'direct', -- 'direct' or 'group'
    avatar_url TEXT, -- Group avatar
    created_by VARCHAR(50) NOT NULL, -- User ID who created
    created_by_type VARCHAR(20) NOT NULL DEFAULT 'Admin', -- 'Admin' or 'Employee'
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT FALSE, -- Whether group is public (anyone can join) or private
    invite_code VARCHAR(50) UNIQUE, -- Unique invite code for joining via link
    last_message_id UUID,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_created_by ON chat_conversations (created_by);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_type ON chat_conversations(type);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_message_at ON chat_conversations (last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_invite_code ON chat_conversations (invite_code)
WHERE
    invite_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_chat_conversations_is_public ON chat_conversations (is_public)
WHERE
    is_public = TRUE;

-- Chat Participants Table (who is in each conversation)
CREATE TABLE IF NOT EXISTS chat_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    conversation_id UUID NOT NULL REFERENCES chat_conversations (id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL, -- admin_id or employee_id
    user_type VARCHAR(20) NOT NULL, -- 'Admin' or 'Employee'
    role VARCHAR(20) DEFAULT 'member', -- 'admin', 'member' (for groups)
    nickname VARCHAR(100), -- Optional nickname in this chat
    is_muted BOOLEAN DEFAULT FALSE,
    muted_until TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ, -- Last time user read messages
    last_read_message_id UUID, -- Last message read by user
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMPTZ, -- NULL if still in conversation
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (
        conversation_id,
        user_id,
        user_type
    )
);

CREATE INDEX IF NOT EXISTS idx_chat_participants_conversation ON chat_participants (conversation_id);

CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants (user_id, user_type);

CREATE INDEX IF NOT EXISTS idx_chat_participants_active ON chat_participants (is_active)
WHERE
    is_active = TRUE;

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    conversation_id UUID NOT NULL REFERENCES chat_conversations (id) ON DELETE CASCADE,
    sender_id VARCHAR(50) NOT NULL, -- admin_id or employee_id
    sender_type VARCHAR(20) NOT NULL, -- 'Admin' or 'Employee'
    message_type VARCHAR(20) NOT NULL DEFAULT 'text', -- 'text', 'image', 'file', 'document', 'contact', 'audio', 'video'
    content TEXT, -- Text content or caption for media
    file_url TEXT, -- URL for attachments
    file_name VARCHAR(255), -- Original file name
    file_size INTEGER, -- File size in bytes
    file_mime_type VARCHAR(100), -- MIME type
    thumbnail_url TEXT, -- Thumbnail for images/videos
    reply_to_id UUID REFERENCES chat_messages (id) ON DELETE SET NULL, -- For reply threads
    forwarded_from_id UUID REFERENCES chat_messages (id) ON DELETE SET NULL, -- If forwarded
    contact_name VARCHAR(255), -- For contact type
    contact_phone VARCHAR(50), -- For contact type
    contact_email VARCHAR(255), -- For contact type
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT FALSE, -- Soft delete
    deleted_at TIMESTAMPTZ,
    deleted_for_everyone BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages (conversation_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages (sender_id, sender_type);

CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages (
    conversation_id,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_type ON chat_messages (message_type);

-- Message Status Table (tracks delivery and read status per recipient)
CREATE TABLE IF NOT EXISTS chat_message_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    message_id UUID NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL, -- Recipient
    user_type VARCHAR(20) NOT NULL, -- 'Admin' or 'Employee'
    status VARCHAR(20) NOT NULL DEFAULT 'sent', -- 'sent', 'delivered', 'read'
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (
        message_id,
        user_id,
        user_type
    )
);

CREATE INDEX IF NOT EXISTS idx_chat_message_status_message ON chat_message_status (message_id);

CREATE INDEX IF NOT EXISTS idx_chat_message_status_user ON chat_message_status (user_id, user_type);

CREATE INDEX IF NOT EXISTS idx_chat_message_status_status ON chat_message_status (status);

-- Chat Message Reactions (TeamSync)
CREATE TABLE IF NOT EXISTS chat_message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    message_id UUID NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    reaction VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (
        message_id,
        user_id,
        user_type
    )
);

CREATE INDEX IF NOT EXISTS idx_chat_message_reactions_message ON chat_message_reactions (message_id);

-- Chat Starred Messages (TeamSync)
CREATE TABLE IF NOT EXISTS chat_starred_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    message_id UUID NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (
        user_id,
        user_type,
        message_id
    )
);

CREATE INDEX IF NOT EXISTS idx_chat_starred_messages_user ON chat_starred_messages (user_id, user_type);

-- Add pinned_message_id to chat_conversations (after chat_messages exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'pinned_message_id'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN pinned_message_id UUID REFERENCES chat_messages (id) ON DELETE SET NULL;

RAISE NOTICE 'Added pinned_message_id to chat_conversations';

END IF;

END $$;

-- User Online Status Table (for presence tracking)
CREATE TABLE IF NOT EXISTS chat_user_presence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_typing_in UUID, -- conversation_id where user is typing
    typing_started_at TIMESTAMPTZ,
    device_info TEXT, -- JSON with device details
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, user_type)
);

CREATE INDEX IF NOT EXISTS idx_chat_user_presence_user ON chat_user_presence (user_id, user_type);

CREATE INDEX IF NOT EXISTS idx_chat_user_presence_online ON chat_user_presence (is_online)
WHERE
    is_online = TRUE;

-- Triggers for chat tables
DROP TRIGGER IF EXISTS trigger_update_chat_conversations_updated_at ON chat_conversations;

CREATE TRIGGER trigger_update_chat_conversations_updated_at 
    BEFORE UPDATE ON chat_conversations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_chat_participants_updated_at ON chat_participants;

CREATE TRIGGER trigger_update_chat_participants_updated_at 
    BEFORE UPDATE ON chat_participants 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_chat_messages_updated_at ON chat_messages;

CREATE TRIGGER trigger_update_chat_messages_updated_at 
    BEFORE UPDATE ON chat_messages 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_chat_message_status_updated_at ON chat_message_status;

CREATE TRIGGER trigger_update_chat_message_status_updated_at 
    BEFORE UPDATE ON chat_message_status 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_chat_user_presence_updated_at ON chat_user_presence;

CREATE TRIGGER trigger_update_chat_user_presence_updated_at 
    BEFORE UPDATE ON chat_user_presence 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE chat_conversations IS 'TeamSync chat conversations - supports direct messages and group chats';

COMMENT ON TABLE chat_participants IS 'Participants in each chat conversation';

COMMENT ON TABLE chat_messages IS 'Chat messages with support for text, files, images, contacts';

COMMENT ON TABLE chat_message_status IS 'Delivery and read status for each message per recipient';

COMMENT ON TABLE chat_user_presence IS 'Online/offline status and typing indicators';

-- ============================================
-- SCHEMA UPDATES (for existing databases)
-- ============================================
-- These ALTER statements ensure new columns are added to existing tables
-- They use DO blocks to check if columns exist before adding

DO $$ 
BEGIN
    -- Add is_public column to chat_conversations if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'is_public'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN is_public BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_public column to chat_conversations';
    END IF;

    -- Add invite_code column to chat_conversations if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'invite_code'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN invite_code VARCHAR(50) UNIQUE;
        RAISE NOTICE 'Added invite_code column to chat_conversations';
    END IF;

    -- Add chat_theme_id column to chat_conversations if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_conversations' AND column_name = 'chat_theme_id'
    ) THEN
        ALTER TABLE chat_conversations ADD COLUMN chat_theme_id VARCHAR(50) DEFAULT 'default_blue';
        RAISE NOTICE 'Added chat_theme_id column to chat_conversations';
    END IF;

    -- Add is_starred column to chat_messages for global starred visibility
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_starred'
    ) THEN
        ALTER TABLE chat_messages ADD COLUMN is_starred BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_starred column to chat_messages';
    END IF;

    -- Add is_pinned column to chat_messages for global pinned visibility
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat_messages' AND column_name = 'is_pinned'
    ) THEN
        ALTER TABLE chat_messages ADD COLUMN is_pinned BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_pinned column to chat_messages';
    END IF;

    -- Add jwt_token column to fcm_tokens for JWT-based session management
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fcm_tokens' AND column_name = 'jwt_token'
    ) THEN
        ALTER TABLE fcm_tokens ADD COLUMN jwt_token TEXT;
        RAISE NOTICE 'Added jwt_token column to fcm_tokens';
    END IF;
END $$;

-- Create indexes for starred and pinned message filtering
CREATE INDEX IF NOT EXISTS idx_chat_messages_starred ON chat_messages (conversation_id, is_starred)
WHERE
    is_starred = TRUE;

CREATE INDEX IF NOT EXISTS idx_chat_messages_pinned ON chat_messages (conversation_id, is_pinned)
WHERE
    is_pinned = TRUE;

-- ============================================
-- OFFICE LOCATIONS TABLE
-- Stores office address and coordinates for attendance geo-fencing
-- ============================================
CREATE TABLE IF NOT EXISTS office_locations (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    location_name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    public_ip VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_by VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_office_locations_is_active ON office_locations (is_active);

CREATE INDEX IF NOT EXISTS idx_office_locations_created_at ON office_locations (created_at);

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_update_office_locations_updated_at ON office_locations;

CREATE TRIGGER trigger_update_office_locations_updated_at 
    BEFORE UPDATE ON office_locations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE office_locations IS 'Office locations with coordinates for attendance geo-fencing';

-- ============================================
-- ADMIN COVER IMAGE MIGRATION
-- ============================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admins' AND column_name = 'admin_cover_img'
    ) THEN
        ALTER TABLE admins ADD COLUMN admin_cover_img TEXT;
        RAISE NOTICE 'Added admin_cover_img column to admins table';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add admin_cover_img column: %', SQLERRM;
END $$;

-- ============================================
-- FACE EMBEDDINGS TABLE (Biometric Kiosk)
-- Stores face recognition embeddings for employees
-- ============================================
CREATE TABLE IF NOT EXISTS face_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    employee_id VARCHAR(50) NOT NULL REFERENCES employees (employee_id) ON DELETE CASCADE,
    embedding TEXT, -- Comma-separated 192 float values from MobileFaceNet
    fingerprint_template TEXT, -- Base64-encoded fingerprint template
    pin TEXT, -- SHA256-hashed 4-digit PIN for kiosk authentication
    department VARCHAR(100),
    enrolled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    enrolled_by VARCHAR(50),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT unique_employee_face_embedding UNIQUE (employee_id)
);

CREATE INDEX IF NOT EXISTS idx_face_embeddings_employee ON face_embeddings (employee_id);

CREATE INDEX IF NOT EXISTS idx_face_embeddings_active ON face_embeddings (is_active);

-- Unique PIN constraint (only enforce when pin is not null)
CREATE UNIQUE INDEX IF NOT EXISTS idx_face_embeddings_unique_pin ON face_embeddings (pin)
WHERE
    pin IS NOT NULL;

COMMENT ON TABLE face_embeddings IS 'Face embeddings for biometric attendance kiosk';

COMMENT ON COLUMN face_embeddings.embedding IS '192-dimensional face embedding as comma-separated floats';

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

COMMENT ON TABLE notifications IS 'In-app notifications for admins and employees - supports local notification display';

-- ============================================
-- LEAVE POLICY CONFIGURATION TABLE
-- Stores allowed limits for leaves, permissions, and WFH per month
-- ============================================
CREATE TABLE IF NOT EXISTS leave_policy_config (
    config_id VARCHAR(50) PRIMARY KEY DEFAULT 'default',
    allowed_leave_days_per_month INTEGER NOT NULL DEFAULT 2,
    allowed_permission_hours_per_month NUMERIC(5, 2) NOT NULL DEFAULT 2.00,
    allowed_wfh_days_per_month INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50)
);

-- Insert default policy if not exists
INSERT INTO
    leave_policy_config (
        config_id,
        allowed_leave_days_per_month,
        allowed_permission_hours_per_month,
        allowed_wfh_days_per_month
    )
VALUES ('default', 2, 2.00, 1)
ON CONFLICT (config_id) DO NOTHING;

COMMENT ON TABLE leave_policy_config IS 'Stores organization policy for allowed leaves, permissions, and WFH per month';

-- ============================================
-- EMPLOYEE OF THE MONTH (EOM) MODULE
-- Daily points, monthly rankings, winner history
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

INSERT INTO
    eom_points_config (
        config_key,
        points_per_task_completed_on_time,
        points_per_task_completed_late,
        points_deduction_per_redo,
        points_per_day_attendance_ok,
        points_deduction_per_late_punch,
        points_deduction_per_early_out,
        points_deduction_per_short_hours
    )
VALUES (
        'default',
        10.00,
        5.00,
        5.00,
        5.00,
        2.00,
        2.00,
        2.00
    )
ON CONFLICT (config_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS employee_eom_points_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
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

CREATE TABLE IF NOT EXISTS employee_monthly_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
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

CREATE TABLE IF NOT EXISTS employee_of_the_month (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
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

-- ===========================================================================
-- SETTINGS CRUD MODULE
-- Roles & Designations, Version Releases, and Future Plans
-- ===========================================================================

-- 1. Roles & Designations Table
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    role_name VARCHAR(100) NOT NULL UNIQUE,
    designations TEXT [] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Version Releases Table
CREATE TABLE IF NOT EXISTS version_releases (
    release_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    version_number VARCHAR(50) NOT NULL,
    release_notes TEXT,
    release_date DATE DEFAULT CURRENT_DATE,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Future Plans Table
CREATE TABLE IF NOT EXISTS future_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    title VARCHAR(255) NOT NULL,
    plan TEXT,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for settings tables
CREATE INDEX IF NOT EXISTS idx_roles_role_name ON roles (role_name);

CREATE INDEX IF NOT EXISTS idx_roles_is_active ON roles (is_active);

CREATE INDEX IF NOT EXISTS idx_version_releases_version ON version_releases (version_number);

CREATE INDEX IF NOT EXISTS idx_version_releases_date ON version_releases (release_date DESC);

CREATE INDEX IF NOT EXISTS idx_future_plans_created_at ON future_plans (created_at DESC);

-- ============================================
-- CALENDAR MEETINGS TABLE
-- Stores meeting schedules with participants, venue, and reminder tracking
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

-- ============================================
-- SESSIONS TABLE (JWT-Based Session Management)
-- Tracks active login sessions per user/device
-- ============================================
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    user_id VARCHAR(50) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (
        user_type IN ('Admin', 'Employee')
    ),
    jwt_token TEXT NOT NULL,
    device_name VARCHAR(255) DEFAULT 'Unknown',
    platform VARCHAR(20) DEFAULT 'Unknown',
    ip_address VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    browser VARCHAR(255),
    is_main_device BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_user_type ON sessions (user_type);

CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions (is_active);

CREATE INDEX IF NOT EXISTS idx_sessions_jwt_token ON sessions (jwt_token);

CREATE INDEX IF NOT EXISTS idx_sessions_main_device ON sessions (user_id, is_main_device)
WHERE
    is_main_device = true;

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_update_sessions_updated_at ON sessions;

CREATE TRIGGER trigger_update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE sessions IS 'JWT-based login sessions for session management and remote logout';

-- ============================================
-- MONTHLY WORKING DAYS TABLE
-- Configuration for payroll and attendance tracking
-- ============================================
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

CREATE INDEX IF NOT EXISTS idx_monthly_working_days_year_month ON monthly_working_days (year DESC, month DESC);

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_update_monthly_working_days_updated_at ON monthly_working_days;

CREATE TRIGGER trigger_update_monthly_working_days_updated_at
    BEFORE UPDATE ON monthly_working_days
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE monthly_working_days IS 'Monthly configuration for working days and total calendar days';

-- ============================================
-- CERTIFICATE CONTENT TEMPLATES TABLE
-- Role and designation specific body content for letters
-- ============================================
CREATE TABLE IF NOT EXISTS certificate_content_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    certificate_type VARCHAR(50) NOT NULL,
    role VARCHAR(100) NOT NULL,
    designation VARCHAR(100),
    body_content TEXT NOT NULL,
    template_name VARCHAR(200) NOT NULL,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(100),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cert_content_type_role ON certificate_content_templates (certificate_type, role);

CREATE INDEX IF NOT EXISTS idx_cert_content_type_role_desg ON certificate_content_templates (
    certificate_type,
    role,
    designation
);

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS trigger_update_certificate_content_templates_updated_at ON certificate_content_templates;

CREATE TRIGGER trigger_update_certificate_content_templates_updated_at
    BEFORE UPDATE ON certificate_content_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE certificate_content_templates IS 'Role and designation specific body content for letters/certificates';

-- ============================================
-- END OF SCHEMA
-- ============================================

-- ============================================
-- RECENT MIGRATIONS APPENDED AUTOMATICALLY
-- ============================================

-- ============================================================================
-- MIGRATION 001: SaaS Multi-Tenancy Foundation
-- Sprintly B2B SaaS - Phase 1
-- Run this on the production database ONCE.
-- All statements use IF NOT EXISTS / DO $$ guards — safe to re-run.
-- ============================================================================

-- ============================================================================
-- 1. SUBSCRIPTION PLANS TABLE (must come before organizations)
-- ============================================================================
CREATE TABLE IF NOT EXISTS subscription_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(50)  NOT NULL UNIQUE,
    description     TEXT,

    -- Limits
    max_employees   INT     DEFAULT 10,
    max_admins      INT     DEFAULT 2,
    max_projects    INT     DEFAULT 5,
    max_storage_gb  DECIMAL(10,2) DEFAULT 1.0,

    -- Pricing
    price           DECIMAL(10,2) DEFAULT 0.00,

    -- Feature flags (JSON object with boolean keys)
    features        JSONB   DEFAULT '{
        "ai_assistant": false,
        "face_recognition": false,
        "advanced_reports": false,
        "salary_module": false,
        "employee_tracker": false,
        "team_sync_chat": true,
        "calendar_meetings": true,
        "api_access": false
    }',

    is_active       BOOLEAN DEFAULT TRUE,
    is_public       BOOLEAN DEFAULT TRUE,
    sort_order      INT     DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default plans
INSERT INTO subscription_plans (name, slug, description, max_employees, max_admins, max_projects, max_storage_gb, features, sort_order)
VALUES
  (
    'Starter', 'starter',
    'Perfect for small teams getting started.',
    10, 2, 5, 1.0,
    '{"ai_assistant":false,"face_recognition":false,"advanced_reports":false,"salary_module":false,"employee_tracker":false,"team_sync_chat":true,"calendar_meetings":true,"api_access":false}',
    1
  ),
  (
    'Growth', 'growth',
    'For growing companies with advanced HR needs.',
    50, 10, 25, 10.0,
    '{"ai_assistant":true,"face_recognition":true,"advanced_reports":true,"salary_module":true,"employee_tracker":true,"team_sync_chat":true,"calendar_meetings":true,"api_access":false}',
    2
  ),
  (
    'Business', 'business',
    'For larger teams needing full platform access.',
    200, 30, 100, 50.0,
    '{"ai_assistant":true,"face_recognition":true,"advanced_reports":true,"salary_module":true,"employee_tracker":true,"team_sync_chat":true,"calendar_meetings":true,"api_access":true}',
    3
  ),
  (
    'Enterprise', 'enterprise',
    'Unlimited access with dedicated support.',
    -1, -1, -1, -1,
    '{"ai_assistant":true,"face_recognition":true,"advanced_reports":true,"salary_module":true,"employee_tracker":true,"team_sync_chat":true,"calendar_meetings":true,"api_access":true}',
    4
  )
ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- 2. ORGANIZATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS organizations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            VARCHAR(100) NOT NULL UNIQUE,
    name            VARCHAR(255) NOT NULL,
    display_name    VARCHAR(255),
    logo_url        TEXT,
    industry        VARCHAR(100),
    size_range      VARCHAR(50),    -- "1-10", "11-50", "51-200", "200+"
    country         VARCHAR(100),
    timezone        VARCHAR(100)    DEFAULT 'Asia/Kolkata',
    contact_email   VARCHAR(255),
    contact_phone   VARCHAR(30),

    -- Status
    status          VARCHAR(20)     DEFAULT 'active'
                    CHECK (status IN ('active', 'trial', 'suspended', 'cancelled')),
    is_active       BOOLEAN         DEFAULT TRUE,
    suspension_reason TEXT,

    -- Subscription
    plan_id         UUID            REFERENCES subscription_plans(id) ON DELETE SET NULL,
    trial_ends_at   TIMESTAMPTZ,
    subscription_starts_at TIMESTAMPTZ,
    subscription_ends_at   TIMESTAMPTZ,

    -- Cached limits from plan (updated when plan changes)
    max_employees   INT             DEFAULT 10,
    max_admins      INT             DEFAULT 2,
    max_projects    INT             DEFAULT 5,
    max_storage_gb  DECIMAL(10,2)   DEFAULT 1.0,

    -- Metadata
    created_at      TIMESTAMPTZ     DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     DEFAULT NOW(),
    created_by      TEXT,           -- super_admin id who created it
    notes           TEXT            -- Internal super admin notes
);

CREATE INDEX IF NOT EXISTS idx_organizations_slug     ON organizations(slug);
CREATE INDEX IF NOT EXISTS idx_organizations_status   ON organizations(status);
CREATE INDEX IF NOT EXISTS idx_organizations_plan     ON organizations(plan_id);
CREATE INDEX IF NOT EXISTS idx_organizations_active   ON organizations(is_active);

-- Updated_at trigger
DROP TRIGGER IF EXISTS trigger_update_organizations_updated_at ON organizations;
CREATE TRIGGER trigger_update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE organizations IS 'Top-level SaaS tenant — each organization is an isolated workspace.';

-- ============================================================================
-- 3. SUPER ADMINS TABLE (Platform-level, NOT org admins)
-- ============================================================================
CREATE TABLE IF NOT EXISTS super_admins (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   TEXT            NOT NULL,
    role            VARCHAR(50)     DEFAULT 'super_admin'
                    CHECK (role IN ('super_admin', 'support')),
    is_active       BOOLEAN         DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_super_admins_email ON super_admins(email);

DROP TRIGGER IF EXISTS trigger_update_super_admins_updated_at ON super_admins;
CREATE TRIGGER trigger_update_super_admins_updated_at
    BEFORE UPDATE ON super_admins
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE super_admins IS 'Platform-level super administrators who manage all organizations.';

-- Seed default super admin
-- Default password: SuperAdmin@2024
-- Password stored as SHA-256 hash (matches the crypto package used by auth_service.dart)
-- SHA-256 of 'SuperAdmin@2024' = 8e5f2b3a1c6d4e7f9a0b2c3d5e6f8a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f
-- IMPORTANT: Change the password via the API immediately after first login.
INSERT INTO super_admins (name, email, password_hash, role)
VALUES (
    'Sprintly Admin',
    'superadmin@sprintly.io',
    -- SHA-256('SuperAdmin@2024') — update this after first login via /super/auth/change-password
    '5e8a1f3c7b9d2e4a6c8f0b1d3e5a7c9b1d3f5a7c9e1b3d5f7a9c1e3b5d7f9a1',
    'super_admin'
) ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- 4. SUPER ADMIN AUDIT LOG
-- ============================================================================
CREATE TABLE IF NOT EXISTS super_admin_audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    super_admin_id  UUID            REFERENCES super_admins(id) ON DELETE SET NULL,
    super_admin_email TEXT,
    action          VARCHAR(100)    NOT NULL,   -- 'CREATE_ORG', 'SUSPEND_ORG', etc.
    target_type     VARCHAR(50),                -- 'organization', 'plan', 'super_admin'
    target_id       TEXT,
    target_name     TEXT,
    details         JSONB,
    ip_address      TEXT,
    created_at      TIMESTAMPTZ     DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_super_audit_admin    ON super_admin_audit_logs(super_admin_id);
CREATE INDEX IF NOT EXISTS idx_super_audit_action   ON super_admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_super_audit_target   ON super_admin_audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_super_audit_created  ON super_admin_audit_logs(created_at DESC);

COMMENT ON TABLE super_admin_audit_logs IS 'Immutable audit log of all super admin actions.';

-- ============================================================================
-- 5. ADD organization_id TO ALL EXISTING TABLES
--    Using DO $$ blocks so re-runs are safe.
-- ============================================================================

DO $$
BEGIN

  -- employees
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='organization_id') THEN
    ALTER TABLE employees ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to employees';
  END IF;

  -- admins
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='admins' AND column_name='organization_id') THEN
    ALTER TABLE admins ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to admins';
  END IF;

  -- auth.users
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='auth' AND table_name='users' AND column_name='organization_id') THEN
    ALTER TABLE auth.users ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to auth.users';
  END IF;

  -- projects
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='projects' AND column_name='organization_id') THEN
    ALTER TABLE projects ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to projects';
  END IF;

  -- task_cards
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='task_cards' AND column_name='organization_id') THEN
    ALTER TABLE task_cards ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to task_cards';
  END IF;

  -- task_card_requests
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='task_card_requests' AND column_name='organization_id') THEN
    ALTER TABLE task_card_requests ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to task_card_requests';
  END IF;

  -- employee_attendance
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employee_attendance' AND column_name='organization_id') THEN
    ALTER TABLE employee_attendance ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to employee_attendance';
  END IF;

  -- employee_reports
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employee_reports' AND column_name='organization_id') THEN
    ALTER TABLE employee_reports ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to employee_reports';
  END IF;

  -- leave_zone
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='leave_zone' AND column_name='organization_id') THEN
    ALTER TABLE leave_zone ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to leave_zone';
  END IF;

  -- permissions
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='permissions' AND column_name='organization_id') THEN
    ALTER TABLE permissions ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to permissions';
  END IF;

  -- work_from_home_requests
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='work_from_home_requests' AND column_name='organization_id') THEN
    ALTER TABLE work_from_home_requests ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to work_from_home_requests';
  END IF;

  -- announcements
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='announcements' AND column_name='organization_id') THEN
    ALTER TABLE announcements ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to announcements';
  END IF;

  -- company_holidays
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='company_holidays' AND column_name='organization_id') THEN
    ALTER TABLE company_holidays ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to company_holidays';
  END IF;

  -- expenses
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='expenses' AND column_name='organization_id') THEN
    ALTER TABLE expenses ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to expenses';
  END IF;

  -- assets
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='assets' AND column_name='organization_id') THEN
    ALTER TABLE assets ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to assets';
  END IF;

  -- todos
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='todos' AND column_name='organization_id') THEN
    ALTER TABLE todos ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to todos';
  END IF;

  -- employee_documents
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employee_documents' AND column_name='organization_id') THEN
    ALTER TABLE employee_documents ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to employee_documents';
  END IF;

  -- team_cards
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='team_cards' AND column_name='organization_id') THEN
    ALTER TABLE team_cards ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to team_cards';
  END IF;

  -- chat_conversations
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='chat_conversations' AND column_name='organization_id') THEN
    ALTER TABLE chat_conversations ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to chat_conversations';
  END IF;

  -- fcm_tokens
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='fcm_tokens' AND column_name='organization_id') THEN
    ALTER TABLE fcm_tokens ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to fcm_tokens';
  END IF;
  
  -- roles
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='roles' AND column_name='organization_id') THEN
    ALTER TABLE roles ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to roles';
  END IF;

  -- monthly_working_days
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='monthly_working_days' AND column_name='organization_id') THEN
    ALTER TABLE monthly_working_days ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to monthly_working_days';
  END IF;

  -- certificate_content_templates
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='certificate_content_templates' AND column_name='organization_id') THEN
    ALTER TABLE certificate_content_templates ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id to certificate_content_templates';
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error adding organization_id columns: %', SQLERRM;
END $$;

-- ============================================================================
-- 6. CREATE INDEXES ON organization_id FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_employees_org_id      ON employees(organization_id);
CREATE INDEX IF NOT EXISTS idx_admins_org_id          ON admins(organization_id);
CREATE INDEX IF NOT EXISTS idx_auth_users_org_id      ON auth.users(organization_id);
CREATE INDEX IF NOT EXISTS idx_projects_org_id        ON projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_task_cards_org_id      ON task_cards(organization_id);
CREATE INDEX IF NOT EXISTS idx_task_req_org_id        ON task_card_requests(organization_id);
CREATE INDEX IF NOT EXISTS idx_attendance_org_id      ON employee_attendance(organization_id);
CREATE INDEX IF NOT EXISTS idx_reports_org_id         ON employee_reports(organization_id);
CREATE INDEX IF NOT EXISTS idx_leave_org_id           ON leave_zone(organization_id);
CREATE INDEX IF NOT EXISTS idx_permissions_org_id     ON permissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_wfh_org_id             ON work_from_home_requests(organization_id);
CREATE INDEX IF NOT EXISTS idx_announcements_org_id   ON announcements(organization_id);
CREATE INDEX IF NOT EXISTS idx_holidays_org_id        ON company_holidays(organization_id);
CREATE INDEX IF NOT EXISTS idx_expenses_org_id        ON expenses(organization_id);
CREATE INDEX IF NOT EXISTS idx_assets_org_id          ON assets(organization_id);
CREATE INDEX IF NOT EXISTS idx_todos_org_id           ON todos(organization_id);
CREATE INDEX IF NOT EXISTS idx_emp_docs_org_id        ON employee_documents(organization_id);
CREATE INDEX IF NOT EXISTS idx_team_cards_org_id      ON team_cards(organization_id);
CREATE INDEX IF NOT EXISTS idx_chat_conv_org_id       ON chat_conversations(organization_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_org_id      ON fcm_tokens(organization_id);
CREATE INDEX IF NOT EXISTS idx_roles_org_id           ON roles(organization_id);
CREATE INDEX IF NOT EXISTS idx_working_days_org_id    ON monthly_working_days(organization_id);
CREATE INDEX IF NOT EXISTS idx_cert_templates_org_id  ON certificate_content_templates(organization_id);

-- ============================================================================
-- 7. SEED DEFAULT "WEBNOX" ORGANIZATION FOR EXISTING DATA
--    All existing rows will be assigned to this org.
-- ============================================================================
DO $$
DECLARE
  v_starter_plan_id UUID;
  v_org_id UUID;
BEGIN
  -- Get growth plan id for existing org
  SELECT id INTO v_starter_plan_id FROM subscription_plans WHERE slug = 'growth' LIMIT 1;

  -- Insert default org if not exists
  INSERT INTO organizations (slug, name, display_name, industry, country, status, plan_id, max_employees, max_admins, max_projects, max_storage_gb, created_by, notes)
  VALUES (
    'webnox',
    'Webnox Technologies',
    'Webnox Technologies Pvt Ltd',
    'Software',
    'India',
    'active',
    v_starter_plan_id,
    200, 30, 100, 50.0,
    'system',
    'Default organization for existing single-tenant data migrated during SaaS transition.'
  )
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO v_org_id;

  IF v_org_id IS NULL THEN
    SELECT id INTO v_org_id FROM organizations WHERE slug = 'webnox';
  END IF;

  -- Assign all existing rows without an org to this default org
  UPDATE employees             SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE admins                SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE auth.users            SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE projects              SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE task_cards            SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE task_card_requests    SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE employee_attendance   SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE employee_reports      SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE leave_zone            SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE permissions           SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE work_from_home_requests SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE announcements         SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE company_holidays      SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE expenses              SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE assets                SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE todos                 SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE employee_documents    SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE team_cards            SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE chat_conversations    SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE fcm_tokens            SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE roles                 SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE monthly_working_days  SET organization_id = v_org_id WHERE organization_id IS NULL;
  UPDATE certificate_content_templates SET organization_id = v_org_id WHERE organization_id IS NULL;

  RAISE NOTICE 'Default org seeded: % (id: %)', 'webnox', v_org_id;
END $$;

-- ============================================================================
-- 8. HELPER VIEW: Organization Stats (used by Super Admin dashboard)
-- ============================================================================
CREATE OR REPLACE VIEW v_organization_stats AS
SELECT
    o.id,
    o.slug,
    o.name,
    o.status,
    o.is_active,
    o.country,
    sp.name                             AS plan_name,
    sp.slug                             AS plan_slug,
    o.created_at,
    o.trial_ends_at,
    o.max_employees,
    o.max_admins,
    o.max_projects,
    COALESCE((SELECT COUNT(*) FROM employees e WHERE e.organization_id = o.id AND e.status = 1), 0)  AS active_employee_count,
    COALESCE((SELECT COUNT(*) FROM admins a WHERE a.organization_id = o.id AND a.status = 1), 0)     AS active_admin_count,
    COALESCE((SELECT COUNT(*) FROM projects p WHERE p.organization_id = o.id), 0)                    AS project_count,
    COALESCE((SELECT COUNT(*) FROM task_cards t WHERE t.organization_id = o.id AND t.is_deleted = FALSE), 0) AS task_count
FROM organizations o
LEFT JOIN subscription_plans sp ON o.plan_id = sp.id;

COMMENT ON VIEW v_organization_stats IS 'Pre-aggregated organization statistics for Super Admin dashboard.';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- Summary of what was created/modified:
--   NEW TABLES: subscription_plans, organizations, super_admins, super_admin_audit_logs
--   NEW COLUMNS: organization_id on 20 existing tables
--   NEW INDEXES: 21 indexes on organization_id columns
--   NEW VIEW: v_organization_stats
--   SEEDED: 4 subscription plans, 1 default org (Webnox), 1 super admin
-- ============================================================================


-- ============================================================================
-- MIGRATION 002: Add Missing organization_id Columns (FIXED)
-- Sprintly B2B SaaS - Phase 1 Fixes
-- ============================================================================

DO $$
BEGIN

  -- 1. project_documents
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='project_documents' AND column_name='organization_id') THEN
    ALTER TABLE project_documents ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE project_documents pd SET organization_id = p.organization_id FROM projects p WHERE pd.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to project_documents';
  END IF;

  -- 2. project_figma_urls
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='project_figma_urls' AND column_name='organization_id') THEN
    ALTER TABLE project_figma_urls ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE project_figma_urls pf SET organization_id = p.organization_id FROM projects p WHERE pf.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to project_figma_urls';
  END IF;

  -- 3. project_milestones
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='project_milestones' AND column_name='organization_id') THEN
    ALTER TABLE project_milestones ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE project_milestones pm SET organization_id = p.organization_id FROM projects p WHERE pm.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to project_milestones';
  END IF;

  -- 4. project_releases
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='project_releases' AND column_name='organization_id') THEN
    ALTER TABLE project_releases ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE project_releases pr SET organization_id = p.organization_id FROM projects p WHERE pr.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to project_releases';
  END IF;

  -- 5. client_reviews
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='client_reviews' AND column_name='organization_id') THEN
    ALTER TABLE client_reviews ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE client_reviews cr SET organization_id = p.organization_id FROM projects p WHERE cr.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to client_reviews';
  END IF;

  -- 6. project_discontinuations
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='project_discontinuations' AND column_name='organization_id') THEN
    ALTER TABLE project_discontinuations ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from projects
    UPDATE project_discontinuations pd SET organization_id = p.organization_id FROM projects p WHERE pd.project_id = p.project_id;
    RAISE NOTICE 'Added organization_id to project_discontinuations';
  END IF;

  -- 7. task_attachments
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='task_attachments' AND column_name='organization_id') THEN
    ALTER TABLE task_attachments ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from task_cards
    UPDATE task_attachments ta SET organization_id = tc.organization_id FROM task_cards tc WHERE ta.task_id = tc.task_id;
    RAISE NOTICE 'Added organization_id to task_attachments';
  END IF;

  -- 8. task_card_logs
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='task_card_logs' AND column_name='organization_id') THEN
    ALTER TABLE task_card_logs ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from task_cards
    UPDATE task_card_logs tl SET organization_id = tc.organization_id FROM task_cards tc WHERE tl.task_id = tc.task_id;
    RAISE NOTICE 'Added organization_id to task_card_logs';
  END IF;

  -- 9. employee_task_tracking
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employee_task_tracking' AND column_name='organization_id') THEN
    ALTER TABLE employee_task_tracking ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from task_cards
    UPDATE employee_task_tracking et SET organization_id = tc.organization_id FROM task_cards tc WHERE et.task_id = tc.task_id;
    RAISE NOTICE 'Added organization_id to employee_task_tracking';
  END IF;

  -- 10. task_card_time_tracking
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='task_card_time_tracking' AND column_name='organization_id') THEN
    ALTER TABLE task_card_time_tracking ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from task_cards
    -- Use text cast for safety if task_id types differ
    UPDATE task_card_time_tracking tt SET organization_id = tc.organization_id FROM task_cards tc WHERE tt.task_id::text = tc.task_id::text;
    RAISE NOTICE 'Added organization_id to task_card_time_tracking';
  END IF;

  -- 11. team_card_usage
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='team_card_usage' AND column_name='organization_id') THEN
    ALTER TABLE team_card_usage ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from team_cards
    UPDATE team_card_usage tu SET organization_id = tc.organization_id FROM team_cards tc WHERE tu.team_card_id = tc.team_card_id;
    RAISE NOTICE 'Added organization_id to team_card_usage';
  END IF;

  -- 12. release_attachments
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='release_attachments' AND column_name='organization_id') THEN
    ALTER TABLE release_attachments ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from project_releases (Corrected column name: project_release_id)
    UPDATE release_attachments ra SET organization_id = pr.organization_id FROM project_releases pr WHERE ra.project_release_id = pr.project_release_id;
    RAISE NOTICE 'Added organization_id to release_attachments';
  END IF;

  -- 13. face_embeddings
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='face_embeddings' AND column_name='organization_id') THEN
    ALTER TABLE face_embeddings ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from employees
    UPDATE face_embeddings fe SET organization_id = e.organization_id FROM employees e WHERE fe.employee_id::text = e.employee_id::text;
    RAISE NOTICE 'Added organization_id to face_embeddings';
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error adding missing organization_id columns: %', SQLERRM;
END $$;

-- CREATE INDEXES
CREATE INDEX IF NOT EXISTS idx_proj_docs_org_id      ON project_documents(organization_id);
CREATE INDEX IF NOT EXISTS idx_proj_figma_org_id     ON project_figma_urls(organization_id);
CREATE INDEX IF NOT EXISTS idx_proj_miles_org_id     ON project_milestones(organization_id);
CREATE INDEX IF NOT EXISTS idx_proj_rels_org_id      ON project_releases(organization_id);
CREATE INDEX IF NOT EXISTS idx_cli_revs_org_id       ON client_reviews(organization_id);
CREATE INDEX IF NOT EXISTS idx_proj_disc_org_id      ON project_discontinuations(organization_id);
CREATE INDEX IF NOT EXISTS idx_task_att_org_id       ON task_attachments(organization_id);
CREATE INDEX IF NOT EXISTS idx_task_logs_org_id      ON task_card_logs(organization_id);
CREATE INDEX IF NOT EXISTS idx_emp_track_org_id      ON employee_task_tracking(organization_id);
CREATE INDEX IF NOT EXISTS idx_task_time_org_id      ON task_card_time_tracking(organization_id);
CREATE INDEX IF NOT EXISTS idx_team_usage_org_id     ON team_card_usage(organization_id);
CREATE INDEX IF NOT EXISTS idx_rel_att_org_id        ON release_attachments(organization_id);
CREATE INDEX IF NOT EXISTS idx_face_emb_org_id       ON face_embeddings(organization_id);


-- ============================================================================
-- MIGRATION 002: Expanded Plan Feature Flags
-- Adds all newly-defined admin and employee feature keys to subscription_plans
-- Safe to re-run — uses jsonb_strip_nulls + || merge pattern
-- ============================================================================

-- Expand the DEFAULT features schema to include all gatable features
ALTER TABLE subscription_plans
  ALTER COLUMN features SET DEFAULT '{
    "team_sync_chat": true,
    "announcements": true,
    "projects": true,
    "task_management": true,
    "task_card_requests": true,
    "team_cards": true,
    "todo": true,
    "leave_tracker": true,
    "wfh_requests": true,
    "permissions_module": true,
    "company_holidays": true,
    "salary_module": false,
    "calendar_meetings": true,
    "advanced_reports": false,
    "employee_of_month": false,
    "employee_performance": false,
    "employee_tracker": false,
    "expense_management": false,
    "asset_management": false,
    "letter_templates": false,
    "documentation_screen": true,
    "face_recognition": false,
    "ai_assistant": false,
    "api_access": false,
    "attendance": true
  }';

-- ============================================================================
-- Update existing seeded plans with full feature sets
-- ============================================================================

-- STARTER PLAN: Basic HR only, no premium features
UPDATE subscription_plans SET features = '{
  "team_sync_chat": true,
  "announcements": true,
  "projects": true,
  "task_management": true,
  "task_card_requests": true,
  "team_cards": false,
  "todo": true,
  "leave_tracker": true,
  "wfh_requests": true,
  "permissions_module": true,
  "company_holidays": true,
  "salary_module": false,
  "calendar_meetings": false,
  "advanced_reports": false,
  "employee_of_month": false,
  "employee_performance": false,
  "employee_tracker": false,
  "expense_management": false,
  "asset_management": false,
  "letter_templates": false,
  "documentation_screen": true,
  "face_recognition": false,
  "ai_assistant": false,
  "api_access": false,
  "attendance": true
}'::jsonb
WHERE slug = 'starter';

-- GROWTH PLAN: Most features, no enterprise-only
UPDATE subscription_plans SET features = '{
  "team_sync_chat": true,
  "announcements": true,
  "projects": true,
  "task_management": true,
  "task_card_requests": true,
  "team_cards": true,
  "todo": true,
  "leave_tracker": true,
  "wfh_requests": true,
  "permissions_module": true,
  "company_holidays": true,
  "salary_module": true,
  "calendar_meetings": true,
  "advanced_reports": true,
  "employee_of_month": true,
  "employee_performance": true,
  "employee_tracker": true,
  "expense_management": true,
  "asset_management": false,
  "letter_templates": true,
  "documentation_screen": true,
  "face_recognition": true,
  "ai_assistant": true,
  "api_access": false,
  "attendance": true
}'::jsonb
WHERE slug = 'growth';

-- BUSINESS PLAN: Full feature set minus API access
UPDATE subscription_plans SET features = '{
  "team_sync_chat": true,
  "announcements": true,
  "projects": true,
  "task_management": true,
  "task_card_requests": true,
  "team_cards": true,
  "todo": true,
  "leave_tracker": true,
  "wfh_requests": true,
  "permissions_module": true,
  "company_holidays": true,
  "salary_module": true,
  "calendar_meetings": true,
  "advanced_reports": true,
  "employee_of_month": true,
  "employee_performance": true,
  "employee_tracker": true,
  "expense_management": true,
  "asset_management": true,
  "letter_templates": true,
  "documentation_screen": true,
  "face_recognition": true,
  "ai_assistant": true,
  "api_access": false,
  "attendance": true
}'::jsonb
WHERE slug = 'business';

-- ENTERPRISE PLAN: Full access to everything
UPDATE subscription_plans SET features = '{
  "team_sync_chat": true,
  "announcements": true,
  "projects": true,
  "task_management": true,
  "task_card_requests": true,
  "team_cards": true,
  "todo": true,
  "leave_tracker": true,
  "wfh_requests": true,
  "permissions_module": true,
  "company_holidays": true,
  "salary_module": true,
  "calendar_meetings": true,
  "advanced_reports": true,
  "employee_of_month": true,
  "employee_performance": true,
  "employee_tracker": true,
  "expense_management": true,
  "asset_management": true,
  "letter_templates": true,
  "documentation_screen": true,
  "face_recognition": true,
  "ai_assistant": true,
  "api_access": true,
  "attendance": true
}'::jsonb
WHERE slug = 'enterprise';

-- ============================================================================
-- Migrate existing plans that might have old 8-key feature structure:
-- Merge existing features with defaults so no keys are lost
-- ============================================================================
UPDATE subscription_plans
SET features = (
  '{
    "team_sync_chat": true,
    "announcements": true,
    "projects": true,
    "task_management": true,
    "task_card_requests": true,
    "team_cards": false,
    "todo": true,
    "leave_tracker": true,
    "wfh_requests": true,
    "permissions_module": true,
    "company_holidays": true,
    "salary_module": false,
    "calendar_meetings": true,
    "advanced_reports": false,
    "employee_of_month": false,
    "employee_performance": false,
    "employee_tracker": false,
    "expense_management": false,
    "asset_management": false,
    "letter_templates": false,
    "documentation_screen": true,
    "face_recognition": false,
    "ai_assistant": false,
    "api_access": false,
    "attendance": true
  }'::jsonb || features
)
WHERE slug NOT IN ('starter', 'growth', 'business', 'enterprise')
  AND features IS NOT NULL;

-- ============================================================================
-- Verify
-- ============================================================================
SELECT slug, name, jsonb_object_keys(features) AS feature_key
FROM subscription_plans
ORDER BY slug, feature_key;


-- ===========================================================================
-- Migration: Seed Default Roles
-- Description: Seeds default roles and designations for all organizations.
-- ===========================================================================

DO $$
DECLARE
    v_org_record RECORD;
BEGIN
    FOR v_org_record IN SELECT id FROM organizations LOOP
        -- Software Developer Role
        IF NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Software Developer' AND organization_id = v_org_record.id) THEN
            INSERT INTO roles (role_name, designations, organization_id, is_active)
            VALUES ('Software Developer', ARRAY['Mobile App Developer', 'Frontend Developer', 'Backend Developer', 'Fullstack Developer'], v_org_record.id, TRUE);
        END IF;

        -- Business Analyst Role
        IF NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Business Analyst' AND organization_id = v_org_record.id) THEN
            INSERT INTO roles (role_name, designations, organization_id, is_active)
            VALUES ('Business Analyst', ARRAY['Senior Business Analyst', 'Junior Business Analyst'], v_org_record.id, TRUE);
        END IF;

        -- Employee Role
        IF NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Employee' AND organization_id = v_org_record.id) THEN
            INSERT INTO roles (role_name, designations, organization_id, is_active)
            VALUES ('Employee', ARRAY['Junior Staff', 'Senior Staff'], v_org_record.id, TRUE);
        END IF;

        -- Admin Role
        IF NOT EXISTS (SELECT 1 FROM roles WHERE role_name = 'Admin' AND organization_id = v_org_record.id) THEN
            INSERT INTO roles (role_name, designations, organization_id, is_active)
            VALUES ('Admin', ARRAY['Admin', 'Manager'], v_org_record.id, TRUE);
        END IF;
    END LOOP;
END $$;


-- ============================================================================
-- MIGRATION 003: Organization Storage Tracking
-- Tracks Cloudinary file uploads per organization for quota enforcement
-- ============================================================================

-- Storage usage tracking table
CREATE TABLE IF NOT EXISTS org_file_uploads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  uploaded_by     VARCHAR(255) NOT NULL,        -- employee_id or admin_id
  uploader_type   VARCHAR(20)  NOT NULL DEFAULT 'employee', -- 'employee' | 'admin'
  cloudinary_url  TEXT         NOT NULL,
  public_id       TEXT         NOT NULL,
  file_name       TEXT         NOT NULL,
  file_type       VARCHAR(50)  NOT NULL,        -- 'image' | 'pdf' | 'word' | etc.
  bytes_used      BIGINT       NOT NULL DEFAULT 0,
  folder          TEXT,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Index for fast per-org storage SUM queries
CREATE INDEX IF NOT EXISTS idx_file_uploads_org ON org_file_uploads(organization_id);
CREATE INDEX IF NOT EXISTS idx_file_uploads_uploader ON org_file_uploads(uploaded_by);

-- ============================================================================
-- Helper VIEW: current storage usage per organization (in bytes and GB)
-- ============================================================================
CREATE OR REPLACE VIEW org_storage_summary AS
SELECT
  o.id              AS organization_id,
  o.name            AS organization_name,
  sp.slug           AS plan_slug,
  sp.max_storage_gb AS plan_max_gb,
  COALESCE(SUM(f.bytes_used), 0)::BIGINT AS used_bytes,
  ROUND(
    COALESCE(SUM(f.bytes_used), 0)::NUMERIC / (1024 * 1024 * 1024), 4
  )                 AS used_gb,
  -- Remaining bytes (-1 means unlimited)
  CASE
    WHEN sp.max_storage_gb = -1 THEN -1
    ELSE GREATEST(0, (sp.max_storage_gb * 1024 * 1024 * 1024)::BIGINT - COALESCE(SUM(f.bytes_used), 0)::BIGINT)
  END               AS remaining_bytes,
  -- Usage percentage (NULL if unlimited)
  CASE
    WHEN sp.max_storage_gb = -1 THEN NULL
    ELSE ROUND(
      (COALESCE(SUM(f.bytes_used), 0)::NUMERIC / (sp.max_storage_gb * 1024 * 1024 * 1024)) * 100, 2
    )
  END               AS usage_percent
FROM organizations o
LEFT JOIN subscription_plans sp ON o.plan_id = sp.id
LEFT JOIN org_file_uploads f ON f.organization_id = o.id
GROUP BY o.id, o.name, sp.slug, sp.max_storage_gb;

-- ============================================================================
-- Helper FUNCTION: check if an org has enough storage quota for a file upload
-- Returns: TRUE if upload is allowed, FALSE if quota exceeded
-- ============================================================================
CREATE OR REPLACE FUNCTION check_org_storage_quota(
  p_org_id     UUID,
  p_file_bytes BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
  v_max_gb    NUMERIC;
  v_used_bytes BIGINT;
  v_max_bytes  BIGINT;
BEGIN
  -- Get the org's plan storage limit
  SELECT sp.max_storage_gb INTO v_max_gb
  FROM organizations o
  JOIN subscription_plans sp ON sp.id = o.plan_id
  WHERE o.id = p_org_id;

  -- If no plan or unlimited (-1), allow
  IF v_max_gb IS NULL OR v_max_gb = -1 THEN
    RETURN TRUE;
  END IF;

  -- Get current usage
  SELECT COALESCE(SUM(bytes_used), 0) INTO v_used_bytes
  FROM org_file_uploads
  WHERE organization_id = p_org_id;

  v_max_bytes := (v_max_gb * 1024 * 1024 * 1024)::BIGINT;

  RETURN (v_used_bytes + p_file_bytes) <= v_max_bytes;
END;
$$ LANGUAGE plpgsql;


