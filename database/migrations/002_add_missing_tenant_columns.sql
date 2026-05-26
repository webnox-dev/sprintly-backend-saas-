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
