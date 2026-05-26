import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../domain/services/employee_tracker_service.dart';
import '../core/utils/logger.dart';

/// Employee Tracker Routes for Admin
class EmployeeTrackerRoutes {
  final Router _router = Router();
  final EmployeeTrackerService _service = EmployeeTrackerService();
  final AppLogger _logger = AppLogger('EmployeeTrackerRoutes');

  Router get router {
    // GET /admin/employee-tracker - Get all employees with status for a date
    _router.get('/admin/employee-tracker', _getEmployeeTrackerList);

    // GET /admin/employee-tracker/export - Export employees to excel
    _router.get('/admin/employee-tracker/export', _exportEmployeeTracker);

    // GET /admin/employee-tracker/:employee_id/detail - Get detailed timeline
    _router.get(
      '/admin/employee-tracker/<employee_id>/detail',
      _getEmployeeTrackerDetail,
    );

    return _router;
  }

  /// GET /admin/employee-tracker
  /// Query params: date (required), search, status_filter, page, limit
  Future<Response> _getEmployeeTrackerList(Request request) async {
    try {
      final queryParams = request.url.queryParameters;

      // Validate required date parameter
      final date = queryParams['date'];
      if (date == null || date.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Date parameter is required (format: YYYY-MM-DD)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final search = queryParams['search'];
      final statusFilter = queryParams['status_filter'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;

      _logger.info(
        'GET /admin/employee-tracker - date: $date, search: $search, status: $statusFilter',
      );

      final result = await _service.getEmployeeTrackerList(
        date: date,
        search: search,
        statusFilter: statusFilter,
        page: page,
        limit: limit,
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Employee tracker data fetched successfully',
          'data': {
            'date': date,
            'summary': result['summary'],
            'employees': result['employees'],
            'pagination': result['pagination'],
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error fetching employee tracker list: $e', e, stackTrace);

      if (e is ArgumentError) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to fetch employee tracker data',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /admin/employee-tracker/:employee_id/detail
  /// Query params: date (required)
  Future<Response> _getEmployeeTrackerDetail(
    Request request,
    String employeeId,
  ) async {
    try {
      final queryParams = request.url.queryParameters;

      // Validate required date parameter
      final date = queryParams['date'];
      if (date == null || date.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Date parameter is required (format: YYYY-MM-DD)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      _logger.info(
        'GET /admin/employee-tracker/$employeeId/detail - date: $date',
      );

      final result = await _service.getEmployeeTrackerDetail(
        employeeId: employeeId,
        date: date,
      );

      if (result == null) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'Employee not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Employee tracker detail fetched successfully',
          'data': result,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching employee tracker detail: $e',
        e,
        stackTrace,
      );

      if (e is ArgumentError) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to fetch employee tracker detail',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// GET /admin/employee-tracker/export
  /// Query params: date (required), search, status_filter
  Future<Response> _exportEmployeeTracker(Request request) async {
    try {
      final queryParams = request.url.queryParameters;

      // Validate required date parameter
      final date = queryParams['date'];
      if (date == null || date.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Date parameter is required (format: YYYY-MM-DD)',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final search = queryParams['search'];
      final statusFilter = queryParams['status_filter'];

      _logger.info(
        'GET /admin/employee-tracker/export - date: $date, search: $search, status: $statusFilter',
      );

      final excelBytes = await _service.exportEmployeeTrackerExcel(
        date: date,
        search: search,
        statusFilter: statusFilter,
      );

      return Response.ok(
        excelBytes,
        headers: {
          'Content-Type':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'Content-Disposition':
              'attachment; filename=employee_tracker_$date.xlsx',
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error exporting employee tracker: $e', e, stackTrace);

      if (e is ArgumentError) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': e.message}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to export employee tracker data',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
