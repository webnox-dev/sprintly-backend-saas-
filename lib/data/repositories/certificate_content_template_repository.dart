import '../database/connection.dart';
import '../../domain/models/certificate_content_template.dart';

class CertificateContentTemplateRepository {
  static const String tableName = 'certificate_content_templates';

  Future<List<CertificateContentTemplate>> getAllTemplates({
    String? certificateType,
    String? role,
    String? designation,
  }) async {
    final conditions = ['is_active = true'];
    final params = <String, dynamic>{};

    if (certificateType != null && certificateType.isNotEmpty) {
      conditions.add(
        "LOWER(REPLACE(TRIM(certificate_type), '_', ' ')) = LOWER(REPLACE(TRIM(@certificateType), '_', ' '))",
      );
      params['certificateType'] = certificateType;
    }

    if (role != null && role.isNotEmpty) {
      conditions.add("LOWER(TRIM(role)) = LOWER(TRIM(@role))");
      params['role'] = role;
    }

    if (designation != null && designation.isNotEmpty) {
      conditions.add("LOWER(TRIM(designation)) = LOWER(TRIM(@designation))");
      params['designation'] = designation;
    }

    final query =
        '''
      SELECT * FROM $tableName
      ${conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : ''}
      ORDER BY created_at DESC
    ''';

    final result = await DatabaseConnection.query(query, values: params);
    return result
        .map((row) => CertificateContentTemplate.fromMap(row))
        .toList();
  }

  Future<CertificateContentTemplate?> getTemplateById(String id) async {
    final query =
        'SELECT * FROM $tableName WHERE id = @id AND is_active = true LIMIT 1';
    final result = await DatabaseConnection.query(query, values: {'id': id});

    if (result.isEmpty) return null;
    return CertificateContentTemplate.fromMap(result.first);
  }

  Future<CertificateContentTemplate?> findBestMatch(
    String certificateType,
    String role,
    String? designation,
  ) async {
    // 1. Exact match (type + role + designation)
    if (designation != null && designation.isNotEmpty && designation != 'All') {
      final exactQuery =
          '''
        SELECT * FROM $tableName 
        WHERE LOWER(REPLACE(TRIM(certificate_type), '_', ' ')) = LOWER(REPLACE(TRIM(@type), '_', ' '))
          AND LOWER(TRIM(role)) = LOWER(TRIM(@role))
          AND LOWER(TRIM(designation)) = LOWER(TRIM(@designation))
          AND is_active = true 
        ORDER BY is_default DESC, created_at DESC 
        LIMIT 1
      ''';

      final exactResult = await DatabaseConnection.query(
        exactQuery,
        values: {
          'type': certificateType,
          'role': role,
          'designation': designation,
        },
      );

      if (exactResult.isNotEmpty) {
        return CertificateContentTemplate.fromMap(exactResult.first);
      }
    }

    // 2. Role-only match (type + role + designation is null/empty/All)
    final roleQuery =
        '''
      SELECT * FROM $tableName 
      WHERE LOWER(REPLACE(TRIM(certificate_type), '_', ' ')) = LOWER(REPLACE(TRIM(@type), '_', ' '))
        AND LOWER(TRIM(role)) = LOWER(TRIM(@role))
        AND (designation IS NULL OR TRIM(designation) = '' OR LOWER(TRIM(designation)) = 'all') 
        AND is_active = true 
      ORDER BY is_default DESC, created_at DESC 
      LIMIT 1
    ''';

    final roleResult = await DatabaseConnection.query(
      roleQuery,
      values: {'type': certificateType, 'role': role},
    );

    if (roleResult.isNotEmpty) {
      return CertificateContentTemplate.fromMap(roleResult.first);
    }

    // 3. Type-only/Generic match (role is null/empty/All)
    final typeQuery =
        '''
      SELECT * FROM $tableName 
      WHERE LOWER(REPLACE(TRIM(certificate_type), '_', ' ')) = LOWER(REPLACE(TRIM(@type), '_', ' '))
        AND (role IS NULL OR TRIM(role) = '' OR LOWER(TRIM(role)) = 'all')
        AND is_active = true 
      ORDER BY is_default DESC, created_at DESC 
      LIMIT 1
    ''';

    final typeResult = await DatabaseConnection.query(
      typeQuery,
      values: {'type': certificateType},
    );

    if (typeResult.isNotEmpty) {
      return CertificateContentTemplate.fromMap(typeResult.first);
    }

    // 4. No match found
    return null;
  }

