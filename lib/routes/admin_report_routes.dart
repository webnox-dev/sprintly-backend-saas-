import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/admin_report_service.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

/// Routes for admin to manage employee reports
class AdminReportRoutes {
  final AdminReportService _service = AdminReportService();
  final AppLogger _logger = AppLogger('AdminReportRoutes');

  Router get router {
    final router = Router();

    // POST /admin/reports/all - Get all employee reports with filters
    router.post('/admin/reports/all', _getAllEmployeeReports);

    // POST /admin/reports/status - Get employees who reported/not reported
    router.post('/admin/reports/status', _getEmployeeReportStatus);

    // POST /admin/reports/details - Get detailed report for a specific employee and date
    router.post('/admin/reports/details', _getReportDetailsById);

    // GET /admin/reports/debug - Debug endpoint to check raw data
    router.get('/admin/reports/debug', _debugReportsData);

    return router;
  }

  /// GET /admin/reports/debug - Debug endpoint to see raw employee_reports data
  Future<Response> _debugReportsData(Request request) async {
    try {
      final result = await _service.getDebugReportsData();
      return ApiResponse.success(data: result).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in debug: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Debug failed: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /admin/reports/all
  /// Get all employee reports with filters and pagination
  /// Request body: {
  ///   search, employee_id, employee_name, designation, date,
  ///   from_date, to_date, status, page, limit, sort_by, sort_order
  /// }
  Future<Response> _getAllEmployeeReports(Request request) async {
    try {
      final body = await request.readAsString();
      Map<String, dynamic> data = {};

      if (body.isNotEmpty) {
        data = jsonDecode(body) as Map<String, dynamic>;
      }

      final result = await _service.getAllEmployeeReports(
        search: data['search']?.toString(),
        employeeId: data['employee_id']?.toString(),
        employeeName: data['employee_name']?.toString(),
        designation: data['designation']?.toString(),
        date: data['date']?.toString(),
        fromDate: data['from_date']?.toString(),
        toDate: data['to_date']?.toString(),
        status: data['status']?.toString(),
        page: int.tryParse(data['page']?.toString() ?? '1') ?? 1,
        limit: int.tryParse(data['limit']?.toString() ?? '10') ?? 10,
        sortBy: data['sort_by']?.toString(),
        sortOrder: data['sort_order']?.toString(),
      );

      return ApiResponse.success(
        data: {'reports': result['reports'], 'summary': result['summary']},
        pagination: result['pagination'],
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching employee reports: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch employee reports: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /admin/reports/status
  /// Get employees who reported/not reported on a specific date
  /// Request body: { date (required), search, designation, status, page, limit }
  /// status can be: 'reported', 'not_reported', or null/empty for all
  Future<Response> _getEmployeeReportStatus(Request request) async {
    try {
      final body = await request.readAsString();

      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final date = data['date']?.toString();
      if (date == null || date.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Date is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getEmployeeReportStatus(
        date: date,
        search: data['search']?.toString(),
        designation: data['designation']?.toString(),
        status: data['status']?.toString(),
        page: int.tryParse(data['page']?.toString() ?? '1') ?? 1,
        limit: int.tryParse(data['limit']?.toString() ?? '10') ?? 10,
      );

      return ApiResponse.success(
        data: {'employees': result['employees'], 'summary': result['summary']},
        pagination: result['pagination'],
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching employee report status: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch employee report status: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /admin/reports/details
  /// Get detailed report for a specific employee and date
  /// Request body: { employee_id, report_id, date }
  Future<Response> _getReportDetailsById(Request request) async {
    try {
      final body = await request.readAsString();

      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id']?.toString();
      final reportId = data['report_id']?.toString();
      final date = data['date']?.toString();

      if (employeeId == null || reportId == null || date == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employee_id, report_id and date are required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getReportDetailsById(
        employeeId: employeeId,
        reportId: reportId,
        date: date,
      );

      if (result == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Report not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(data: result).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching report details: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch report details: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
