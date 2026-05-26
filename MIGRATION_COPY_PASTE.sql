-- COPY AND PASTE THIS INTO pgAdmin Query Tool
-- Connect to database: webnox_sprintly
-- Then execute this entire script (press F5 or click Execute button)

-- 1. Convert admins.status
ALTER TABLE admins 
ALTER COLUMN status DROP DEFAULT;

ALTER TABLE admins 
ALTER COLUMN status TYPE SMALLINT USING (CASE WHEN status THEN 1 ELSE 0 END);

ALTER TABLE admins 
ALTER COLUMN status SET DEFAULT 1;

-- 2. Convert employees.status
ALTER TABLE employees 
ALTER COLUMN status DROP DEFAULT;

ALTER TABLE employees 
ALTER COLUMN status TYPE SMALLINT USING (CASE WHEN status THEN 1 ELSE 0 END);

ALTER TABLE employees 
ALTER COLUMN status SET DEFAULT 1;

-- 3. Update/Add auth.users columns
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS is_active SMALLINT DEFAULT 1;

ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS reference_id VARCHAR(50);

-- 4. Convert employee_attendance.is_remote_override
ALTER TABLE employee_attendance 
ALTER COLUMN is_remote_override DROP DEFAULT;

ALTER TABLE employee_attendance 
ALTER COLUMN is_remote_override TYPE SMALLINT USING (CASE WHEN is_remote_override THEN 1 ELSE 0 END);

ALTER TABLE employee_attendance 
ALTER COLUMN is_remote_override SET DEFAULT 0;

-- 5. Convert leave_zone.is_paid_leave
ALTER TABLE leave_zone 
ALTER COLUMN is_paid_leave DROP DEFAULT;

ALTER TABLE leave_zone 
ALTER COLUMN is_paid_leave TYPE SMALLINT USING (CASE WHEN is_paid_leave THEN 1 ELSE 0 END);

ALTER TABLE leave_zone 
ALTER COLUMN is_paid_leave SET DEFAULT 0;

-- 6. Convert permissions.is_permission_approved
ALTER TABLE permissions 
ALTER COLUMN is_permission_approved DROP DEFAULT;

ALTER TABLE permissions 
ALTER COLUMN is_permission_approved TYPE SMALLINT USING (CASE WHEN is_permission_approved THEN 1 ELSE 0 END);

ALTER TABLE permissions 
ALTER COLUMN is_permission_approved SET DEFAULT 0;

-- 7. Convert announcements.is_active
ALTER TABLE announcements 
ALTER COLUMN is_active DROP DEFAULT;

ALTER TABLE announcements 
ALTER COLUMN is_active TYPE SMALLINT USING (CASE WHEN is_active THEN 1 ELSE 0 END);

ALTER TABLE announcements 
ALTER COLUMN is_active SET DEFAULT 1;

-- 8. Convert password_reset_helper.is_used
ALTER TABLE password_reset_helper 
ALTER COLUMN is_used DROP DEFAULT;

ALTER TABLE password_reset_helper 
ALTER COLUMN is_used TYPE SMALLINT USING (CASE WHEN is_used THEN 1 ELSE 0 END);

ALTER TABLE password_reset_helper 
ALTER COLUMN is_used SET DEFAULT 0;

-- Verification: Check the data types
SELECT 
    table_name, 
    column_name, 
    data_type,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public'
AND column_name IN ('status', 'is_remote_override', 'is_paid_leave', 'is_permission_approved', 'is_active', 'is_used')
ORDER BY table_name, column_name;
