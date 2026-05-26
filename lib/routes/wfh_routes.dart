import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/wfh_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// WFH (Work From Home) routes handler
class WFHRoutes {
  final Router _router = Router();
  final WFHService _wfhService = WFHService();
  final AppLogger _logger = AppLogger('WFHRoutes');

  Router get router {
    // === Simplified Routes (for Frontend compatibility) ===
    // POST /wfh - Create WFH request (frontend calls this)
    _router.post('/wfh', _createWFHRequest);

    // GET /wfh/employee/:employeeId - Get WFH by employee (frontend calls this)
    _router.get('/wfh/employee/<employeeId>', _getWFHRequestsByRequester);

    // === Verbose Routes (backward compatibility) ===
    // Create new WFH request
    _router.post('/wfh/createNewWFHRequest', _createWFHRequest);

    // Get all WFH requests with filters and pagination
    _router.get('/wfh/getAllWFHRequests', _getAllWFHRequests);

    // Get WFH request by ID
    _router.get('/wfh/getWFHRequestById/<id>', _getWFHRequestById);

    // Update WFH request
    _router.put('/wfh/updateWFHRequest/<id>', _updateWFHRequest);

    // Delete WFH request
    _router.delete('/wfh/deleteWFHRequest/<id>', _deleteWFHRequest);

    // Approve or reject WFH request
    _router.patch(
      '/wfh/approveRejectWFHRequest/<id>',
      _approveRejectWFHRequest,
    );

    // Get WFH requests by requester
    _router.get(
      '/wfh/getWFHRequestsByRequester/<requesterId>',
      _getWFHRequestsByRequester,
    );

    return _router;
  }

  /// POST /api/wfh/createNewWFHRequest
  Future<Response> _createWFHRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final wfh = await _wfhService.createWFHRequest(data);

      return ApiResponse.success(
        data: wfh.toJson(),
        message: 'WFH request created successfully',
      ).toShelfResponse(statusCode: 201);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error creating WFH request', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to create WFH request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/wfh/getAllWFHRequests
  Future<Response> _getAllWFHRequests(Request request) async {
    try {
      final params = request.url.queryParameters;

      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final status = int.tryParse(params['status'] ?? '');
      final requesterType = params['requester_type'];
      final requesterId = params['requester_id'];
      final fromDate = params['from_date'];
      final toDate = params['to_date'];

      if (fromDate != null && toDate != null) {
        final start = DateTime.tryParse(fromDate);
        final end = DateTime.tryParse(toDate);
        if (start != null && end != null && start.isAfter(end)) {
          return ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'From Date cannot be after To Date',
          ).toShelfResponse(statusCode: 400);
        }
      }
      final search = params['search'];
      final sortBy = params['sort_by'];
      final ascending = params['ascending'] == 'true';

      final result = await _wfhService.getAllWFHRequests(
        page: page,
        limit: limit,
        status: status,
        requesterType: requesterType,
        requesterId: requesterId,
        fromDate: fromDate,
        toDate: toDate,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: result['pagination'],
        message: 'WFH requests fetched successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error fetching WFH requests', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch WFH requests',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/wfh/getWFHRequestById/:id
  Future<Response> _getWFHRequestById(Request request, String id) async {
    try {
      final wfh = await _wfhService.getWFHRequestById(id);

      return ApiResponse.success(
        data: wfh.toJson(),
        message: 'WFH request fetched successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error fetching WFH request', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch WFH request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/wfh/updateWFHRequest/:id
  Future<Response> _updateWFHRequest(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final updates = jsonDecode(body) as Map<String, dynamic>;

      final wfh = await _wfhService.updateWFHRequest(id, updates);

      return ApiResponse.success(
        data: wfh.toJson(),
        message: 'WFH request updated successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error updating WFH request', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update WFH request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/wfh/deleteWFHRequest/:id
  Future<Response> _deleteWFHRequest(Request request, String id) async {
    try {
      await _wfhService.deleteWFHRequest(id);

      return ApiResponse.success(
        message: 'WFH request deleted successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error deleting WFH request', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete WFH request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PATCH /api/wfh/approveRejectWFHRequest/:id
  Future<Response> _approveRejectWFHRequest(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final approve = data['approve'] == true;
      final actionBy = data['action_by']?.toString();
      final remarks = data['remarks']?.toString();

      if (actionBy == null || actionBy.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Action by (admin ID) is required',
        ).toShelfResponse(statusCode: 400);
      }

      final wfh = await _wfhService.approveRejectWFHRequest(
        wfhId: id,
        approve: approve,
        actionBy: actionBy,
        remarks: remarks,
      );

      return ApiResponse.success(
        data: wfh.toJson(),
        message:
            'WFH request ${approve ? 'approved' : 'rejected'} successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error approving/rejecting WFH request', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to process WFH request',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/wfh/getWFHRequestsByRequester/:requesterId
  Future<Response> _getWFHRequestsByRequester(
    Request request,
    String requesterId,
  ) async {
    try {
      final wfhRequests = await _wfhService.getWFHRequestsByRequester(
        requesterId,
      );

      return ApiResponse.success(
        data: wfhRequests.map((w) => w.toJson()).toList(),
        message: 'WFH requests fetched successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stack) {
      _logger.error('Error fetching WFH requests by requester', e, stack);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch WFH requests',
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
      case 'FORBIDDEN':
        return 403;
      case 'UNAUTHORIZED':
        return 401;
      default:
        return 500;
    }
  }
}
