import 'dart:convert';

import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Repository for Employee of the Month (EOM) data access.
/// Handles daily points rollup, monthly rankings cache, and winner history.
class EmployeeOfTheMonthRepository {
  final AppLogger _logger = AppLogger('EmployeeOfTheMonthRepository');

  // ==================== EOM POINTS CONFIG ====================

  /// Fetches the points configuration used for EOM calculations.
  /// Returns a map with keys like points_per_task_completed_on_time, etc.
  Future<Map<String, dynamic>> getPointsConfig() async {
    try {
      const sql = '''
        SELECT * FROM eom_points_config WHERE config_key = 'default' LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(sql);
      if (row == null) return {};
      return Map<String, dynamic>.from(row);
    } catch (e, stackTrace) {
      _logger.error('Error getting EOM points config: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== ACTIVE EMPLOYEES ====================

  /// Returns list of active employee IDs (status = 1) for EOM calculations.
  Future<List<String>> getActiveEmployeeIds() async {
    try {
      const sql = '''
        SELECT employee_id FROM employees WHERE status = 1
      ''';
      final rows = await DatabaseConnection.query(sql);
      return rows
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting active employee ids: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== DAILY POINTS ====================

  /// Upserts one row in employee_eom_points_daily.
  /// [breakdown] should be a Map that will be stored as JSONB.
  Future<void> upsertDailyPoints({
    required String employeeId,
    required DateTime pointsDate,
    required double taskPoints,
    required double attendancePoints,
    required Map<String, dynamic> breakdown,
  }) async {
    try {
      final dateStr = _dateToStr(pointsDate);
      final month = pointsDate.month;
      final year = pointsDate.year;
      final total = taskPoints + attendancePoints;

      const sql = '''
        INSERT INTO employee_eom_points_daily (
          employee_id, points_date, month, year,
          task_points, attendance_points, total_points, breakdown
        ) VALUES (
          @employee_id, @points_date::date, @month, @year,
          @task_points, @attendance_points, @total_points, @breakdown::jsonb
        )
        ON CONFLICT (employee_id, points_date)
        DO UPDATE SET
          task_points = EXCLUDED.task_points,
          attendance_points = EXCLUDED.attendance_points,
          total_points = EXCLUDED.total_points,
          breakdown = EXCLUDED.breakdown
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {
          'employee_id': employeeId,
          'points_date': dateStr,
          'month': month,
          'year': year,
          'task_points': taskPoints,
          'attendance_points': attendancePoints,
          'total_points': total,
          'breakdown': _encodeJson(breakdown),
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error upserting daily points: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Fetches all daily points rows for an employee in a given month/year.
  Future<List<Map<String, dynamic>>> getDailyPointsForEmployeeMonth({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    try {
      const sql = '''
        SELECT * FROM employee_eom_points_daily
        WHERE employee_id = @employee_id AND month = @month AND year = @year
        ORDER BY points_date ASC
      ''';
      final rows = await DatabaseConnection.query(
        sql,
        values: {'employee_id': employeeId, 'month': month, 'year': year},
      );
      return rows.map((r) {
        final data = Map<String, dynamic>.from(r);
        data['task_points'] = _parseNum(data['task_points']);
        data['attendance_points'] = _parseNum(data['attendance_points']);
        data['total_points'] = _parseNum(data['total_points']);
        return data;
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting daily points for employee month: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Returns aggregated total points per employee for a month (for rankings).
  /// Result: list of { employee_id, total_points }.
  Future<List<Map<String, dynamic>>> getMonthlyTotalsByEmployee({
    required int month,
    required int year,
  }) async {
    try {
      const sql = '''
        SELECT employee_id, COALESCE(SUM(total_points), 0)::numeric(10,2) as total_points
        FROM employee_eom_points_daily
        WHERE month = @month AND year = @year
        GROUP BY employee_id
        ORDER BY total_points DESC
      ''';
      final rows = await DatabaseConnection.query(
        sql,
        values: {'month': month, 'year': year},
      );
      return rows.map((r) {
        final totalPointsRaw = r['total_points'];
        return {
          'employee_id': r['employee_id'],
          'total_points': _parseNum(totalPointsRaw),
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting monthly totals: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Safely parses a numeric value from the database (handles num and String).
  num? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  // ==================== ATTENDANCE / LEAVE / PERMISSION / WFH ====================

  /// Returns attendance record for [employeeId] on [date] if any.
  /// work_date is stored as TEXT; we compare with date cast.
  Future<Map<String, dynamic>?> getAttendanceForDate({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      const sql = '''
        SELECT * FROM employee_attendance
        WHERE employee_id = @employee_id AND work_date::date = @date::date
        ORDER BY clock_on_for_the_day DESC
        LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );
      if (row == null) return null;
      final data = Map<String, dynamic>.from(row);
      // Optional: if attendance table has numeric fields we use in EOM, parse them here.
      // For now, EOM mostly uses the attendance logs for direct computation in service,
      // but let's be safe if any totals were added.
      return data;
    } catch (e, stackTrace) {
      _logger.error('Error getting attendance for date: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Returns true if employee has approved leave covering [dateStr].
  Future<bool> isOnLeave({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      const sql = '''
        SELECT 1 FROM leave_zone
        WHERE employee_id = @employee_id AND leave_status = 1
          AND @date::date BETWEEN leave_from_date AND leave_to_date
        LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );
      return row != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking leave: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Returns true if employee has approved permission on [dateStr].
  Future<bool> isOnPermission({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      const sql = '''
        SELECT 1 FROM permissions
        WHERE employee_id = @employee_id AND permission_status = 1
          AND permission_date::date = @date::date
        LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );
      return row != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking permission: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Returns true if employee has approved WFH covering [dateStr].
  Future<bool> isOnWfh({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      const sql = '''
        SELECT 1 FROM work_from_home_requests
        WHERE employee_id = @employee_id AND wfh_status = 1
          AND @date::date BETWEEN start_date AND end_date
        LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );
      return row != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking WFH: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Returns true if [dateStr] is a company holiday.
  Future<bool> isCompanyHoliday(String dateStr) async {
    try {
      const sql = '''
        SELECT 1 FROM company_holidays
        WHERE @date::date >= from_date::date
          AND (to_date IS NULL OR @date::date <= to_date::date)
        LIMIT 1
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'date': dateStr},
      );
      return row != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking company holiday: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== TASK STATS FOR A DAY ====================

  /// Returns task counts for [employeeId] for tasks that were completed (Work Done)
  /// or moved to Redo on [dateStr]. Uses qc_completed_at or dev_completed_at for completion date.
  /// Returns map: assigned_count, completed_count, completed_on_time_count, redo_count.
  Future<Map<String, dynamic>> getTaskStatsForDate({
    required String employeeId,
    required String dateStr,
  }) async {
    try {
      // Tasks completed on this date (workflow_status = 'Work Done', completion on date)
      const completedSql = '''
        SELECT task_id, to_date, qc_completed_at, dev_completed_at
        FROM task_cards
        WHERE employee_id = @employee_id AND is_deleted = false
          AND workflow_status = 'Work Done'
          AND (
            (qc_completed_at IS NOT NULL AND (qc_completed_at::date)::text = @date)
            OR (qc_completed_at IS NULL AND dev_completed_at IS NOT NULL AND (dev_completed_at::date)::text = @date)
          )
      ''';
      final completedRows = await DatabaseConnection.query(
        completedSql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );

      // Redo: tasks that were set to Redo on this date (we use updated_at as proxy if no status change log)
      const redoSql = '''
        SELECT task_id FROM task_cards
        WHERE employee_id = @employee_id AND is_deleted = false
          AND workflow_status = 'Redo'
          AND (updated_at::date)::text = @date
      ''';
      final redoRows = await DatabaseConnection.query(
        redoSql,
        values: {'employee_id': employeeId, 'date': dateStr},
      );

      int completedOnTime = 0;
      for (final r in completedRows) {
        final toDate = r['to_date'];
        final qcAt = r['qc_completed_at'];
        final devAt = r['dev_completed_at'];
        DateTime? completedAt;
        if (qcAt != null) completedAt = _parseDateTime(qcAt);
        if (completedAt == null && devAt != null) {
          completedAt = _parseDateTime(devAt);
        }
        if (completedAt != null && toDate != null) {
          final toDt = _parseDateTime(toDate);
          if (toDt != null &&
              !completedAt.isAfter(
                DateTime(toDt.year, toDt.month, toDt.day, 23, 59, 59),
              )) {
            completedOnTime++;
          } else if (toDt == null) {
            completedOnTime++;
          }
        } else {
          completedOnTime++;
        }
      }

      return {
        'completed_count': completedRows.length,
        'completed_on_time_count': completedOnTime,
        'redo_count': redoRows.length,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting task stats for date: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== MONTHLY RANKINGS ====================

  /// Saves or updates monthly rankings for all employees for the given month/year.
  /// [rankings] is list of { employee_id, total_points, rank, task_summary?, attendance_summary? }.
  Future<void> upsertMonthlyRankings({
    required int month,
    required int year,
    required List<Map<String, dynamic>> rankings,
  }) async {
    try {
      for (final r in rankings) {
        final employeeId = r['employee_id'] as String?;
        if (employeeId == null) continue;
        final totalPoints = _parseNum(r['total_points'])?.toDouble() ?? 0;
        final rank = _parseNum(r['rank'])?.toInt() ?? 0;
        final taskSummary = r['task_summary'] as Map<String, dynamic>? ?? {};
        final attendanceSummary =
            r['attendance_summary'] as Map<String, dynamic>? ?? {};

        const sql = '''
          INSERT INTO employee_monthly_rankings (
            employee_id, month, year, total_points, rank, task_summary, attendance_summary
          ) VALUES (
            @employee_id, @month, @year, @total_points, @rank, @task_summary::jsonb, @attendance_summary::jsonb
          )
          ON CONFLICT (employee_id, month, year)
          DO UPDATE SET
            total_points = EXCLUDED.total_points,
            rank = EXCLUDED.rank,
            task_summary = EXCLUDED.task_summary,
            attendance_summary = EXCLUDED.attendance_summary,
            updated_at = CURRENT_TIMESTAMP
        ''';
        await DatabaseConnection.execute(
          sql,
          values: {
            'employee_id': employeeId,
            'month': month,
            'year': year,
            'total_points': totalPoints,
            'rank': rank,
            'task_summary': _encodeJson(taskSummary),
            'attendance_summary': _encodeJson(attendanceSummary),
          },
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error upserting monthly rankings: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Fetches rankings for [month] and [year] with optional pagination and search.
  /// Joins employees for name, role, email, designation, image.
  Future<Map<String, dynamic>> getRankingsPaginated({
    required int month,
    required int year,
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final params = <String, dynamic>{
        'month': month,
        'year': year,
        'limit': limit,
        'offset': offset,
      };

      String searchCondition = '';
      if (search != null && search.trim().isNotEmpty) {
        searchCondition = '''
          AND (
            LOWER(e.employee_name) LIKE LOWER(@search)
            OR LOWER(e.employee_id) LIKE LOWER(@search)
            OR LOWER(e.employee_designation) LIKE LOWER(@search)
            OR LOWER(e.employee_personal_email) LIKE LOWER(@search)
          )
        ''';
        params['search'] = '%${search.trim()}%';
      }

      final countSql =
          '''
        SELECT COUNT(*) as total
        FROM employee_monthly_rankings r
        INNER JOIN employees e ON e.employee_id = r.employee_id AND e.status = 1
        WHERE r.month = @month AND r.year = @year
        $searchCondition
      ''';
      final countParams = <String, dynamic>{'month': month, 'year': year};
      if (params.containsKey('search')) {
        countParams['search'] = params['search'];
      }
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: countParams,
      );
      final total = _parseNum(countResult?['total'])?.toInt() ?? 0;

      final dataSql =
          '''
        SELECT
          r.employee_id,
          r.total_points,
          r.rank,
          e.employee_name,
          e.employee_role,
          e.employee_personal_email,
          e.employee_designation,
          e.employee_img
        FROM employee_monthly_rankings r
        INNER JOIN employees e ON e.employee_id = r.employee_id AND e.status = 1
        WHERE r.month = @month AND r.year = @year
        $searchCondition
        ORDER BY r.rank ASC, r.total_points DESC
        LIMIT @limit OFFSET @offset
      ''';
      final rows = await DatabaseConnection.query(dataSql, values: params);

      final data = rows
          .map(
            (r) => {
              'employee_id': r['employee_id']?.toString(),
              'employee_name': r['employee_name']?.toString(),
              'employee_role': r['employee_role']?.toString(),
              'employee_personal_email': r['employee_personal_email']
                  ?.toString(),
              'employee_designation': r['employee_designation']?.toString(),
              'employee_img': r['employee_img']?.toString(),
              'total_points': _parseNum(r['total_points'])?.toDouble(),
              'rank': _parseNum(r['rank'])?.toInt(),
            },
          )
          .toList();

      return {
        'data': data,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': total > 0 ? (total / limit).ceil() : 0,
          'hasNext': page * limit < total,
          'hasPrev': page > 1,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting rankings paginated: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Fallback: when employee_monthly_rankings is empty, aggregate from daily table.
  Future<Map<String, dynamic>> getRankingsFromDailyPaginated({
    required int month,
    required int year,
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final params = <String, dynamic>{
        'month': month,
        'year': year,
        'limit': limit,
        'offset': offset,
      };

      String searchCondition = '';
      if (search != null && search.trim().isNotEmpty) {
        searchCondition = '''
          AND (
            LOWER(e.employee_name) LIKE LOWER(@search)
            OR LOWER(e.employee_id) LIKE LOWER(@search)
            OR LOWER(e.employee_designation) LIKE LOWER(@search)
            OR LOWER(e.employee_personal_email) LIKE LOWER(@search)
          )
        ''';
        params['search'] = '%${search.trim()}%';
      }

      final countSql =
          '''
        SELECT COUNT(DISTINCT d.employee_id) as total
        FROM employee_eom_points_daily d
        INNER JOIN employees e ON e.employee_id = d.employee_id AND e.status = 1
        WHERE d.month = @month AND d.year = @year
        $searchCondition
      ''';
      final countParams = <String, dynamic>{'month': month, 'year': year};
      if (params.containsKey('search')) {
        countParams['search'] = params['search'];
      }
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: countParams,
      );
      final total = _parseNum(countResult?['total'])?.toInt() ?? 0;

      final dataSql =
          '''
        WITH ranked AS (
          SELECT
            d.employee_id,
            SUM(d.total_points) as total_points,
            ROW_NUMBER() OVER (ORDER BY SUM(d.total_points) DESC) as rank
          FROM employee_eom_points_daily d
          INNER JOIN employees e ON e.employee_id = d.employee_id AND e.status = 1
          WHERE d.month = @month AND d.year = @year
          $searchCondition
          GROUP BY d.employee_id
        )
        SELECT
          r.employee_id,
          r.total_points,
          r.rank::int,
          e.employee_name,
          e.employee_role,
          e.employee_personal_email,
          e.employee_designation,
          e.employee_img
        FROM ranked r
        INNER JOIN employees e ON e.employee_id = r.employee_id
        ORDER BY r.rank ASC
        LIMIT @limit OFFSET @offset
      ''';
      final rows = await DatabaseConnection.query(dataSql, values: params);

      final data = rows.map((r) {
        return {
          'employee_id': r['employee_id']?.toString(),
          'employee_name': r['employee_name']?.toString(),
          'employee_role': r['employee_role']?.toString(),
          'employee_personal_email': r['employee_personal_email']?.toString(),
          'employee_designation': r['employee_designation']?.toString(),
          'employee_img': r['employee_img']?.toString(),
          'total_points': _parseNum(r['total_points']),
          'rank': _parseNum(r['rank']),
        };
      }).toList();

      return {
        'data': data,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': total > 0 ? (total / limit).ceil() : 0,
          'hasNext': page * limit < total,
          'hasPrev': page > 1,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting rankings from daily: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== EMPLOYEE OF THE MONTH WINNER ====================

  /// Saves the winner for the given month/year.
  Future<void> setWinner({
    required String employeeId,
    required int month,
    required int year,
    required double totalPoints,
    DateTime? certificateEmailSentAt,
  }) async {
    try {
      const sql = '''
        INSERT INTO employee_of_the_month (
          employee_id, month, year, total_points, rank, certificate_email_sent_at
        ) VALUES (
          @employee_id, @month, @year, @total_points, 1, @cert_sent
        )
        ON CONFLICT (month, year)
        DO UPDATE SET
          employee_id = EXCLUDED.employee_id,
          total_points = EXCLUDED.total_points,
          certificate_email_sent_at = EXCLUDED.certificate_email_sent_at
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {
          'employee_id': employeeId,
          'month': month,
          'year': year,
          'total_points': totalPoints,
          'cert_sent': certificateEmailSentAt,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error setting EOM winner: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Marks certificate email as sent for the given month/year.
  Future<void> markCertificateEmailSent({
    required int month,
    required int year,
  }) async {
    try {
      const sql = '''
        UPDATE employee_of_the_month
        SET certificate_email_sent_at = CURRENT_TIMESTAMP
        WHERE month = @month AND year = @year
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {'month': month, 'year': year},
      );
    } catch (e, stackTrace) {
      _logger.error('Error marking certificate sent: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Fetches the winner for the given month/year (if any).
  Future<Map<String, dynamic>?> getWinner({
    required int month,
    required int year,
  }) async {
    try {
      const sql = '''
        SELECT eom.*, e.employee_name, e.employee_personal_email, e.employee_img
        FROM employee_of_the_month eom
        INNER JOIN employees e ON e.employee_id = eom.employee_id
        WHERE eom.month = @month AND eom.year = @year
      ''';
      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'month': month, 'year': year},
      );
      if (row == null) return null;

      final data = Map<String, dynamic>.from(row);
      data['total_points'] = _parseNum(data['total_points']);
      data['rank'] = _parseNum(data['rank']);
      return data;
    } catch (e, stackTrace) {
      _logger.error('Error getting EOM winner: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Returns whether monthly rankings exist for the given month/year.
  Future<bool> hasMonthlyRankingsFor(int month, int year) async {
    try {
      final r = await DatabaseConnection.queryOne(
        'SELECT 1 FROM employee_monthly_rankings WHERE month = @month AND year = @year LIMIT 1',
        values: {'month': month, 'year': year},
      );
      return r != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking monthly rankings: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==================== HELPERS ====================

  String _dateToStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _encodeJson(Map<String, dynamic> m) {
    try {
      return jsonEncode(m);
    } catch (_) {
      return '{}';
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}
