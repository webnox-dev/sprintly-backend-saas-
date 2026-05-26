import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/dashboard_service.dart';
import '../core/utils/logger.dart';
import '../core/exceptions/app_exception.dart';

/// Dashboard routes for admin dashboard APIs
class DashboardRoutes {
  final DashboardService _dashboardService = DashboardService();
  final AppLogger _logger = AppLogger('DashboardRoutes');

  Router get router {
    final router = Router();

    // POST /dashboard/calendar-events - Get consolidated events for a date
    router.post('/calendar-events', _getCalendarEvents);

    // GET /dashboard/birthdays - Get birthdays for current month
    router.get('/birthdays', _getBirthdays);

    // GET /dashboard/task-analytics - Get task card analytics
    router.get('/task-analytics', _getTaskAnalytics);

    return router;
  }

  /// Get HTTP status code from AppException
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
      default:
        return 500;
    }
  }

  /// POST /dashboard/calendar-events
  /// Request body: { "date": "2026-01-16" }
  Future<Response> _getCalendarEvents(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final body = bodyStr.isNotEmpty
          ? jsonDecode(bodyStr) as Map<String, dynamic>
          : <String, dynamic>{};

      // Get date from body or use today
      String date =
          body['date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0];

      // Validate date format (YYYY-MM-DD)
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'error': 'Invalid date format. Use YYYY-MM-DD',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      _logger.info('Fetching calendar events for date: $date');
      final result = await _dashboardService.getCalendarEvents(date);

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getCalendarEvents: ${e.message}');
      return Response(
        _getStatusCode(e),
        body: jsonEncode({
          'success': false,
          'error': e.message,
          'code': e.code,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getCalendarEvents: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': 'Failed to fetch calendar events',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// GET /dashboard/birthdays
  /// Query params: month (optional, defaults to current month)
  Future<Response> _getBirthdays(Request request) async {
    try {
      // Get month from query params or use current month
      final monthStr = request.url.queryParameters['month'];
      int? month;
      if (monthStr != null) {
        month = int.tryParse(monthStr);
        if (month == null || month < 1 || month > 12) {
          return Response.badRequest(
            body: jsonEncode({
              'success': false,
              'error': 'Invalid month value. Must be between 1 and 12',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      }

      _logger.info(
        'Fetching birthdays for month: ${month ?? DateTime.now().month}',
      );
      final result = await _dashboardService.getBirthdays(month: month);

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getBirthdays: ${e.message}');
      return Response(
        _getStatusCode(e),
        body: jsonEncode({
          'success': false,
          'error': e.message,
          'code': e.code,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getBirthdays: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': 'Failed to fetch birthdays',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// GET /dashboard/task-analytics
  /// Returns task card analytics for charts
  Future<Response> _getTaskAnalytics(Request request) async {
    try {
      _logger.info('Fetching task analytics');
      final result = await _dashboardService.getTaskAnalytics();

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getTaskAnalytics: ${e.message}');
      return Response(
        _getStatusCode(e),
        body: jsonEncode({
          'success': false,
          'error': e.message,
          'code': e.code,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getTaskAnalytics: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': 'Failed to fetch task analytics',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
