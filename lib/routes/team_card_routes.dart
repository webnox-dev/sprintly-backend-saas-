import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/team_card_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// TeamCard routes handler with proper naming conventions
/// Handles non-project work cards (Meeting, KT, Learning, R&D)
class TeamCardRoutes {
  final TeamCardService _service = TeamCardService();
  final AppLogger _logger = AppLogger('TeamCardRoutes');

  Router get router {
    final router = Router();

    // ==========================================
    // ADMIN ROUTES - /admin/team-cards
    // ==========================================

    // POST /admin/team-cards - createNewTeamCard
    router.post('/admin/team-cards', _createNewTeamCard);

    // PUT /admin/team-cards/<teamCardId> - updateTeamCard
    router.put('/admin/team-cards/<teamCardId>', _updateTeamCard);

    // GET /admin/team-cards - getAllTeamCards
    router.get('/admin/team-cards', _getAllTeamCards);

    // GET /admin/team-cards/<teamCardId> - getTeamCardById
    router.get('/admin/team-cards/<teamCardId>', _getTeamCardById);

    // PATCH /admin/team-cards/<teamCardId>/status - updateTeamCardStatus
    router.patch(
      '/admin/team-cards/<teamCardId>/status',
      _updateTeamCardStatus,
    );

    // DELETE /admin/team-cards/<teamCardId> - deleteTeamCard
    router.delete('/admin/team-cards/<teamCardId>', _deleteTeamCard);

    // GET /admin/team-cards/<teamCardId>/usage - getTeamCardUsageReport
    router.get('/admin/team-cards/<teamCardId>/usage', _getTeamCardUsageReport);

    // ==========================================
    // EMPLOYEE ROUTES - /employee/team-cards
    // ==========================================

    // GET /employee/team-cards - getAvailableTeamCards
    router.get('/employee/team-cards', _getAvailableTeamCards);

    // POST /employee/team-cards/<teamCardId>/clock - clockInOutTeamCard
    router.post('/employee/team-cards/<teamCardId>/clock', _clockInOutTeamCard);

    // GET /employee/team-cards/usage - getEmployeeTeamCardUsage
    router.get('/employee/team-cards/usage', _getEmployeeTeamCardUsage);

    return router;
  }

  // ==========================================
  // ADMIN HANDLERS
  // ==========================================

