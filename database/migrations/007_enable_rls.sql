-- ============================================================================
-- MIGRATION 007: Enable Row-Level Security (RLS)
-- Enables database-level tenant isolation as a primary security safety net.
-- ============================================================================

DO $$
DECLARE
  t_name TEXT;
  tables_list TEXT[] := ARRAY[
    'employees',
    'admins',
    'auth.users',
    'projects',
    'task_cards',
    'task_card_requests',
    'employee_attendance',
    'employee_reports',
    'leave_zone',
    'permissions',
    'work_from_home_requests',
    'announcements',
    'company_holidays',
    'expenses',
    'assets',
    'todos',
    'employee_documents',
    'team_cards',
    'chat_conversations',
    'fcm_tokens',
    'roles',
    'monthly_working_days',
    'certificate_content_templates',
    'project_documents',
    'project_figma_urls',
    'project_milestones',
    'project_releases',
    'client_reviews',
    'project_discontinuations',
    'task_attachments',
    'task_card_logs',
    'employee_task_tracking',
    'task_card_time_tracking',
    'team_card_usage',
    'release_attachments',
    'face_embeddings',
    'calendar_meetings'
  ];
BEGIN
  -- Enable organization_id for calendar_meetings if not done
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='calendar_meetings' AND column_name='organization_id') THEN
    ALTER TABLE calendar_meetings ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
    -- Backfill from default Webnox organization
    UPDATE calendar_meetings SET organization_id = (SELECT id FROM organizations WHERE slug = 'webnox' LIMIT 1);
  END IF;

  -- Loop through all tenant tables to enable RLS and create isolation policies
  FOREACH t_name IN ARRAY tables_list
  LOOP
    -- Enable RLS
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', t_name);
    
    -- Drop existing policy if any
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %s', t_name);
    
    -- Create policy
    EXECUTE format(
      'CREATE POLICY tenant_isolation ON %s USING (
        (current_setting(''app.bypass_rls'', true) = ''true'') OR
        (organization_id = NULLIF(current_setting(''app.current_tenant'', true), '''')::uuid)
      )', 
      t_name
    );
    
    RAISE NOTICE 'Enabled RLS and created tenant_isolation policy on table %', t_name;
  END LOOP;
END $$;
