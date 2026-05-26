import 'dart:convert';
import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';
import '../../domain/models/employee_attendance.dart';

/// Attendance repository for database operations
class AttendanceRepository {
  final AppLogger _logger = AppLogger('AttendanceRepository');

  /// Get all attendance records with pagination and filters
  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 50,
    String? employeeId,
    String? date,
    String? fromDate,
    String? toDate,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var whereConditions = <String>[];
      final params = <String, dynamic>{};
      var paramIndex = 1;

      // Employee ID filter
      if (employeeId != null && employeeId.isNotEmpty) {
        whereConditions.add('employee_id = @empId$paramIndex');
        params['empId$paramIndex'] = employeeId;
        paramIndex++;
      }

      // Specific date filter
      if (date != null && date.isNotEmpty) {
        whereConditions.add('work_date = @date$paramIndex');
        params['date$paramIndex'] = date;
        paramIndex++;
      }

      // Date range filter
      if (fromDate != null && fromDate.isNotEmpty) {
        whereConditions.add('work_date >= @fromDate$paramIndex');
        params['fromDate$paramIndex'] = fromDate;
        paramIndex++;
      }
      if (toDate != null && toDate.isNotEmpty) {
        whereConditions.add('work_date <= @toDate$paramIndex');
        params['toDate$paramIndex'] = toDate;
        paramIndex++;
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      // Sort by
      final orderBy = sortBy != null
          ? 'ORDER BY $sortBy ${ascending ? 'ASC' : 'DESC'}'
          : 'ORDER BY work_date DESC, clock_on_for_the_day DESC';

      // Count query
      final countSql =
          'SELECT COUNT(*) as total FROM employee_attendance $whereClause';
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Data query with PostgreSQL pagination
      final sql =
          '''
        SELECT * FROM employee_attendance 
        $whereClause 
        $orderBy 
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: params);
      final attendances = results
          .map((row) => EmployeeAttendance.fromMap(row))
          .toList();

      return {
        'data': attendances,
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': (total / limit).ceil(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get attendance by ID
  Future<EmployeeAttendance?> getById(String attendanceId) async {
    try {
      final sql = 'SELECT * FROM employee_attendance WHERE attendance_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': attendanceId},
      );

      return result != null ? EmployeeAttendance.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting attendance by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get attendance for employee on specific date
  Future<EmployeeAttendance?> getByEmployeeAndDate(
    String employeeId,
    String date,
  ) async {
    try {
      final sql = '''
        SELECT * FROM employee_attendance 
        WHERE employee_id = @empId AND work_date = @date
        ORDER BY clock_on_for_the_day DESC
        LIMIT 1
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'empId': employeeId, 'date': date},
      );

      return result != null ? EmployeeAttendance.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting attendance by employee and date: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get attendance records for employee within date range
  Future<List<EmployeeAttendance>> getByEmployeeDateRange(
    String employeeId,
    String fromDate,
    String toDate,
  ) async {
    try {
      final sql = '''
        SELECT * FROM employee_attendance 
        WHERE employee_id = @empId 
        AND work_date >= @fromDate 
        AND work_date <= @toDate
        ORDER BY work_date DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'empId': employeeId, 'fromDate': fromDate, 'toDate': toDate},
      );

      return results.map((row) => EmployeeAttendance.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting attendance by date range: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create attendance record
  Future<EmployeeAttendance> create(EmployeeAttendance attendance) async {
    try {
      final data = attendance.toInsertMap();

      // Convert tasks_for_the_day to JSON string for PostgreSQL
      if (data['tasks_for_the_day'] != null) {
        data['tasks_for_the_day'] = jsonEncode(data['tasks_for_the_day']);
      }

      final sql = '''
        INSERT INTO employee_attendance (
          employee_id, work_date, clock_on_for_the_day, clock_off_for_the_day,
          task_id, worked_hrs, created_by, updated_by,
          tasks_for_the_day, is_remote_override, remote_reason
        )
        VALUES (
          @employee_id, @work_date, @clock_on_for_the_day, @clock_off_for_the_day,
          @task_id, @worked_hrs, @created_by, @updated_by,
          @tasks_for_the_day, @is_remote_override, @remote_reason
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: data);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create attendance record');
      }

      return EmployeeAttendance.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update attendance record
  Future<EmployeeAttendance> update(
    String attendanceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (updates.isEmpty) {
        throw ValidationException({
          'updates': ['No fields to update'],
        });
      }

      // Convert tasks_for_the_day to JSON string if present
      if (updates['tasks_for_the_day'] != null) {
        updates['tasks_for_the_day'] = jsonEncode(updates['tasks_for_the_day']);
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE employee_attendance 
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = @id
        RETURNING *
      ''';

      updates['id'] = attendanceId;
      final result = await DatabaseConnection.queryOne(sql, values: updates);

      if (result == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }

      return EmployeeAttendance.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Punch in for the day
  Future<EmployeeAttendance> punchIn({
    required String employeeId,
    required String workDate,
    required String clockOnForTheDay,
    required String createdBy,
    bool? isRemoteOverride,
    String? remoteReason,
  }) async {
    try {
      // Check if record already exists for this date (active session without clock off)
      final existingSql = '''
        SELECT * FROM employee_attendance 
        WHERE employee_id = @empId AND work_date = @date AND clock_off_for_the_day IS NULL
      ''';
      final existing = await DatabaseConnection.queryOne(
        existingSql,
        values: {'empId': employeeId, 'date': workDate},
      );

      if (existing != null) {
        throw ConflictException(
          resource: 'Attendance',
          field: 'employee_id and work_date',
        );
      }

      final sql = '''
        INSERT INTO employee_attendance (
          attendance_id, employee_id, work_date, clock_on_for_the_day,
          created_by, updated_by, is_remote_override, remote_reason
        )
        VALUES (
          gen_random_uuid(), @employee_id, @work_date, CAST(@clock_on_for_the_day AS TEXT),
          @created_by, @updated_by, @is_remote_override, @remote_reason
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'employee_id': employeeId,
          'work_date': workDate,
          'clock_on_for_the_day': clockOnForTheDay,
          'created_by': createdBy,
          'updated_by': createdBy,
          'is_remote_override': isRemoteOverride ?? false,
          'remote_reason': remoteReason,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to punch in');
      }

      return EmployeeAttendance.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error punching in: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Punch out for the day
  Future<EmployeeAttendance> punchOut({
    required String attendanceId,
    required String clockOffForTheDay,
    required double workedHrs,
    required String updatedBy,
    String? sessionDuration,
  }) async {
    try {
      final sql = '''
        UPDATE employee_attendance 
        SET clock_off_for_the_day = @clock_off_for_the_day,
            worked_hrs = @worked_hrs,
            session_duration = @session_duration,
            updated_by = @updated_by,
            updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': attendanceId,
          'clock_off_for_the_day': clockOffForTheDay,
          'worked_hrs': workedHrs,
          'session_duration': sessionDuration,
          'updated_by': updatedBy,
        },
      );

      if (result == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }

      return EmployeeAttendance.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking off: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add task to attendance
  Future<EmployeeAttendance> addTask({
    required String attendanceId,
    required Map<String, dynamic> task,
    required String updatedBy,
  }) async {
    try {
      // Get current attendance
      final current = await getById(attendanceId);
      if (current == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }

      // Add task to the list
      final tasks = List<dynamic>.from(current.tasksForTheDay);
      tasks.add(task);

      final sql = '''
        UPDATE employee_attendance 
        SET tasks_for_the_day = @tasks,
            updated_by = @updated_by,
            updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': attendanceId,
          'tasks': jsonEncode(tasks),
          'updated_by': updatedBy,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to add task');
      }

      return EmployeeAttendance.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error adding task: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete attendance record
  Future<bool> delete(String attendanceId) async {
    try {
      final sql = 'DELETE FROM employee_attendance WHERE attendance_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': attendanceId},
      );
      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get today's attendance for all employees
  Future<List<EmployeeAttendance>> getTodayAttendance() async {
    try {
      // Calculate today's date in IST (UTC+5:30)
      final nowUtc = DateTime.now().toUtc();
      final istOffset = Duration(hours: 5, minutes: 30);
      final nowIst = nowUtc.add(istOffset);
      final today = nowIst.toIso8601String().split('T')[0];
      final sql = '''
        SELECT * FROM employee_attendance 
        WHERE work_date = @date
        ORDER BY clock_on_for_the_day DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'date': today},
      );
      return results.map((row) => EmployeeAttendance.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting today attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get attendance summary for employee
  Future<Map<String, dynamic>> getEmployeeSummary(
    String employeeId,
    String fromDate,
    String toDate,
  ) async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_days,
          SUM(COALESCE(worked_hrs, 0)) as total_hours,
          COUNT(CASE WHEN clock_off_for_the_day IS NOT NULL THEN 1 END) as completed_days
        FROM employee_attendance 
        WHERE employee_id = @empId 
        AND work_date >= @fromDate 
        AND work_date <= @toDate
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'empId': employeeId, 'fromDate': fromDate, 'toDate': toDate},
      );

      return {
        'totalDays': result?['total_days'] ?? 0,
        'totalHours': result?['total_hours'] ?? 0.0,
        'completedDays': result?['completed_days'] ?? 0,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting employee summary: $e', e, stackTrace);
      rethrow;
    }
  }
}