  /// POST /admin/team-cards - Create new team card
  Future<Response> _createNewTeamCard(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final createdBy = data['created_by']?.toString() ?? 'admin';

      final teamCard = await _service.createNewTeamCard(data, createdBy);

      return ApiResponse.success(
        data: teamCard.toJson(),
        message: 'Team card created successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in createNewTeamCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PUT /admin/team-cards/<teamCardId> - Update team card
  Future<Response> _updateTeamCard(Request request, String teamCardId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final updatedBy = data['updated_by']?.toString() ?? 'admin';

      final teamCard = await _service.updateTeamCard(
        teamCardId,
        data,
        updatedBy,
      );

      return ApiResponse.success(
        data: teamCard.toJson(),
        message: 'Team card updated successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateTeamCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/team-cards - Get all team cards
  Future<Response> _getAllTeamCards(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final cardType = params['card_type'];
      final teamType = params['team_type'];
      final status = int.tryParse(params['status'] ?? '');
      final search = params['search'];

      final result = await _service.getAllTeamCards(
        page: page,
        limit: limit,
        cardType: cardType,
        teamType: teamType,
        status: status,
        search: search,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
          'totalPages': result['totalPages'],
          'hasNext': result['page'] < result['totalPages'],
          'hasPrev': result['page'] > 1,
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getAllTeamCards: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/team-cards/<teamCardId> - Get team card by ID
  Future<Response> _getTeamCardById(Request request, String teamCardId) async {
    try {
      final teamCard = await _service.getTeamCardById(teamCardId);
      return ApiResponse.success(data: teamCard.toJson()).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } catch (e, stackTrace) {
      _logger.error('Error in getTeamCardById: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /admin/team-cards/<teamCardId>/status - Activate/Deactivate
  Future<Response> _updateTeamCardStatus(
    Request request,
    String teamCardId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final status = (data['team_card_status'] as num?)?.toInt() ?? 1;
      final updatedBy = data['updated_by']?.toString() ?? 'admin';

      final teamCard = await _service.updateTeamCardStatus(
        teamCardId,
        status,
        updatedBy,
      );

      final message = status == 1
          ? 'Team card activated'
          : 'Team card deactivated';
      return ApiResponse.success(
        data: teamCard.toJson(),
        message: message,
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateTeamCardStatus: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// DELETE /admin/team-cards/<teamCardId> - Delete team card
  Future<Response> _deleteTeamCard(Request request, String teamCardId) async {
    try {
      await _service.deleteTeamCard(teamCardId);

      return ApiResponse.success(
        message: 'Team card deleted successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } catch (e, stackTrace) {
      _logger.error('Error in deleteTeamCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/team-cards/<teamCardId>/usage - Get usage report
  Future<Response> _getTeamCardUsageReport(
    Request request,
    String teamCardId,
  ) async {
    try {
      final params = request.url.queryParameters;
      DateTime? fromDate;
      DateTime? toDate;

      if (params['from_date'] != null) {
        fromDate = DateTime.tryParse(params['from_date']!);
      }
      if (params['to_date'] != null) {
        toDate = DateTime.tryParse(params['to_date']!);
      }

      final report = await _service.getTeamCardUsageReport(
        teamCardId,
        fromDate: fromDate,
        toDate: toDate,
      );

      return ApiResponse.success(data: report).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } catch (e, stackTrace) {
      _logger.error('Error in getTeamCardUsageReport: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // EMPLOYEE HANDLERS
  // ==========================================

  /// GET /employee/team-cards - Get available team cards
  Future<Response> _getAvailableTeamCards(Request request) async {
    try {
      final teamCards = await _service.getAvailableTeamCards();
      return ApiResponse.success(
        data: teamCards.map((t) => t.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getAvailableTeamCards: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /employee/team-cards/<teamCardId>/clock - Clock-in/Clock-out
  Future<Response> _clockInOutTeamCard(
    Request request,
    String teamCardId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final action =
          data['action']?.toString() ?? 'clock_in'; // clock_in or clock_out
      final notes = data['notes']?.toString();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      dynamic result;
      String message;

      if (action == 'clock_out') {
        result = await _service.clockOutFromTeamCard(teamCardId, employeeId);
        message = 'Clocked out successfully';
      } else {
        result = await _service.clockInToTeamCard(
          teamCardId,
          employeeId,
          notes,
        );
        message = 'Clocked in successfully';
      }

      return ApiResponse.success(
        data: result.toJson(),
        message: message,
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Team card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in clockInOutTeamCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /employee/team-cards/usage - Get employee's usage history
  Future<Response> _getEmployeeTeamCardUsage(Request request) async {
    try {
      final params = request.url.queryParameters;
      final employeeId =
          params['employee_id'] ?? request.headers['x-employee-id'] ?? '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      DateTime? fromDate;
      DateTime? toDate;

      if (params['from_date'] != null) {
        fromDate = DateTime.tryParse(params['from_date']!);
      }
      if (params['to_date'] != null) {
        toDate = DateTime.tryParse(params['to_date']!);
      }

      final usage = await _service.getEmployeeTeamCardUsage(
        employeeId,
        fromDate: fromDate,
        toDate: toDate,
      );

      return ApiResponse.success(
        data: usage.map((u) => u.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeeTeamCardUsage: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Response _notFound(String resource) {
    return ApiResponse.error(
      code: 'NOT_FOUND',
      message: '$resource not found',
    ).toShelfResponse(statusCode: 404);
  }

  Response _internalError() {
    return ApiResponse.error(
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    ).toShelfResponse(statusCode: 500);
  }
}
