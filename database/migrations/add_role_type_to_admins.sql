-- Add role_type column to admins table
ALTER TABLE admins ADD COLUMN role_type VARCHAR(50);

-- Update existing admins based on their admin_role permissions pattern (heuristic)
-- This is a best-effort migration for existing data
UPDATE admins
SET
    role_type = CASE
        WHEN admin_role = 'HR' THEN 'HR'
        WHEN admin_role = 'Team Leader' THEN 'Team Leader'
        WHEN admin_role = 'BDE' THEN 'BDE'
        ELSE 'Super Admin' -- Default others (CEO, CTO, etc.) to Super Admin for safety/access
    END;