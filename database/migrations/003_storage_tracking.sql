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
