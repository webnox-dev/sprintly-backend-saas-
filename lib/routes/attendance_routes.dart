import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/attendance_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Attendance routes handler
class AttendanceRoutes {
  final AttendanceService _service = AttendanceService();
  final AppLogger _logger = AppLogger('AttendanceRoutes');

  Router get router {
    final router = Router();

    // GET /api/attendance - Get all attendance records
    router.get('/attendance', _getAllAttendance);

    // GET /api/attendance/today - Get today's attendance
    router.get('/attendance/today', _getTodayAttendance);

    // GET /api/attendance/:id - Get attendance by ID
    router.get('/attendance/<id>', _getAttendanceById);

    // GET /api/attendance/employee/:employeeId - Get attendance by employee
    router.get('/attendance/employee/<employeeId>', _getEmployeeAttendance);

    // GET /api/attendance/employee/:employeeId/date/:date - Get attendance for specific date
    router.get(
      '/attendance/employee/<employeeId>/date/<date>',
      _getEmployeeAttendanceByDate,
    );

    // GET /api/attendance/employee/:employeeId/summary - Get employee summary
    router.get(
      '/attendance/employee/<employeeId>/summary',
      _getEmployeeSummary,
    );

    // POST /api/attendance - Create attendance record
    router.post('/attendance', _createAttendance);

    // POST /api/attendance/punch-in - Punch in for the day
    router.post('/attendance/punch-in', _punchIn);

    // PUT /api/attendance/:id/punch-out - Punch out for the day
    router.put('/attendance/<id>/punch-out', _punchOut);

    // PUT /api/attendance/:id - Update attendance record
    router.put('/attendance/<id>', _updateAttendance);

    // POST /api/attendance/:id/task - Add task to attendance
    router.post('/attendance/<id>/task', _addTask);

    // DELETE /api/attendance/:id - Delete attendance record
    router.delete('/attendance/<id>', _deleteAttendance);

    return router;
  }

