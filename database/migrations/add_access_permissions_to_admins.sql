-- ============================================
-- Migration: Add access_permissions JSONB column to admins table
-- Purpose: Supports dynamic Role-Based Access Control (RBAC)
-- Date: 2026-02-11
-- ============================================

-- Add access_permissions column (JSONB) to store granular permission strings.
-- If NULL, the system falls back to default permissions based on admin_role.
-- Example value: '["view_projects", "manage_hrms", "view_teamsync"]'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'admins' AND column_name = 'access_permissions'
    ) THEN
        ALTER TABLE admins ADD COLUMN access_permissions JSONB DEFAULT NULL;
        RAISE NOTICE 'Column access_permissions added to admins table.';
    ELSE
        RAISE NOTICE 'Column access_permissions already exists in admins table.';
    END IF;
END $$;