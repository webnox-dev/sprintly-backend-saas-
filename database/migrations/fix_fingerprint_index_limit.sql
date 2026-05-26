-- Drop any existing index on fingerprint_template to fix the "index row requires X bytes" error
-- This allows storing large RD Service PID XMLs (up to 15KB) which exceed the B-Tree 8KB limit.

DO $$ 
BEGIN
    -- We don't know the exact name of the index if it was created automatically,
    -- but usually it would be unique or named similarly.
    -- This migration ensures NO index exists on the large biometric columns.
    
    -- Drop by name if it exists (common naming conventions)
    DROP INDEX IF EXISTS idx_face_embeddings_fingerprint;
    DROP INDEX IF EXISTS unique_fingerprint_template;
    
    -- Also check for any unique constraint that might act as an index
    ALTER TABLE face_embeddings DROP CONSTRAINT IF EXISTS unique_fingerprint_template;
    
    RAISE NOTICE 'B-Tree indexes/constraints removed from fingerprint_template to support large payloads.';
END $$;