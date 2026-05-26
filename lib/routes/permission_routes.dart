import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/permission_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Permission routes handler
class PermissionRoutes {
  final PermissionService _permissionService = PermissionService();
  final AppLogger _logger = AppLogger('PermissionRoutes');
  final Router _router = Router();

  Router get router {
    // GET /permissions - Get all permissions with filters
    _router.get('/permissions', _getAllPermissions);

    // GET /permissions/pending - Get pending permissions (for admin)
    _router.get('/permissions/pending', _getPendingPermissions);

    // GET /permissions/:id - Get permission by ID
    _router.get('/permissions/<id>', _getPermissionById);

    // GET /permissions/employee/:employeeId - Get permissions by employee
    _router.get('/permissions/employee/<employeeId>', _getEmployeePermissions);

    // GET /permissions/employee/:employeeId/statistics - Get employee permission statistics
    _router.get(
      '/permissions/employee/<employeeId>/statistics',
      _getEmployeeStatistics,
    );

    // POST /permissions - Create permission request
    _router.post('/permissions', _createPermission);

    // PUT /permissions/:id - Update permission request
    _router.put('/permissions/<id>', _updatePermission);

    // PUT /permissions/:id/approve - Approve permission request
    _router.put('/permissions/<id>/approve', _approvePermission);

    // PUT /permissions/:id/reject - Reject permission request
    _router.put('/permissions/<id>/reject', _rejectPermission);

    // DELETE /permissions/:id - Delete permission request
    _router.delete('/permissions/<id>', _deletePermission);

    return _router;
  }

  /// GET /permissions
  Future<Response> _getAllPermissions(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final employeeId = params['employee_id'];
      final status = params['status'];
      final fromDate = params['from_date'];
      final toDate = params['to_date'];

      if (fromDate != null && toDate != null) {
        final start = DateTime.tryParse(fromDate);
        final end = DateTime.tryParse(toDate);
        if (start != null && end != null && start.isAfter(end)) {
          return ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'From Date cannot be after To Date',
          ).toShelfResponse(statusCode: 400);
        }
      }
      final sortBy = params['sort_by'];
      final ascending = params['ascending'] == 'true';

      final result = await _permissionService.getAllPermissions(
        page: page,
        limit: limit,
        employeeId: employeeId,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
        sortBy: sortBy,
        ascending: ascending,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: result['pagination'],
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting all permissions', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch permissions',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /permissions/pending
  Future<Response> _getPendingPermissions(Request request) async {
    try {
      final permissions = await _permissionService
          .getPendingPermissionRequests();
      return ApiResponse.success(
        data: permissions.map((p) => p.toJson()).toList(),
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting pending permissions', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch pending permissions',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /permissions/:id
  Future<Response> _getPermissionById(Request request, String id) async {
    try {
      final permission = await _permissionService.getPermissionById(id);
      if (permission == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Permission request not found',
        ).toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(data: permission.toJson()).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting permission by ID', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch permission',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /permissions/employee/:employeeId
  Future<Response> _getEmployeePermissions(
    Request request,
    String employeeId,
  ) async {
    try {
      final permissions = await _permissionService.getPermissionsByEmployeeId(
        employeeId,
      );
      return ApiResponse.success(
        data: permissions.map((p) => p.toJson()).toList(),
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting employee permissions', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch employee permissions',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /permissions/employee/:employeeId/statistics
  Future<Response> _getEmployeeStatistics(
    Request request,
    String employeeId,
  ) async {
    try {
      final stats = await _permissionService.getEmployeePermissionStatistics(
        employeeId,
      );
      return ApiResponse.success(data: stats).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting employee statistics', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch permission statistics',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /permissions
  Future<Response> _createPermission(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      if (data['employee_id'] == null ||
          data['permission_date'] == null ||
          data['permission_from_time'] == null ||
          data['permission_to_time'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message:
              'Missing required fields: employee_id, permission_date, permission_from_time, permission_to_time',
        ).toShelfResponse(statusCode: 400);
      }

      final permission = await _permissionService.createPermissionRequest(
        employeeId: data['employee_id']?.toString() ?? '',
        permissionDate: data['permission_date']?.toString() ?? '',
        permissionFromTime: data['permission_from_time']?.toString() ?? '',
        permissionToTime: data['permission_to_time']?.toString() ?? '',
        requesterType: data['requester_type']?.toString() ?? 'Employee',
        permissionStatus: 0, // Default pending
        permissionRemarks: data['permission_remarks']?.toString(),
        createdBy:
            data['created_by']?.toString() ?? data['employee_id']?.toString(),
      );

      return ApiResponse.success(
        data: permission.toJson(),
        message: 'Permission request created successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error creating permission', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to create permission request: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /permissions/:id
  Future<Response> _updatePermission(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final permission = await _permissionService.updatePermissionRequest(
        id,
        data,
      );
      if (permission == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Permission request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: permission.toJson(),
        message: 'Permission request updated successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error updating permission', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update permission request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /permissions/:id/approve
  Future<Response> _approvePermission(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['approved_by'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'approved_by is required',
        ).toShelfResponse(statusCode: 400);
      }

      final permission = await _permissionService.approvePermissionRequest(
        permissionId: id,
        approvedBy: data['approved_by'] as String,
        permissionApprovalRejectionRemarks: data['remarks']?.toString(),
      );

      if (permission == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Permission request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: permission.toJson(),
        message: 'Permission request approved successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error approving permission', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to approve permission request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /permissions/:id/reject
  Future<Response> _rejectPermission(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['rejected_by'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'rejected_by is required',
        ).toShelfResponse(statusCode: 400);
      }

      final permission = await _permissionService.rejectPermissionRequest(
        permissionId: id,
        rejectedBy: data['rejected_by'] as String,
        permissionApprovalRejectionRemarks: data['remarks']?.toString(),
      );

      if (permission == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Permission request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: permission.toJson(),
        message: 'Permission request rejected successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error rejecting permission', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to reject permission request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /permissions/:id
  Future<Response> _deletePermission(Request request, String id) async {
    try {
      final deleted = await _permissionService.deletePermissionRequest(id);
      if (!deleted) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Permission request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        message: 'Permission request deleted successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error deleting permission', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete permission request',
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
      case 'FORBIDDEN':
        return 403;
      case 'CONFLICT':
        return 409;
      case 'DATABASE_ERROR':
        return 500;
      default:
        return 500;
    }
  }
}
