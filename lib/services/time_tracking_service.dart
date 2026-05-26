import '../data/repositories/time_tracking_repository.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class TimeTrackingService {
  final TimeTrackingRepository _repository = TimeTrackingRepository();
  final AppLogger _logger = AppLogger('TimeTrackingService');

  /// Clock in to a task
  /// [workDate] - Optional work date from client (YYYY-MM-DD format)
  /// [clockInTime] - Optional clock in time from client (ISO8601 format)
  Future<Map<String, dynamic>> clockIn({
    required String employeeId,
    required String taskId,
    String? taskName,
    String? workDate,
    String? clockInTime,
  }) async {
    try {
      // Check for existing active session
      final existingSession = await _repository.getActiveSessionForEmployee(
        employeeId,
      );
      if (existingSession != null) {
        throw ConflictException(
          resource: 'time_tracking',
          field: 'active_session',
        );
      }

      final result = await _repository.clockIn(
        employeeId: employeeId,
        taskId: taskId,
        taskName: taskName,
        workDate: workDate,
        clockInTime: clockInTime,
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to clock in');
      }

      return result;
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      _logger.error('Error clocking in: $e', e, stackTrace);
      throw DatabaseException(message: 'Error clocking in: $e');
    }
  }

  /// Clock out from a task
  /// [customClockOutTime] - Optional custom time for clock out (defaults to now)
  Future<Map<String, dynamic>> clockOut({
    required String employeeId,
    required String taskId,
    DateTime? customClockOutTime,
  }) async {
    try {
      // Check if there's an active session for this task
      final activeSession = await _repository.getActiveSession(
        employeeId,
        taskId,
      );
      if (activeSession == null) {
        throw NotFoundException(resource: 'time_tracking', id: taskId);
      }

      final result = await _repository.clockOut(
        employeeId: employeeId,
        taskId: taskId,
        customClockOutTime: customClockOutTime,
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to clock out');
      }

      return result;
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      _logger.error('Error clocking out: $e', e, stackTrace);
      throw DatabaseException(message: 'Error clocking out: $e');
    }
  }

  /// Get current active session for an employee
  Future<Map<String, dynamic>?> getActiveSession(String employeeId) async {
    try {
      return await _repository.getActiveSessionForEmployee(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting active session: $e', e, stackTrace);
      throw DatabaseException(message: 'Error getting active session: $e');
    }
  }

  /// Clear stale sessions for an employee
  Future<int> clearStaleSessions(String employeeId) async {
    try {
      return await _repository.clearStaleActiveSessions(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error clearing stale sessions: $e', e, stackTrace);
      throw DatabaseException(message: 'Error clearing stale sessions: $e');
    }
  }

  /// Get tracking history for a task
  Future<List<Map<String, dynamic>>> getTaskHistory({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _repository.getTaskTrackingRecords(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting task history: $e', e, stackTrace);
      throw DatabaseException(message: 'Error getting task history: $e');
    }
  }

  /// Get daily tracking records for an employee
  Future<List<Map<String, dynamic>>> getDailyRecords({
    required String employeeId,
    required String workDate,
  }) async {
    try {
      return await _repository.getDailyTrackingRecords(
        employeeId: employeeId,
        workDate: workDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting daily records: $e', e, stackTrace);
      throw DatabaseException(message: 'Error getting daily records: $e');
    }
  }

  /// Get total hours for a task
  Future<double> getTotalHours({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _repository.getTotalHoursForTask(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting total hours: $e', e, stackTrace);
      throw DatabaseException(message: 'Error getting total hours: $e');
    }
  }

  /// Get task tracking summary
  Future<Map<String, dynamic>> getTaskSummary({
    required String taskId,
    String? employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _repository.getTaskTrackingSummary(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting task summary: $e', e, stackTrace);
      throw DatabaseException(message: 'Error getting task summary: $e');
    }
  }
}
