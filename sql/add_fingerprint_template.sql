ALTER TABLE face_embeddings
ADD COLUMN IF NOT EXISTS fingerprint_template TEXT;