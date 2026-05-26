import '../../../domain/models/task_card.dart';
import '../../database/connection.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/logger.dart';

/// Task Usage Tracking Repository Helper
/// Handles employee task tracking (clock-in/out) operations
class TaskUsageTrackingHelper {
  final AppLogger _logger = AppLogger('TaskUsageTrackingHelper');

  /// Clock in to a task
  Future<EmployeeTaskTracking> clockInToTask(
    String taskId,
    String employeeId,
    String? notes,
  ) async {
    try {
      final query = '''
        INSERT INTO employee_task_tracking (
          task_id, employee_id, started_at, employee_task_status, session_notes
        ) VALUES (
          @task_id, @employee_id, CURRENT_TIMESTAMP, 1, @notes
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'task_id': taskId, 'employee_id': employeeId, 'notes': notes},
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to clock in to task');
      }

      return EmployeeTaskTracking.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking in to task: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock out from a task
  Future<EmployeeTaskTracking> clockOutFromTask(
    String trackingId,
    String? notes,
  ) async {
    try {
      final query = '''
        UPDATE employee_task_tracking
        SET 
          completed_at = CURRENT_TIMESTAMP,
          employee_task_status = 2,
          total_hours = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - started_at)) / 3600,
          session_notes = COALESCE(@notes, session_notes),
          updated_at = CURRENT_TIMESTAMP
        WHERE tracking_id = @tracking_id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'tracking_id': trackingId, 'notes': notes},
      );

      if (result == null) {
        throw NotFoundException(
          resource: 'EmployeeTaskTracking',
          id: trackingId,
        );
      }

      return EmployeeTaskTracking.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking out from task: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Pause task tracking
  Future<EmployeeTaskTracking> pauseTaskTracking(String trackingId) async {
    try {
      final query = '''
        UPDATE employee_task_tracking
        SET 
          paused_at = CURRENT_TIMESTAMP,
          employee_task_status = 3,
          total_hours = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - started_at)) / 3600,
          updated_at = CURRENT_TIMESTAMP
        WHERE tracking_id = @tracking_id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'tracking_id': trackingId},
      );

      if (result == null) {
        throw NotFoundException(
          resource: 'EmployeeTaskTracking',
          id: trackingId,
        );
      }

      return EmployeeTaskTracking.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error pausing task tracking: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task usage by task ID
  Future<List<EmployeeTaskTracking>> getTaskUsageByTaskId(String taskId) async {
    try {
      final query = '''
        SELECT 
          ett.*,
          json_build_object(
            'employee_id', e.employee_id,
            'employee_name', e.employee_name,
            'employee_personal_email', e.employee_personal_email,
            'employee_role', e.employee_role,
            'employee_img', e.employee_img
          ) as employee_details
        FROM employee_task_tracking ett
        LEFT JOIN employees e ON ett.employee_id = e.employee_id
        WHERE ett.task_id = @task_id
        ORDER BY ett.started_at DESC
      ''';

      final results = await DatabaseConnection.query(
        query,
        values: {'task_id': taskId},
      );

      return results.map((row) => EmployeeTaskTracking.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting task usage by task ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task usage by employee ID
  Future<List<EmployeeTaskTracking>> getTaskUsageByEmployeeId(
    String employeeId,
  ) async {
    try {
      final query = '''
        SELECT 
          ett.*,
          json_build_object(
            'task_id', tc.task_id,
            'task_name', tc.task_name,
            'task_type', tc.task_type,
            'priority_level', tc.priority_level,
            'workflow_status', tc.workflow_status
          ) as task_details
        FROM employee_task_tracking ett
        LEFT JOIN task_cards tc ON ett.task_id = tc.task_id
        WHERE ett.employee_id = @employee_id
        ORDER BY ett.started_at DESC
      ''';

      final results = await DatabaseConnection.query(
        query,
        values: {'employee_id': employeeId},
      );

      return results.map((row) => EmployeeTaskTracking.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting task usage by employee ID: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if task is delayed and get delay info
  Future<Map<String, dynamic>> checkTaskDelay(String taskId) async {
    try {
      final query = '''
        SELECT 
          tc.task_id,
          tc.to_date as expected_completion,
          tc.workflow_status,
          COALESCE(SUM(ett.total_hours), 0) as total_hours_spent,
          CASE 
            WHEN tc.to_date < CURRENT_DATE AND tc.workflow_status != 'Work Done' THEN true
            ELSE false
          END as is_delayed,
          CASE 
            WHEN tc.to_date < CURRENT_DATE AND tc.workflow_status != 'Work Done' 
            THEN CURRENT_DATE - tc.to_date
            ELSE 0
          END as delay_days
        FROM task_cards tc
        LEFT JOIN employee_task_tracking ett ON tc.task_id = ett.task_id
        WHERE tc.task_id = @task_id
        GROUP BY tc.task_id, tc.to_date, tc.workflow_status
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'task_id': taskId},
      );

      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error checking task delay: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get active tracking session for employee on a task
  Future<EmployeeTaskTracking?> getActiveTrackingSession(
    String taskId,
    String employeeId,
  ) async {
    try {
      final query = '''
        SELECT * FROM employee_task_tracking
        WHERE task_id = @task_id 
          AND employee_id = @employee_id
          AND completed_at IS NULL
        ORDER BY started_at DESC
        LIMIT 1
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'task_id': taskId, 'employee_id': employeeId},
      );

      return result != null ? EmployeeTaskTracking.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting active tracking session: $e', e, stackTrace);
      rethrow;
    }
  }
}
