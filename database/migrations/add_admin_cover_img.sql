-- Migration: Add admin_cover_img column to admins table
-- Date: 2026-01-16

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admins' AND column_name = 'admin_cover_img'
    ) THEN
        ALTER TABLE admins ADD COLUMN admin_cover_img TEXT;
        RAISE NOTICE 'Added admin_cover_img column to admins table';
    ELSE
        RAISE NOTICE 'admin_cover_img column already exists';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add admin_cover_img column: %', SQLERRM;
END $$;