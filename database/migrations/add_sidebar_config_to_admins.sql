-- Migration: Add sidebar_config column to admins table
-- Last Updated: 2026-03-18
-- Used for per-admin sidebar customization

ALTER TABLE admins
ADD COLUMN IF NOT EXISTS sidebar_config JSONB DEFAULT NULL;

COMMENT ON COLUMN admins.sidebar_config IS 
  'Per-admin sidebar customization: { "tab_order": [...], "hidden_tabs": [...], "group_order": [...], "group_titles": {...} }';
