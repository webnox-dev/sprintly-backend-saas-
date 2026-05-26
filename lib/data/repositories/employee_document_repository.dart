import '../database/connection.dart';
import '../../domain/models/employee_document.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// Repository for employee document operations
class EmployeeDocumentRepository {
  final AppLogger _logger = AppLogger('EmployeeDocumentRepository');

  /// Get all document types
  Future<List<DocumentType>> getDocumentTypes() async {
    try {
      final result = await DatabaseConnection.query(
        'SELECT * FROM document_types WHERE is_active = TRUE ORDER BY display_order ASC',
      );

      return result.map((row) => DocumentType.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting document types: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to get document types');
    }
  }

  /// Request documents from an employee
  /// Creates one row per document in pending status
  Future<List<EmployeeDocument>> requestDocuments({
    required String employeeId,
    required String requestedBy,
    required List<Map<String, dynamic>> documents,
  }) async {
    try {
      final List<EmployeeDocument> createdDocs = [];

      for (final doc in documents) {
        final documentName =
            doc['documentName']?.toString() ??
            doc['document_name']?.toString() ??
            '';
        final isRequired =
            doc['isRequired'] == true || doc['is_required'] == true;

        if (documentName.isEmpty) {
          continue;
        }

        // Validate document type
        if (!DocumentTypes.isValid(documentName)) {
          _logger.warning('Invalid document type: $documentName');
          continue;
        }

        // Check if there's already a pending/submitted request for this document
        final existing = await DatabaseConnection.query(
          '''
          SELECT id FROM employee_documents 
          WHERE employee_id = @employeeId 
            AND document_name = @documentName 
            AND status IN ('pending', 'submitted')
          LIMIT 1
          ''',
          values: {'employeeId': employeeId, 'documentName': documentName},
        );

        if (existing.isNotEmpty) {
          _logger.info('Skipping duplicate request for $documentName');
          continue;
        }

        // Create new document request
        final result = await DatabaseConnection.query(
          '''
          INSERT INTO employee_documents (
            employee_id, document_name, status, is_required,
            requested_by, created_by, created_at
          ) VALUES (
            @employeeId, @documentName, 'pending', @isRequired,
            @requestedBy, @requestedBy, CURRENT_TIMESTAMP
          )
          RETURNING *
          ''',
          values: {
            'employeeId': employeeId,
            'documentName': documentName,
            'isRequired': isRequired,
            'requestedBy': requestedBy,
          },
        );

        if (result.isNotEmpty) {
          createdDocs.add(EmployeeDocument.fromMap(result.first));
        }
      }

      return createdDocs;
    } catch (e, stackTrace) {
      _logger.error('Error requesting documents: $e', e, stackTrace);
      throw DatabaseException(
        message: 'Failed to request documents: ${e.toString()}',
      );
    }
  }

  /// Get documents requested from an employee with admin details
  Future<List<EmployeeDocument>> getEmployeeDocuments(String employeeId) async {
    try {
      final result = await DatabaseConnection.query(
        '''
        SELECT 
          ed.*,
          -- Requested by admin details
          jsonb_build_object(
            'id', req_admin.admin_id,
            'name', req_admin.admin_name,
            'email', req_admin.admin_personal_email,
            'role', req_admin.admin_role,
            'designation', req_admin.admin_designation,
            'profileImg', req_admin.admin_img
          ) as requested_by_details,
          -- Updated by admin details (who approved/rejected)
          CASE 
            WHEN ed.updated_by IS NOT NULL THEN
              jsonb_build_object(
                'id', upd_admin.admin_id,
                'name', upd_admin.admin_name,
                'email', upd_admin.admin_personal_email,
                'role', upd_admin.admin_role,
                'designation', upd_admin.admin_designation,
                'profileImg', upd_admin.admin_img
              )
            ELSE NULL
          END as updated_by_details
        FROM employee_documents ed
        LEFT JOIN admins req_admin ON ed.requested_by = req_admin.admin_id
        LEFT JOIN admins upd_admin ON ed.updated_by = upd_admin.admin_id
        WHERE ed.employee_id = @employeeId 
        ORDER BY ed.created_at DESC
        ''',
        values: {'employeeId': employeeId},
      );

      return result.map((row) => EmployeeDocument.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting employee documents: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to get employee documents');
    }
  }

  /// Get pending documents for an employee
  Future<List<EmployeeDocument>> getPendingDocuments(String employeeId) async {
    try {
      final result = await DatabaseConnection.query(
        '''
        SELECT * FROM employee_documents 
        WHERE employee_id = @employeeId 
          AND status IN ('pending', 'rejected')
        ORDER BY created_at DESC
        ''',
        values: {'employeeId': employeeId},
      );

      return result.map((row) => EmployeeDocument.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting pending documents: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to get pending documents');
    }
  }

  /// Get a single document by ID
  Future<EmployeeDocument?> getDocumentById(String documentId) async {
    try {
      final result = await DatabaseConnection.query(
        'SELECT * FROM employee_documents WHERE id = @id',
        values: {'id': documentId},
      );

      if (result.isEmpty) {
        return null;
      }

      return EmployeeDocument.fromMap(result.first);
    } catch (e, stackTrace) {
      _logger.error('Error getting document by ID: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to get document');
    }
  }

  /// Submit document (employee uploads URL)
  Future<EmployeeDocument> submitDocument({
    required String documentId,
    required String documentUrl,
    required String employeeId,
  }) async {
    try {
      // Validate document exists and belongs to employee
      final existing = await getDocumentById(documentId);
      if (existing == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }

      if (existing.employeeId != employeeId) {
        throw ValidationException({
          'document': ['Document does not belong to this employee'],
        });
      }

      // Validate status allows submission
      if (existing.status != DocumentStatus.pending &&
          existing.status != DocumentStatus.rejected) {
        throw ValidationException({
          'status': [
            'Document cannot be submitted in current status: ${existing.status.value}',
          ],
        });
      }

      // Validate URL
      if (!_isValidUrl(documentUrl)) {
        throw ValidationException({
          'documentUrl': ['Invalid document URL'],
        });
      }

      // Update document
      final result = await DatabaseConnection.query(
        '''
        UPDATE employee_documents 
        SET document_url = @documentUrl,
            status = 'submitted',
            submitted_at = CURRENT_TIMESTAMP,
            updated_by = @employeeId,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = @id
        RETURNING *
        ''',
        values: {
          'id': documentId,
          'documentUrl': documentUrl,
          'employeeId': employeeId,
        },
      );

      if (result.isEmpty) {
        throw DatabaseException(message: 'Failed to submit document');
      }

      return EmployeeDocument.fromMap(result.first);
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      _logger.error('Error submitting document: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to submit document');
    }
  }

  /// Review document (admin approves/rejects)
  Future<EmployeeDocument> reviewDocument({
    required String documentId,
    required String status,
    required String adminId,
    String? adminComments,
  }) async {
    try {
      // Validate document exists
      final existing = await getDocumentById(documentId);
      if (existing == null) {
        throw NotFoundException(resource: 'Document', id: documentId);
      }

      // Validate status allows review
      if (existing.status != DocumentStatus.submitted) {
        throw ValidationException({
          'status': [
            'Only submitted documents can be reviewed. Current status: ${existing.status.value}',
          ],
        });
      }

      // Validate new status
      if (status != 'approved' && status != 'rejected') {
        throw ValidationException({
          'status': ['Invalid status. Must be approved or rejected'],
        });
      }

      // Update document - handle null adminComments properly to avoid type inconsistency
      // PostgreSQL can't infer the type when null is passed, so we conditionally build the query
      final Map<String, dynamic> updateValues = {
        'id': documentId,
        'status': status,
        'adminId': adminId,
      };

      // Build SQL based on whether adminComments is provided
      // This avoids the type inference issue with null values
      String sql;
      if (adminComments != null && adminComments.isNotEmpty) {
        updateValues['adminComments'] = adminComments;
        sql = '''
          UPDATE employee_documents 
          SET status = @status::varchar,
              admin_comments = @adminComments::text,
              updated_by = @adminId::varchar,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = @id::uuid
          RETURNING *
        ''';
      } else {
        // When adminComments is null, set it directly to NULL in SQL (not as parameter)
        sql = '''
          UPDATE employee_documents 
          SET status = @status::varchar,
              admin_comments = NULL,
              updated_by = @adminId::varchar,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = @id::uuid
          RETURNING *
        ''';
      }

      final result = await DatabaseConnection.query(
        sql,
        values: updateValues,
      );

      if (result.isEmpty) {
        throw DatabaseException(message: 'Failed to review document');
      }

      return EmployeeDocument.fromMap(result.first);
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      _logger.error('Error reviewing document: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to review document');
    }
  }

  /// Get all documents with filters (for admin view)
  Future<Map<String, dynamic>> getAllDocuments({
    String? employeeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      String whereClause = 'WHERE 1=1';
      final params = <String, dynamic>{};

      if (employeeId != null && employeeId.isNotEmpty) {
        whereClause += ' AND ed.employee_id = @employeeId';
        params['employeeId'] = employeeId;
      }

      if (status != null && status.isNotEmpty && status != 'all') {
        whereClause += ' AND ed.status = @status';
        params['status'] = status;
      }

      // Get total count
      final countResult = await DatabaseConnection.query('''
        SELECT COUNT(*) as total 
        FROM employee_documents ed
        $whereClause
        ''', values: params);
      final total = int.tryParse(countResult.first['total'].toString()) ?? 0;

      // Get paginated results with employee info
      final offset = (page - 1) * limit;
      params['limit'] = limit;
      params['offset'] = offset;

      final result = await DatabaseConnection.query('''
        SELECT 
          ed.*,
          e.employee_name,
          e.employee_personal_email,
          e.employee_designation
        FROM employee_documents ed
        LEFT JOIN employees e ON ed.employee_id = e.employee_id
        $whereClause
        ORDER BY ed.created_at DESC
        LIMIT @limit OFFSET @offset
        ''', values: params);

      final documents = result.map((row) {
        final doc = EmployeeDocument.fromMap(row);
        return {
          ...doc.toJson(),
          'employee_name': row['employee_name'],
          'employeeName': row['employee_name'],
          'employee_email': row['employee_personal_email'],
          'employeeEmail': row['employee_personal_email'],
          'employee_designation': row['employee_designation'],
          'employeeDesignation': row['employee_designation'],
        };
      }).toList();

      return {
        'data': documents,
        'page': page,
        'limit': limit,
        'total': total,
        'totalPages': (total / limit).ceil(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all documents: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to get documents');
    }
  }

  /// Delete a document request (admin only)
  Future<bool> deleteDocument(String documentId, String adminId) async {
    try {
      final result = await DatabaseConnection.query(
        'DELETE FROM employee_documents WHERE id = @id RETURNING id',
        values: {'id': documentId},
      );

      return result.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.error('Error deleting document: $e', e, stackTrace);
      throw DatabaseException(message: 'Failed to delete document');
    }
  }

  /// URL validation helper
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