  /// GET /api/attendance
  Future<Response> _getAllAttendance(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final employeeId = params['employee_id'];
      final date = params['date'];
      final fromDate = params['from_date'];
      final toDate = params['to_date'];
      final sortBy = params['sort_by'];
      final ascending = params['order'] != 'desc';

      final result = await _service.getAllAttendance(
        page: page,
        limit: limit,
        employeeId: employeeId,
        date: date,
        fromDate: fromDate,
        toDate: toDate,
        sortBy: sortBy,
        ascending: ascending,
      );

      return ApiResponse.success(
        data: (result['data'] as List).map((e) => e.toJson()).toList(),
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
          'totalPages': result['totalPages'],
          'hasNext': result['page'] < result['totalPages'],
          'hasPrev': result['page'] > 1,
        },
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _getAllAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/attendance/today
  Future<Response> _getTodayAttendance(Request request) async {
    try {
      final attendances = await _service.getTodayAttendance();
      return ApiResponse.success(
        data: attendances.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getTodayAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/attendance/:id
  Future<Response> _getAttendanceById(Request request, String id) async {
    try {
      final attendance = await _service.getAttendanceById(id);
      return ApiResponse.success(data: attendance.toJson()).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Attendance record not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _getAttendanceById: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/attendance/employee/:employeeId
  Future<Response> _getEmployeeAttendance(
    Request request,
    String employeeId,
  ) async {
    try {
      final params = request.url.queryParameters;
      // Calculate dates in IST (UTC+5:30)
      final nowUtc = DateTime.now().toUtc();
      final istOffset = Duration(hours: 5, minutes: 30);
      final nowIst = nowUtc.add(istOffset);
      final fromDate =
          params['from_date'] ??
          nowIst
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .split('T')[0];
      final toDate =
          params['to_date'] ?? nowIst.toIso8601String().split('T')[0];

      final attendances = await _service.getEmployeeAttendanceRange(
        employeeId,
        fromDate,
        toDate,
      );

      return ApiResponse.success(
        data: attendances.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getEmployeeAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/attendance/employee/:employeeId/date/:date
  /// Returns ALL attendance records for the specified date (to support multiple punch-in/out sessions)
  Future<Response> _getEmployeeAttendanceByDate(
    Request request,
    String employeeId,
    String date,
  ) async {
    try {
      // Use getEmployeeAttendanceRange with same date for from and to
      // This returns ALL records for that date (supporting multiple punch-in/out sessions)
      final attendances = await _service.getEmployeeAttendanceRange(
        employeeId,
        date,
        date,
      );

      if (attendances.isEmpty) {
        return ApiResponse.success(data: []).toShelfResponse();
      }

      // Return list of all attendance records for the date
      return ApiResponse.success(
        data: attendances.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getEmployeeAttendanceByDate: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/attendance/employee/:employeeId/summary
  Future<Response> _getEmployeeSummary(
    Request request,
    String employeeId,
  ) async {
    try {
      final params = request.url.queryParameters;
      // Calculate dates in IST (UTC+5:30)
      final nowUtc = DateTime.now().toUtc();
      final istOffset = Duration(hours: 5, minutes: 30);
      final nowIst = nowUtc.add(istOffset);
      final fromDate =
          params['from_date'] ??
          nowIst
              .subtract(const Duration(days: 30))
              .toIso8601String()
              .split('T')[0];
      final toDate =
          params['to_date'] ?? nowIst.toIso8601String().split('T')[0];

      final summary = await _service.getEmployeeSummary(
        employeeId,
        fromDate,
        toDate,
      );
      return ApiResponse.success(data: summary).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getEmployeeSummary: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/attendance
  Future<Response> _createAttendance(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final attendance = await _service.createAttendance(data);

      return ApiResponse.success(
        data: attendance.toJson(),
        message: 'Attendance record created successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on ConflictException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 409);
    } catch (e, stackTrace) {
      _logger.error('Error in _createAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/attendance/punch-in
  Future<Response> _punchIn(Request request) async {
    try {
      final body = await request.readAsString();
      _logger.info('Punch-in request body: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;

      final attendance = await _service.punchIn(data);

      return ApiResponse.success(
        data: attendance.toJson(),
        message: 'Punched in successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      _logger.warning('Validation error in punch-in: ${e.errors}');
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on ConflictException catch (e) {
      _logger.warning('Conflict error in punch-in: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 409);
    } catch (e, stackTrace) {
      _logger.error(
        'Error in _punchIn: $e\nType: ${e.runtimeType}\nStack: $stackTrace',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/attendance/:id/punch-out
  Future<Response> _punchOut(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final attendance = await _service.punchOut(id, data);

      return ApiResponse.success(
        data: attendance.toJson(),
        message: 'Punched out successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Attendance record not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _punchOut: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/attendance/:id
  Future<Response> _updateAttendance(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final attendance = await _service.updateAttendance(id, data);

      return ApiResponse.success(
        data: attendance.toJson(),
        message: 'Attendance record updated successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Attendance record not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _updateAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/attendance/:id/task
  Future<Response> _addTask(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final task = data['task'] as Map<String, dynamic>?;
      final updatedBy = data['updated_by']?.toString();

      if (task == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Task data is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (updatedBy == null || updatedBy.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Updated by is required',
        ).toShelfResponse(statusCode: 400);
      }

      final attendance = await _service.addTask(id, task, updatedBy);

      return ApiResponse.success(
        data: attendance.toJson(),
        message: 'Task added successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Attendance record not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _addTask: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/attendance/:id
  Future<Response> _deleteAttendance(Request request, String id) async {
    try {
      await _service.deleteAttendance(id);
      return ApiResponse.success(
        message: 'Attendance record deleted successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Attendance record not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _deleteAttendance: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// Get HTTP status code from exception
  int _getStatusCode(AppException e) {
    switch (e.code) {
      case 'NOT_FOUND':
        return 404;
      case 'VALIDATION_ERROR':
        return 400;
      case 'UNAUTHORIZED':
        return 401;
      case 'CONFLICT':
        return 409;
      case 'DATABASE_ERROR':
        return 500;
      default:
        return 500;
    }
  }
}
