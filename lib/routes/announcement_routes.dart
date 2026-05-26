import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/announcement_service.dart';
import '../domain/models/announcement.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class AnnouncementRoutes {
  final AnnouncementService _service = AnnouncementService();
  final AppLogger _logger = AppLogger('AnnouncementRoutes');

  Router get router {
    final router = Router();
    // Public endpoint for employees to fetch active announcements
    router.get('/announcements/active', getTodaysAnnouncements);
    // Admin endpoints
    router.get('/admin/announcements', _getAllAnnouncements);
    router.get('/admin/announcements/<id>', _getAnnouncementById);
    router.post('/admin/announcements', _createAnnouncement);
    router.put('/admin/announcements/<id>', _updateAnnouncement);
    router.delete('/admin/announcements/<id>', _deleteAnnouncement);
    return router;
  }

  /// Get active announcements for employees (public endpoint)
  Future<Response> getTodaysAnnouncements(Request request) async {
  try {
    // Always use current date
    final DateTime today = DateTime.now();

    // Optional: keep limit, default 10
    final queryParams = request.url.queryParameters;
    final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;

    final (announcements, _) = await _service.getAllAnnouncements(
      page: 1,
      limit: limit,
      startDate: today,
      endDate: today,
      sortBy: 'created_at',
      sortOrder: 'DESC',
    );

    _logger.info(
      'Fetched ${announcements.length} announcements for today ($today)',
    );

    return ApiResponse.success(
      data: announcements.map((e) => e.toJson()).toList(),
    ).toShelfResponse();
  } catch (e, stackTrace) {
    _logger.error('Error fetching today\'s announcements', e, stackTrace);
    return ApiResponse.error(
      code: 'FETCH_ERROR',
      message: e.toString(),
    ).toShelfResponse(statusCode: 500);
  }
}


  Future<Response> _getAllAnnouncements(Request request) async {
    try {
      // Parse query parameters
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final isActiveStr = queryParams['is_active'] ?? queryParams['isActive'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final sortBy = queryParams['sort_by'] ?? queryParams['sortBy'];
      final sortOrder = queryParams['sort_order'] ?? queryParams['sortOrder'];
      final startDateStr =
          queryParams['start_date'] ?? queryParams['startDate'];
      final endDateStr = queryParams['end_date'] ?? queryParams['endDate'];

      bool? isActive;
      if (isActiveStr != null) {
        isActive = isActiveStr == 'true' || isActiveStr == '1';
      }

      DateTime? startDate;
      DateTime? endDate;
      if (startDateStr != null) {
        startDate = DateTime.tryParse(startDateStr);
      }
      if (endDateStr != null) {
        endDate = DateTime.tryParse(endDateStr);
      }

      final (announcements, totalCount) = await _service.getAllAnnouncements(
        search: search,
        isActive: isActive,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return ApiResponse.success(
        data: {
          'items': announcements.map((e) => e.toJson()).toList(),
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
      _logger.error('Error fetching announcements', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getAnnouncementById(Request request, String id) async {
    try {
      final item = await _service.getAnnouncementById(id);
      return ApiResponse.success(data: item.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching announcement $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createAnnouncement(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final item = Announcement.fromJson(data);
      final created = await _service.createAnnouncement(item);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating announcement', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateAnnouncement(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateAnnouncement(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating announcement $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteAnnouncement(Request request, String id) async {
    try {
      await _service.deleteAnnouncement(id);
      return ApiResponse.success(
        message: 'Announcement deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting announcement $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
