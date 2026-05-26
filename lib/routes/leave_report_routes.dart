import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/leave_report_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Leave Report Routes Handler
/// Handles consolidated leave report endpoints for admin
class LeaveReportRoutes {
  final Router _router = Router();
  final LeaveReportService _service = LeaveReportService();
  final AppLogger _logger = AppLogger('LeaveReportRoutes');

  Router get router {
    // Get consolidated report for all employees
    _router.get('/leave-report/consolidated', _getConsolidatedReport);

    // Get detailed report for a specific employee
    _router.get(
      '/leave-report/employee/<employeeId>/detail',
      _getEmployeeDetailReport,
    );

    // Export consolidated report as Excel
    _router.get('/leave-report/export/consolidated', _exportConsolidatedExcel);

    // Export employee detail report as Excel
    _router.get(
      '/leave-report/export/employee/<employeeId>',
      _exportEmployeeExcel,
    );

    // Get leave policy configuration
    _router.get('/leave-report/policy', _getPolicyConfig);

    // Update leave policy configuration
    _router.put('/leave-report/policy', _updatePolicyConfig);

    return _router;
  }

  /// GET /admin/leave-report/consolidated
  /// Get consolidated leave report for all employees for a specific month
  Future<Response> _getConsolidatedReport(Request request) async {
    try {
      _logger.info('GET /leave-report/consolidated');

      final queryParams = request.url.queryParameters;

      // Validate required parameters
      final monthStr = queryParams['month'];
      final yearStr = queryParams['year'];

      if (monthStr == null || yearStr == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'month and year are required query parameters',
        ).toShelfResponse(statusCode: 400);
      }

      final month = int.tryParse(monthStr);
      final year = int.tryParse(yearStr);

      if (month == null || month < 1 || month > 12) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Invalid month. Must be between 1 and 12',
        ).toShelfResponse(statusCode: 400);
      }

      if (year == null || year < 2000 || year > 2100) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Invalid year',
        ).toShelfResponse(statusCode: 400);
      }

      final search = queryParams['search'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '50') ?? 50;

      final result = await _service.getConsolidatedReport(
        month: month,
        year: year,
        search: search,
        page: page,
        limit: limit,
      );

      return ApiResponse.success(
        message: 'Consolidated report fetched successfully',
        data: result,
      ).toShelfResponse();
    } on AppException catch (e) {
      _logger.error('Error in getConsolidatedReport: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error in getConsolidatedReport: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch consolidated report: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/leave-report/employee/:employeeId/detail
  /// Get detailed leave report for a specific employee
  Future<Response> _getEmployeeDetailReport(
    Request request,
    String employeeId,
  ) async {
    try {
      _logger.info('GET /leave-report/employee/$employeeId/detail');

      final queryParams = request.url.queryParameters;
      final yearStr = queryParams['year'];
      final year = yearStr != null ? int.tryParse(yearStr) : null;

      final result = await _service.getEmployeeDetailReport(
        employeeId: employeeId,
        year: year,
      );

      return ApiResponse.success(
        message: 'Employee detailed report fetched successfully',
        data: result,
      ).toShelfResponse();
    } on AppException catch (e) {
      _logger.error('Error in getEmployeeDetailReport: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error in getEmployeeDetailReport: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch employee detail report: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/leave-report/export/consolidated
  /// Export consolidated report as Excel file
  Future<Response> _exportConsolidatedExcel(Request request) async {
    try {
      _logger.info('GET /leave-report/export/consolidated');

      final queryParams = request.url.queryParameters;

      final monthStr = queryParams['month'];
      final yearStr = queryParams['year'];

      if (monthStr == null || yearStr == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'month and year are required query parameters',
        ).toShelfResponse(statusCode: 400);
      }

      final month = int.tryParse(monthStr);
      final year = int.tryParse(yearStr);

      if (month == null || month < 1 || month > 12) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Invalid month. Must be between 1 and 12',
        ).toShelfResponse(statusCode: 400);
      }

      if (year == null || year < 2000 || year > 2100) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Invalid year',
        ).toShelfResponse(statusCode: 400);
      }

      final excelBytes = await _service.generateConsolidatedExcel(
        month: month,
        year: year,
      );

      final monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final monthName = monthNames[month - 1];
      final fileName = 'Leave_Report_${monthName}_$year.xlsx';

      return Response.ok(
        excelBytes,
        headers: {
          'Content-Type':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'Content-Disposition': 'attachment; filename="$fileName"',
          'Content-Length': excelBytes.length.toString(),
        },
      );
    } on AppException catch (e) {
      _logger.error('Error in exportConsolidatedExcel: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error in exportConsolidatedExcel: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to export consolidated report: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/leave-report/export/employee/:employeeId
  /// Export employee detail report as Excel file
  Future<Response> _exportEmployeeExcel(
    Request request,
    String employeeId,
  ) async {
    try {
      _logger.info('GET /leave-report/export/employee/$employeeId');

      final queryParams = request.url.queryParameters;
      final yearStr = queryParams['year'];
      final year = yearStr != null ? int.tryParse(yearStr) : null;

      final excelBytes = await _service.generateEmployeeDetailExcel(
        employeeId: employeeId,
        year: year,
      );

      final yearSuffix = year != null ? '_$year' : '';
      final fileName = 'Leave_Report_$employeeId$yearSuffix.xlsx';

      return Response.ok(
        excelBytes,
        headers: {
          'Content-Type':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'Content-Disposition': 'attachment; filename="$fileName"',
          'Content-Length': excelBytes.length.toString(),
        },
      );
    } on AppException catch (e) {
      _logger.error('Error in exportEmployeeExcel: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error in exportEmployeeExcel: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to export employee report: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/leave-report/policy
  /// Get current leave policy configuration
  Future<Response> _getPolicyConfig(Request request) async {
    try {
      _logger.info('GET /leave-report/policy');

      final policy = await _service.getLeavePolicyConfig();

      return ApiResponse.success(
        message: 'Leave policy fetched successfully',
        data: policy.toJson(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Unexpected error in getPolicyConfig: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch policy configuration: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /admin/leave-report/policy
  /// Update leave policy configuration
  Future<Response> _updatePolicyConfig(Request request) async {
    try {
      _logger.info('PUT /leave-report/policy');

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Get admin ID from request context
      final adminId = request.context['userId']?.toString() ?? 'system';

      final allowedLeave = data['allowed_leave_days_per_month'];
      final allowedPermission = data['allowed_permission_hours_per_month'];
      final allowedWfh = data['allowed_wfh_days_per_month'];

      if (allowedLeave == null ||
          allowedPermission == null ||
          allowedWfh == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message:
              'allowed_leave_days_per_month, allowed_permission_hours_per_month, and allowed_wfh_days_per_month are required',
        ).toShelfResponse(statusCode: 400);
      }

      final policy = await _service.updateLeavePolicyConfig(
        allowedLeaveDaysPerMonth: (allowedLeave as num).toInt(),
        allowedPermissionHoursPerMonth: (allowedPermission as num).toDouble(),
        allowedWfhDaysPerMonth: (allowedWfh as num).toInt(),
        updatedBy: adminId,
      );

      return ApiResponse.success(
        message: 'Leave policy updated successfully',
        data: policy.toJson(),
      ).toShelfResponse();
    } on AppException catch (e) {
      _logger.error('Error in updatePolicyConfig: ${e.message}');
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected error in updatePolicyConfig: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update policy configuration: ${e.toString()}',
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
