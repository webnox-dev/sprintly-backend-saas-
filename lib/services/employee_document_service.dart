import '../data/repositories/employee_document_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../domain/models/employee_document.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';

/// Service for employee document operations
class EmployeeDocumentService {
  final EmployeeDocumentRepository _repository = EmployeeDocumentRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final AppLogger _logger = AppLogger('EmployeeDocumentService');

  /// Get all document types
  Future<List<DocumentType>> getDocumentTypes() async {
    return await _repository.getDocumentTypes();
  }

  /// Admin requests documents from employee
  Future<Map<String, dynamic>> requestDocumentsFromEmployee({
    required String employeeId,
    required String requestedBy,
    required List<Map<String, dynamic>> documents,
  }) async {
    // Validate employee exists
    final employee = await _employeeRepository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    // Validate admin exists
    final admin = await _adminRepository.getById(requestedBy);
    if (admin == null) {
      throw NotFoundException(resource: 'Admin', id: requestedBy);
    }

    // Validate documents list
    if (documents.isEmpty) {
      throw ValidationException({
        'documents': ['At least one document must be requested'],
      });
    }

    // Validate all document types
    for (final doc in documents) {
      final docName =
          doc['documentName']?.toString() ??
          doc['document_name']?.toString() ??
          '';
      if (!DocumentTypes.isValid(docName)) {
        throw ValidationException({
          'documentName': ['Invalid document type: $docName'],
        });
      }
    }

    // Create document requests
    final createdDocs = await _repository.requestDocuments(
      employeeId: employeeId,
      requestedBy: requestedBy,
      documents: documents,
    );

    if (createdDocs.isEmpty) {
      throw ValidationException({
        'documents': [
          'No new documents were requested. They may already be pending.',
        ],
      });
    }

    // Send notifications via UnifiedNotificationService
    final docListStr = createdDocs.map((d) => d.documentName).join(', ');
    Future.wait([
      UnifiedNotificationService.notifyDocumentRequested(
        employeeId: employeeId,
        employeeName: employee.employeeName,
        adminName: admin.adminName,
        documentList: docListStr,
        documentCount: createdDocs.length,
      ),
    ]).catchError((e, st) {
      _logger.warning('Document request notifications error: $e');
      return Future.value([]);
    });

    return {
      'success': true,
      'message': 'Documents requested successfully',
      'data': createdDocs.map((d) => d.toJson()).toList(),
      'count': createdDocs.length,
    };
  }

  /// Employee fetches their requested documents
  Future<Map<String, dynamic>> getEmployeeRequestedDocuments(
    String employeeId,
  ) async {
    final employee = await _employeeRepository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    final documents = await _repository.getEmployeeDocuments(employeeId);

    return {
      'employee': {
        'id': employee.employeeId,
        'name': employee.employeeName,
        'email': employee.employeePersonalEmail,
      },
      'documents': documents.map((d) => d.toJson()).toList(),
    };
  }

  /// Employee submits a document
  Future<Map<String, dynamic>> submitDocument({
    required String documentId,
    required String documentUrl,
    required String employeeId,
  }) async {
    // Validate URL
    if (documentUrl.isEmpty) {
      throw ValidationException({
        'documentUrl': ['Document URL is required'],
      });
    }

    if (!documentUrl.startsWith('https://')) {
      throw ValidationException({
        'documentUrl': ['Document URL must be HTTPS'],
      });
    }

    final document = await _repository.submitDocument(
      documentId: documentId,
      documentUrl: documentUrl,
      employeeId: employeeId,
    );

    // Get employee info for email
    final employee = await _employeeRepository.getById(employeeId);
    final empName = employee?.employeeName ?? 'Employee';
    final docName = document.documentName;

    // Send notifications via UnifiedNotificationService
    Future.wait([
      UnifiedNotificationService.notifyDocumentSubmitted(
        employeeId: employeeId,
        employeeName: empName,
        documentName: docName,
      ),
    ]).catchError((e, st) {
      _logger.warning('Document submitted notifications error: $e');
      return Future.value([]);
    });

    return {
      'success': true,
      'message': 'Document submitted successfully',
      'data': document.toJson(),
    };
  }

  /// Admin gets all employee documents
  Future<Map<String, dynamic>> getEmployeeDocumentsForAdmin({
    required String employeeId,
  }) async {
    final employee = await _employeeRepository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    final documents = await _repository.getEmployeeDocuments(employeeId);

    return {
      'employee': {
        'id': employee.employeeId,
        'name': employee.employeeName,
        'email': employee.employeePersonalEmail,
        'designation': employee.employeeDesignation,
      },
      'documents': documents.map((d) => d.toJson()).toList(),
    };
  }

  /// Admin reviews (approves/rejects) a document
  Future<Map<String, dynamic>> reviewDocument({
    required String documentId,
    required String status,
    required String adminId,
    String? adminComments,
  }) async {
    // Validate status
    if (status != 'approved' && status != 'rejected') {
      throw ValidationException({
        'status': ['Status must be either approved or rejected'],
      });
    }

    if (status == 'rejected' &&
        (adminComments == null || adminComments.isEmpty)) {
      throw ValidationException({
        'adminComments': [
          'Admin comments are required when rejecting a document',
        ],
      });
    }

    final document = await _repository.reviewDocument(
      documentId: documentId,
      status: status,
      adminId: adminId,
      adminComments: adminComments,
    );

    // Get employee info for email
    final employee = await _employeeRepository.getById(document.employeeId);

    // Send notifications via UnifiedNotificationService
    if (employee != null) {
      Future.wait([
        UnifiedNotificationService.notifyDocumentReviewed(
          employeeId: document.employeeId,
          employeeName: employee.employeeName,
          documentName: document.documentName,
          status: status,
          adminComments: adminComments,
        ),
      ]).catchError((e, st) {
        _logger.warning('Document review notifications error: $e');
        return Future.value([]);
      });
    }

    return {
      'success': true,
      'message':
          'Document ${status == 'approved' ? 'approved' : 'rejected'} successfully',
      'data': document.toJson(),
    };
  }

  /// Get all documents with optional filters
  Future<Map<String, dynamic>> getAllDocuments({
    String? employeeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    return await _repository.getAllDocuments(
      employeeId: employeeId,
      status: status,
      page: page,
      limit: limit,
    );
  }

  // =====================
  // EMAIL METHODS
  // =====================

  // Email templates were moved to UnifiedNotificationService/EmailService
}
