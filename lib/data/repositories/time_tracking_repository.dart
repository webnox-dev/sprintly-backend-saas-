import '../database/connection.dart';
import '../../core/utils/logger.dart';

class TimeTrackingRepository {
  final AppLogger _logger = AppLogger('TimeTrackingRepository');

  /// Clock in - create a new time tracking record
  /// [workDate] - Optional work date from client (YYYY-MM-DD format), uses IST if not provided
  /// [clockInTime] - Optional clock in time from client (ISO8601 format), uses NOW() if not provided
  Future<Map<String, dynamic>?> clockIn({
    required String employeeId,
    required String taskId,
    String? taskName,
    String? workDate,
    String? clockInTime,
  }) async {
    try {
      // Use provided workDate from client, or calculate based on IST timezone
      // IST is UTC+5:30
      String effectiveWorkDate;
      if (workDate != null && workDate.isNotEmpty) {
        effectiveWorkDate = workDate;
      } else {
        // Calculate current date in IST (UTC+5:30)
        final nowUtc = DateTime.now().toUtc();
        final istOffset = Duration(hours: 5, minutes: 30);
        final nowIst = nowUtc.add(istOffset);
        effectiveWorkDate = nowIst.toIso8601String().split('T')[0];
      }

      // Check if there's already an active session for this employee
      final activeSession = await getActiveSessionForEmployee(employeeId);
      if (activeSession != null) {
        _logger.warning('Employee $employeeId already has an active session');
        return null;
      }

      Map<String, dynamic>? result;

      if (clockInTime != null && clockInTime.isNotEmpty) {
        // Use client-provided clock in time (like daily attendance does)
        result = await DatabaseConnection.queryOne(
          '''
            INSERT INTO task_card_time_tracking (
              employee_id, task_id, task_name, work_date, 
              clock_in_time, created_by, updated_by
            )
            VALUES (
              @employee_id, @task_id::uuid, @task_name, @work_date, 
              @clock_in_time::timestamp, @employee_id, @employee_id
            )
            RETURNING *
          ''',
          values: {
            'employee_id': employeeId,
            'task_id': taskId,
            'task_name': taskName,
            'work_date': effectiveWorkDate,
            'clock_in_time': clockInTime,
          },
        );
      } else {
        // Fallback to NOW() if client doesn't provide clock_in_time
        result = await DatabaseConnection.queryOne(
          '''
            INSERT INTO task_card_time_tracking (
              employee_id, task_id, task_name, work_date, 
              clock_in_time, created_by, updated_by
            )
            VALUES (
              @employee_id, @task_id::uuid, @task_name, @work_date, 
              NOW(), @employee_id, @employee_id
            )
            RETURNING *
          ''',
          values: {
            'employee_id': employeeId,
            'task_id': taskId,
            'task_name': taskName,
            'work_date': effectiveWorkDate,
          },
        );
      }

      if (result == null) return null;

      return _rowToMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking in: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock out - update the active tracking record
  /// [customClockOutTime] - Optional custom time for clock out (defaults to NOW())
  Future<Map<String, dynamic>?> clockOut({
    required String employeeId,
    required String taskId,
    DateTime? customClockOutTime,
  }) async {
    try {
      // Get active session first
      final activeSession = await getActiveSession(employeeId, taskId);
      if (activeSession == null) {
        _logger.warning(
          'No active session found for employee $employeeId and task $taskId',
        );
        return null;
      }

      Map<String, dynamic>? result;

      if (customClockOutTime != null) {
        // Use custom clock out time - pass as parameter
        // Convert to UTC as the DB seems to store clock_in_time in UTC
        result = await DatabaseConnection.queryOne(
          '''
            UPDATE task_card_time_tracking
            SET 
              clock_out_time = @clock_out_time::timestamp,
              worked_hours = EXTRACT(EPOCH FROM (@clock_out_time::timestamp - clock_in_time)) / 3600.0,
              session_duration = 
                CASE 
                  WHEN EXTRACT(EPOCH FROM (@clock_out_time::timestamp - clock_in_time)) >= 3600 
                  THEN CONCAT(
                    FLOOR(EXTRACT(EPOCH FROM (@clock_out_time::timestamp - clock_in_time)) / 3600)::text, 'h ',
                    FLOOR((EXTRACT(EPOCH FROM (@clock_out_time::timestamp - clock_in_time)) % 3600) / 60)::text, 'm'
                  )
                  ELSE CONCAT(ROUND((EXTRACT(EPOCH FROM (@clock_out_time::timestamp - clock_in_time)) / 60.0)::numeric, 1)::text, 'm')
                END,
              updated_at = NOW()::timestamp,
              updated_by = @employee_id
            WHERE tracking_id = @tracking_id::uuid
            RETURNING *
          ''',
          values: {
            'employee_id': employeeId,
            'tracking_id': activeSession['tracking_id'],
            // Use local time (NOT UTC) to be consistent with clock_in_time storage
            'clock_out_time': customClockOutTime.toIso8601String(),
          },
        );
      } else {
        // Use NOW() for clock out time
        result = await DatabaseConnection.queryOne(
          '''
            UPDATE task_card_time_tracking
            SET 
              clock_out_time = NOW(),
              worked_hours = EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 3600.0,
              session_duration = 
                CASE 
                  WHEN EXTRACT(EPOCH FROM (NOW() - clock_in_time)) >= 3600 
                  THEN CONCAT(
                    FLOOR(EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 3600)::text, 'h ',
                    FLOOR((EXTRACT(EPOCH FROM (NOW() - clock_in_time)) % 3600) / 60)::text, 'm'
                  )
                  ELSE CONCAT(ROUND((EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 60.0)::numeric, 1)::text, 'm')
                END,
              updated_at = NOW()::timestamp,
              updated_by = @employee_id
            WHERE tracking_id = @tracking_id::uuid
            RETURNING *
          ''',
          values: {
            'employee_id': employeeId,
            'tracking_id': activeSession['tracking_id'],
          },
        );
      }

      if (result == null) return null;

      return _rowToMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking out: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get active session for specific employee and task
  Future<Map<String, dynamic>?> getActiveSession(
    String employeeId,
    String taskId,
  ) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
          SELECT * FROM task_card_time_tracking
          WHERE employee_id = @employee_id
            AND task_id = @task_id::uuid
            AND clock_out_time IS NULL
          LIMIT 1
        ''',
        values: {'employee_id': employeeId, 'task_id': taskId},
      );

      if (result == null) return null;

      return _rowToMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting active session: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get active session for employee (any task)
  Future<Map<String, dynamic>?> getActiveSessionForEmployee(
    String employeeId,
  ) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
          SELECT * FROM task_card_time_tracking
          WHERE employee_id = @employee_id
            AND clock_out_time IS NULL
          LIMIT 1
        ''',
        values: {'employee_id': employeeId},
      );

      if (result == null) return null;

      return _rowToMap(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting active session for employee: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Clear stale active sessions for an employee
  Future<int> clearStaleActiveSessions(String employeeId) async {
    try {
      final affectedRows = await DatabaseConnection.execute(
        '''
          UPDATE task_card_time_tracking
          SET 
            clock_out_time = NOW(),
            worked_hours = EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 3600.0,
            session_duration = 
              CASE 
                WHEN EXTRACT(EPOCH FROM (NOW() - clock_in_time)) >= 3600 
                THEN CONCAT(
                  FLOOR(EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 3600)::text, 'h ',
                  FLOOR((EXTRACT(EPOCH FROM (NOW() - clock_in_time)) % 3600) / 60)::text, 'm'
                )
                ELSE CONCAT(FLOOR(EXTRACT(EPOCH FROM (NOW() - clock_in_time)) / 60)::text, 'm')
              END,
            updated_at = NOW(),
            updated_by = @employee_id
          WHERE employee_id = @employee_id AND clock_out_time IS NULL
        ''',
        values: {'employee_id': employeeId},
      );

      return affectedRows;
    } catch (e, stackTrace) {
      _logger.error('Error clearing stale sessions: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get tracking records for a task
  Future<List<Map<String, dynamic>>> getTaskTrackingRecords({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      var sql = '''
        SELECT * FROM task_card_time_tracking
        WHERE task_id = @task_id::uuid
      ''';

      final params = <String, dynamic>{'task_id': taskId};

      if (employeeId != null) {
        sql += ' AND employee_id = @employee_id';
        params['employee_id'] = employeeId;
      }

      if (startDate != null) {
        sql += ' AND work_date >= @start_date';
        params['start_date'] = startDate;
      }

      if (endDate != null) {
        sql += ' AND work_date <= @end_date';
        params['end_date'] = endDate;
      }

      sql += ' ORDER BY clock_in_time DESC';

      final results = await DatabaseConnection.query(sql, values: params);

      return results.map((row) => _rowToMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting task tracking records: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get daily tracking records for an employee
  Future<List<Map<String, dynamic>>> getDailyTrackingRecords({
    required String employeeId,
    required String workDate,
  }) async {
    try {
      final results = await DatabaseConnection.query(
        '''
          SELECT 
            tctt.*, 
            p.project_id, 
            p.project_name, 
            p.project_description
          FROM task_card_time_tracking tctt
          LEFT JOIN task_cards tc ON tctt.task_id = tc.task_id
          LEFT JOIN projects p ON tc.project_id = p.project_id
          WHERE tctt.employee_id = @employee_id
            AND tctt.work_date = @work_date
          ORDER BY tctt.clock_in_time ASC
        ''',
        values: {'employee_id': employeeId, 'work_date': workDate},
      );

      _logger.info('getDailyTrackingRecords found ${results.length} records');
      if (results.isNotEmpty) {
        _logger.info('First record sample: ${results.first}');
      }

      return results.map((row) => _rowToMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting daily tracking records: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get total hours worked per task for a list of task IDs (batch).
  /// Returns map of task_id (string) -> total_hours (double).
  Future<Map<String, double>> getTotalHoursByTaskIds(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return {};
    try {
      final placeholders = List.generate(
        taskIds.length,
        (i) => '@id$i',
      ).join(', ');
      final params = <String, dynamic>{};
      for (var i = 0; i < taskIds.length; i++) {
        params['id$i'] = taskIds[i];
      }
      final result = await DatabaseConnection.query(
        '''
        SELECT task_id::text as task_id, COALESCE(SUM(worked_hours), 0) as total_hours
        FROM task_card_time_tracking
        WHERE task_id IN ($placeholders)
          AND worked_hours IS NOT NULL
        GROUP BY task_id
        ''',
        values: params,
      );
      final map = <String, double>{};
      for (final row in result) {
        final id = row['task_id']?.toString();
        if (id != null) {
          final h = row['total_hours'];
          map[id] = (h is num) ? h.toDouble() : 0.0;
        }
      }
      return map;
    } catch (e, stackTrace) {
      _logger.error('Error getting total hours by task IDs: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get total hours worked on a task
  Future<double> getTotalHoursForTask({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      var sql = '''
        SELECT COALESCE(SUM(worked_hours), 0) as total_hours
        FROM task_card_time_tracking
        WHERE task_id = @task_id::uuid
          AND worked_hours IS NOT NULL
      ''';

      final params = <String, dynamic>{'task_id': taskId};

      if (employeeId != null) {
        sql += ' AND employee_id = @employee_id';
        params['employee_id'] = employeeId;
      }

      if (startDate != null) {
        sql += ' AND work_date >= @start_date';
        params['start_date'] = startDate;
      }

      if (endDate != null) {
        sql += ' AND work_date <= @end_date';
        params['end_date'] = endDate;
      }

      final result = await DatabaseConnection.queryOne(sql, values: params);

      if (result == null) return 0.0;

      final totalHours = result['total_hours'];
      return (totalHours as num?)?.toDouble() ?? 0.0;
    } catch (e, stackTrace) {
      _logger.error('Error getting total hours: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task tracking summary
  Future<Map<String, dynamic>> getTaskTrackingSummary({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      var sql = '''
        SELECT 
          COUNT(*) FILTER (WHERE clock_out_time IS NOT NULL) as total_sessions,
          COALESCE(SUM(worked_hours) FILTER (WHERE clock_out_time IS NOT NULL), 0) as total_hours,
          MIN(clock_in_time) as first_clock_in,
          MAX(clock_out_time) as last_clock_out,
          bool_or(clock_out_time IS NULL) as is_currently_active
        FROM task_card_time_tracking
        WHERE task_id = @task_id::uuid
      ''';

      final params = <String, dynamic>{'task_id': taskId};

      if (employeeId != null) {
        sql += ' AND employee_id = @employee_id';
        params['employee_id'] = employeeId;
      }

      if (startDate != null) {
        sql += ' AND work_date >= @start_date';
        params['start_date'] = startDate;
      }

      if (endDate != null) {
        sql += ' AND work_date <= @end_date';
        params['end_date'] = endDate;
      }

      final result = await DatabaseConnection.queryOne(sql, values: params);

      if (result == null) {
        return {
          'task_id': taskId,
          'total_sessions': 0,
          'total_hours': 0.0,
          'average_session_hours': 0.0,
          'first_clock_in': null,
          'last_clock_out': null,
          'is_currently_active': false,
        };
      }

      final totalSessions = (result['total_sessions'] as num?)?.toInt() ?? 0;
      final totalHours = (result['total_hours'] as num?)?.toDouble() ?? 0.0;

      return {
        'task_id': taskId,
        'total_sessions': totalSessions,
        'total_hours': totalHours,
        'average_session_hours': totalSessions > 0
            ? totalHours / totalSessions
            : 0.0,
        'first_clock_in': result['first_clock_in']?.toString(),
        'last_clock_out': result['last_clock_out']?.toString(),
        'is_currently_active': result['is_currently_active'] ?? false,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting task tracking summary: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Convert database row to map with proper type handling
  /// Note: PostgreSQL 'timestamp without time zone' stores local times
  /// but the Dart driver returns them as UTC DateTime objects.
  /// We output ISO strings WITHOUT 'Z' suffix so frontend treats them as local time.
  Map<String, dynamic> _rowToMap(Map<String, dynamic> row) {
    final map = <String, dynamic>{};
    row.forEach((key, value) {
      if (value is DateTime) {
        // Output ISO8601 string without 'Z' suffix to indicate it's local time
        // Format: 2026-01-21T12:49:53.123456 (no 'Z')
        final isoString = value.toIso8601String();
        // Remove 'Z' suffix if present to indicate local time
        map[key] = isoString.endsWith('Z')
            ? isoString.substring(0, isoString.length - 1)
            : isoString;
      } else {
        map[key] = value;
      }
    });
    return map;
  }
}
