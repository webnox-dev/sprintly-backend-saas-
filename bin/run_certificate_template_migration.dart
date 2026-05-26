import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  print('Running Certificate Content Templates migration...');

  try {
    await DatabaseConnection.getConnection();
    await DatabaseConnection.execute('''
      CREATE TABLE IF NOT EXISTS certificate_content_templates (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        certificate_type VARCHAR(50) NOT NULL,
        role VARCHAR(100) NOT NULL,
        designation VARCHAR(100),
        body_content TEXT NOT NULL,
        template_name VARCHAR(200) NOT NULL,
        is_default BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        created_by VARCHAR(100) DEFAULT 'admin',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_by VARCHAR(100),
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    print('table created');

    await DatabaseConnection.execute(
      'CREATE INDEX IF NOT EXISTS idx_cert_content_type_role ON certificate_content_templates (certificate_type, role)',
    );
    await DatabaseConnection.execute(
      'CREATE INDEX IF NOT EXISTS idx_cert_content_type_role_desg ON certificate_content_templates (certificate_type, role, designation)',
    );
    print('indexes created');

    await DatabaseConnection.execute(
      'DROP TRIGGER IF EXISTS trigger_update_certificate_content_templates_updated_at ON certificate_content_templates',
    );

    await DatabaseConnection.execute('''
      CREATE TRIGGER trigger_update_certificate_content_templates_updated_at
          BEFORE UPDATE ON certificate_content_templates
          FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
    ''');
    print('Migration successful: certificate_content_templates table created.');
  } catch (e) {
    print('Error running migration: $e');
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
