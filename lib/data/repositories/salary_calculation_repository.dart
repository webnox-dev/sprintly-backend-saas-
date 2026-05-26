import 'package:postgres/postgres.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/salary_range.dart';

class SalaryCalculationRepository {
  final AppLogger _logger = AppLogger('SalaryCalculationRepository');

  /// Fetch all active salary ranges with components
  Future<List<SalaryRange>> getAllRanges() async {
    try {
      final sql =
          'SELECT * FROM salary_ranges WHERE is_active = true ORDER BY salary_start ASC';
      final results = await DatabaseConnection.query(sql);

      if (results.isEmpty) return [];

      final ranges = results.map((row) => SalaryRange.fromMap(row)).toList();
      final rangeIds = ranges.map((r) => r.id).toList();

      // Fetch components
      final placeholders = List.generate(
        rangeIds.length,
        (i) => '@id$i',
      ).join(', ');
      final compSql =
          'SELECT * FROM salary_components WHERE is_active = true AND salary_range_id IN ($placeholders) ORDER BY sort_order ASC';

      final values = <String, dynamic>{};
      for (int i = 0; i < rangeIds.length; i++) {
        values['id$i'] = rangeIds[i];
      }

      final compResults = await DatabaseConnection.query(
        compSql,
        values: values,
      );

      for (int i = 0; i < ranges.length; i++) {
        final rId = ranges[i].id;
        final earningsStrList = compResults
            .where(
              (c) =>
                  c['salary_range_id'] == rId &&
                  c['component_type'] == 'earning',
            )
            .toList();
        final deductionsStrList = compResults
            .where(
              (c) =>
                  c['salary_range_id'] == rId &&
                  c['component_type'] == 'deduction',
            )
            .toList();

        // Use copyWith if it existed, or we can mutate our map creation slightly
        // Since SalaryRange.fromMap takes nested maps if we build it:
        ranges[i] = SalaryRange.fromMap({
          ...results[i],
          'earnings': earningsStrList,
          'deductions': deductionsStrList,
        });
      }

      return ranges;
    } catch (e, stackTrace) {
      _logger.error('Error fetching salary ranges: $e', e, stackTrace);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch salary ranges',
      );
    }
  }

  /// Get single range by ID
  Future<SalaryRange?> getRangeById(String id) async {
    try {
      final sql = 'SELECT * FROM salary_ranges WHERE id = @id';
      final result = await DatabaseConnection.queryOne(sql, values: {'id': id});

      if (result == null) return null;

      final compSql =
          'SELECT * FROM salary_components WHERE is_active = true AND salary_range_id = @id ORDER BY sort_order ASC';
      final compResults = await DatabaseConnection.query(
        compSql,
        values: {'id': id},
      );

      return SalaryRange.fromMap({
        ...result,
        'earnings': compResults
            .where((c) => c['component_type'] == 'earning')
            .toList(),
        'deductions': compResults
            .where((c) => c['component_type'] == 'deduction')
            .toList(),
      });
    } catch (e, stackTrace) {
      _logger.error('Error fetching salary range by ID: $e', e, stackTrace);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch salary range',
      );
    }
  }

  /// Create a new salary range
  Future<dynamic> createRange(Map<String, dynamic> data) async {
    try {
      final sql = '''
        INSERT INTO salary_ranges (range_name, salary_start, salary_end, is_active, created_by, updated_by)
        VALUES (@range_name, @salary_start, @salary_end, @is_active, @created_by, @created_by)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'range_name': data['range_name'],
          'salary_start': data['salary_start'],
          'salary_end': data['salary_end'],
          'is_active': data['is_active'] ?? true,
          'created_by': data['created_by'] ?? 'admin',
        },
      );

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error creating salary range: $e', e, stackTrace);
      throw AppException(
        code: 'CREATE_ERROR',
        message: 'Failed to create salary range',
      );
    }
  }

  /// Update salary range
  Future<dynamic> updateRange(String id, Map<String, dynamic> data) async {
    try {
      final sql = '''
        UPDATE salary_ranges SET
          range_name = @range_name,
          salary_start = @salary_start,
          salary_end = @salary_end,
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
          'range_name': data['range_name'],
          'salary_start': data['salary_start'],
          'salary_end': data['salary_end'],
          'is_active': data['is_active'] ?? true,
          'updated_by': data['updated_by'] ?? 'admin',
        },
      );

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error updating salary range: $e', e, stackTrace);
      throw AppException(
        code: 'UPDATE_ERROR',
        message: 'Failed to update salary range',
      );
    }
  }

  /// Delete salary range (cascades to components due to FK constraint)
  Future<void> deleteRange(String id) async {
    try {
      final sql = 'DELETE FROM salary_ranges WHERE id = @id';
      await DatabaseConnection.execute(sql, values: {'id': id});
    } catch (e, stackTrace) {
      _logger.error('Error deleting salary range: $e', e, stackTrace);
      throw AppException(
        code: 'DELETE_ERROR',
        message: 'Failed to delete salary range',
      );
    }
  }

  /// Replace all components for a given salary range
  Future<void> saveComponents(String rangeId, List<dynamic> components) async {
    try {
      await DatabaseConnection.transaction((conn) async {
        // 1. Delete existing
        final deleteSql =
            'DELETE FROM salary_components WHERE salary_range_id = @id';
        await conn.execute(Sql.named(deleteSql), parameters: {'id': rangeId});

        // 2. Insert new ones
        if (components.isNotEmpty) {
          final insertSql = '''
            INSERT INTO salary_components (salary_range_id, component_type, component_name, percentage, calculated_amount, sort_order)
            VALUES (@salary_range_id, @component_type, @component_name, @percentage, @calculated_amount, @sort_order)
          ''';

          for (var idx = 0; idx < components.length; idx++) {
            final c = components[idx];
            await conn.execute(
              Sql.named(insertSql),
              parameters: {
                'salary_range_id': rangeId,
                'component_type': c['component_type'],
                'component_name': c['component_name'],
                'percentage': c['percentage'],
                'calculated_amount': c['calculated_amount'],
                'sort_order': c['sort_order'] ?? idx,
              },
            );
          }
        }
      });
    } catch (e, stackTrace) {
      _logger.error('Error saving salary components: $e', e, stackTrace);
      throw AppException(
        code: 'COMPONENTS_ERROR',
        message: 'Failed to save salary components',
      );
    }
  }
}
