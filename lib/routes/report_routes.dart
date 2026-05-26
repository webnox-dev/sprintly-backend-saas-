import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/report_service.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class ReportRoutes {
  final ReportService _service = ReportService();
  final AppLogger _logger = AppLogger('ReportRoutes');

  Router get router {
    final router = Router();

    // POST /reports - Submit a daily report
    router.post('/reports', _submitReport);

    // GET /reports/check - Check if report exists
    router.get('/reports/check', _checkReportExists);

    // GET /reports/history - Get report history
    router.get('/reports/history', _getReportHistory);

    return router;
  }

  /// POST /reports
  Future<Response> _submitReport(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Request body is empty',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      await _service.submitReport(data);

      return ApiResponse.success(
        message: 'Report submitted successfully',
      ).toShelfResponse(statusCode: 201);
    } catch (e, stackTrace) {
      _logger.error('Error submitting report: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to submit report details: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /reports/check?employee_id=...&date=...
  Future<Response> _checkReportExists(Request request) async {
    try {
      final params = request.url.queryParameters;
      final employeeId = params['employee_id'];
      final date = params['date'];

      if (employeeId == null || date == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Missing employee_id or date parameters',
        ).toShelfResponse(statusCode: 400);
      }

      final exists = await _service.checkReportExists(employeeId, date);

      return ApiResponse.success(data: exists).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error checking report existence: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to check report existence',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /reports/history?employee_id=...&page=...&limit=...
  Future<Response> _getReportHistory(Request request) async {
    try {
      final params = request.url.queryParameters;
      final employeeId = params['employee_id'];
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;

      _logger.info(
        'ReportRoutes: Fetching history for employeeId: $employeeId, page: $page, limit: $limit, dates: ${params['start_date']} - ${params['end_date']}',
      );

      final startDate = params['start_date'];
      final endDate = params['end_date'];

      if (employeeId == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Missing employee_id parameter',
        ).toShelfResponse(statusCode: 400);
      }

      final reports = await _service.getReportHistory(
        employeeId,
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      return ApiResponse.success(data: reports).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching report history: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch report history',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
