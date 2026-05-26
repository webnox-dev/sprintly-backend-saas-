-- ============================================
-- Migration: Create office_locations table
-- Date: 2026-01-16
-- Description: Stores office address and coordinates for attendance geo-fencing
-- ============================================

-- Create the office_locations table
CREATE TABLE IF NOT EXISTS office_locations (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    location_name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    public_ip VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    updated_by VARCHAR(50)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_office_locations_is_active ON office_locations (is_active);

CREATE INDEX IF NOT EXISTS idx_office_locations_created_at ON office_locations (created_at);

-- Create trigger for auto-updating updated_at timestamp
DROP TRIGGER IF EXISTS trigger_update_office_locations_updated_at ON office_locations;

CREATE TRIGGER trigger_update_office_locations_updated_at 
    BEFORE UPDATE ON office_locations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add table comment
COMMENT ON TABLE office_locations IS 'Office locations with coordinates for attendance geo-fencing';

-- Verify table was created
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'office_locations') THEN
        RAISE NOTICE 'SUCCESS: office_locations table created successfully';
    ELSE
        RAISE EXCEPTION 'FAILED: office_locations table was not created';
    END IF;
END $$;