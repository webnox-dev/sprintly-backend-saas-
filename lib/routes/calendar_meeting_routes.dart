import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/calendar_meeting_service.dart';
import '../domain/models/calendar_meeting.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';
import '../core/exceptions/app_exception.dart';

/// Calendar Meeting Routes
/// Admin: Create, Update, Delete, Get All
/// Both Admin & Employee: Get My Meetings, Get by ID, Respond (Accept/Decline)
class CalendarMeetingRoutes {
  final CalendarMeetingService _service = CalendarMeetingService();
  final AppLogger _logger = AppLogger('CalendarMeetingRoutes');

  Router get router {
    final router = Router();

    // Admin endpoints
    router.post('/admin/calendar/meetings', _createMeeting);
    router.get('/admin/calendar/meetings', _getAllMeetings);
    router.get('/admin/calendar/meetings/<id>', _getMeetingById);
    router.put('/admin/calendar/meetings/<id>', _updateMeeting);
    router.put('/admin/calendar/meetings/<id>/postpone', _postponeMeeting);
    router.delete('/admin/calendar/meetings/<id>', _deleteMeeting);

    // Employee endpoints (also accessible by admin)
    router.get('/calendar/my-meetings', _getMyMeetings);
    router.get('/calendar/meetings/<id>', _getMeetingById);
    router.post('/calendar/meetings/<id>/respond', _respondToMeeting);
    router.post('/calendar/meetings/check-conflicts', _checkConflicts);

    // Utility endpoints
    router.get('/calendar/venues', _getVenueOptions);
    router.get('/calendar/venues/availability', _getVenueAvailability);
    router.get(
      '/calendar/participants/availability',
      _getParticipantAvailability,
    );

    return router;
  }

