import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/employee_document_service.dart';
import '../domain/models/employee_document.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Employee Document routes handler
class EmployeeDocumentRoutes {
  final EmployeeDocumentService _service = EmployeeDocumentService();
  final AppLogger _logger = AppLogger('EmployeeDocumentRoutes');

  Router get router {
    final router = Router();

    // ============================================
    // ADMIN ENDPOINTS
    // ============================================

    // POST /api/admin/request-docs-from-employee - Admin requests documents from employee
    router.post(
      '/admin/request-docs-from-employee',
      _requestDocumentsFromEmployee,
    );

    // GET /api/admin/employee-documents - Admin gets all documents (with optional employeeId filter)
    router.get('/admin/employee-documents', _getEmployeeDocumentsForAdmin);

    // POST /api/admin/review-document - Admin approves/rejects a document
    router.post('/admin/review-document', _reviewDocument);

    // GET /api/admin/document-types - Get all valid document types
    router.get('/admin/document-types', _getDocumentTypes);

    // ============================================
    // EMPLOYEE ENDPOINTS
    // ============================================

    // GET /api/employee/requested-documents - Employee gets their requested documents
    router.get(
      '/employee/requested-documents/<employeeId>',
      _getEmployeeRequestedDocuments,
    );

    // POST /api/employee/submit-document - Employee submits a document
    router.post('/employee/submit-document', _submitDocument);

    // ============================================
    // GENERAL ENDPOINTS
    // ============================================

    // GET /api/document-types - Get all valid document types (public)
    router.get('/document-types', _getDocumentTypes);

    return router;
  }

  /// POST /api/admin/request-docs-from-employee
  /// Admin requests documents from an employee
  Future<Response> _requestDocumentsFromEmployee(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId =
          data['employeeId']?.toString() ?? data['employee_id']?.toString();
      final requestedBy =
          data['requestedBy']?.toString() ?? data['requested_by']?.toString();
      final documents = data['documents'] as List<dynamic>?;

      // Validate required fields
      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employeeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (requestedBy == null || requestedBy.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'requestedBy is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (documents == null || documents.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'documents array is required and cannot be empty',
        ).toShelfResponse(statusCode: 400);
      }

      // Parse documents - handle both string array and object array
      final List<Map<String, dynamic>> parsedDocuments = [];
      for (final doc in documents) {
        if (doc is String) {
          // Simple string format from original API spec
          parsedDocuments.add({'documentName': doc, 'isRequired': false});
        } else if (doc is Map<String, dynamic>) {
          // Full object format with isRequired
          parsedDocuments.add({
            'documentName':
                doc['documentName']?.toString() ??
                doc['document_name']?.toString() ??
                '',
            'isRequired':
                doc['isRequired'] == true || doc['is_required'] == true,
          });
        }
      }

      final result = await _service.requestDocumentsFromEmployee(
        employeeId: employeeId,
        requestedBy: requestedBy,
        documents: parsedDocuments,
      );

      return ApiResponse.success(
        data: result,
        message: 'Documents requested successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Error in _requestDocumentsFromEmployee: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/admin/employee-documents
  /// Admin gets all documents for an employee
  Future<Response> _getEmployeeDocumentsForAdmin(Request request) async {
    try {
      final params = request.url.queryParameters;
      final employeeId = params['employeeId'] ?? params['employee_id'];
      final status = params['status'];
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;

      if (employeeId != null && employeeId.isNotEmpty) {
        // Get documents for specific employee
        final result = await _service.getEmployeeDocumentsForAdmin(
          employeeId: employeeId,
        );
        return ApiResponse.success(data: result).toShelfResponse();
      } else {
        // Get all documents with optional status filter
        final result = await _service.getAllDocuments(
          employeeId: employeeId,
          status: status,
          page: page,
          limit: limit,
        );
        return ApiResponse.success(
          data: result['data'],
          pagination: {
            'page': result['page'],
            'limit': result['limit'],
            'total': result['total'],
            'totalPages': result['totalPages'],
          },
        ).toShelfResponse();
      }
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Error in _getEmployeeDocumentsForAdmin: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/admin/review-document
  /// Admin approves or rejects a document
  Future<Response> _reviewDocument(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final documentId =
          data['documentId']?.toString() ?? data['document_id']?.toString();
      final status = data['status']?.toString();
      final adminId =
          data['adminId']?.toString() ?? data['admin_id']?.toString();
      final adminComments =
          data['adminComments']?.toString() ??
          data['admin_comments']?.toString();

      // Validate required fields
      if (documentId == null || documentId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'documentId is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (status == null || status.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'status is required (approved or rejected)',
        ).toShelfResponse(statusCode: 400);
      }

      if (status != 'approved' && status != 'rejected') {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'status must be either approved or rejected',
        ).toShelfResponse(statusCode: 400);
      }

      if (adminId == null || adminId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'adminId is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.reviewDocument(
        documentId: documentId,
        status: status,
        adminId: adminId,
        adminComments: adminComments,
      );

      return ApiResponse.success(
        data: result,
        message:
            'Document ${status == 'approved' ? 'approved' : 'rejected'} successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _reviewDocument: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employee/requested-documents/:employeeId
  /// Employee gets their requested documents
  Future<Response> _getEmployeeRequestedDocuments(
    Request request,
    String employeeId,
  ) async {
    try {
      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employeeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.getEmployeeRequestedDocuments(employeeId);

      return ApiResponse.success(data: result).toShelfResponse();
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error(
        'Error in _getEmployeeRequestedDocuments: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employee/submit-document
  /// Employee submits a document
  Future<Response> _submitDocument(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final documentId =
          data['documentId']?.toString() ?? data['document_id']?.toString();
      final documentUrl =
          data['documentUrl']?.toString() ?? data['document_url']?.toString();
      final employeeId =
          data['employeeId']?.toString() ?? data['employee_id']?.toString();

      // Validate required fields
      if (documentId == null || documentId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'documentId is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (documentUrl == null || documentUrl.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'documentUrl is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employeeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Validate URL format
      if (!documentUrl.startsWith('https://')) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'documentUrl must be a valid HTTPS URL',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.submitDocument(
        documentId: documentId,
        documentUrl: documentUrl,
        employeeId: employeeId,
      );

      return ApiResponse.success(
        data: result,
        message: 'Document submitted successfully',
      ).toShelfResponse();
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on NotFoundException catch (e) {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: e.message,
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _submitDocument: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/document-types
  /// Get all valid document types
  Future<Response> _getDocumentTypes(Request request) async {
    try {
      final documentTypes = await _service.getDocumentTypes();

      // Also include the static list for reference
      return ApiResponse.success(
        data: {
          'documentTypes': documentTypes.map((dt) => dt.toJson()).toList(),
          'validTypes': DocumentTypes.validTypes,
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getDocumentTypes: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
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
      case 'UNAUTHORIZED':
        return 401;
      case 'CONFLICT':
        return 409;
      case 'DATABASE_ERROR':
        return 500;
      default:
        return 500;
    }
  }
}
