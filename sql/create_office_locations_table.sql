-- SQL Script to create the office_locations table
-- Run this in your PostgreSQL database

CREATE TABLE IF NOT EXISTS office_locations (
    location_id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
    location_name text NOT NULL,
    address text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    radius_meters integer NOT NULL DEFAULT 100,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by text,
    updated_by text,
    public_ip text
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_office_locations_is_active ON office_locations (is_active);

CREATE INDEX IF NOT EXISTS idx_office_locations_created_at ON office_locations (created_at);

-- Insert a sample office location (optional - you can remove this)
-- INSERT INTO office_locations (location_name, address, latitude, longitude, radius_meters, is_active)
-- VALUES ('Main Office', '123 Business Street, City', 12.9716, 77.5946, 100, true);

-- Verify the table was created
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE
    table_name = 'office_locations';