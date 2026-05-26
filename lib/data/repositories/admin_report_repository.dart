import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Repository for admin-side employee reports management
class AdminReportRepository {
  final AppLogger _logger = AppLogger('AdminReportRepository');

  /// Get all employee reports for a specific date with comprehensive details
  /// Includes both reported and not-reported employees
  /// Calculates working hours analysis (less than / more than 9 hours)
  Future<Map<String, dynamic>> getAllEmployeeReports({
    String? search,
    String? employeeId,
    String? employeeName,
    String? designation,
    String? date,
    String? fromDate,
    String? toDate,
    String? status, // 'reported' or 'not_reported' or null for all
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      // Date is required - default to today if not provided
      final reportDate = date ?? DateTime.now().toIso8601String().split('T')[0];

      final offset = (page - 1) * limit;
      final conditions = <String>['e.status = 1']; // Only active employees
      final values = <String, dynamic>{
        'date': reportDate,
        'limit': limit,
        'offset': offset,
      };

      // Build WHERE conditions for employee filters
      if (search != null && search.isNotEmpty) {
        conditions.add('''
          (e.employee_name ILIKE @search 
           OR e.employee_id ILIKE @search
           OR e.employee_designation ILIKE @search
           OR e.employee_personal_email ILIKE @search)
        ''');
        values['search'] = '%$search%';
      }

      if (employeeId != null && employeeId.isNotEmpty) {
        conditions.add('e.employee_id = @employeeId');
        values['employeeId'] = employeeId;
      }

      if (employeeName != null && employeeName.isNotEmpty) {
        conditions.add('e.employee_name ILIKE @employeeName');
        values['employeeName'] = '%$employeeName%';
      }

      if (designation != null && designation.isNotEmpty) {
        conditions.add('e.employee_designation ILIKE @designation');
        values['designation'] = '%$designation%';
      }

      final whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(' AND ')}'
          : '';

      // Status filter (reported / not_reported)
      String havingClause = '';
      if (status == 'reported') {
        havingClause = 'HAVING COUNT(r.report_id) > 0';
      } else if (status == 'not_reported') {
        havingClause = 'HAVING COUNT(r.report_id) = 0';
      }

      // Determine sort column
      String orderBy = 'has_reported DESC, e.employee_name ASC';
      if (sortBy != null) {
        final sortColumn = switch (sortBy.toLowerCase()) {
          'name' => 'e.employee_name',
          'date' => 'r.report_date',
          'designation' => 'e.employee_designation',
          'clock_on' => 'r.clock_on_for_the_day',
          'clock_off' => 'r.clock_off_for_the_day',
          'hours' => 'r.total_working_hrs',
          _ => 'has_reported DESC, e.employee_name',
        };
        final order = (sortOrder?.toUpperCase() == 'ASC') ? 'ASC' : 'DESC';
        orderBy = '$sortColumn $order';
      }

      // Main query: Get ALL employees with their report status for the date
      // Uses LEFT JOIN to include employees who haven't reported
      final sql =
          '''
        SELECT 
          e.employee_id,
          e.employee_name,
          e.employee_role,
          e.employee_designation,
          e.employee_img,
          e.employee_personal_email,
          e.employee_company_email,
          e.employee_phone_num,
          r.report_id,
          r.report_date,
          r.work_type,
          r.total_tasks_count,
          r.total_working_hrs,
          r.clock_on_for_the_day,
          r.clock_off_for_the_day,
          r.created_at as reported_time,
          r.updated_at,
          CASE WHEN r.report_id IS NOT NULL THEN true ELSE false END as has_reported,
          -- Calculate working hours difference from 9 hours (540 minutes)
          CASE 
            WHEN r.clock_on_for_the_day IS NOT NULL AND r.clock_off_for_the_day IS NOT NULL THEN
              EXTRACT(EPOCH FROM (r.clock_off_for_the_day - r.clock_on_for_the_day)) / 60
            ELSE NULL
          END as working_minutes
        FROM employees e
        LEFT JOIN employee_reports r ON e.employee_id = r.employee_id AND r.report_date = @date
        $whereClause
        GROUP BY e.employee_id, e.employee_name, e.employee_role, e.employee_designation,
                 e.employee_img, e.employee_personal_email, e.employee_company_email,
                 e.employee_phone_num, r.report_id, r.report_date, r.work_type,
                 r.total_tasks_count, r.total_working_hrs, r.clock_on_for_the_day,
                 r.clock_off_for_the_day, r.created_at, r.updated_at
        $havingClause
        ORDER BY $orderBy
        LIMIT @limit OFFSET @offset
      ''';

      final results = await DatabaseConnection.query(sql, values: values);

      // Count queries for summary
      final reportedCountSql = '''
        SELECT COUNT(DISTINCT e.employee_id) as count
        FROM employees e
        INNER JOIN employee_reports r ON e.employee_id = r.employee_id AND r.report_date = @date
        WHERE e.status = 1
      ''';

      final totalActiveCountSql = '''
        SELECT COUNT(*) as count FROM employees WHERE status = 1
      ''';

      final reportedResult = await DatabaseConnection.queryOne(
        reportedCountSql,
        values: {'date': reportDate},
      );
      final totalActiveResult = await DatabaseConnection.queryOne(
        totalActiveCountSql,
        values: {},
      );

      final reportedCount = (reportedResult?['count'] as int?) ?? 0;
      final totalActive = (totalActiveResult?['count'] as int?) ?? 0;
      final notReportedCount = totalActive - reportedCount;

      // Calculate total for pagination based on filter
      int total;
      if (status == 'reported') {
        total = reportedCount;
      } else if (status == 'not_reported') {
        total = notReportedCount;
      } else {
        total = totalActive;
      }
      final totalPages = total > 0 ? (total / limit).ceil() : 0;

      // Format results with hours analysis
      final reports = results.map((row) {
        final hasReported =
            row['has_reported'] == true || row['report_id'] != null;
        final workingMinutes = row['working_minutes'] as num?;

        // Calculate hours analysis
        String? hoursAnalysis;
        int? differenceMinutes;

        if (hasReported && workingMinutes != null) {
          final standardMinutes = 9 * 60; // 9 hours in minutes
          final diff = workingMinutes.toInt() - standardMinutes;
          differenceMinutes = diff.abs();

          final diffHours = differenceMinutes ~/ 60;
          final diffMins = differenceMinutes % 60;
          final formattedDiff = diffHours > 0
              ? '$diffHours hr${diffHours > 1 ? 's' : ''} $diffMins min${diffMins != 1 ? 's' : ''}'
              : '$diffMins min${diffMins != 1 ? 's' : ''}';

          if (diff < 0) {
            hoursAnalysis = 'Less than 9 hours (short by $formattedDiff)';
          } else if (diff > 0) {
            hoursAnalysis = 'More than 9 hours (excess by $formattedDiff)';
          } else {
            hoursAnalysis = 'Exactly 9 hours';
          }
        } else if (hasReported) {
          hoursAnalysis = 'Hours not calculated (missing clock data)';
        }

        return {
          'report_id': row['report_id']?.toString(),
          'report_date': reportDate,
          'has_reported': hasReported,
          // Employee details
          'employee_id': row['employee_id']?.toString(),
          'employee_name': row['employee_name']?.toString(),
          'employee_role': row['employee_role']?.toString(),
          'employee_designation': row['employee_designation']?.toString(),
          'employee_img': row['employee_img']?.toString(),
          'employee_email':
              row['employee_personal_email']?.toString() ??
              row['employee_company_email']?.toString(),
          'employee_phone': row['employee_phone_num']?.toString(),
          // Report details (null if not reported)
          'work_type':
              row['work_type']?.toString() ?? (hasReported ? 'Office' : null),
          'total_tasks_count': row['total_tasks_count'],
          'total_working_hrs': row['total_working_hrs']?.toString(),
          'clock_on_for_the_day': row['clock_on_for_the_day']?.toString(),
          'clock_off_for_the_day': row['clock_off_for_the_day']?.toString(),
          'reported_time': row['reported_time']?.toString(),
          'updated_at': row['updated_at']?.toString(),
          // Hours analysis
          'working_minutes': workingMinutes?.toInt(),
          'hours_analysis': hoursAnalysis,
          'hours_difference_minutes': differenceMinutes,
        };
      }).toList();

      return {
        'reports': reports,
        'summary': {
          'date': reportDate,
          'total_active_employees': totalActive,
          'reported_count': reportedCount,
          'not_reported_count': notReportedCount,
          'reported_percentage': totalActive > 0
              ? ((reportedCount / totalActive) * 100).toStringAsFixed(1)
              : '0.0',
        },
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': totalPages,
          'hasNext': page < totalPages,
          'hasPrev': page > 1,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching employee reports: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees who reported/not reported on a specific date
  /// This compares all active employees against reports for the given date
  Future<Map<String, dynamic>> getEmployeeReportStatus({
    required String date,
    String? search,
    String? designation,
    String? status, // 'reported', 'not_reported', or null for all
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final values = <String, dynamic>{
        'date': date,
        'limit': limit,
        'offset': offset,
      };
      final conditions = <String>['e.status = 1']; // Only active employees

      if (search != null && search.isNotEmpty) {
        conditions.add('''
          (e.employee_name ILIKE @search 
           OR e.employee_id ILIKE @search
           OR e.employee_designation ILIKE @search)
        ''');
        values['search'] = '%$search%';
      }

      if (designation != null && designation.isNotEmpty) {
        conditions.add('e.employee_designation ILIKE @designation');
        values['designation'] = '%$designation%';
      }

      final whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(' AND ')}'
          : '';

      // Status filter logic
      String havingClause = '';
      if (status == 'reported') {
        havingClause = 'HAVING COUNT(r.report_id) > 0';
      } else if (status == 'not_reported') {
        havingClause = 'HAVING COUNT(r.report_id) = 0';
      }

      // Query to get employees with their report status for the date
      final sql =
          '''
        SELECT 
          e.employee_id,
          e.employee_name,
          e.employee_role,
          e.employee_designation,
          e.employee_img,
          e.employee_personal_email,
          e.employee_company_email,
          e.employee_phone_num,
          r.report_id,
          r.report_date,
          r.work_type,
          r.total_tasks_count,
          r.total_working_hrs,
          r.clock_on_for_the_day,
          r.clock_off_for_the_day,
          CASE WHEN r.report_id IS NOT NULL THEN true ELSE false END as has_reported
        FROM employees e
        LEFT JOIN employee_reports r ON e.employee_id = r.employee_id AND r.report_date = @date
        $whereClause
        GROUP BY e.employee_id, e.employee_name, e.employee_role, e.employee_designation,
                 e.employee_img, e.employee_personal_email, e.employee_company_email,
                 e.employee_phone_num, r.report_id, r.report_date, r.work_type,
                 r.total_tasks_count, r.total_working_hrs, r.clock_on_for_the_day,
                 r.clock_off_for_the_day
        $havingClause
        ORDER BY has_reported DESC, e.employee_name ASC
        LIMIT @limit OFFSET @offset
      ''';

      final results = await DatabaseConnection.query(sql, values: values);

      // Count queries
      final reportedCountSql = '''
        SELECT COUNT(DISTINCT e.employee_id) as count
        FROM employees e
        INNER JOIN employee_reports r ON e.employee_id = r.employee_id AND r.report_date = @date
        WHERE e.status = 1
      ''';

      final totalActiveCountSql = '''
        SELECT COUNT(*) as count FROM employees WHERE status = 1
      ''';

      final reportedResult = await DatabaseConnection.queryOne(
        reportedCountSql,
        values: {'date': date},
      );
      final totalActiveResult = await DatabaseConnection.queryOne(
        totalActiveCountSql,
        values: {},
      );

      final reportedCount = (reportedResult?['count'] as int?) ?? 0;
      final totalActive = (totalActiveResult?['count'] as int?) ?? 0;
      final notReportedCount = totalActive - reportedCount;

      // Calculate total for pagination based on filter
      int total;
      if (status == 'reported') {
        total = reportedCount;
      } else if (status == 'not_reported') {
        total = notReportedCount;
      } else {
        total = totalActive;
      }
      final totalPages = (total / limit).ceil();

      // Format results
      final employees = results.map((row) {
        final hasReported =
            row['has_reported'] == true || row['report_id'] != null;
        return {
          'employee_id': row['employee_id']?.toString(),
          'employee_name': row['employee_name']?.toString(),
          'employee_role': row['employee_role']?.toString(),
          'employee_designation': row['employee_designation']?.toString(),
          'employee_img': row['employee_img']?.toString(),
          'employee_email':
              row['employee_personal_email']?.toString() ??
              row['employee_company_email']?.toString(),
          'employee_phone': row['employee_phone_num']?.toString(),
          'has_reported': hasReported,
          'report_date': date,
          // Report details (null if not reported)
          'report_id': row['report_id']?.toString(),
          'work_type':
              row['work_type']?.toString() ?? (hasReported ? 'Office' : null),
          'total_tasks_count': row['total_tasks_count'],
          'total_working_hrs': row['total_working_hrs']?.toString(),
          'clock_on_for_the_day': row['clock_on_for_the_day']?.toString(),
          'clock_off_for_the_day': row['clock_off_for_the_day']?.toString(),
        };
      }).toList();

      return {
        'employees': employees,
        'summary': {
          'date': date,
          'total_active_employees': totalActive,
          'reported_count': reportedCount,
          'not_reported_count': notReportedCount,
        },
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': totalPages,
          'hasNext': page < totalPages,
          'hasPrev': page > 1,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching employee report status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Debug method to fetch raw employee_reports data
  Future<Map<String, dynamic>> getDebugReportsData() async {
    try {
      final sql = '''
        SELECT 
          r.report_id,
          r.report_date,
          r.employee_id,
          r.work_type,
          r.total_tasks_count,
          r.total_working_hrs,
          r.clock_on_for_the_day,
          r.clock_off_for_the_day,
          r.created_at,
          e.employee_name
        FROM employee_reports r
        LEFT JOIN employees e ON r.employee_id = e.employee_id
        ORDER BY r.report_date DESC, r.created_at DESC
        LIMIT 20
      ''';

      final results = await DatabaseConnection.query(sql, values: {});

      final reports = results.map((row) {
        return {
          'report_id': row['report_id']?.toString(),
          'report_date': row['report_date']?.toString(),
          'employee_id': row['employee_id']?.toString(),
          'employee_name': row['employee_name']?.toString(),
          'work_type': row['work_type']?.toString(),
          'total_tasks_count': row['total_tasks_count'],
          'total_working_hrs': row['total_working_hrs']?.toString(),
          'clock_on_for_the_day': row['clock_on_for_the_day']?.toString(),
          'clock_off_for_the_day': row['clock_off_for_the_day']?.toString(),
          'created_at': row['created_at']?.toString(),
        };
      }).toList();

      // Get count
      final countResult = await DatabaseConnection.queryOne(
        'SELECT COUNT(*) as count FROM employee_reports',
        values: {},
      );

      // Get distinct dates
      final datesResult = await DatabaseConnection.query(
        'SELECT DISTINCT report_date FROM employee_reports ORDER BY report_date DESC LIMIT 10',
        values: {},
      );

      return {
        'total_records': countResult?['count'] ?? 0,
        'available_dates': datesResult
            .map((r) => r['report_date']?.toString())
            .toList(),
        'recent_reports': reports,
      };
    } catch (e, stackTrace) {
      _logger.error('Error in debug: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get detailed report for a specific employee and date
  Future<Map<String, dynamic>?> getReportDetailsById({
    required String employeeId,
    required String reportId,
    required String date,
  }) async {
    try {
      final sql = '''
        SELECT 
          r.report_id,
          r.report_date,
          r.employee_id,
          r.work_type,
          r.total_tasks_count,
          r.total_working_hrs,
          r.clock_on_for_the_day,
          r.clock_off_for_the_day,
          r.task_details,
          r.created_at,
          r.updated_at,
          e.employee_name,
          e.employee_role,
          e.employee_designation,
          e.employee_img,
          e.employee_personal_email,
          e.employee_company_email,
          e.employee_phone_num
        FROM employee_reports r
        LEFT JOIN employees e ON r.employee_id = e.employee_id
        WHERE r.report_id = @reportId 
          AND r.employee_id = @employeeId 
          AND r.report_date = @date
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'reportId': reportId, 'employeeId': employeeId, 'date': date},
      );

      if (result == null) return null;

      final taskDetails = result['task_details'];

      return {
        'report_id': result['report_id']?.toString(),
        'report_date': result['report_date']?.toString(),
        'employee_id': result['employee_id']?.toString(),
        'work_type': result['work_type']?.toString(),
        'total_tasks_count': result['total_tasks_count'],
        'total_working_hrs': result['total_working_hrs']?.toString(),
        'clock_on_for_the_day': result['clock_on_for_the_day']?.toString(),
        'clock_off_for_the_day': result['clock_off_for_the_day']?.toString(),
        'task_details': taskDetails,
        'created_at': result['created_at']?.toString(),
        'updated_at': result['updated_at']?.toString(),
        // Employee Details
        'employee': {
          'name': result['employee_name']?.toString(),
          'role': result['employee_role']?.toString(),
          'designation': result['employee_designation']?.toString(),
          'img': result['employee_img']?.toString(),
          'email':
              result['employee_personal_email']?.toString() ??
              result['employee_company_email']?.toString(),
          'phone': result['employee_phone_num']?.toString(),
        },
      };
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching details for report $reportId: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
