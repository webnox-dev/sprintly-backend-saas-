-- ============================================
-- Migration: Add ON UPDATE CASCADE to all foreign keys referencing employees(employee_id) or admins(admin_id)
-- This allows updating incorrect IDs without violating foreign key constraints.
-- ============================================

DO $$
DECLARE
    r RECORD;
    p_table_name TEXT;
    p_column_name TEXT;
BEGIN
    -- Loop through all foreign keys that reference employees(employee_id) or admins(admin_id)
    FOR r IN (
        SELECT 
            tc.table_schema,
            tc.table_name, 
            tc.constraint_name, 
            kcu.column_name,
            rc.delete_rule,
            rc.unique_constraint_name,
            rc.unique_constraint_schema
        FROM 
            information_schema.table_constraints AS tc 
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.referential_constraints AS rc
              ON tc.constraint_name = rc.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
              ON rc.unique_constraint_name = ccu.constraint_name
              AND rc.unique_constraint_schema = ccu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
          AND ccu.table_name IN ('employees', 'admins')
          AND ccu.column_name IN ('employee_id', 'admin_id')
          AND tc.table_schema IN ('public', 'auth')
    ) LOOP
        -- Extract the referenced table and column from information_schema.constraint_column_usage (the parent)
        SELECT ccu.table_name, ccu.column_name INTO p_table_name, p_column_name
        FROM information_schema.constraint_column_usage ccu
        WHERE ccu.constraint_name = r.unique_constraint_name 
          AND ccu.table_schema = r.unique_constraint_schema
        LIMIT 1;

        RAISE NOTICE 'Updating constraint % on table %.% (references %.%) to include ON UPDATE CASCADE', 
            r.constraint_name, r.table_schema, r.table_name, p_table_name, p_column_name;
        
        -- Drop existing constraint
        EXECUTE 'ALTER TABLE ' || quote_ident(r.table_schema) || '.' || quote_ident(r.table_name) || 
                ' DROP CONSTRAINT ' || quote_ident(r.constraint_name);
        
        -- Re-add with ON UPDATE CASCADE and preserve ON DELETE rule
        EXECUTE 'ALTER TABLE ' || quote_ident(r.table_schema) || '.' || quote_ident(r.table_name) || 
                ' ADD CONSTRAINT ' || quote_ident(r.constraint_name) || 
                ' FOREIGN KEY (' || quote_ident(r.column_name) || ') ' ||
                ' REFERENCES ' || quote_ident(r.unique_constraint_schema) || '.' || quote_ident(p_table_name) || '(' || quote_ident(p_column_name) || ') ' ||
                ' ON UPDATE CASCADE ON DELETE ' || r.delete_rule;
    END LOOP;
END $$;
