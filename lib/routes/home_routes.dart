import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/home_service.dart';
import '../core/utils/logger.dart';
import '../core/exceptions/app_exception.dart';

/// Home Routes for admin dashboard
/// Provides consolidated APIs for the home screen
class HomeRoutes {
  final Router _router = Router();
  final HomeService _service = HomeService();
  final AppLogger _logger = AppLogger('HomeRoutes');

  Router get router {
    // POST /overview - Get home overview (task stats, charts, birthdays)
    _router.post('/overview', _getHomeOverview);

    // POST /monthly-events - Get all events for a month (calendar feed)
    _router.post('/monthly-events', _getMonthlyEvents);

    // POST /date-details - Get details for a specific date (expansion tile)
    _router.post('/date-details', _getDateDetails);

    // POST /no-status-today - Get employees with no status for a date
    _router.post('/no-status-today', _getNoStatusToday);

    return _router;
  }

  // ============================================================
  // API 4: NO STATUS TODAY
  // POST /api/home/no-status-today
  // Body: { "date": "2026-03-27" } (Optional)
  // ============================================================
  Future<Response> _getNoStatusToday(Request request) async {
    try {
      final body = await request.readAsString();
      Map<String, dynamic> data = {};
      if (body.isNotEmpty) {
        data = jsonDecode(body) as Map<String, dynamic>;
      }

      final date = data['date']?.toString();

      _logger.info('Fetching "No Status Today" employees for date: $date');

      final result = await _service.getNoStatusToday(date: date);

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getNoStatusToday: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': 'An unexpected error occurred',
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ============================================================
  // API 1: HOME OVERVIEW
  // POST /api/home/overview
  // Body: { "month": 1, "year": 2026 }
  // ============================================================
  Future<Response> _getHomeOverview(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      if (data['month'] == null || data['year'] == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'month and year are required fields',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final month = data['month'] as int;
      final year = data['year'] as int;
      final date = data['date'] as String?;

      // Validate month range
      if (month < 1 || month > 12) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'month must be between 1 and 12',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      _logger.info('Fetching home overview for $month/$year (date: $date)');

      final result = await _service.getHomeOverview(
        month: month,
        year: year,
        date: date,
      );

      return Response.ok(
        jsonEncode(
          {'success': true, 'data': result},
          toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item;
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getHomeOverview: ${e.message}');
      return Response(
        _getStatusCode(e.code),
        body: jsonEncode({
          'success': false,
          'error': {'code': e.code, 'message': e.message},
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getHomeOverview: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': 'An unexpected error occurred',
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ============================================================
  // API 2: MONTHLY EVENTS
  // POST /api/home/monthly-events
  // Body: { "month": 1, "year": 2026 }
  // ============================================================
  Future<Response> _getMonthlyEvents(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      if (data['month'] == null || data['year'] == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'month and year are required fields',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final month = data['month'] as int;
      final year = data['year'] as int;

      // Validate month range
      if (month < 1 || month > 12) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'month must be between 1 and 12',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      _logger.info('Fetching monthly events for $month/$year');

      final result = await _service.getMonthlyEvents(month: month, year: year);

      return Response.ok(
        jsonEncode(
          {'success': true, 'data': result},
          toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item;
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getMonthlyEvents: ${e.message}');
      return Response(
        _getStatusCode(e.code),
        body: jsonEncode({
          'success': false,
          'error': {'code': e.code, 'message': e.message},
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getMonthlyEvents: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': 'An unexpected error occurred',
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ============================================================
  // API 3: DATE DETAILS
  // POST /api/home/date-details
  // Body: { "date": "2026-01-15" }
  // ============================================================
  Future<Response> _getDateDetails(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required field
      if (data['date'] == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'date is required (format: YYYY-MM-DD)',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final date = data['date'] as String;

      // Validate date format
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!dateRegex.hasMatch(date)) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Invalid date format. Use YYYY-MM-DD',
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      _logger.info('Fetching date details for $date');

      final result = await _service.getDateDetails(date: date);

      return Response.ok(
        jsonEncode(
          {'success': true, 'data': result},
          toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item;
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    } on AppException catch (e) {
      _logger.error('AppException in getDateDetails: ${e.message}');
      return Response(
        _getStatusCode(e.code),
        body: jsonEncode(
          {
            'success': false,
            'error': {'code': e.code, 'message': e.message},
          },
          toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item;
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error in getDateDetails: $e', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode(
          {
            'success': false,
            'error': {
              'code': 'INTERNAL_ERROR',
              'message': 'An unexpected error occurred',
            },
          },
          toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item;
          },
        ),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Helper to get HTTP status code from error code
  int _getStatusCode(String code) {
    switch (code) {
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
