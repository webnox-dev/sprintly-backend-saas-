import '../data/repositories/project_helper_repository.dart';
import '../data/repositories/project_repository.dart';
import '../domain/models/project.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Service for Project Helper Tables with comprehensive validation
/// Handles: Documents, Figma URLs, Releases, Milestones, Reviews, Discontinuation
class ProjectHelperService {
  final ProjectHelperRepository _repository = ProjectHelperRepository();
  final ProjectRepository _projectRepository = ProjectRepository();
  final AppLogger _logger = AppLogger('ProjectHelperService');

  // ============================================
  // VALIDATION CONSTANTS
  // ============================================

  static const int maxDocumentNameLength = 255;
  static const int maxMilestoneTitleLength = 255;
  static const int maxMilestoneDescriptionLength = 2000;
  static const int maxReleaseTitleLength = 255;
  static const int maxReleaseNotesLength = 5000;
  static const int maxReviewCommentLength = 2000;
  static const int maxDiscontinuationReasonLength = 2000;
  static const int maxDiscontinuationRemarksLength = 2000;

  // ============================================
  // PROJECT VERIFICATION
  // ============================================

  /// Verify project exists
  Future<void> _verifyProjectExists(String projectId) async {
    final project = await _projectRepository.getById(projectId);
    if (project == null) {
      throw NotFoundException(resource: 'Project', id: projectId);
    }
  }

  void _validateId(String id, String fieldName) {
    if (id.trim().isEmpty) {
      throw ValidationException({
        fieldName: ['$fieldName is required'],
      });
    }
  }

  // ============================================
  // PROJECT DOCUMENTS
  // ============================================