  Future<CertificateContentTemplate?> createTemplate(
    CertificateContentTemplate template,
  ) async {
    final query =
        '''
      INSERT INTO $tableName (
        certificate_type, role, designation, body_content, template_name, 
        is_default, is_active, created_by, updated_by
      ) VALUES (
        @certificateType, @role, @designation, @bodyContent, @templateName, 
        @isDefault, @isActive, @createdBy, @updatedBy
      ) RETURNING *
    ''';

    final params = {
      'certificateType': template.certificateType,
      'role': template.role,
      'designation': template.designation,
      'bodyContent': template.bodyContent,
      'templateName': template.templateName,
      'isDefault': template.isDefault,
      'isActive': template.isActive,
      'createdBy': template.createdBy ?? 'system',
      'updatedBy': template.createdBy ?? 'system',
    };

    final result = await DatabaseConnection.query(query, values: params);
    if (result.isEmpty) return null;
    return CertificateContentTemplate.fromMap(result.first);
  }

  Future<CertificateContentTemplate?> updateTemplate(
    String id,
    CertificateContentTemplate template,
  ) async {
    final query =
        '''
      UPDATE $tableName SET
        certificate_type = @certificateType,
        role = @role,
        designation = @designation,
        body_content = @bodyContent,
        template_name = @templateName,
        is_default = @isDefault,
        is_active = @isActive,
        updated_by = @updatedBy,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = @id
      RETURNING *
    ''';

    final params = {
      'id': id,
      'certificateType': template.certificateType,
      'role': template.role,
      'designation': template.designation,
      'bodyContent': template.bodyContent,
      'templateName': template.templateName,
      'isDefault': template.isDefault,
      'isActive': template.isActive,
      'updatedBy': template.updatedBy ?? 'system',
    };

    final result = await DatabaseConnection.query(query, values: params);
    if (result.isEmpty) return null;
    return CertificateContentTemplate.fromMap(result.first);
  }

  Future<bool> deleteTemplate(String id) async {
    // For safety, we can do hard delete or soft delete. Opting for hard delete or 'is_active = false' based on typical patterns. Let's do hard delete to keep DB clean, since it's an admin operation. But let's check schema. We have is_active. Let's do soft delete if we want, or hard delete. Plan says "Hard delete". So:
    final query = 'DELETE FROM $tableName WHERE id = @id RETURNING id';
    final result = await DatabaseConnection.query(query, values: {'id': id});
    return result.isNotEmpty;
  }

  Future<List<String>> getDistinctRoles() async {
    final query =
        'SELECT DISTINCT TRIM(employee_role) as employee_role FROM employees WHERE employee_role IS NOT NULL AND TRIM(employee_role) != \'\' ORDER BY employee_role';
    final result = await DatabaseConnection.query(query);
    return result
        .map((row) => row['employee_role']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<String>> getDistinctDesignations({String? role}) async {
    String query =
        "SELECT DISTINCT TRIM(employee_designation) as employee_designation FROM employees WHERE employee_designation IS NOT NULL AND TRIM(employee_designation) != ''";
    final params = <String, dynamic>{};

    if (role != null && role.isNotEmpty) {
      query += " AND LOWER(TRIM(employee_role)) = LOWER(TRIM(@role))";
      params['role'] = role;
    }

    query += " ORDER BY employee_designation";

    final result = await DatabaseConnection.query(query, values: params);
    return result
        .map((row) => row['employee_designation']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
