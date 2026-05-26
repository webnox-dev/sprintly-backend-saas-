import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/company_holiday_service.dart';
import '../domain/models/company_holiday.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class CompanyHolidayRoutes {
  final CompanyHolidayService _service = CompanyHolidayService();
  final AppLogger _logger = AppLogger('CompanyHolidayRoutes');

  Router get router {
    final router = Router();
    router.get('/admin/company-holidays', _getAllHolidays);
    router.get('/admin/company-holidays/<id>', _getHolidayById);
    router.post('/admin/company-holidays', _createHoliday);
    router.put('/admin/company-holidays/<id>', _updateHoliday);
    router.delete('/admin/company-holidays/<id>', _deleteHoliday);
    return router;
  }

  Future<Response> _getAllHolidays(Request request) async {
    try {
      // Parse query parameters
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final filterType =
          queryParams['filter_type'] ?? queryParams['filterType'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final sortBy = queryParams['sort_by'] ?? queryParams['sortBy'];
      final sortOrder = queryParams['sort_order'] ?? queryParams['sortOrder'];
      final startDateStr =
          queryParams['start_date'] ?? queryParams['startDate'];
      final endDateStr = queryParams['end_date'] ?? queryParams['endDate'];

      DateTime? startDate;
      DateTime? endDate;
      if (startDateStr != null) {
        startDate = DateTime.tryParse(startDateStr);
      }
      if (endDateStr != null) {
        endDate = DateTime.tryParse(endDateStr);
      }

      final (holidays, totalCount) = await _service.getAllHolidays(
        search: search,
        filterType: filterType,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
        startDate: startDate,
        endDate: endDate,
      );

      return ApiResponse.success(
        data: {
          'items': holidays.map((e) => e.toJson()).toList(),
          'pagination': {
            'page': page,
            'limit': limit,
            'total': totalCount,
            'totalPages': (totalCount / limit).ceil(),
            'hasMore': page * limit < totalCount,
          },
        },
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching holidays', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getHolidayById(Request request, String id) async {
    try {
      final holiday = await _service.getHolidayById(id);
      return ApiResponse.success(data: holiday.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching holiday $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createHoliday(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final holiday = CompanyHoliday.fromJson(data);
      final created = await _service.createHoliday(holiday);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating holiday', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateHoliday(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateHoliday(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating holiday $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteHoliday(Request request, String id) async {
    try {
      await _service.deleteHoliday(id);
      return ApiResponse.success(
        message: 'Holiday deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting holiday $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