  /// GET /calendar/venues/availability
  Future<Response> _getVenueAvailability(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final date = queryParams['date'];
      final startTime = queryParams['start_time'];
      final endTime = queryParams['end_time'];
      final excludeId = queryParams['exclude_meeting_id'];

      if (date == null || startTime == null || endTime == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Date, start_time, and end_time are required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getVenueAvailability(
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeId,
      );

      return ApiResponse.success(data: result).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching venue availability', e, stackTrace);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /calendar/participants/availability
  Future<Response> _getParticipantAvailability(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final date = queryParams['date'];
      final startTime = queryParams['start_time'];
      final endTime = queryParams['end_time'];
      final excludeId = queryParams['exclude_meeting_id'];

      if (date == null || startTime == null || endTime == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Date, start_time, and end_time are required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getParticipantAvailability(
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeId,
      );

      return ApiResponse.success(data: result).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching participant availability', e, stackTrace);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // ADMIN ENDPOINTS
  // ============================================

  /// POST /calendar/meetings/check-conflicts
  Future<Response> _checkConflicts(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final venue = data['venue'] as String?;
      final date = data['date'] as String?;
      final startTime = data['start_time'] as String?;
      final endTime = data['end_time'] as String?;
      final participantIds =
          (data['participant_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final excludeMeetingId = data['exclude_meeting_id'] as String?;

      if (venue == null ||
          date == null ||
          startTime == null ||
          endTime == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Missing required fields',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.checkConflicts(
        venue: venue,
        date: date,
        startTime: startTime,
        endTime: endTime,
        participantIds: participantIds,
        excludeMeetingId: excludeMeetingId,
      );

      return ApiResponse.success(data: result).toShelfResponse();
    } catch (e, stackTrace) {
      if (e is AppException) {
        return ApiResponse.error(
          code: e.code,
          message: e.message,
          details: e.details,
        ).toShelfResponse(statusCode: 400);
      }
      _logger.error('Error checking conflicts', e, stackTrace);
      return ApiResponse.error(
        code: 'CHECK_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /admin/calendar/meetings - Create a new meeting (Admin only)
  Future<Response> _createMeeting(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Validate required fields
      if (data['meeting_name'] == null ||
          (data['meeting_name'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Meeting name is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['meeting_venue'] == null ||
          (data['meeting_venue'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Meeting venue is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['meeting_date'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Meeting date is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['meeting_start_time'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Meeting start time is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['meeting_end_time'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Meeting end time is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['host_id'] == null || (data['host_id'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Host ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final meeting = CalendarMeeting.fromJson(data);
      final created = await _service.createMeeting(meeting);

      return ApiResponse.success(
        data: created.toJson(),
        message: 'Meeting scheduled successfully',
      ).toShelfResponse(statusCode: 201);
    } catch (e, stackTrace) {
      if (e is AppException) {
        return ApiResponse.error(
          code: e.code,
          message: e.message,
          details: e.details,
        ).toShelfResponse(statusCode: 400);
      }
      _logger.error('Error creating meeting', e, stackTrace);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/calendar/meetings - Get all meetings (Admin only)
  Future<Response> _getAllMeetings(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final hostId = queryParams['host_id'] ?? queryParams['hostId'];
      final status = queryParams['status'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
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

      final (meetings, totalCount) = await _service.getAllMeetings(
        search: search,
        hostId: hostId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return ApiResponse.success(
        data: {
          'items': meetings.map((e) => e.toJson()).toList(),
          'pagination': {
            'page': page,
            'limit': limit,
            'total': totalCount,
            'totalPages': (totalCount / limit).ceil(),
            'hasMore': page * limit < totalCount,
          },
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching meetings', e, stackTrace);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /admin/calendar/meetings/:id OR /calendar/meetings/:id
  Future<Response> _getMeetingById(Request request, String id) async {
    try {
      final meeting = await _service.getMeetingById(id);
      return ApiResponse.success(data: meeting.toJson()).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching meeting $id', e, stackTrace);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /admin/calendar/meetings/:id - Update a meeting (Admin only)
  Future<Response> _updateMeeting(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateMeeting(id, updates);
      return ApiResponse.success(
        data: updated.toJson(),
        message: 'Meeting updated successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error updating meeting $id', e, stackTrace);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /admin/calendar/meetings/:id/postpone - Postpone a meeting (Admin only)
  Future<Response> _postponeMeeting(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Validate required fields
      if (data['new_date'] == null || (data['new_date'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'New date is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['new_start_time'] == null ||
          (data['new_start_time'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'New start time is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['new_end_time'] == null ||
          (data['new_end_time'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'New end time is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['reason'] == null || (data['reason'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Reason for postponement is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (data['postponed_by'] == null ||
          (data['postponed_by'] as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Postponed by (Admin ID) is required',
        ).toShelfResponse(statusCode: 400);
      }

      final updated = await _service.postponeMeeting(
        meetingId: id,
        newDate: data['new_date'],
        newStartTime: data['new_start_time'],
        newEndTime: data['new_end_time'],
        reason: data['reason'],
        postponedBy: data['postponed_by'],
      );

      return ApiResponse.success(
        data: updated.toJson(),
        message: 'Meeting postponed successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error postponing meeting $id', e, stackTrace);
      return ApiResponse.error(
        code: 'POSTPONE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /admin/calendar/meetings/:id - Delete a meeting (Admin only)
  Future<Response> _deleteMeeting(Request request, String id) async {
    try {
      await _service.deleteMeeting(id);
      return ApiResponse.success(
        message: 'Meeting deleted successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error deleting meeting $id', e, stackTrace);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // EMPLOYEE & ADMIN SHARED ENDPOINTS
  // ============================================

  /// GET /calendar/my-meetings - Get meetings for current user
  Future<Response> _getMyMeetings(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final userId = queryParams['user_id'] ?? queryParams['userId'];
      final search = queryParams['search'];
      final status = queryParams['status'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
      final sortBy = queryParams['sort_by'] ?? queryParams['sortBy'];
      final sortOrder = queryParams['sort_order'] ?? queryParams['sortOrder'];
      final startDateStr =
          queryParams['start_date'] ?? queryParams['startDate'];
      final endDateStr = queryParams['end_date'] ?? queryParams['endDate'];

      if (userId == null || userId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'User ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      DateTime? startDate;
      DateTime? endDate;
      if (startDateStr != null) {
        startDate = DateTime.tryParse(startDateStr);
      }
      if (endDateStr != null) {
        endDate = DateTime.tryParse(endDateStr);
      }

      final (meetings, totalCount) = await _service.getMeetingsForUser(
        userId: userId,
        search: search,
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return ApiResponse.success(
        data: {
          'items': meetings.map((e) => e.toJson()).toList(),
          'pagination': {
            'page': page,
            'limit': limit,
            'total': totalCount,
            'totalPages': (totalCount / limit).ceil(),
            'hasMore': page * limit < totalCount,
          },
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error fetching user meetings', e, stackTrace);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /calendar/meetings/:id/respond - Accept or Decline a meeting
  Future<Response> _respondToMeeting(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final userId = data['user_id'] as String?;
      final response = data['response'] as String?; // 'accepted' or 'declined'

      if (userId == null || userId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'User ID is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (response == null || !['accepted', 'declined'].contains(response)) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Response must be "accepted" or "declined"',
        ).toShelfResponse(statusCode: 400);
      }

      final updated = await _service.respondToMeeting(
        meetingId: id,
        userId: userId,
        response: response,
      );

      return ApiResponse.success(
        data: updated.toJson(),
        message: 'Meeting response recorded successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error responding to meeting $id', e, stackTrace);
      return ApiResponse.error(
        code: 'RESPONSE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // UTILITY ENDPOINTS
  // ============================================

  /// GET /calendar/venues - Get list of predefined venues
  Future<Response> _getVenueOptions(Request request) async {
    return ApiResponse.success(
      data: _service.getVenueOptions(),
    ).toShelfResponse();
  }
}
