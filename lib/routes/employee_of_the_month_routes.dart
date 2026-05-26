import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/response/api_response.dart';
import '../core/utils/logger.dart';
import '../services/employee_of_the_month_service.dart';

/// Routes for the Employee of the Month (EOM) module.
/// All endpoints are intended for admin use (mount under /api/admin/ or protect with auth).
class EmployeeOfTheMonthRoutes {
  final AppLogger _logger = AppLogger('EmployeeOfTheMonthRoutes');
  final EmployeeOfTheMonthService _service = EmployeeOfTheMonthService();

  Router get router {
    final r = Router();

    /// GET /employee-of-the-month/rankings
    /// Query: month (1-12), year (e.g. 2026), page (default 1), limit (default 50), search (optional).
    /// Returns paginated rankings with employee name, role, id, email, designation, profile image, points, rank.
    /// Also returns current month's winner (employee_of_the_month).
    r.get('/rankings', _getEmployeeRankings);

    /// GET /employee-of-the-month/employees/`employeeId`/breakdown
    /// Query: month (1-12), year (e.g. 2026). Defaults to current month/year.
    /// Returns full points breakdown for the employee: task and attendance summary plus daily breakdown.
    r.get('/employees/<employeeId>/breakdown', _getEmployeePointsBreakdown);

    /// POST /employee-of-the-month/run-daily-calculation
    /// Body: { "date": "YYYY-MM-DD" } or query param date=YYYY-MM-DD.
    /// Computes and stores daily EOM points for all active employees for the given date.
    /// Intended to be called by a scheduler (e.g. cron) once per day.
    r.post('/run-daily-calculation', _runDailyCalculation);

    /// POST /employee-of-the-month/run-monthly-award
    /// Body: { "month": 1-12, "year": 2026 } or query params.
    /// Runs monthly award: aggregates points, builds rankings, sets winner, sends certificate email.
    /// Intended to be called on the last day of the month or first day of next month.
    r.post('/run-monthly-award', _runMonthlyAward);

    return r;
  }

  /// GET /employee-of-the-month/rankings
  Future<Response> _getEmployeeRankings(Request request) async {
    try {
      final params = request.url.queryParameters;
      final now = DateTime.now();
      final month = int.tryParse(params['month'] ?? '') ?? now.month;
      final year = int.tryParse(params['year'] ?? '') ?? now.year;
      final page = (int.tryParse(params['page'] ?? '1') ?? 1).clamp(1, 9999);
      final limit = (int.tryParse(params['limit'] ?? '50') ?? 50).clamp(1, 100);
      final search = params['search']?.trim();

      if (month < 1 || month > 12) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'month must be between 1 and 12',
        ).toShelfResponse(statusCode: 400);
      }
      if (year < 2000 || year > 2100) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'year must be between 2000 and 2100',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getEmployeeRankings(
        month: month,
        year: year,
        page: page,
        limit: limit,
        search: search,
      );

      return ApiResponse.success(
        data: result,
        pagination: result['pagination'] as Map<String, dynamic>?,
      ).toShelfResponse();
    } on Exception catch (e, st) {
      _logger.error('Error in GET /employee-of-the-month/rankings: $e', e, st);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /employee-of-the-month/employees/`employeeId`/breakdown
  Future<Response> _getEmployeePointsBreakdown(
    Request request,
    String employeeId,
  ) async {
    try {
      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employeeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      final params = request.url.queryParameters;
      final now = DateTime.now();
      final month = int.tryParse(params['month'] ?? '') ?? now.month;
      final year = int.tryParse(params['year'] ?? '') ?? now.year;

      if (month < 1 || month > 12 || year < 2000 || year > 2100) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'month (1-12) and year (2000-2100) must be valid',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getEmployeePointsBreakdown(
        employeeId: employeeId,
        month: month,
        year: year,
      );

      return ApiResponse.success(data: result).toShelfResponse();
    } on Exception catch (e, st) {
      _logger.error(
        'Error in GET /employee-of-the-month/employees/$employeeId/breakdown: $e',
        e,
        st,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /employee-of-the-month/run-daily-calculation
  Future<Response> _runDailyCalculation(Request request) async {
    try {
      String? dateStr;
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final json = jsonDecode(body) as Map<String, dynamic>?;
          dateStr = json?['date']?.toString();
        }
      } catch (_) {}
      dateStr ??= request.url.queryParameters['date'];

      DateTime date;
      if (dateStr != null && dateStr.isNotEmpty) {
        date = DateTime.tryParse(dateStr) ?? DateTime.now().subtract(const Duration(days: 1));
        date = DateTime(date.year, date.month, date.day);
      } else {
        date = DateTime.now().subtract(const Duration(days: 1));
        date = DateTime(date.year, date.month, date.day);
      }

      await _service.computeDailyPointsForDate(date);

      return ApiResponse.success(
        data: {'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}', 'status': 'computed'},
      ).toShelfResponse();
    } on Exception catch (e, st) {
      _logger.error('Error in POST /employee-of-the-month/run-daily-calculation: $e', e, st);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /employee-of-the-month/run-monthly-award
  Future<Response> _runMonthlyAward(Request request) async {
    try {
      int? month;
      int? year;
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final json = jsonDecode(body) as Map<String, dynamic>?;
          month = (json?['month'] as num?)?.toInt();
          year = (json?['year'] as num?)?.toInt();
        }
      } catch (_) {}
      final params = request.url.queryParameters;
      month ??= int.tryParse(params['month'] ?? '');
      year ??= int.tryParse(params['year'] ?? '');

      final now = DateTime.now();
      if (month == null || month < 1 || month > 12) {
        month = now.month == 1 ? 12 : now.month - 1;
      }
      if (year == null || year < 2000 || year > 2100) {
        year = now.month == 1 ? now.year - 1 : now.year;
      }

      final result = await _service.runMonthlyAward(month: month, year: year);

      return ApiResponse.success(data: result).toShelfResponse();
    } on Exception catch (e, st) {
      _logger.error('Error in POST /employee-of-the-month/run-monthly-award: $e', e, st);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
