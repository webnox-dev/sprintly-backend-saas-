/// Employee Document domain model
/// Represents a document request and its lifecycle in the verification workflow
library;

/// Valid document types (static list for validation)
class DocumentTypes {
  static const List<String> validTypes = [
    '10th Marksheet',
    '12th Marksheet',
    'Diploma Marksheet',
    'Aadhar Card',
    'PAN Card',
    'Degree Certificate',
    'Provisional Certificate',
    '6th / 8th Semester Mark Sheets',
    'Old Payslip',
    'Resume',
  ];

  /// Check if a document name is valid
  static bool isValid(String documentName) {
    return validTypes.contains(documentName);
  }
}

/// Document status enumeration
enum DocumentStatus {
  pending,
  submitted,
  approved,
  rejected;

  static DocumentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return DocumentStatus.pending;
      case 'submitted':
        return DocumentStatus.submitted;
      case 'approved':
        return DocumentStatus.approved;
      case 'rejected':
        return DocumentStatus.rejected;
      default:
        return DocumentStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case DocumentStatus.pending:
        return 'pending';
      case DocumentStatus.submitted:
        return 'submitted';
      case DocumentStatus.approved:
        return 'approved';
      case DocumentStatus.rejected:
        return 'rejected';
    }
  }
}

/// Employee Document model
class EmployeeDocument {
  final String id;
  final String employeeId;
  final String documentName;
  final String? documentUrl;
  final DocumentStatus status;
  final bool isRequired;

  // Request audit
  final String requestedBy;
  final String createdBy;
  final DateTime? createdAt;

  // Submission audit
  final DateTime? submittedAt;

  // Review audit
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? adminComments;

  // Approval/Rejection tracking
  final String? approvedBy;
  final String? rejectedBy;

  // Admin details (from JOINs)
  final Map<String, dynamic>? requestedByDetails;
  final Map<String, dynamic>? updatedByDetails;

  EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.documentName,
    this.documentUrl,
    required this.status,
    this.isRequired = false,
    required this.requestedBy,
    required this.createdBy,
    this.createdAt,
    this.submittedAt,
    this.updatedBy,
    this.updatedAt,
    this.adminComments,
    this.approvedBy,
    this.rejectedBy,
    this.requestedByDetails,
    this.updatedByDetails,
  });

  /// Create from database row
  factory EmployeeDocument.fromMap(Map<String, dynamic> map) {
    return EmployeeDocument(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      documentName: map['document_name']?.toString() ?? '',
      documentUrl: map['document_url']?.toString(),
      status: DocumentStatus.fromString(map['status']?.toString() ?? 'pending'),
      isRequired: map['is_required'] == true || map['is_required'] == 1,
      requestedBy: map['requested_by']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
      submittedAt: map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
      adminComments: map['admin_comments']?.toString(),
      approvedBy: map['approved_by']?.toString(),
      rejectedBy: map['rejected_by']?.toString(),
      requestedByDetails: map['requested_by_details'] is Map
          ? Map<String, dynamic>.from(map['requested_by_details'])
          : (map['requested_by_details'] is String
              ? null
              : map['requested_by_details']),
      updatedByDetails: map['updated_by_details'] is Map
          ? Map<String, dynamic>.from(map['updated_by_details'])
          : (map['updated_by_details'] is String
              ? null
              : map['updated_by_details']),
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'documentName': documentName,
      'documentUrl': documentUrl,
      'status': status.value,
      'isRequired': isRequired,
      'requestedBy': requestedBy,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String(),
      'adminComments': adminComments,
      'approvedBy': approvedBy,
      'rejectedBy': rejectedBy,
      'requestedByDetails': requestedByDetails,
      'updatedByDetails': updatedByDetails,
    };
  }

  /// Copy with modifications
  EmployeeDocument copyWith({
    String? id,
    String? employeeId,
    String? documentName,
    String? documentUrl,
    DocumentStatus? status,
    bool? isRequired,
    String? requestedBy,
    String? createdBy,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? updatedBy,
    DateTime? updatedAt,
    String? adminComments,
    String? approvedBy,
    String? rejectedBy,
    Map<String, dynamic>? requestedByDetails,
    Map<String, dynamic>? updatedByDetails,
  }) {
    return EmployeeDocument(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      documentName: documentName ?? this.documentName,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
      isRequired: isRequired ?? this.isRequired,
      requestedBy: requestedBy ?? this.requestedBy,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      adminComments: adminComments ?? this.adminComments,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      requestedByDetails: requestedByDetails ?? this.requestedByDetails,
      updatedByDetails: updatedByDetails ?? this.updatedByDetails,
    );
  }
}

/// Document Type model for reference list
class DocumentType {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int displayOrder;

  DocumentType({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory DocumentType.fromMap(Map<String, dynamic> map) {
    return DocumentType(
      id: map['id'] is int
          ? map['id']
          : int.tryParse(map['id'].toString()) ?? 0,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      isActive: map['is_active'] == true || map['is_active'] == 1,
      displayOrder: map['display_order'] is int
          ? map['display_order']
          : int.tryParse(map['display_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'isActive': isActive,
      'display_order': displayOrder,
      'displayOrder': displayOrder,
    };
  }
}
