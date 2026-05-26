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
