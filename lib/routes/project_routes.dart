import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/project_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Project routes handler with standardized error handling
class ProjectRoutes {
  final ProjectService _service = ProjectService();
  final AppLogger _logger = AppLogger('ProjectRoutes');

  Router get router {
    final router = Router();

    // ============================================
    // CORE PROJECT ENDPOINTS
    // ============================================

    // GET /api/projects - Get all projects with pagination and filtering
    router.get('/projects', _getAllProjects);

    // GET /api/projects/statistics - Get project statistics
    router.get('/projects/statistics', _getStatistics);

    // GET /api/projects/:id - Get project by ID with all related data
    router.get('/projects/<id>', _getProjectById);

    // POST /api/projects - Create a new project
    router.post('/projects', _createProject);

    // PUT /api/projects/:id - Update project core fields
    router.put('/projects/<id>', _updateProject);

    // PATCH /api/projects/:id/status - Update project status
    router.patch('/projects/<id>/status', _updateProjectStatus);

    // DELETE /api/projects/:id - Delete project
    router.delete('/projects/<id>', _deleteProject);

    // ============================================
    // TEAM MEMBER ENDPOINTS
    // ============================================

    // POST /api/projects/:id/team-members - Add team member
    router.post('/projects/<id>/team-members', _addTeamMember);

    // DELETE /api/projects/:id/team-members/:memberId - Remove team member
    router.delete('/projects/<id>/team-members/<memberId>', _removeTeamMember);

    return router;
  }

  // ============================================
  // HANDLER METHODS
  // ============================================

  /// GET /api/projects
  /// Query Parameters:
  /// - page (int, default: 1)
  /// - limit (int, default: 50, max: 100)
  /// - status (string): Filter by status
  /// - priority_level (string): Filter by priority
  /// - project_type (string): Filter by type
  /// - team_leader_id (string): Filter by team leader
  /// - manager_id (string): Filter by manager
  /// - search (string): Search in name and description
  /// - sort_by (string): Field to sort by
  /// - order (string): asc or desc
  Future<Response> _getAllProjects(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final status = params['status'];
      final priorityLevel = params['priority_level'];
      final projectType = params['project_type'];
      final teamLeaderId = params['team_leader_id'];
      final managerId = params['manager_id'];
      final search = params['search'];
      final sortBy = params['sort_by'];
      final ascending = params['order'] == 'asc';
      final requestingEmployeeId = params['requesting_employee_id'];
      final requestingRole = params['requesting_role'];

      final result = await _service.getAllProjects(
        page: page,
        limit: limit,
        status: status,
        priorityLevel: priorityLevel,
        projectType: projectType,
        teamLeaderId: teamLeaderId,
        managerId: managerId,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
        requestingEmployeeId: requestingEmployeeId,
        requestingRole: requestingRole,
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
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _getAllProjects: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /api/projects/statistics
  Future<Response> _getStatistics(Request request) async {
    try {
      final stats = await _service.getStatistics();
      return ApiResponse.success(
        data: stats,
        message: 'Statistics retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getStatistics: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /api/projects/:id - Returns project with full employee/admin details
  Future<Response> _getProjectById(Request request, String id) async {
    try {
      // Use rich endpoint - returns full employee/admin details embedded
      final project = await _service.getProjectByIdRich(id);
      return ApiResponse.success(
        data: project,
        message: 'Project retrieved successfully',
      ).toShelfResponse();
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _getProjectById: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /api/projects
  /// Request Body: Project JSON with optional nested documents, milestones, etc.
  Future<Response> _createProject(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final project = await _service.createProject(data);

      return ApiResponse.success(
        data: project.toJson(),
        message: 'Project created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return ApiResponse.error(
        code: 'BAD_REQUEST',
        message: 'Invalid JSON format',
      ).toShelfResponse(statusCode: 400);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _createProject: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PUT /api/projects/:id
  /// Request Body: Partial update fields
  Future<Response> _updateProject(Request request, String id) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final project = await _service.updateProject(id, data);

      return ApiResponse.success(
        data: project.toJson(),
        message: 'Project updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return ApiResponse.error(
        code: 'BAD_REQUEST',
        message: 'Invalid JSON format',
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _updateProject: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /api/projects/:id/status
  /// Request Body: { "status": "IN_PROGRESS", "updated_by": "admin_id" }
  Future<Response> _updateProjectStatus(Request request, String id) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final status = data['status']?.toString();
      final updatedBy = data['updated_by']?.toString() ?? 'system';

      if (status == null || status.isEmpty) {
        return ApiResponse.validationError({
          'status': ['Status is required'],
        }).toShelfResponse(statusCode: 400);
      }

      final project = await _service.updateProjectStatus(id, status, updatedBy);

      return ApiResponse.success(
        data: project.toJson(),
        message: 'Project status updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return ApiResponse.error(
        code: 'BAD_REQUEST',
        message: 'Invalid JSON format',
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _updateProjectStatus: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// DELETE /api/projects/:id
  Future<Response> _deleteProject(Request request, String id) async {
    try {
      await _service.deleteProject(id);
      return ApiResponse.success(
        message: 'Project deleted successfully',
      ).toShelfResponse();
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _deleteProject: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /api/projects/:id/team-members
  /// Request Body: { "member_id": "employee_id", "updated_by": "admin_id" }
  Future<Response> _addTeamMember(Request request, String id) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return ApiResponse.error(
          code: 'BAD_REQUEST',
          message: 'Request body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final memberId = data['member_id']?.toString();
      final updatedBy = data['updated_by']?.toString() ?? 'system';

      if (memberId == null || memberId.isEmpty) {
        return ApiResponse.validationError({
          'member_id': ['member_id is required'],
        }).toShelfResponse(statusCode: 400);
      }

      final project = await _service.addTeamMember(id, memberId, updatedBy);

      return ApiResponse.success(
        data: project.toJson(),
        message: 'Team member added successfully',
      ).toShelfResponse();
    } on FormatException {
      return ApiResponse.error(
        code: 'BAD_REQUEST',
        message: 'Invalid JSON format',
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _addTeamMember: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// DELETE /api/projects/:id/team-members/:memberId
  Future<Response> _removeTeamMember(
    Request request,
    String id,
    String memberId,
  ) async {
    try {
      final updatedBy = request.url.queryParameters['updated_by'] ?? 'system';

      final project = await _service.removeTeamMember(id, memberId, updatedBy);

      return ApiResponse.success(
        data: project.toJson(),
        message: 'Team member removed successfully',
      ).toShelfResponse();
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _removeTeamMember: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Response _internalError() {
    return ApiResponse.error(
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred. Please try again later.',
    ).toShelfResponse(statusCode: 500);
  }
}
