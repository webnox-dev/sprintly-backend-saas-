-- Letter Template Module
-- Created: 2026-02-26

CREATE TABLE IF NOT EXISTS letter_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    template_type VARCHAR(50) NOT NULL,
    template_name VARCHAR(150) NOT NULL,
    header_config JSONB DEFAULT '{}',
    footer_config JSONB DEFAULT '{}',
    watermark_config JSONB DEFAULT '{}',
    body_content TEXT NOT NULL,
    placeholders JSONB DEFAULT '[]',
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_letter_templates_type ON letter_templates (template_type);

CREATE INDEX IF NOT EXISTS idx_letter_templates_active ON letter_templates (is_active);

-- Ensure there is only one default template per type
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_default_template ON letter_templates (template_type)
WHERE
    is_default = true;