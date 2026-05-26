/// WFH request status enum
enum WFHStatus {
  pending(0),
  approved(1),
  rejected(2);

  const WFHStatus(this.value);
  final int value;

  static WFHStatus fromValue(int value) {
    return WFHStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WFHStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case WFHStatus.pending:
        return 'Pending';
      case WFHStatus.approved:
        return 'Approved';
      case WFHStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Work From Home request domain model
class WFHRequest {
  final String? wfhId;
  final String employeeId;
  final String requesterType;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final int wfhStatus;
  final String? reason;
  final String? approvalRejectionRemarks;
  final String? approvedBy;
  final String? rejectedBy;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  // Flattened details for easier access
  final String? employeeRole;
  final String? employeeDesignation;
  final String? employeeProfileImage;

  // Populated fields for response
  final Map<String, dynamic>? requesterDetails;
  final Map<String, dynamic>? adminDetails;

  WFHRequest({
    this.wfhId,
    required this.employeeId,
    required this.requesterType,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    this.totalDays = 1,
    this.wfhStatus = 0,
    this.reason,
    this.approvalRejectionRemarks,
    this.approvedBy,
    this.rejectedBy,
    this.approvedAt,
    this.rejectedAt,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.requesterDetails,
    this.adminDetails,
    this.employeeRole,
    this.employeeDesignation,
    this.employeeProfileImage,
  });

  /// Create from database row
  factory WFHRequest.fromMap(Map<String, dynamic> map) {
    final requesterDetails = map['requester_details'] as Map<String, dynamic>?;

    return WFHRequest(
      wfhId: map['wfh_id']?.toString(),
      employeeId: map['employee_id']?.toString() ?? '',
      requesterType: map['requester_type']?.toString() ?? 'Employee',
      employeeName: map['employee_name']?.toString() ?? '',
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      totalDays: (map['total_days'] as num?)?.toInt() ?? 1,
      wfhStatus: (map['wfh_status'] as num?)?.toInt() ?? 0,
      reason: map['reason']?.toString(),
      approvalRejectionRemarks: map['approval_rejection_remarks']?.toString(),
      approvedBy: map['approved_by']?.toString(),
      rejectedBy: map['rejected_by']?.toString(),
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'].toString())
          : null,
      rejectedAt: map['rejected_at'] != null
          ? DateTime.parse(map['rejected_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
      requesterDetails: requesterDetails,
      adminDetails: map['admin_details'] as Map<String, dynamic>?,
      // Populate flattened fields from requester_details or map
      employeeRole:
          requesterDetails?['role']?.toString() ??
          map['employee_role']?.toString(),
      employeeDesignation:
          requesterDetails?['designation']?.toString() ??
          map['employee_designation']?.toString(),
      employeeProfileImage:
          requesterDetails?['img']?.toString() ??
          map['employee_profile_image']?.toString(),
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'wfh_id': wfhId,
      'employee_id': employeeId,
      'requester_type': requesterType,
      'employee_name': employeeName,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'total_days': totalDays,
      'wfh_status': wfhStatus,
      'wfh_status_display': WFHStatus.fromValue(wfhStatus).displayName,
      'reason': reason,
      'approval_rejection_remarks': approvalRejectionRemarks,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
      if (requesterDetails != null) 'requester_details': requesterDetails,
      if (adminDetails != null) 'admin_details': adminDetails,
      // Flattened fields
      if (employeeRole != null) 'employee_role': employeeRole,
      if (employeeDesignation != null)
        'employee_designation': employeeDesignation,
      if (employeeProfileImage != null)
        'employee_profile_image': employeeProfileImage,
    };
  }

  /// Convert to map for database insert
  Map<String, dynamic> toInsertMap() {
    return {
      'employee_id': employeeId,
      'requester_type': requesterType,
      'employee_name': employeeName,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'wfh_status': wfhStatus,
      'reason': reason,
      'created_by': createdBy,
    };
  }

  /// Copy with new values
  WFHRequest copyWith({
    String? wfhId,
    String? employeeId,
    String? requesterType,
    String? employeeName,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    int? wfhStatus,
    String? reason,
    String? approvalRejectionRemarks,
    String? approvedBy,
    String? rejectedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return WFHRequest(
      wfhId: wfhId ?? this.wfhId,
      employeeId: employeeId ?? this.employeeId,
      requesterType: requesterType ?? this.requesterType,
      employeeName: employeeName ?? this.employeeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      wfhStatus: wfhStatus ?? this.wfhStatus,
      reason: reason ?? this.reason,
      approvalRejectionRemarks:
          approvalRejectionRemarks ?? this.approvalRejectionRemarks,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
