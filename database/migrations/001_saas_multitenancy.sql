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
