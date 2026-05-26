-- ===========================================================================
-- Migration: Create Settings CRUD Tables
-- Date: 2026-02-13
-- Description: Creates tables for Roles & Designations, Version Releases,
--              and Future Plans management.
-- ===========================================================================

-- 1. Roles & Designations Table
-- Each role has a name and an array of designations associated with it.
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    role_name VARCHAR(100) NOT NULL UNIQUE,
    designations TEXT [] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Version Releases Table
-- Tracks application version releases with version number and release notes.
CREATE TABLE IF NOT EXISTS version_releases (
    release_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    version_number VARCHAR(50) NOT NULL,
    release_notes TEXT,
    release_date DATE DEFAULT CURRENT_DATE,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Future Plans Table
-- Stores future plans with title and plan description.
CREATE TABLE IF NOT EXISTS future_plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    title VARCHAR(255) NOT NULL,
    plan TEXT,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_roles_role_name ON roles (role_name);

CREATE INDEX IF NOT EXISTS idx_roles_is_active ON roles (is_active);

CREATE INDEX IF NOT EXISTS idx_version_releases_version ON version_releases (version_number);

CREATE INDEX IF NOT EXISTS idx_version_releases_date ON version_releases (release_date DESC);

CREATE INDEX IF NOT EXISTS idx_future_plans_created_at ON future_plans (created_at DESC);