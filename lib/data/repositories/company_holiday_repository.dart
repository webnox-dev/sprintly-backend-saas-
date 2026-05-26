import '../../domain/models/company_holiday.dart';
import '../database/connection.dart';

class CompanyHolidayRepository {
  /// Get all holidays with server-side search, filter, and pagination
  Future<(List<CompanyHoliday>, int)> getAllHolidays({
    String? search,
    String? filterType, // 'all', 'single_day', 'multi_day'
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Build WHERE clauses
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    // Search filter
    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(holiday_name) LIKE @search OR LOWER(holiday_remarks) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    // Type filter
    if (filterType != null && filterType != 'all') {
      if (filterType == 'single_day') {
        whereClauses.add("(to_date IS NULL OR to_date = from_date)");
      } else if (filterType == 'multi_day') {
        whereClauses.add("(to_date IS NOT NULL AND to_date != from_date)");
      }
    }

    // Date range filter
    if (startDate != null) {
      whereClauses.add("from_date >= @startDate");
      values['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add(
        "(to_date <= @endDate OR (to_date IS NULL AND from_date <= @endDate))",
      );
      values['endDate'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Sorting
    final validSortColumns = [
      'holiday_name',
      'from_date',
      'to_date',
      'total_days',
      'created_at',
    ];
    final sortColumn = validSortColumns.contains(sortBy) ? sortBy : 'from_date';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM company_holidays $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    // Get paginated results
    final result = await DatabaseConnection.query('''
      SELECT * FROM company_holidays 
      $whereClause 
      ORDER BY $sortColumn $order 
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final holidays = result.map((row) => CompanyHoliday.fromJson(row)).toList();
    return (holidays, totalCount);
  }

  Future<CompanyHoliday?> getHolidayById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM company_holidays WHERE holiday_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return CompanyHoliday.fromJson(result.first);
  }

  Future<CompanyHoliday> createHoliday(CompanyHoliday holiday) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO company_holidays (
        holiday_name, from_date, to_date, total_days, holiday_remarks, 
        is_optional, created_by
      ) VALUES (
        @name, @fromDate, @toDate, @totalDays, @remarks, 
        @isOptional, @createdBy
      ) RETURNING *
      ''',
      values: {
        'name': holiday.holidayName,
        'fromDate': holiday.fromDate,
        'toDate': holiday.toDate,
        'totalDays': holiday.totalDays,
        'remarks': holiday.holidayRemarks,
        'isOptional': holiday.isOptional,
        'createdBy': holiday.createdBy,
      },
    );
    return CompanyHoliday.fromJson(result.first);
  }

  Future<CompanyHoliday?> updateHoliday(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      // Exclude generic fields that shouldn't be updated manually via this map
      if (key != 'holiday_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getHolidayById(id);

    final query =
        '''
      UPDATE company_holidays 
      SET ${setClauses.join(', ')} 
      WHERE holiday_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return CompanyHoliday.fromJson(result.first);
  }

  Future<bool> deleteHoliday(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM company_holidays WHERE holiday_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
