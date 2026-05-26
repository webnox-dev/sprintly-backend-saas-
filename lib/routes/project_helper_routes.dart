import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/project_helper_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Routes for Project Helper Tables (Sub-resources)
///
/// Endpoint Structure:
/// - /api/projects/:projectId/documents       - Project Documents
/// - /api/projects/:projectId/figma-urls      - Figma URLs
/// - /api/projects/:projectId/releases        - Project Releases
/// - /api/projects/:projectId/milestones      - Project Milestones
/// - /api/projects/:projectId/client-reviews  - Client Reviews
/// - /api/projects/:projectId/discontinuation - Project Discontinuation
class ProjectHelperRoutes {
  final ProjectHelperService _service = ProjectHelperService();
  final AppLogger _logger = AppLogger('ProjectHelperRoutes');

  Router get router {
    final router = Router();

    // ============================================
    // PROJECT DOCUMENTS ENDPOINTS
    // ============================================
    router.get('/<projectId>/documents', _getDocuments);
    router.get('/<projectId>/documents/<documentId>', _getDocumentById);
    router.post('/<projectId>/documents', _createDocument);
    router.put('/<projectId>/documents/<documentId>', _updateDocument);
    router.delete('/<projectId>/documents/<documentId>', _deleteDocument);

    // ============================================
    // PROJECT FIGMA URLS ENDPOINTS
    // ============================================
    router.get('/<projectId>/figma-urls', _getFigmaUrls);
    router.get('/<projectId>/figma-urls/<figmaUrlId>', _getFigmaUrlById);
    router.post('/<projectId>/figma-urls', _createFigmaUrl);
    router.put('/<projectId>/figma-urls/<figmaUrlId>', _updateFigmaUrl);
    router.delete('/<projectId>/figma-urls/<figmaUrlId>', _deleteFigmaUrl);

    // ============================================
    // PROJECT RELEASES ENDPOINTS
    // ============================================
    router.get('/<projectId>/releases', _getReleases);
    router.get('/<projectId>/releases/<releaseId>', _getReleaseById);
    router.post('/<projectId>/releases', _createRelease);
    router.put('/<projectId>/releases/<releaseId>', _updateRelease);
    router.delete('/<projectId>/releases/<releaseId>', _deleteRelease);

    // ============================================
    // PROJECT MILESTONES ENDPOINTS
    // ============================================
    router.get('/<projectId>/milestones', _getMilestones);
    router.get('/<projectId>/milestones/<milestoneId>', _getMilestoneById);
    router.post('/<projectId>/milestones', _createMilestone);
    router.put('/<projectId>/milestones/<milestoneId>', _updateMilestone);
    router.delete('/<projectId>/milestones/<milestoneId>', _deleteMilestone);

    // ============================================
    // CLIENT REVIEWS ENDPOINTS
    // ============================================
    router.get('/<projectId>/client-reviews', _getClientReviews);
    router.get('/<projectId>/client-reviews/<reviewId>', _getClientReviewById);
    router.post('/<projectId>/client-reviews', _createClientReview);
    router.put('/<projectId>/client-reviews/<reviewId>', _updateClientReview);
    router.delete(
      '/<projectId>/client-reviews/<reviewId>',
      _deleteClientReview,
    );

    // ============================================
    // PROJECT DISCONTINUATION ENDPOINTS
    // ============================================
    router.get('/<projectId>/discontinuation', _getDiscontinuation);
    router.post('/<projectId>/discontinuation', _discontinueProject);
    router.put('/<projectId>/discontinuation', _updateDiscontinuation);
    router.delete('/<projectId>/discontinuation', _reactivateProject);

    return router;
  }

  // ============================================
  // DOCUMENT HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/documents
  Future<Response> _getDocuments(Request request, String projectId) async {
    try {
      final documents = await _service.getDocuments(projectId);
      return ApiResponse.success(
        data: documents.map((d) => d.toJson()).toList(),
        message: 'Documents retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getDocuments');
    }
  }

  /// GET /api/projects/:projectId/documents/:documentId
  Future<Response> _getDocumentById(
    Request request,
    String projectId,
    String documentId,
  ) async {
    try {
      final document = await _service.getDocumentById(documentId);
      return ApiResponse.success(
        data: document.toJson(),
        message: 'Document retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getDocumentById');
    }
  }

