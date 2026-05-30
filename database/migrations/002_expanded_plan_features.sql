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
