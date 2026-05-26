import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/leave_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Leave routes handler
class LeaveRoutes {
  final LeaveService _leaveService = LeaveService();
  final AppLogger _logger = AppLogger('LeaveRoutes');
  final Router _router = Router();

  Router get router {
    // GET /leave - Get all leaves with filters
    _router.get('/leave', _getAllLeaves);

    // GET /leave/pending - Get pending leaves (for admin)
    _router.get('/leave/pending', _getPendingLeaves);

    // GET /leave/:id - Get leave by ID
    _router.get('/leave/<id>', _getLeaveById);

    // GET /leave/employee/:employeeId - Get leaves by employee
    _router.get('/leave/employee/<employeeId>', _getEmployeeLeaves);

    // GET /leave/employee/:employeeId/statistics - Get employee leave statistics
    _router.get(
      '/leave/employee/<employeeId>/statistics',
      _getEmployeeStatistics,
    );

    // POST /leave - Create leave request
    _router.post('/leave', _createLeave);

    // PUT /leave/:id - Update leave request
    _router.put('/leave/<id>', _updateLeave);

    // PUT /leave/:id/approve - Approve leave request
    _router.put('/leave/<id>/approve', _approveLeave);

    // PUT /leave/:id/reject - Reject leave request
    _router.put('/leave/<id>/reject', _rejectLeave);

    // DELETE /leave/:id - Delete leave request
    _router.delete('/leave/<id>', _deleteLeave);

    return _router;
  }

  /// GET /leave
  Future<Response> _getAllLeaves(Request request) async {
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

      final result = await _leaveService.getAllLeaves(
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
      _logger.error('Error getting all leaves', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch leaves',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /leave/pending
  Future<Response> _getPendingLeaves(Request request) async {
    try {
      final leaves = await _leaveService.getPendingLeaveRequests();
      return ApiResponse.success(
        data: leaves.map((l) => l.toJson()).toList(),
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting pending leaves', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch pending leaves',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /leave/:id
  Future<Response> _getLeaveById(Request request, String id) async {
    try {
      final leave = await _leaveService.getLeaveById(id);
      if (leave == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Leave request not found',
        ).toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(data: leave.toJson()).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting leave by ID', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch leave',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /leave/employee/:employeeId
  Future<Response> _getEmployeeLeaves(
    Request request,
    String employeeId,
  ) async {
    try {
      final leaves = await _leaveService.getLeavesByEmployeeId(employeeId);
      return ApiResponse.success(
        data: leaves.map((l) => l.toJson()).toList(),
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error getting employee leaves', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch employee leaves',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /leave/employee/:employeeId/statistics
  Future<Response> _getEmployeeStatistics(
    Request request,
    String employeeId,
  ) async {
    try {
      final stats = await _leaveService.getEmployeeLeaveStatistics(employeeId);
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
        message: 'Failed to fetch leave statistics',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /leave
  Future<Response> _createLeave(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields - only employee_id is mandatory
      if (data['employee_id'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Missing required field: employee_id',
        ).toShelfResponse(statusCode: 400);
      }

      // Handle is_paid_leave as either bool or int (1/0)
      bool isPaidLeave = false;
      if (data['is_paid_leave'] != null) {
        if (data['is_paid_leave'] is bool) {
          isPaidLeave = data['is_paid_leave'] as bool;
        } else if (data['is_paid_leave'] is int) {
          isPaidLeave = (data['is_paid_leave'] as int) == 1;
        }
      }

      // Handle is_half_day as either bool or int (1/0)
      bool isHalfDay = false;
      if (data['is_half_day'] != null) {
        if (data['is_half_day'] is bool) {
          isHalfDay = data['is_half_day'] as bool;
        } else if (data['is_half_day'] is int) {
          isHalfDay = (data['is_half_day'] as int) == 1;
        }
      }

      // Handle total_leave_days as num (can be int, double, or string)
      num? totalLeaveDays;
      if (data['total_leave_days'] != null) {
        final rawDays = data['total_leave_days'];
        if (rawDays is num) {
          totalLeaveDays = rawDays;
        } else if (rawDays is String) {
          totalLeaveDays = num.tryParse(rawDays);
        } else {
          totalLeaveDays = num.tryParse(rawDays.toString());
        }
      }

      // Handle leave_status as int (can be int or string)
      int? leaveStatus;
      if (data['leave_status'] != null) {
        final rawStatus = data['leave_status'];
        if (rawStatus is int) {
          leaveStatus = rawStatus;
        } else if (rawStatus is String) {
          leaveStatus = int.tryParse(rawStatus);
        } else {
          leaveStatus = int.tryParse(rawStatus.toString());
        }
      }

      // Handle selected_dates - can be list or JSON string
      List<dynamic>? selectedDatesList;
      if (data['selected_dates'] != null) {
        if (data['selected_dates'] is List) {
          selectedDatesList = data['selected_dates'] as List<dynamic>;
        } else if (data['selected_dates'] is String) {
          try {
            selectedDatesList =
                jsonDecode(data['selected_dates'] as String) as List<dynamic>;
          } catch (_) {}
        }
      }

      final leave = await _leaveService.createLeaveRequest(
        employeeId: data['employee_id'] as String,
        leaveFromDate: data['leave_from_date']?.toString(),
        leaveToDate: data['leave_to_date']?.toString(),
        leaveRemarks: data['leave_remarks']?.toString(),
        isPaidLeave: isPaidLeave,
        leaveApprovalRejectionRemarks: data['leave_approval_rejection_remarks']
            ?.toString(),
        leaveStatus: leaveStatus,
        leaveType: data['leave_type']?.toString(),
        selectedDatesList: selectedDatesList,
        totalLeaveDays: totalLeaveDays,
        isHalfDay: isHalfDay,
        halfDayType: data['half_day_type']?.toString(),
      );

      return ApiResponse.success(
        data: leave.toJson(),
        message: 'Leave request created successfully',
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
      _logger.error('Error creating leave', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to create leave request: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /leave/:id
  Future<Response> _updateLeave(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final leave = await _leaveService.updateLeaveRequest(id, data);
      if (leave == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Leave request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: leave.toJson(),
        message: 'Leave request updated successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error updating leave', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update leave request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /leave/:id/approve
  Future<Response> _approveLeave(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['approved_by'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'approved_by is required',
        ).toShelfResponse(statusCode: 400);
      }

      final leave = await _leaveService.approveLeaveRequest(
        leaveId: id,
        approvedBy: data['approved_by'] as String,
        leaveApprovalRejectionRemarks: data['remarks']?.toString(),
      );

      if (leave == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Leave request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: leave.toJson(),
        message: 'Leave request approved successfully',
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
      _logger.error('Error approving leave', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to approve leave request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /leave/:id/reject
  Future<Response> _rejectLeave(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['rejected_by'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'rejected_by is required',
        ).toShelfResponse(statusCode: 400);
      }

      final leave = await _leaveService.rejectLeaveRequest(
        leaveId: id,
        rejectedBy: data['rejected_by'] as String,
        leaveApprovalRejectionRemarks: data['remarks']?.toString(),
      );

      if (leave == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Leave request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: leave.toJson(),
        message: 'Leave request rejected successfully',
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
      _logger.error('Error rejecting leave', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to reject leave request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /leave/:id
  Future<Response> _deleteLeave(Request request, String id) async {
    try {
      final deleted = await _leaveService.deleteLeaveRequest(id);
      if (!deleted) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Leave request not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        message: 'Leave request deleted successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error deleting leave', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete leave request',
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
