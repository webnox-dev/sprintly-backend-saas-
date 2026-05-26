import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/time_tracking_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class TimeTrackingRoutes {
  final TimeTrackingService _service = TimeTrackingService();
  final AppLogger _logger = AppLogger('TimeTrackingRoutes');

  Router get router {
    final router = Router();

    // Clock in to a task
    // POST /time-tracking/clock-in
    router.post('/clock-in', _clockIn);

    // Clock out from a task
    // POST /time-tracking/clock-out
    router.post('/clock-out', _clockOut);

    // Get current active session
    // GET /time-tracking/active?employee_id=XXX
    router.get('/active', _getActiveSession);

    // Clear stale sessions
    // POST /time-tracking/clear-stale
    router.post('/clear-stale', _clearStaleSessions);

    // Get task tracking history
    // GET /time-tracking/task/:taskId/history
    router.get('/task/<taskId>/history', _getTaskHistory);

    // Get task tracking summary
    // GET /time-tracking/task/:taskId/summary
    router.get('/task/<taskId>/summary', _getTaskSummary);

    // Get total hours for a task
    // GET /time-tracking/task/:taskId/hours
    router.get('/task/<taskId>/hours', _getTotalHours);

    // Get daily records for an employee
    // GET /time-tracking/daily?employee_id=XXX&work_date=YYYY-MM-DD
    router.get('/daily', _getDailyRecords);

    return router;
  }

  /// POST /time-tracking/clock-in
  Future<Response> _clockIn(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id'] as String?;
      final taskId = data['task_id'] as String?;
      final taskName = data['task_name'] as String?;
      final workDate = data['work_date'] as String?;
      final clockInTime = data['clock_in_time'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (taskId == null || taskId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'task_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.clockIn(
        employeeId: employeeId,
        taskId: taskId,
        taskName: taskName,
        workDate: workDate,
        clockInTime: clockInTime,
      );

      return ApiResponse.success(
        data: result,
        message: 'Clocked in successfully',
      ).toShelfResponse();
    } on ConflictException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: 'You are already clocked in to a task. Clock out first.',
      ).toShelfResponse(statusCode: 409);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error in clock in: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error clocking in: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /time-tracking/clock-out
  /// Supports optional clock_out_time for custom time selection
  Future<Response> _clockOut(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id'] as String?;
      final taskId = data['task_id'] as String?;
      final clockOutTimeStr = data['clock_out_time'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (taskId == null || taskId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'task_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Parse optional custom clock out time
      DateTime? customClockOutTime;
      if (clockOutTimeStr != null && clockOutTimeStr.isNotEmpty) {
        try {
          customClockOutTime = DateTime.parse(clockOutTimeStr);
          _logger.info('Using custom clock out time: $customClockOutTime');
        } catch (e) {
          _logger.warning('Failed to parse clock_out_time: $clockOutTimeStr');
        }
      }

      final result = await _service.clockOut(
        employeeId: employeeId,
        taskId: taskId,
        customClockOutTime: customClockOutTime,
      );

      return ApiResponse.success(
        data: result,
        message: 'Clocked out successfully',
      ).toShelfResponse();
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: 'No active session found for this task',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error in clock out: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error clocking out: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /time-tracking/active?employee_id=XXX
  Future<Response> _getActiveSession(Request request) async {
    try {
      final employeeId = request.url.queryParameters['employee_id'];

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getActiveSession(employeeId);

      if (result == null) {
        return ApiResponse.success(
          data: null,
          message: 'No active session',
        ).toShelfResponse();
      }

      return ApiResponse.success(
        data: result,
        message: 'Active session found',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error getting active session: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error getting active session: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /time-tracking/clear-stale
  Future<Response> _clearStaleSessions(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      final count = await _service.clearStaleSessions(employeeId);

      return ApiResponse.success(
        data: {'cleared_count': count},
        message: 'Cleared $count stale session(s)',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error clearing stale sessions: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error clearing stale sessions: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /time-tracking/task/:taskId/history
  Future<Response> _getTaskHistory(Request request, String taskId) async {
    try {
      final queryParams = request.url.queryParameters;
      final employeeId = queryParams['employee_id'];
      final startDate = queryParams['start_date'];
      final endDate = queryParams['end_date'];

      final result = await _service.getTaskHistory(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );

      return ApiResponse.success(
        data: result,
        message: 'Retrieved ${result.length} tracking records',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error getting task history: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error getting task history: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /time-tracking/task/:taskId/summary
  Future<Response> _getTaskSummary(Request request, String taskId) async {
    try {
      final queryParams = request.url.queryParameters;
      final employeeId = queryParams['employee_id'];
      final startDate = queryParams['start_date'];
      final endDate = queryParams['end_date'];

      final result = await _service.getTaskSummary(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );

      return ApiResponse.success(
        data: result,
        message: 'Task summary retrieved',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error getting task summary: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error getting task summary: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /time-tracking/task/:taskId/hours
  Future<Response> _getTotalHours(Request request, String taskId) async {
    try {
      final queryParams = request.url.queryParameters;
      final employeeId = queryParams['employee_id'];
      final startDate = queryParams['start_date'];
      final endDate = queryParams['end_date'];

      final result = await _service.getTotalHours(
        taskId: taskId,
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );

      return ApiResponse.success(
        data: {'total_hours': result},
        message: 'Total hours retrieved',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error getting total hours: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error getting total hours: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /time-tracking/daily?employee_id=XXX&work_date=YYYY-MM-DD
  Future<Response> _getDailyRecords(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final employeeId = queryParams['employee_id'];
      final workDate = queryParams['work_date'];

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (workDate == null || workDate.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'work_date is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getDailyRecords(
        employeeId: employeeId,
        workDate: workDate,
      );

      return ApiResponse.success(
        data: result,
        message: 'Retrieved ${result.length} daily records',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 500);
    } catch (e, stackTrace) {
      _logger.error('Error getting daily records: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'SERVER_ERROR',
        message: 'Error getting daily records: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