  /// POST /api/projects/:projectId/documents
  Future<Response> _createDocument(Request request, String projectId) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final document = await _service.createDocument(data);
      return ApiResponse.success(
        data: document.toJson(),
        message: 'Document created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'createDocument');
    }
  }

  /// PUT /api/projects/:projectId/documents/:documentId
  Future<Response> _updateDocument(
    Request request,
    String projectId,
    String documentId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final document = await _service.updateDocument(documentId, data);
      return ApiResponse.success(
        data: document.toJson(),
        message: 'Document updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateDocument');
    }
  }

  /// DELETE /api/projects/:projectId/documents/:documentId
  Future<Response> _deleteDocument(
    Request request,
    String projectId,
    String documentId,
  ) async {
    try {
      await _service.deleteDocument(documentId);
      return ApiResponse.success(
        message: 'Document deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'deleteDocument');
    }
  }

  // ============================================
  // FIGMA URL HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/figma-urls
  Future<Response> _getFigmaUrls(Request request, String projectId) async {
    try {
      final figmaUrls = await _service.getFigmaUrls(projectId);
      return ApiResponse.success(
        data: figmaUrls.map((f) => f.toJson()).toList(),
        message: 'Figma URLs retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getFigmaUrls');
    }
  }

  /// GET /api/projects/:projectId/figma-urls/:figmaUrlId
  Future<Response> _getFigmaUrlById(
    Request request,
    String projectId,
    String figmaUrlId,
  ) async {
    try {
      final figmaUrl = await _service.getFigmaUrlById(figmaUrlId);
      return ApiResponse.success(
        data: figmaUrl.toJson(),
        message: 'Figma URL retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getFigmaUrlById');
    }
  }

  /// POST /api/projects/:projectId/figma-urls
  Future<Response> _createFigmaUrl(Request request, String projectId) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final figmaUrl = await _service.createFigmaUrl(data);
      return ApiResponse.success(
        data: figmaUrl.toJson(),
        message: 'Figma URL created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'createFigmaUrl');
    }
  }

  /// PUT /api/projects/:projectId/figma-urls/:figmaUrlId
  Future<Response> _updateFigmaUrl(
    Request request,
    String projectId,
    String figmaUrlId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final figmaUrl = await _service.updateFigmaUrl(figmaUrlId, data);
      return ApiResponse.success(
        data: figmaUrl.toJson(),
        message: 'Figma URL updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateFigmaUrl');
    }
  }

  /// DELETE /api/projects/:projectId/figma-urls/:figmaUrlId
  Future<Response> _deleteFigmaUrl(
    Request request,
    String projectId,
    String figmaUrlId,
  ) async {
    try {
      await _service.deleteFigmaUrl(figmaUrlId);
      return ApiResponse.success(
        message: 'Figma URL deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'deleteFigmaUrl');
    }
  }

  // ============================================
  // RELEASE HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/releases
  Future<Response> _getReleases(Request request, String projectId) async {
    try {
      final releases = await _service.getReleases(projectId);
      return ApiResponse.success(
        data: releases.map((r) => r.toJson()).toList(),
        message: 'Releases retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getReleases');
    }
  }

  /// GET /api/projects/:projectId/releases/:releaseId
  Future<Response> _getReleaseById(
    Request request,
    String projectId,
    String releaseId,
  ) async {
    try {
      final release = await _service.getReleaseById(releaseId);
      return ApiResponse.success(
        data: release.toJson(),
        message: 'Release retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getReleaseById');
    }
  }

  /// POST /api/projects/:projectId/releases
  Future<Response> _createRelease(Request request, String projectId) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final release = await _service.createRelease(data);
      return ApiResponse.success(
        data: release.toJson(),
        message: 'Release created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'createRelease');
    }
  }

  /// PUT /api/projects/:projectId/releases/:releaseId
  Future<Response> _updateRelease(
    Request request,
    String projectId,
    String releaseId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final release = await _service.updateRelease(releaseId, data);
      return ApiResponse.success(
        data: release.toJson(),
        message: 'Release updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateRelease');
    }
  }

  /// DELETE /api/projects/:projectId/releases/:releaseId
  Future<Response> _deleteRelease(
    Request request,
    String projectId,
    String releaseId,
  ) async {
    try {
      await _service.deleteRelease(releaseId);
      return ApiResponse.success(
        message: 'Release deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'deleteRelease');
    }
  }

  // ============================================
  // MILESTONE HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/milestones
  Future<Response> _getMilestones(Request request, String projectId) async {
    try {
      final milestones = await _service.getMilestones(projectId);
      return ApiResponse.success(
        data: milestones.map((m) => m.toJson()).toList(),
        message: 'Milestones retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getMilestones');
    }
  }

  /// GET /api/projects/:projectId/milestones/:milestoneId
  Future<Response> _getMilestoneById(
    Request request,
    String projectId,
    String milestoneId,
  ) async {
    try {
      final milestone = await _service.getMilestoneById(milestoneId);
      return ApiResponse.success(
        data: milestone.toJson(),
        message: 'Milestone retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getMilestoneById');
    }
  }

  /// POST /api/projects/:projectId/milestones
  Future<Response> _createMilestone(Request request, String projectId) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final milestone = await _service.createMilestone(data);
      return ApiResponse.success(
        data: milestone.toJson(),
        message: 'Milestone created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'createMilestone');
    }
  }

  /// PUT /api/projects/:projectId/milestones/:milestoneId
  Future<Response> _updateMilestone(
    Request request,
    String projectId,
    String milestoneId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final milestone = await _service.updateMilestone(milestoneId, data);
      return ApiResponse.success(
        data: milestone.toJson(),
        message: 'Milestone updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateMilestone');
    }
  }

  /// DELETE /api/projects/:projectId/milestones/:milestoneId
  Future<Response> _deleteMilestone(
    Request request,
    String projectId,
    String milestoneId,
  ) async {
    try {
      await _service.deleteMilestone(milestoneId);
      return ApiResponse.success(
        message: 'Milestone deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'deleteMilestone');
    }
  }

  // ============================================
  // CLIENT REVIEW HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/client-reviews
  Future<Response> _getClientReviews(Request request, String projectId) async {
    try {
      final reviews = await _service.getClientReviews(projectId);
      return ApiResponse.success(
        data: reviews.map((r) => r.toJson()).toList(),
        message: 'Client reviews retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getClientReviews');
    }
  }

  /// GET /api/projects/:projectId/client-reviews/:reviewId
  Future<Response> _getClientReviewById(
    Request request,
    String projectId,
    String reviewId,
  ) async {
    try {
      final review = await _service.getClientReviewById(reviewId);
      return ApiResponse.success(
        data: review.toJson(),
        message: 'Client review retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getClientReviewById');
    }
  }

  /// POST /api/projects/:projectId/client-reviews
  Future<Response> _createClientReview(
    Request request,
    String projectId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final review = await _service.createClientReview(data);
      return ApiResponse.success(
        data: review.toJson(),
        message: 'Client review created successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'createClientReview');
    }
  }

  /// PUT /api/projects/:projectId/client-reviews/:reviewId
  Future<Response> _updateClientReview(
    Request request,
    String projectId,
    String reviewId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final review = await _service.updateClientReview(reviewId, data);
      return ApiResponse.success(
        data: review.toJson(),
        message: 'Client review updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateClientReview');
    }
  }

  /// DELETE /api/projects/:projectId/client-reviews/:reviewId
  Future<Response> _deleteClientReview(
    Request request,
    String projectId,
    String reviewId,
  ) async {
    try {
      await _service.deleteClientReview(reviewId);
      return ApiResponse.success(
        message: 'Client review deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'deleteClientReview');
    }
  }

  // ============================================
  // DISCONTINUATION HANDLERS
  // ============================================

  /// GET /api/projects/:projectId/discontinuation
  Future<Response> _getDiscontinuation(
    Request request,
    String projectId,
  ) async {
    try {
      final discontinuation = await _service.getDiscontinuation(projectId);
      if (discontinuation == null) {
        return ApiResponse.success(
          data: null,
          message: 'Project is not discontinued',
        ).toShelfResponse();
      }
      return ApiResponse.success(
        data: discontinuation.toJson(),
        message: 'Discontinuation retrieved successfully',
      ).toShelfResponse();
    } catch (e) {
      return _handleError(e, 'getDiscontinuation');
    }
  }

  /// POST /api/projects/:projectId/discontinuation
  Future<Response> _discontinueProject(
    Request request,
    String projectId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      data['project_id'] = projectId;

      final discontinuation = await _service.discontinueProject(data);
      return ApiResponse.success(
        data: discontinuation.toJson(),
        message: 'Project discontinued successfully',
      ).toShelfResponse(statusCode: 201);
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'discontinueProject');
    }
  }

  /// PUT /api/projects/:projectId/discontinuation
  Future<Response> _updateDiscontinuation(
    Request request,
    String projectId,
  ) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return _badRequest('Request body is required');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final existing = await _service.getDiscontinuation(projectId);
      if (existing == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Project is not discontinued',
        ).toShelfResponse(statusCode: 404);
      }

      final updated = await _service.updateDiscontinuation(
        existing.projectDiscontinuationId!,
        data,
      );
      return ApiResponse.success(
        data: updated.toJson(),
        message: 'Discontinuation updated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'updateDiscontinuation');
    }
  }

  /// DELETE /api/projects/:projectId/discontinuation
  Future<Response> _reactivateProject(Request request, String projectId) async {
    try {
      String updatedBy = 'system';

      // Try to read from body if exists
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          updatedBy = data['updated_by']?.toString() ?? 'system';
        }
      } catch (_) {}

      // Fallback to query params
      updatedBy = request.url.queryParameters['updated_by'] ?? updatedBy;

      await _service.reactivateProject(projectId, updatedBy);
      return ApiResponse.success(
        message: 'Project reactivated successfully',
      ).toShelfResponse();
    } on FormatException {
      return _badRequest('Invalid JSON format');
    } catch (e) {
      return _handleError(e, 'reactivateProject');
    }
  }

  // ============================================
  // ERROR HANDLING
  // ============================================

  Response _handleError(dynamic error, String operation) {
    if (error is ValidationException) {
      return ApiResponse.validationError(
        error.errors,
      ).toShelfResponse(statusCode: 400);
    }
    if (error is NotFoundException) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: error.message,
      ).toShelfResponse(statusCode: 404);
    }
    if (error is UnauthorizedException) {
      return ApiResponse.error(
        code: 'UNAUTHORIZED',
        message: error.message,
      ).toShelfResponse(statusCode: 401);
    }

    _logger.error('Error in $operation: $error');
    return ApiResponse.error(
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred. Please try again later.',
    ).toShelfResponse(statusCode: 500);
  }

  Response _badRequest(String message) {
    return ApiResponse.error(
      code: 'BAD_REQUEST',
      message: message,
    ).toShelfResponse(statusCode: 400);
  }
}
