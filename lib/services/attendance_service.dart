import '../data/repositories/attendance_repository.dart';
import '../domain/models/employee_attendance.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Attendance service for business logic
class AttendanceService {
  final AttendanceRepository _repository = AttendanceRepository();
  final AppLogger _logger = AppLogger('AttendanceService');

  /// Get all attendance records with pagination
  Future<Map<String, dynamic>> getAllAttendance({
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
      return await _repository.getAll(
        page: page,
        limit: limit,
        employeeId: employeeId,
        date: date,
        fromDate: fromDate,
        toDate: toDate,
        sortBy: sortBy,
        ascending: ascending,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get attendance by ID
  Future<EmployeeAttendance> getAttendanceById(String attendanceId) async {
    try {
      final attendance = await _repository.getById(attendanceId);
      if (attendance == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }
      return attendance;
    } catch (e, stackTrace) {
      _logger.error('Error getting attendance by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get attendance for employee on date
  Future<EmployeeAttendance?> getAttendanceByEmployeeAndDate(
    String employeeId,
    String date,
  ) async {
    try {
      return await _repository.getByEmployeeAndDate(employeeId, date);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting attendance by employee and date: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get attendance records for employee in date range
  Future<List<EmployeeAttendance>> getEmployeeAttendanceRange(
    String employeeId,
    String fromDate,
    String toDate,
  ) async {
    try {
      return await _repository.getByEmployeeDateRange(
        employeeId,
        fromDate,
        toDate,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee attendance range: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Create attendance record
  Future<EmployeeAttendance> createAttendance(Map<String, dynamic> data) async {
    try {
      // Validate required fields
      final errors = <String, List<String>>{};

      if (data['employee_id'] == null ||
          data['employee_id'].toString().isEmpty) {
        errors['employee_id'] = ['Employee ID is required'];
      }
      if (data['work_date'] == null || data['work_date'].toString().isEmpty) {
        errors['work_date'] = ['Work date is required'];
      }
      if (data['clock_on_for_the_day'] == null ||
          data['clock_on_for_the_day'].toString().isEmpty) {
        errors['clock_on_for_the_day'] = ['Clock on timestamp is required'];
      }
      if (data['clock_on_for_the_day'] == null ||
          data['clock_on_for_the_day'].toString().isEmpty) {
        errors['clock_on_for_the_day'] = ['Clock on timestamp is required'];
      }
      if (data['created_by'] == null || data['created_by'].toString().isEmpty) {
        errors['created_by'] = ['Created by is required'];
      }

      if (errors.isNotEmpty) {
        throw ValidationException(errors);
      }

      final attendance = EmployeeAttendance(
        attendanceId: '',
        employeeId: data['employee_id'].toString(),
        workDate: data['work_date'].toString(),
        clockOnForTheDay: data['clock_on_for_the_day'].toString(),
        clockOffForTheDay: data['clock_off_for_the_day']?.toString(),
        clockOnTime: data['clock_on_for_the_day']
            .toString()
            .split('T')
            .last
            .split('.')
            .first,
        clockOffTime: data['clock_off_time']?.toString(),
        taskId: data['task_id']?.toString(),
        workedHrs: data['worked_hrs'] != null
            ? double.tryParse(data['worked_hrs'].toString()) ?? 0.0
            : null,
        createdBy: data['created_by'].toString(),
        updatedBy:
            data['updated_by']?.toString() ?? data['created_by'].toString(),
        tasksForTheDay: data['tasks_for_the_day'] as List<dynamic>? ?? [],
        isRemoteOverride: data['is_remote_override'] as bool?,
        remoteReason: data['remote_reason']?.toString(),
      );

      return await _repository.create(attendance);
    } catch (e, stackTrace) {
      _logger.error('Error creating attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update attendance record
  Future<EmployeeAttendance> updateAttendance(
    String attendanceId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Verify attendance exists
      final existing = await _repository.getById(attendanceId);
      if (existing == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }

      return await _repository.update(attendanceId, updates);
    } catch (e, stackTrace) {
      _logger.error('Error updating attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Punch in for the day
  Future<EmployeeAttendance> punchIn(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      if (data['employee_id'] == null ||
          data['employee_id'].toString().isEmpty) {
        errors['employee_id'] = ['Employee ID is required'];
      }
      if (data['work_date'] == null || data['work_date'].toString().isEmpty) {
        errors['work_date'] = ['Work date is required'];
      }
      if (data['clock_on_for_the_day'] == null ||
          data['clock_on_for_the_day'].toString().isEmpty) {
        errors['clock_on_for_the_day'] = ['Clock on timestamp is required'];
      }
      if (data['created_by'] == null || data['created_by'].toString().isEmpty) {
        errors['created_by'] = ['Created by is required'];
      }

      if (errors.isNotEmpty) {
        throw ValidationException(errors);
      }

      return await _repository.punchIn(
        employeeId: data['employee_id'].toString(),
        workDate: data['work_date'].toString(),
        clockOnForTheDay: data['clock_on_for_the_day'].toString(),
        createdBy: data['created_by'].toString(),
        isRemoteOverride: data['is_remote_override'] as bool?,
        remoteReason: data['remote_reason']?.toString(),
      );
    } catch (e, stackTrace) {
      _logger.error('Error punching in: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Punch out for the day
  Future<EmployeeAttendance> punchOut(
    String attendanceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final errors = <String, List<String>>{};

      if (data['clock_off_for_the_day'] == null ||
          data['clock_off_for_the_day'].toString().isEmpty) {
        errors['clock_off_for_the_day'] = ['Clock off timestamp is required'];
      }
      if (data['worked_hrs'] == null) {
        errors['worked_hrs'] = ['Worked hours is required'];
      }
      if (data['updated_by'] == null || data['updated_by'].toString().isEmpty) {
        errors['updated_by'] = ['Updated by is required'];
      }

      if (errors.isNotEmpty) {
        throw ValidationException(errors);
      }

      // Fetch existing record to get clock_on time for precise duration calculation
      final existingRecord = await _repository.getById(attendanceId);
      String? sessionDuration = data['session_duration']?.toString();
      double workedHrsVal = data['worked_hrs'] != null
          ? double.tryParse(data['worked_hrs'].toString()) ?? 0.0
          : 0.0;

      if (existingRecord != null &&
          existingRecord.clockOnForTheDay.isNotEmpty &&
          data['clock_off_for_the_day'] != null) {
        try {
          final clockOn = DateTime.parse(existingRecord.clockOnForTheDay);
          final clockOff = DateTime.parse(
            data['clock_off_for_the_day'].toString(),
          );
          final duration = clockOff.difference(clockOn);

          final int hours = duration.inHours;
          final int minutes = duration.inMinutes % 60;
          final int seconds = duration.inSeconds % 60;

          if (hours > 0) {
            sessionDuration = '${hours}h ${minutes}m ${seconds}s';
          } else if (minutes > 0) {
            sessionDuration = '${minutes}m ${seconds}s';
          } else {
            sessionDuration = '${seconds}s';
          }

          // Update worked hours with higher precision
          workedHrsVal = duration.inSeconds / 3600.0;
        } catch (e) {
          _logger.warning('Error calculating precise duration: $e');
        }
      }

      // Fallback calculation if timestamp parsing failed or record not found
      if (sessionDuration == null) {
        final int totalSeconds = (workedHrsVal * 3600).round();
        final int hours = totalSeconds ~/ 3600;
        final int minutes = (totalSeconds % 3600) ~/ 60;
        final int seconds = totalSeconds % 60;

        if (hours > 0) {
          sessionDuration = '${hours}h ${minutes}m ${seconds}s';
        } else if (minutes > 0) {
          sessionDuration = '${minutes}m ${seconds}s';
        } else {
          sessionDuration = '${seconds}s';
        }
      }

      return await _repository.punchOut(
        attendanceId: attendanceId,
        clockOffForTheDay: data['clock_off_for_the_day'].toString(),
        workedHrs: workedHrsVal,
        sessionDuration: sessionDuration,
        updatedBy: data['updated_by'].toString(),
      );
    } catch (e, stackTrace) {
      _logger.error('Error clocking off: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add task to attendance
  Future<EmployeeAttendance> addTask(
    String attendanceId,
    Map<String, dynamic> task,
    String updatedBy,
  ) async {
    try {
      return await _repository.addTask(
        attendanceId: attendanceId,
        task: task,
        updatedBy: updatedBy,
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding task: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete attendance record
  Future<void> deleteAttendance(String attendanceId) async {
    try {
      final existing = await _repository.getById(attendanceId);
      if (existing == null) {
        throw NotFoundException(resource: 'Attendance', id: attendanceId);
      }

      await _repository.delete(attendanceId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get today's attendance
  Future<List<EmployeeAttendance>> getTodayAttendance() async {
    try {
      return await _repository.getTodayAttendance();
    } catch (e, stackTrace) {
      _logger.error('Error getting today attendance: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee attendance summary
  Future<Map<String, dynamic>> getEmployeeSummary(
    String employeeId,
    String fromDate,
    String toDate,
  ) async {
    try {
      return await _repository.getEmployeeSummary(employeeId, fromDate, toDate);
    } catch (e, stackTrace) {
      _logger.error('Error getting employee summary: $e', e, stackTrace);
      rethrow;
    }
  }
}
