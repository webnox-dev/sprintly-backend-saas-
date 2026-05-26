-- Migration: Add UNIQUE constraint on email in password_reset_helper table
-- Date: 2026-01-15
-- Description: Fixes ON CONFLICT (email) clause by adding unique constraint

-- First, remove duplicate emails keeping only the latest record per email
DELETE FROM password_reset_helper a USING (
    SELECT MAX(id::text)::uuid as id, email
    FROM password_reset_helper
    GROUP BY
        email
    HAVING
        COUNT(*) > 1
) b
WHERE
    a.email = b.email
    AND a.id <> b.id;

-- Add unique constraint on email column
ALTER TABLE password_reset_helper
ADD CONSTRAINT password_reset_helper_email_unique UNIQUE (email);

-- Verify the constraint was added
SELECT con.conname as constraint_name
FROM
    pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
WHERE
    rel.relname = 'password_reset_helper'
    AND con.contype = 'u';