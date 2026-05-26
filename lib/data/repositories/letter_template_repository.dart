import 'dart:convert';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/letter_template.dart';

class LetterTemplateRepository {
  final AppLogger _logger = AppLogger('LetterTemplateRepository');

  /// Fetch all templates, optionally filtered by type
  Future<List<LetterTemplate>> getAllTemplates([String? templateType]) async {
    try {
      String sql = 'SELECT * FROM letter_templates WHERE is_active = true';
      Map<String, dynamic>? values;

      if (templateType != null && templateType.isNotEmpty) {
        sql += ' AND template_type = @template_type';
        values = {'template_type': templateType};
      }

      sql += ' ORDER BY template_type ASC, is_default DESC, template_name ASC';

      final results = await DatabaseConnection.query(sql, values: values);
      return results.map((row) => LetterTemplate.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error fetching letter templates: $e', e, stackTrace);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch letter templates',
      );
    }
  }

  /// Get single template by ID
  Future<LetterTemplate?> getTemplateById(String id) async {
    try {
      final sql = 'SELECT * FROM letter_templates WHERE id = @id';
      final result = await DatabaseConnection.queryOne(sql, values: {'id': id});

      if (result == null) return null;
      return LetterTemplate.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error fetching letter template by ID: $e', e, stackTrace);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch letter template',
      );
    }
  }

  /// Get default template by type
  Future<LetterTemplate?> getDefaultTemplate(String type) async {
    try {
      final sql =
          'SELECT * FROM letter_templates WHERE template_type = @type AND is_default = true AND is_active = true';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'type': type},
      );

      if (result == null) return null;
      return LetterTemplate.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error fetching default template: $e', e, stackTrace);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch default template',
      );
    }
  }

  /// Create a new template
  Future<LetterTemplate> createTemplate(Map<String, dynamic> data) async {
    try {
      // If setting as default, clear other defaults for this type
      if (data['is_default'] == true) {
        await _clearDefaultFlags(data['template_type']);
      }

      final sql = '''
        INSERT INTO letter_templates (
          template_type, template_name, header_config, footer_config,
          watermark_config, body_content, placeholders, is_default, is_active, created_by
        )
        VALUES (
          @template_type, @template_name, @header_config, @footer_config,
          @watermark_config, @body_content, @placeholders, @is_default, @is_active, @created_by
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'template_type': data['template_type'],
          'template_name': data['template_name'],
          'header_config': jsonEncode(data['header_config'] ?? {}),
          'footer_config': jsonEncode(data['footer_config'] ?? {}),
          'watermark_config': jsonEncode(data['watermark_config'] ?? {}),
          'body_content': data['body_content'],
          'placeholders': jsonEncode(data['placeholders'] ?? []),
          'is_default': data['is_default'] ?? false,
          'is_active': data['is_active'] ?? true,
          'created_by': data['created_by'] ?? 'admin',
        },
      );

      return LetterTemplate.fromMap(result!);
    } catch (e, stackTrace) {
      _logger.error('Error creating letter template: $e', e, stackTrace);
      throw AppException(
        code: 'CREATE_ERROR',
        message: 'Failed to create letter template',
      );
    }
  }

  /// Update template
  Future<LetterTemplate> updateTemplate(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      // If setting as default, clear other defaults for this type
      if (data['is_default'] == true) {
        await _clearDefaultFlags(data['template_type']);
      }

      final sql = '''
        UPDATE letter_templates SET
          template_type = @template_type,
          template_name = @template_name,
          header_config = @header_config,
          footer_config = @footer_config,
          watermark_config = @watermark_config,
          body_content = @body_content,
          placeholders = @placeholders,
          is_default = @is_default,
          is_active = @is_active,
          updated_by = @updated_by,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': id,
          'template_type': data['template_type'],
          'template_name': data['template_name'],
          'header_config': jsonEncode(data['header_config'] ?? {}),
          'footer_config': jsonEncode(data['footer_config'] ?? {}),
          'watermark_config': jsonEncode(data['watermark_config'] ?? {}),
          'body_content': data['body_content'],
          'placeholders': jsonEncode(data['placeholders'] ?? []),
          'is_default': data['is_default'] ?? false,
          'is_active': data['is_active'] ?? true,
          'updated_by': data['updated_by'] ?? 'admin',
        },
      );

      return LetterTemplate.fromMap(result!);
    } catch (e, stackTrace) {
      _logger.error('Error updating letter template: $e', e, stackTrace);
      throw AppException(
        code: 'UPDATE_ERROR',
        message: 'Failed to update letter template',
      );
    }
  }

  /// Delete template
  Future<void> deleteTemplate(String id) async {
    try {
      final sql = 'DELETE FROM letter_templates WHERE id = @id';
      await DatabaseConnection.execute(sql, values: {'id': id});
    } catch (e, stackTrace) {
      _logger.error('Error deleting letter template: $e', e, stackTrace);
      throw AppException(
        code: 'DELETE_ERROR',
        message: 'Failed to delete letter template',
      );
    }
  }

  /// Clears the is_default flag for all templates of a given type
  Future<void> _clearDefaultFlags(String templateType) async {
    final sql =
        'UPDATE letter_templates SET is_default = false WHERE template_type = @type';
    await DatabaseConnection.execute(sql, values: {'type': templateType});
  }
}