  /// Get all documents for a project
  Future<List<ProjectDocument>> getDocuments(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getDocumentsByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting documents: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get document by ID
  Future<ProjectDocument> getDocumentById(String documentId) async {
    try {
      _validateId(documentId, 'document_id');
      final doc = await _repository.getDocumentById(documentId);
      if (doc == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }
      return doc;
    } catch (e, stackTrace) {
      _logger.error('Error getting document: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create document with validation
  Future<ProjectDocument> createDocument(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      // Required field validation
      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['document_name'] == null ||
          data['document_name'].toString().trim().isEmpty) {
        errors['document_name'] = ['Document name is required'];
      } else {
        final name = data['document_name'].toString().trim();
        if (name.length > maxDocumentNameLength) {
          errors['document_name'] = [
            'Document name cannot exceed $maxDocumentNameLength characters',
          ];
        }
        data['document_name'] = name;
      }

      if (data['document_url'] == null ||
          data['document_url'].toString().trim().isEmpty) {
        errors['document_url'] = ['Document URL is required'];
      } else if (!_isValidUrl(data['document_url'].toString())) {
        errors['document_url'] = ['Invalid URL format'];
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);
      return await _repository.createDocument(data);
    } catch (e, stackTrace) {
      _logger.error('Error creating document: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update document
  Future<ProjectDocument> updateDocument(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(documentId, 'document_id');

      final existing = await _repository.getDocumentById(documentId);
      if (existing == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('document_name')) {
        final name = data['document_name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          errors['document_name'] = ['Document name cannot be empty'];
        } else if (name.length > maxDocumentNameLength) {
          errors['document_name'] = [
            'Document name cannot exceed $maxDocumentNameLength characters',
          ];
        }
        data['document_name'] = name;
      }

      if (data.containsKey('document_url') && data['document_url'] != null) {
        if (!_isValidUrl(data['document_url'].toString())) {
          errors['document_url'] = ['Invalid URL format'];
        }
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateDocument(documentId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating document: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete document
  Future<void> deleteDocument(String documentId) async {
    try {
      _validateId(documentId, 'document_id');

      final existing = await _repository.getDocumentById(documentId);
      if (existing == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }
      await _repository.deleteDocument(documentId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting document: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT FIGMA URLS
  // ============================================

  /// Get all figma URLs for a project
  Future<List<FigmaUrl>> getFigmaUrls(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getFigmaUrlsByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting figma URLs: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get figma URL by ID
  Future<FigmaUrl> getFigmaUrlById(String figmaUrlId) async {
    try {
      _validateId(figmaUrlId, 'figma_url_id');
      final url = await _repository.getFigmaUrlById(figmaUrlId);
      if (url == null) {
        throw NotFoundException(resource: 'Figma URL', id: figmaUrlId);
      }
      return url;
    } catch (e, stackTrace) {
      _logger.error('Error getting figma URL: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create figma URL with validation
  Future<FigmaUrl> createFigmaUrl(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['figma_url_name'] == null ||
          data['figma_url_name'].toString().trim().isEmpty) {
        errors['figma_url_name'] = ['Figma URL name is required'];
      } else {
        data['figma_url_name'] = data['figma_url_name'].toString().trim();
      }

      if (data['figma_url'] == null ||
          data['figma_url'].toString().trim().isEmpty) {
        errors['figma_url'] = ['Figma URL is required'];
      } else if (!_isValidFigmaUrl(data['figma_url'].toString())) {
        errors['figma_url'] = ['Invalid Figma URL. Must be a figma.com URL'];
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);
      return await _repository.createFigmaUrl(data);
    } catch (e, stackTrace) {
      _logger.error('Error creating figma URL: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update figma URL
  Future<FigmaUrl> updateFigmaUrl(
    String figmaUrlId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(figmaUrlId, 'figma_url_id');

      final existing = await _repository.getFigmaUrlById(figmaUrlId);
      if (existing == null) {
        throw NotFoundException(resource: 'Figma URL', id: figmaUrlId);
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('figma_url') && data['figma_url'] != null) {
        if (!_isValidFigmaUrl(data['figma_url'].toString())) {
          errors['figma_url'] = ['Invalid Figma URL. Must be a figma.com URL'];
        }
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateFigmaUrl(figmaUrlId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating figma URL: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete figma URL
  Future<void> deleteFigmaUrl(String figmaUrlId) async {
    try {
      _validateId(figmaUrlId, 'figma_url_id');

      final existing = await _repository.getFigmaUrlById(figmaUrlId);
      if (existing == null) {
        throw NotFoundException(resource: 'Figma URL', id: figmaUrlId);
      }
      await _repository.deleteFigmaUrl(figmaUrlId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting figma URL: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT RELEASES
  // ============================================

  /// Get all releases for a project
  Future<List<ProjectRelease>> getReleases(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getReleasesByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting releases: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get release by ID
  Future<ProjectRelease> getReleaseById(String releaseId) async {
    try {
      _validateId(releaseId, 'release_id');
      final release = await _repository.getReleaseById(releaseId);
      if (release == null) {
        throw NotFoundException(resource: 'Release', id: releaseId);
      }
      return release;
    } catch (e, stackTrace) {
      _logger.error('Error getting release: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create release with validation
  Future<ProjectRelease> createRelease(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['project_release_title'] == null ||
          data['project_release_title'].toString().trim().isEmpty) {
        errors['project_release_title'] = ['Release title is required'];
      } else {
        final title = data['project_release_title'].toString().trim();
        if (title.length > maxReleaseTitleLength) {
          errors['project_release_title'] = [
            'Title cannot exceed $maxReleaseTitleLength characters',
          ];
        }
        data['project_release_title'] = title;
      }

      if (data['project_release_notes'] != null) {
        final notes = data['project_release_notes'].toString().trim();
        if (notes.length > maxReleaseNotesLength) {
          errors['project_release_notes'] = [
            'Notes cannot exceed $maxReleaseNotesLength characters',
          ];
        }
        data['project_release_notes'] = notes.isEmpty ? null : notes;
      }

      // Date validation
      _validateReleaseDates(data, errors);

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);
      return await _repository.createRelease(data);
    } catch (e, stackTrace) {
      _logger.error('Error creating release: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update release
  Future<ProjectRelease> updateRelease(
    String releaseId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(releaseId, 'release_id');

      final existing = await _repository.getReleaseById(releaseId);
      if (existing == null) {
        throw NotFoundException(resource: 'Release', id: releaseId);
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('project_release_title')) {
        final title = data['project_release_title']?.toString().trim() ?? '';
        if (title.isEmpty) {
          errors['project_release_title'] = ['Release title cannot be empty'];
        } else if (title.length > maxReleaseTitleLength) {
          errors['project_release_title'] = [
            'Title cannot exceed $maxReleaseTitleLength characters',
          ];
        }
        data['project_release_title'] = title;
      }

      // Date validation with existing values
      _validateReleaseDates(data, errors, existing: existing);

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateRelease(releaseId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating release: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete release
  Future<void> deleteRelease(String releaseId) async {
    try {
      _validateId(releaseId, 'release_id');

      final existing = await _repository.getReleaseById(releaseId);
      if (existing == null) {
        throw NotFoundException(resource: 'Release', id: releaseId);
      }
      await _repository.deleteRelease(releaseId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting release: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT MILESTONES
  // ============================================

  /// Get all milestones for a project
  Future<List<ProjectMilestone>> getMilestones(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getMilestonesByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting milestones: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get milestone by ID
  Future<ProjectMilestone> getMilestoneById(String milestoneId) async {
    try {
      _validateId(milestoneId, 'milestone_id');
      final milestone = await _repository.getMilestoneById(milestoneId);
      if (milestone == null) {
        throw NotFoundException(resource: 'Milestone', id: milestoneId);
      }
      return milestone;
    } catch (e, stackTrace) {
      _logger.error('Error getting milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create milestone with validation
  Future<ProjectMilestone> createMilestone(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['project_milestone_title'] == null ||
          data['project_milestone_title'].toString().trim().isEmpty) {
        errors['project_milestone_title'] = ['Milestone title is required'];
      } else {
        final title = data['project_milestone_title'].toString().trim();
        if (title.length > maxMilestoneTitleLength) {
          errors['project_milestone_title'] = [
            'Title cannot exceed $maxMilestoneTitleLength characters',
          ];
        }
        data['project_milestone_title'] = title;
      }

      if (data['project_milestone_achievement_description'] != null) {
        final desc = data['project_milestone_achievement_description']
            .toString()
            .trim();
        if (desc.length > maxMilestoneDescriptionLength) {
          errors['project_milestone_achievement_description'] = [
            'Description cannot exceed $maxMilestoneDescriptionLength characters',
          ];
        }
        data['project_milestone_achievement_description'] = desc.isEmpty
            ? null
            : desc;
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);
      return await _repository.createMilestone(data);
    } catch (e, stackTrace) {
      _logger.error('Error creating milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update milestone
  Future<ProjectMilestone> updateMilestone(
    String milestoneId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(milestoneId, 'milestone_id');

      final existing = await _repository.getMilestoneById(milestoneId);
      if (existing == null) {
        throw NotFoundException(resource: 'Milestone', id: milestoneId);
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('project_milestone_title')) {
        final title = data['project_milestone_title']?.toString().trim() ?? '';
        if (title.isEmpty) {
          errors['project_milestone_title'] = [
            'Milestone title cannot be empty',
          ];
        } else if (title.length > maxMilestoneTitleLength) {
          errors['project_milestone_title'] = [
            'Title cannot exceed $maxMilestoneTitleLength characters',
          ];
        }
        data['project_milestone_title'] = title;
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateMilestone(milestoneId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete milestone
  Future<void> deleteMilestone(String milestoneId) async {
    try {
      _validateId(milestoneId, 'milestone_id');

      final existing = await _repository.getMilestoneById(milestoneId);
      if (existing == null) {
        throw NotFoundException(resource: 'Milestone', id: milestoneId);
      }
      await _repository.deleteMilestone(milestoneId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // CLIENT REVIEWS
  // ============================================

  /// Get all client reviews for a project
  Future<List<ClientReview>> getClientReviews(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getClientReviewsByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting client reviews: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get client review by ID
  Future<ClientReview> getClientReviewById(String reviewId) async {
    try {
      _validateId(reviewId, 'review_id');
      final review = await _repository.getClientReviewById(reviewId);
      if (review == null) {
        throw NotFoundException(resource: 'Client Review', id: reviewId);
      }
      return review;
    } catch (e, stackTrace) {
      _logger.error('Error getting client review: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create client review with validation
  Future<ClientReview> createClientReview(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['client_review_comment'] == null ||
          data['client_review_comment'].toString().trim().isEmpty) {
        errors['client_review_comment'] = ['Review comment is required'];
      } else {
        final comment = data['client_review_comment'].toString().trim();
        if (comment.length > maxReviewCommentLength) {
          errors['client_review_comment'] = [
            'Comment cannot exceed $maxReviewCommentLength characters',
          ];
        }
        data['client_review_comment'] = comment;
      }

      if (data['client_review_rating'] == null) {
        errors['client_review_rating'] = ['Rating is required'];
      } else {
        final rating = (data['client_review_rating'] as num?)?.toInt();
        if (rating == null || rating < 0 || rating > 5) {
          errors['client_review_rating'] = [
            'Rating must be an integer between 0 and 5',
          ];
        }
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);
      return await _repository.createClientReview(data);
    } catch (e, stackTrace) {
      _logger.error('Error creating client review: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update client review
  Future<ClientReview> updateClientReview(
    String reviewId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(reviewId, 'review_id');

      final existing = await _repository.getClientReviewById(reviewId);
      if (existing == null) {
        throw NotFoundException(resource: 'Client Review', id: reviewId);
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('client_review_comment')) {
        final comment = data['client_review_comment']?.toString().trim() ?? '';
        if (comment.isEmpty) {
          errors['client_review_comment'] = ['Review comment cannot be empty'];
        } else if (comment.length > maxReviewCommentLength) {
          errors['client_review_comment'] = [
            'Comment cannot exceed $maxReviewCommentLength characters',
          ];
        }
        data['client_review_comment'] = comment;
      }

      if (data.containsKey('client_review_rating')) {
        final rating = (data['client_review_rating'] as num?)?.toInt();
        if (rating == null || rating < 0 || rating > 5) {
          errors['client_review_rating'] = ['Rating must be between 0 and 5'];
        }
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateClientReview(reviewId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating client review: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete client review
  Future<void> deleteClientReview(String reviewId) async {
    try {
      _validateId(reviewId, 'review_id');

      final existing = await _repository.getClientReviewById(reviewId);
      if (existing == null) {
        throw NotFoundException(resource: 'Client Review', id: reviewId);
      }
      await _repository.deleteClientReview(reviewId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting client review: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT DISCONTINUATION
  // ============================================

  /// Get discontinuation for a project
  Future<ProjectDiscontinuation?> getDiscontinuation(String projectId) async {
    try {
      _validateId(projectId, 'project_id');
      await _verifyProjectExists(projectId);
      return await _repository.getDiscontinuationByProjectId(projectId);
    } catch (e, stackTrace) {
      _logger.error('Error getting discontinuation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Discontinue a project with validation
  Future<ProjectDiscontinuation> discontinueProject(
    Map<String, dynamic> data,
  ) async {
    try {
      final errors = <String, List<String>>{};

      if (data['project_id'] == null ||
          data['project_id'].toString().trim().isEmpty) {
        errors['project_id'] = ['Project ID is required'];
      }

      if (data['project_discontinuation_reason'] == null ||
          data['project_discontinuation_reason'].toString().trim().isEmpty) {
        errors['project_discontinuation_reason'] = [
          'Discontinuation reason is required',
        ];
      } else {
        final reason = data['project_discontinuation_reason'].toString().trim();
        if (reason.length > maxDiscontinuationReasonLength) {
          errors['project_discontinuation_reason'] = [
            'Reason cannot exceed $maxDiscontinuationReasonLength characters',
          ];
        }
        data['project_discontinuation_reason'] = reason;
      }

      if (data['project_discontinuation_by'] == null ||
          data['project_discontinuation_by'].toString().trim().isEmpty) {
        errors['project_discontinuation_by'] = ['Discontinued by is required'];
      }

      if (data['project_discontinuation_remarks'] != null) {
        final remarks = data['project_discontinuation_remarks']
            .toString()
            .trim();
        if (remarks.length > maxDiscontinuationRemarksLength) {
          errors['project_discontinuation_remarks'] = [
            'Remarks cannot exceed $maxDiscontinuationRemarksLength characters',
          ];
        }
        data['project_discontinuation_remarks'] = remarks.isEmpty
            ? null
            : remarks;
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      await _verifyProjectExists(data['project_id']);

      // Check if already discontinued
      final existing = await _repository.getDiscontinuationByProjectId(
        data['project_id'],
      );
      if (existing != null) {
        throw ValidationException({
          'project_id': ['Project is already discontinued'],
        });
      }

      return await _repository.createDiscontinuation(data);
    } catch (e, stackTrace) {
      _logger.error('Error discontinuing project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update discontinuation details
  Future<ProjectDiscontinuation> updateDiscontinuation(
    String discontinuationId,
    Map<String, dynamic> data,
  ) async {
    try {
      _validateId(discontinuationId, 'discontinuation_id');

      final existing = await _repository.getDiscontinuationById(
        discontinuationId,
      );
      if (existing == null) {
        throw NotFoundException(
          resource: 'Discontinuation',
          id: discontinuationId,
        );
      }

      final errors = <String, List<String>>{};

      if (data.containsKey('project_discontinuation_reason')) {
        final reason =
            data['project_discontinuation_reason']?.toString().trim() ?? '';
        if (reason.isEmpty) {
          errors['project_discontinuation_reason'] = ['Reason cannot be empty'];
        } else if (reason.length > maxDiscontinuationReasonLength) {
          errors['project_discontinuation_reason'] = [
            'Reason cannot exceed $maxDiscontinuationReasonLength characters',
          ];
        }
        data['project_discontinuation_reason'] = reason;
      }

      if (errors.isNotEmpty) throw ValidationException(errors);

      return await _repository.updateDiscontinuation(discontinuationId, data);
    } catch (e, stackTrace) {
      _logger.error('Error updating discontinuation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Reactivate a discontinued project
  Future<void> reactivateProject(String projectId, String updatedBy) async {
    try {
      _validateId(projectId, 'project_id');
      _validateId(updatedBy, 'updated_by');

      await _verifyProjectExists(projectId);

      final discontinuation = await _repository.getDiscontinuationByProjectId(
        projectId,
      );
      if (discontinuation == null) {
        throw ValidationException({
          'project_id': ['Project is not discontinued'],
        });
      }

      await _repository.deleteDiscontinuation(
        discontinuation.projectDiscontinuationId!,
        projectId,
        updatedBy,
      );
    } catch (e, stackTrace) {
      _logger.error('Error reactivating project: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PRIVATE HELPER METHODS
  // ============================================

  void _validateReleaseDates(
    Map<String, dynamic> data,
    Map<String, List<String>> errors, {
    ProjectRelease? existing,
  }) {
    DateTime? plannedDate;
    DateTime? devCutoff;
    DateTime? qcCutoff;

    // Parse or use existing dates
    if (data['project_release_planned_date'] != null) {
      plannedDate = DateTime.tryParse(
        data['project_release_planned_date'].toString(),
      );
      if (plannedDate == null) {
        errors['project_release_planned_date'] = [
          'Invalid date format. Use YYYY-MM-DD',
        ];
      }
    } else if (existing?.projectReleasePlannedDate != null) {
      plannedDate = DateTime.tryParse(existing!.projectReleasePlannedDate!);
    }

    if (data['project_release_dev_cutoff_date'] != null) {
      devCutoff = DateTime.tryParse(
        data['project_release_dev_cutoff_date'].toString(),
      );
      if (devCutoff == null) {
        errors['project_release_dev_cutoff_date'] = [
          'Invalid date format. Use YYYY-MM-DD',
        ];
      }
    } else if (existing?.projectReleaseDevCutoffDate != null) {
      devCutoff = DateTime.tryParse(existing!.projectReleaseDevCutoffDate!);
    }

    if (data['project_release_qc_cutoff_date'] != null) {
      qcCutoff = DateTime.tryParse(
        data['project_release_qc_cutoff_date'].toString(),
      );
      if (qcCutoff == null) {
        errors['project_release_qc_cutoff_date'] = [
          'Invalid date format. Use YYYY-MM-DD',
        ];
      }
    } else if (existing?.projectReleaseQcCutoffDate != null) {
      qcCutoff = DateTime.tryParse(existing!.projectReleaseQcCutoffDate!);
    }

    // Cross-field validation: Dev Cutoff < QC Cutoff < Planned Date
    // Check: Dev Cutoff must be before QC Cutoff
    if (devCutoff != null &&
        qcCutoff != null &&
        !devCutoff.isBefore(qcCutoff)) {
      errors['project_release_dev_cutoff_date'] = [
        'Dev cutoff date must be before QC cutoff date',
      ];
    }

    // Check: QC Cutoff must be before Planned Date
    if (qcCutoff != null &&
        plannedDate != null &&
        !qcCutoff.isBefore(plannedDate)) {
      errors['project_release_qc_cutoff_date'] = [
        'QC cutoff date must be before planned release date',
      ];
    }

    // Check: Dev Cutoff must be before Planned Date (implied, but explicit for better UX)
    if (devCutoff != null &&
        plannedDate != null &&
        !devCutoff.isBefore(plannedDate)) {
      errors['project_release_dev_cutoff_date'] ??= [];
      if (!errors.containsKey('project_release_dev_cutoff_date')) {
        errors['project_release_dev_cutoff_date'] = [
          'Dev cutoff date must be before planned release date',
        ];
      }
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  bool _isValidFigmaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          (uri.host.contains('figma.com') || uri.host.contains('figma.app'));
    } catch (_) {
      return false;
    }
  }
}
