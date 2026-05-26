import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/task_card_request_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// TaskCardRequest routes handler
/// Handles task card request flow for Admin approval and Employee requests
class TaskCardRequestRoutes {
  final TaskCardRequestService _service = TaskCardRequestService();
  final AppLogger _logger = AppLogger('TaskCardRequestRoutes');

  Router get router {
    final router = Router();

    // ==========================================
    // ADMIN ROUTES - /admin/task-card-requests
    // ==========================================

    // GET /admin/task-card-requests - getAllTaskCardRequests
    router.get('/admin/task-card-requests', _getAllTaskCardRequests);

    // GET /admin/task-card-requests/<requestId> - getTaskCardRequestById
    router.get(
      '/admin/task-card-requests/<requestId>',
      _getTaskCardRequestById,
    );

    // POST /admin/task-card-requests/<requestId>/approve - approveTaskCardRequest
    router.post(
      '/admin/task-card-requests/<requestId>/approve',
      _approveTaskCardRequest,
    );

    // POST /admin/task-card-requests/<requestId>/reject - rejectTaskCardRequest
    router.post(
      '/admin/task-card-requests/<requestId>/reject',
      _rejectTaskCardRequest,
    );

    // ==========================================
    // EMPLOYEE ROUTES - /employee/task-card-requests
    // ==========================================

    // POST /employee/task-card-requests - createTaskCardRequest
    router.post('/employee/task-card-requests', _createTaskCardRequest);

    // GET /employee/task-card-requests - getEmployeeTaskCardRequests
    router.get('/employee/task-card-requests', _getEmployeeTaskCardRequests);

    // DELETE /employee/task-card-requests/<requestId> - cancelTaskCardRequest
    router.delete(
      '/employee/task-card-requests/<requestId>',
      _cancelTaskCardRequest,
    );

    return router;
  }

  // ==========================================
  // ADMIN HANDLERS
  // ==========================================

  /// GET /admin/task-card-requests - Get all task card requests
  Future<Response> _getAllTaskCardRequests(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final status = params['status'];
      final employeeId = params['employee_id'];
      final projectId = params['project_id'];
      final search = params['search'];

      final result = await _service.getAllTaskCardRequests(
        page: page,
        limit: limit,
        status: status,
        employeeId: employeeId,
        projectId: projectId,
        search: search,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
          'totalPages': result['totalPages'],
          'hasNext': result['page'] < result['totalPages'],
          'hasPrev': result['page'] > 1,
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getAllTaskCardRequests: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/task-card-requests/<requestId> - Get request by ID
  Future<Response> _getTaskCardRequestById(
    Request request,
    String requestId,
  ) async {
    try {
      final taskRequest = await _service.getTaskCardRequestById(requestId);
      return ApiResponse.success(data: taskRequest.toJson()).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card request');
    } catch (e, stackTrace) {
      _logger.error('Error in getTaskCardRequestById: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /admin/task-card-requests/<requestId>/approve - Approve request
  Future<Response> _approveTaskCardRequest(
    Request request,
    String requestId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = body.isNotEmpty
          ? jsonDecode(body) as Map<String, dynamic>
          : {};
      final approvedBy =
          data['approved_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';
      final remarks = data['remarks']?.toString();

      final taskRequest = await _service.approveTaskCardRequest(
        requestId,
        approvedBy,
        remarks,
      );

      // Notification is handled by TaskCardRequestService

      return ApiResponse.success(
        data: taskRequest.toJson(),
        message: 'Task card request approved successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card request');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in approveTaskCardRequest: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /admin/task-card-requests/<requestId>/reject - Reject request
  Future<Response> _rejectTaskCardRequest(
    Request request,
    String requestId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rejectedBy =
          data['rejected_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';
      final reason = data['reason']?.toString() ?? '';

      if (reason.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Reason is required for rejection',
        ).toShelfResponse(statusCode: 400);
      }

      final taskRequest = await _service.rejectTaskCardRequest(
        requestId,
        rejectedBy,
        reason,
      );

      // Notification is handled by TaskCardRequestService

      return ApiResponse.success(
        data: taskRequest.toJson(),
        message: 'Task card request rejected',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card request');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in rejectTaskCardRequest: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // EMPLOYEE HANDLERS
  // ==========================================

  /// POST /employee/task-card-requests - Create new request
  Future<Response> _createTaskCardRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taskRequest = await _service.createTaskCardRequest(
        data,
        employeeId,
      );

      // Notification is handled by TaskCardRequestService

      return ApiResponse.success(
        data: taskRequest.toJson(),
        message: 'Task card request submitted successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in createTaskCardRequest: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /employee/task-card-requests - Get employee's requests
  Future<Response> _getEmployeeTaskCardRequests(Request request) async {
    try {
      final employeeId =
          request.url.queryParameters['employee_id'] ??
          request.headers['x-employee-id'] ??
          '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final requests = await _service.getEmployeeTaskCardRequests(employeeId);

      return ApiResponse.success(
        data: requests.map((r) => r.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeeTaskCardRequests: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// DELETE /employee/task-card-requests/<requestId> - Cancel request
  Future<Response> _cancelTaskCardRequest(
    Request request,
    String requestId,
  ) async {
    try {
      final employeeId =
          request.url.queryParameters['employee_id'] ??
          request.headers['x-employee-id'] ??
          '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      await _service.cancelTaskCardRequest(requestId, employeeId);

      return ApiResponse.success(
        message: 'Task card request cancelled successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card request');
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: 'UNAUTHORIZED',
        message: e.message,
      ).toShelfResponse(statusCode: 403);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in cancelTaskCardRequest: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Response _notFound(String resource) {
    return ApiResponse.error(
      code: 'NOT_FOUND',
      message: '$resource not found',
    ).toShelfResponse(statusCode: 404);
  }

  Response _internalError() {
    return ApiResponse.error(
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    ).toShelfResponse(statusCode: 500);
  }
}
