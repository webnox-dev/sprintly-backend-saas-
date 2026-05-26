import '../../../domain/models/task_card.dart';
import '../../database/connection.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/logger.dart';
import 'task_card_query_builder.dart';
import 'task_usage_tracking_helper.dart';

/// Additional Task Card Repository Methods
/// New methods for search, filtering, and task usage tracking
class TaskCardRepositoryExtensions {
  final AppLogger _logger = AppLogger('TaskCardRepositoryExtensions');
  final TaskUsageTrackingHelper _usageHelper = TaskUsageTrackingHelper();

  // ==========================================
  // SEARCH & FILTER METHODS
  // ==========================================

  /// Search task cards across task name, employee name, project name
  Future<List<TaskCard>> searchTaskCards(String query, {int limit = 50}) async {
    try {
      final sql = TaskCardQueryBuilder.searchTaskCardsQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'query': '%$query%', 'limit': limit},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error searching task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task cards for a specific date (calendar view)
  Future<List<TaskCard>> getTaskCardsByDate(DateTime date) async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCardsByDateQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date.toIso8601String().split('T')[0]},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting tasks by date: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task count by status (for kanban headers)
  Future<Map<String, int>> getTaskCountByStatus() async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCountByStatusQuery();
      final results = await DatabaseConnection.query(sql);

      final counts = <String, int>{};
      for (final row in results) {
        counts[row['workflow_status'] as String] = (row['count'] as num)
            .toInt();
      }
      return counts;
    } catch (e, stackTrace) {
      _logger.error('Error getting task count by status: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // TASK USAGE TRACKING METHODS
  // ==========================================

  /// Clock in to a task
  Future<EmployeeTaskTracking> clockInToTask(
    String taskId,
    String employeeId,
    String? notes,
  ) async {
    try {
      // Check if already clocked in
      final activeSession = await _usageHelper.getActiveTrackingSession(
        taskId,
        employeeId,
      );
      if (activeSession != null) {
        throw ValidationException({
          'tracking': ['Employee already clocked in to this task'],
        });
      }

      return await _usageHelper.clockInToTask(taskId, employeeId, notes);
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
      return await _usageHelper.clockOutFromTask(trackingId, notes);
    } catch (e, stackTrace) {
      _logger.error('Error clocking out from task: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Pause task tracking
  Future<EmployeeTaskTracking> pauseTaskTracking(String trackingId) async {
    try {
      return await _usageHelper.pauseTaskTracking(trackingId);
    } catch (e, stackTrace) {
      _logger.error('Error pausing task tracking: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task usage statistics
  Future<Map<String, dynamic>> getTaskUsageStats(String taskId) async {
    try {
      final usage = await _usageHelper.getTaskUsageByTaskId(taskId);
      final delayInfo = await _usageHelper.checkTaskDelay(taskId);

      return {
        'task_id': taskId,
        'total_tracking_sessions': usage.length,
        'total_hours': usage.fold(0.0, (sum, t) => sum + (t.totalHours ?? 0)),
        'is_delayed': delayInfo['is_delayed'],
        'delay_days': delayInfo['delay_days'],
        'expected_completion': delayInfo['expected_completion'],
        'tracking_sessions': usage.map((t) => t.toJson()).toList(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting task usage stats: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee task usage
  Future<List<EmployeeTaskTracking>> getEmployeeTaskUsage(
    String employeeId,
  ) async {
    try {
      return await _usageHelper.getTaskUsageByEmployeeId(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting employee task usage: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get active tracking session for employee
  Future<EmployeeTaskTracking?> getActiveTrackingSession(
    String taskId,
    String employeeId,
  ) async {
    try {
      return await _usageHelper.getActiveTrackingSession(taskId, employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting active tracking session: $e', e, stackTrace);
      rethrow;
    }
  }
}
