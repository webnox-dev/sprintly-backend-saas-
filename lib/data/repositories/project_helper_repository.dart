import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';
import '../../domain/models/project.dart';

/// Repository for Project Helper Tables CRUD operations
class ProjectHelperRepository {
  final AppLogger _logger = AppLogger('ProjectHelperRepository');

  // ============================================
  // PROJECT DOCUMENTS CRUD
  // ============================================

  /// Get all documents for a project
  Future<List<ProjectDocument>> getDocumentsByProjectId(
    String projectId,
  ) async {
    try {
      final results = await DatabaseConnection.query(
        'SELECT * FROM project_documents WHERE project_id = @projectId ORDER BY created_at DESC',
        values: {'projectId': projectId},
      );
      return results.map((row) => ProjectDocument.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting documents for project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get document by ID
  Future<ProjectDocument?> getDocumentById(String documentId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_documents WHERE document_id = @documentId',
        values: {'documentId': documentId},
      );
      if (result == null) return null;
      return ProjectDocument.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting document by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create document
  Future<ProjectDocument> createDocument(Map<String, dynamic> data) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO project_documents (project_id, document_name, document_url, document_type, created_by)
        VALUES (@projectId, @documentName, @documentUrl, @documentType, @createdBy)
        RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'documentName': data['document_name'],
          'documentUrl': data['document_url'],
          'documentType': data['document_type'],
          'createdBy': data['created_by'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create document');
      }
      return ProjectDocument.fromMap(result);
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
      final updates = <String>[];
      final params = <String, dynamic>{'documentId': documentId};

      if (data.containsKey('document_name')) {
        updates.add('document_name = @documentName');
        params['documentName'] = data['document_name'];
      }
      if (data.containsKey('document_url')) {
        updates.add('document_url = @documentUrl');
        params['documentUrl'] = data['document_url'];
      }
      if (data.containsKey('document_type')) {
        updates.add('document_type = @documentType');
        params['documentType'] = data['document_type'];
      }
      if (data.containsKey('updated_by')) {
        updates.add('updated_by = @updatedBy');
        params['updatedBy'] = data['updated_by'];
      }

      if (updates.isEmpty) {
        final existing = await getDocumentById(documentId);
        if (existing == null) {
          throw NotFoundException(resource: 'Document', id: documentId);
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE project_documents SET ${updates.join(', ')}
        WHERE document_id = @documentId RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }
      return ProjectDocument.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating document: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete document
  Future<void> deleteDocument(String documentId) async {
    try {
      await DatabaseConnection.execute(
        'DELETE FROM project_documents WHERE document_id = @documentId',
        values: {'documentId': documentId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting document: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT FIGMA URLS CRUD
  // ============================================

  /// Get all figma urls for a project
  Future<List<FigmaUrl>> getFigmaUrlsByProjectId(String projectId) async {
    try {
      final results = await DatabaseConnection.query(
        'SELECT * FROM project_figma_urls WHERE project_id = @projectId ORDER BY created_at DESC',
        values: {'projectId': projectId},
      );
      return results.map((row) => FigmaUrl.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting figma urls for project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get figma url by ID
  Future<FigmaUrl?> getFigmaUrlById(String figmaUrlId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_figma_urls WHERE figma_url_id = @figmaUrlId',
        values: {'figmaUrlId': figmaUrlId},
      );
      if (result == null) return null;
      return FigmaUrl.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting figma url by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create figma url
  Future<FigmaUrl> createFigmaUrl(Map<String, dynamic> data) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO project_figma_urls (project_id, figma_url_name, figma_url, created_by)
        VALUES (@projectId, @figmaUrlName, @figmaUrl, @createdBy)
        RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'figmaUrlName': data['figma_url_name'],
          'figmaUrl': data['figma_url'],
          'createdBy': data['created_by'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create figma URL');
      }
      return FigmaUrl.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating figma url: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update figma url
  Future<FigmaUrl> updateFigmaUrl(
    String figmaUrlId,
    Map<String, dynamic> data,
  ) async {
    try {
      final updates = <String>[];
      final params = <String, dynamic>{'figmaUrlId': figmaUrlId};

      if (data.containsKey('figma_url_name')) {
        updates.add('figma_url_name = @figmaUrlName');
        params['figmaUrlName'] = data['figma_url_name'];
      }
      if (data.containsKey('figma_url')) {
        updates.add('figma_url = @figmaUrl');
        params['figmaUrl'] = data['figma_url'];
      }
      if (data.containsKey('updated_by')) {
        updates.add('updated_by = @updatedBy');
        params['updatedBy'] = data['updated_by'];
      }

      if (updates.isEmpty) {
        final existing = await getFigmaUrlById(figmaUrlId);
        if (existing == null) {
          throw NotFoundException(resource: 'Figma URL', id: figmaUrlId);
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE project_figma_urls SET ${updates.join(', ')}
        WHERE figma_url_id = @figmaUrlId RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(resource: 'Figma URL', id: figmaUrlId);
      }
      return FigmaUrl.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating figma url: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete figma url
  Future<void> deleteFigmaUrl(String figmaUrlId) async {
    try {
      await DatabaseConnection.execute(
        'DELETE FROM project_figma_urls WHERE figma_url_id = @figmaUrlId',
        values: {'figmaUrlId': figmaUrlId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting figma url: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT RELEASES CRUD
  // ============================================

  /// Get all releases for a project
  Future<List<ProjectRelease>> getReleasesByProjectId(String projectId) async {
    try {
      final results = await DatabaseConnection.query(
        'SELECT * FROM project_releases WHERE project_id = @projectId ORDER BY project_release_created_at DESC',
        values: {'projectId': projectId},
      );
      return results.map((row) => ProjectRelease.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting releases for project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get release by ID
  Future<ProjectRelease?> getReleaseById(String releaseId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_releases WHERE project_release_id = @releaseId',
        values: {'releaseId': releaseId},
      );
      if (result == null) return null;
      return ProjectRelease.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting release by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create release
  Future<ProjectRelease> createRelease(Map<String, dynamic> data) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO project_releases (
          project_id, project_release_title, project_release_planned_date, 
          project_release_actual_date, project_release_dev_cutoff_date,
          project_release_qc_cutoff_date, project_release_notes, project_release_created_by
        ) VALUES (
          @projectId, @title, @plannedDate, @actualDate, @devCutoffDate,
          @qcCutoffDate, @notes, @createdBy
        ) RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'title': data['project_release_title'],
          'plannedDate': data['project_release_planned_date'],
          'actualDate': data['project_release_actual_date'],
          'devCutoffDate': data['project_release_dev_cutoff_date'],
          'qcCutoffDate': data['project_release_qc_cutoff_date'],
          'notes': data['project_release_notes'],
          'createdBy': data['project_release_created_by'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create release');
      }
      return ProjectRelease.fromMap(result);
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
      final updates = <String>[];
      final params = <String, dynamic>{'releaseId': releaseId};

      final fieldMap = {
        'project_release_title': 'title',
        'project_release_planned_date': 'plannedDate',
        'project_release_actual_date': 'actualDate',
        'project_release_dev_cutoff_date': 'devCutoffDate',
        'project_release_qc_cutoff_date': 'qcCutoffDate',
        'project_release_notes': 'notes',
        'project_release_updated_by': 'updatedBy',
      };

      fieldMap.forEach((dbField, paramName) {
        if (data.containsKey(dbField)) {
          updates.add('$dbField = @$paramName');
          params[paramName] = data[dbField];
        }
      });

      // Always update the timestamp on update
      updates.add('project_release_updated_at = CURRENT_TIMESTAMP');

      if (updates.isEmpty) {
        final existing = await getReleaseById(releaseId);
        if (existing == null) {
          throw NotFoundException(resource: 'Release', id: releaseId);
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE project_releases SET ${updates.join(', ')}
        WHERE project_release_id = @releaseId RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(resource: 'Release', id: releaseId);
      }
      return ProjectRelease.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating release: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete release
  Future<void> deleteRelease(String releaseId) async {
    try {
      await DatabaseConnection.execute(
        'DELETE FROM project_releases WHERE project_release_id = @releaseId',
        values: {'releaseId': releaseId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting release: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT MILESTONES CRUD
  // ============================================

  /// Get all milestones for a project
  Future<List<ProjectMilestone>> getMilestonesByProjectId(
    String projectId,
  ) async {
    try {
      final results = await DatabaseConnection.query(
        'SELECT * FROM project_milestones WHERE project_id = @projectId ORDER BY project_milestone_created_at DESC',
        values: {'projectId': projectId},
      );
      return results.map((row) => ProjectMilestone.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting milestones for project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get milestone by ID
  Future<ProjectMilestone?> getMilestoneById(String milestoneId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_milestones WHERE project_milestone_id = @milestoneId',
        values: {'milestoneId': milestoneId},
      );
      if (result == null) return null;
      return ProjectMilestone.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting milestone by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create milestone
  Future<ProjectMilestone> createMilestone(Map<String, dynamic> data) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO project_milestones (
          project_id, project_milestone_title, project_milestone_achievement_description, 
          project_milestone_created_by
        ) VALUES (@projectId, @title, @description, @createdBy)
        RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'title': data['project_milestone_title'],
          'description': data['project_milestone_achievement_description'],
          'createdBy': data['project_milestone_created_by'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create milestone');
      }
      return ProjectMilestone.fromMap(result);
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
      final updates = <String>[];
      final params = <String, dynamic>{'milestoneId': milestoneId};

      if (data.containsKey('project_milestone_title')) {
        updates.add('project_milestone_title = @title');
        params['title'] = data['project_milestone_title'];
      }
      if (data.containsKey('project_milestone_achievement_description')) {
        updates.add('project_milestone_achievement_description = @description');
        params['description'] =
            data['project_milestone_achievement_description'];
      }
      if (data.containsKey('project_milestone_updated_by')) {
        updates.add('project_milestone_updated_by = @updatedBy');
        params['updatedBy'] = data['project_milestone_updated_by'];
      }

      // Always update the timestamp on update
      updates.add('project_milestone_updated_at = CURRENT_TIMESTAMP');

      if (updates.isEmpty) {
        final existing = await getMilestoneById(milestoneId);
        if (existing == null) {
          throw NotFoundException(resource: 'Milestone', id: milestoneId);
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE project_milestones SET ${updates.join(', ')}
        WHERE project_milestone_id = @milestoneId RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(resource: 'Milestone', id: milestoneId);
      }
      return ProjectMilestone.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete milestone
  Future<void> deleteMilestone(String milestoneId) async {
    try {
      await DatabaseConnection.execute(
        'DELETE FROM project_milestones WHERE project_milestone_id = @milestoneId',
        values: {'milestoneId': milestoneId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting milestone: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // CLIENT REVIEWS CRUD
  // ============================================

  /// Get all client reviews for a project
  Future<List<ClientReview>> getClientReviewsByProjectId(
    String projectId,
  ) async {
    try {
      final results = await DatabaseConnection.query(
        'SELECT * FROM client_reviews WHERE project_id = @projectId ORDER BY client_review_created_at DESC',
        values: {'projectId': projectId},
      );
      return results.map((row) => ClientReview.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting client reviews for project: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get client review by ID
  Future<ClientReview?> getClientReviewById(String reviewId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM client_reviews WHERE client_review_id = @reviewId',
        values: {'reviewId': reviewId},
      );
      if (result == null) return null;
      return ClientReview.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting client review by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create client review
  Future<ClientReview> createClientReview(Map<String, dynamic> data) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO client_reviews (
          project_id, client_review_comment, client_review_rating, client_review_created_by
        ) VALUES (@projectId, @comment, @rating, @createdBy)
        RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'comment': data['client_review_comment'],
          'rating': data['client_review_rating'],
          'createdBy': data['client_review_created_by'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create client review');
      }
      return ClientReview.fromMap(result);
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
      final updates = <String>[];
      final params = <String, dynamic>{'reviewId': reviewId};

      if (data.containsKey('client_review_comment')) {
        updates.add('client_review_comment = @comment');
        params['comment'] = data['client_review_comment'];
      }
      if (data.containsKey('client_review_rating')) {
        updates.add('client_review_rating = @rating');
        params['rating'] = data['client_review_rating'];
      }
      if (data.containsKey('client_review_updated_by')) {
        updates.add('client_review_updated_by = @updatedBy');
        params['updatedBy'] = data['client_review_updated_by'];
      }

      // Always update the timestamp on update
      updates.add('client_review_updated_at = CURRENT_TIMESTAMP');

      if (updates.isEmpty) {
        final existing = await getClientReviewById(reviewId);
        if (existing == null) {
          throw NotFoundException(resource: 'Client Review', id: reviewId);
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE client_reviews SET ${updates.join(', ')}
        WHERE client_review_id = @reviewId RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(resource: 'Client Review', id: reviewId);
      }
      return ClientReview.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating client review: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete client review
  Future<void> deleteClientReview(String reviewId) async {
    try {
      await DatabaseConnection.execute(
        'DELETE FROM client_reviews WHERE client_review_id = @reviewId',
        values: {'reviewId': reviewId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting client review: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PROJECT DISCONTINUATION CRUD
  // ============================================

  /// Get discontinuation for a project
  Future<ProjectDiscontinuation?> getDiscontinuationByProjectId(
    String projectId,
  ) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_discontinuations WHERE project_id = @projectId',
        values: {'projectId': projectId},
      );
      if (result == null) return null;
      return ProjectDiscontinuation.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting discontinuation for project: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get discontinuation by ID
  Future<ProjectDiscontinuation?> getDiscontinuationById(
    String discontinuationId,
  ) async {
    try {
      final result = await DatabaseConnection.queryOne(
        'SELECT * FROM project_discontinuations WHERE project_discontinuation_id = @id',
        values: {'id': discontinuationId},
      );
      if (result == null) return null;
      return ProjectDiscontinuation.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting discontinuation by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create discontinuation (also updates project status)
  Future<ProjectDiscontinuation> createDiscontinuation(
    Map<String, dynamic> data,
  ) async {
    try {
      // First update project status to DISCONTINUED
      await DatabaseConnection.execute(
        '''
        UPDATE projects SET project_status = 'DISCONTINUED', 
          project_updated_by = @updatedBy,
          project_updated_at = CURRENT_TIMESTAMP
        WHERE project_id = @projectId
      ''',
        values: {
          'projectId': data['project_id'],
          'updatedBy': data['project_discontinuation_by'],
        },
      );

      // Then create discontinuation record
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO project_discontinuations (
          project_id, project_discontinuation_reason, project_discontinuation_by,
          project_discontinuation_remarks
        ) VALUES (@projectId, @reason, @discontinuedBy, @remarks)
        RETURNING *
      ''',
        values: {
          'projectId': data['project_id'],
          'reason': data['project_discontinuation_reason'],
          'discontinuedBy': data['project_discontinuation_by'],
          'remarks': data['project_discontinuation_remarks'],
        },
      );
      if (result == null) {
        throw DatabaseException(message: 'Failed to create discontinuation');
      }
      return ProjectDiscontinuation.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating discontinuation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update discontinuation
  Future<ProjectDiscontinuation> updateDiscontinuation(
    String discontinuationId,
    Map<String, dynamic> data,
  ) async {
    try {
      final updates = <String>[];
      final params = <String, dynamic>{'id': discontinuationId};

      if (data.containsKey('project_discontinuation_reason')) {
        updates.add('project_discontinuation_reason = @reason');
        params['reason'] = data['project_discontinuation_reason'];
      }
      if (data.containsKey('project_discontinuation_remarks')) {
        updates.add('project_discontinuation_remarks = @remarks');
        params['remarks'] = data['project_discontinuation_remarks'];
      }

      if (updates.isEmpty) {
        final existing = await getDiscontinuationById(discontinuationId);
        if (existing == null) {
          throw NotFoundException(
            resource: 'Discontinuation',
            id: discontinuationId,
          );
        }
        return existing;
      }

      final result = await DatabaseConnection.queryOne('''
        UPDATE project_discontinuations SET ${updates.join(', ')}
        WHERE project_discontinuation_id = @id RETURNING *
      ''', values: params);
      if (result == null) {
        throw NotFoundException(
          resource: 'Discontinuation',
          id: discontinuationId,
        );
      }
      return ProjectDiscontinuation.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating discontinuation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete discontinuation (reactivate project)
  Future<void> deleteDiscontinuation(
    String discontinuationId,
    String projectId,
    String updatedBy,
  ) async {
    try {
      // Delete discontinuation record
      await DatabaseConnection.execute(
        'DELETE FROM project_discontinuations WHERE project_discontinuation_id = @id',
        values: {'id': discontinuationId},
      );

      // Update project status back to ON_HOLD
      await DatabaseConnection.execute(
        '''
        UPDATE projects SET project_status = 'ON_HOLD',
          project_updated_by = @updatedBy,
          project_updated_at = CURRENT_TIMESTAMP
        WHERE project_id = @projectId
      ''',
        values: {'projectId': projectId, 'updatedBy': updatedBy},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting discontinuation: $e', e, stackTrace);
      rethrow;
    }
  }
}
