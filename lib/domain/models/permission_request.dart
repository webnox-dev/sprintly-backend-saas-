/// Permission request status enum
enum PermissionStatus {
  pending(0),
  approved(1),
  rejected(2);

  const PermissionStatus(this.value);
  final int value;

  static PermissionStatus fromValue(int value) {
    return PermissionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PermissionStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PermissionStatus.pending:
        return 'Pending';
      case PermissionStatus.approved:
        return 'Approved';
      case PermissionStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Permission request domain model
class PermissionRequest {
  final String? permissionId;
  final String requesterId;
  final String requesterType;
  final DateTime permissionDate;
  final String permissionFromTime;
  final String permissionToTime;
  final int permissionStatus;
  final String? permissionRemarks;
  final String? permissionApprovalRejectionRemarks;
  final String? approvedBy;
  final String? rejectedBy;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  // Populated fields for response
  final Map<String, dynamic>? requesterDetails;
  final Map<String, dynamic>? approverDetails;
  final Map<String, dynamic>? rejecterDetails;

  PermissionRequest({
    this.permissionId,
    required this.requesterId,
    required this.requesterType,
    required this.permissionDate,
    required this.permissionFromTime,
    required this.permissionToTime,
    this.permissionStatus = 0,
    this.permissionRemarks,
    this.permissionApprovalRejectionRemarks,
    this.approvedBy,
    this.rejectedBy,
    this.approvedAt,
    this.rejectedAt,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.requesterDetails,
    this.approverDetails,
    this.rejecterDetails,
  });

  /// Calculate duration in minutes
  int get durationInMinutes {
    try {
      final fromParts = permissionFromTime.split(':');
      final toParts = permissionToTime.split(':');
      final fromMinutes =
          int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
      final toMinutes = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);
      return toMinutes - fromMinutes;
    } catch (_) {
      return 0;
    }
  }

  /// Get duration as formatted string (e.g., "2h 30m")
  String get durationFormatted {
    final mins = durationInMinutes;
    if (mins <= 0) return '0m';
    final hours = mins ~/ 60;
    final minutes = mins % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  /// Create from database row
  factory PermissionRequest.fromMap(Map<String, dynamic> map) {
    String parseTime(dynamic val) {
      if (val == null) return '00:00';
      final str = val.toString();
      // Handle PostgreSQL time format
      if (str.contains(':')) {
        final parts = str.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }
      return str;
    }

    return PermissionRequest(
      permissionId: map['permission_id']?.toString(),
      requesterId: map['requester_id']?.toString() ?? '',
      requesterType: map['requester_type']?.toString() ?? 'Employee',
      permissionDate: DateTime.parse(map['permission_date'].toString()),
      permissionFromTime: parseTime(map['permission_from_time']),
      permissionToTime: parseTime(map['permission_to_time']),
      permissionStatus: (map['permission_status'] as num?)?.toInt() ?? 0,
      permissionRemarks: map['permission_remarks']?.toString(),
      permissionApprovalRejectionRemarks:
          map['permission_approval_rejection_remarks']?.toString(),
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
      requesterDetails: map['requester_details'] as Map<String, dynamic>?,
      approverDetails: map['approver_details'] as Map<String, dynamic>?,
      rejecterDetails: map['rejecter_details'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'permission_id': permissionId,
      'requester_id': requesterId,
      'requester_type': requesterType,
      'permission_date': permissionDate.toIso8601String().split('T').first,
      'permission_from_time': permissionFromTime,
      'permission_to_time': permissionToTime,
      'permission_status': permissionStatus,
      'permission_status_display': PermissionStatus.fromValue(
        permissionStatus,
      ).displayName,
      'duration_minutes': durationInMinutes,
      'duration_formatted': durationFormatted,
      'permission_remarks': permissionRemarks,
      'permission_approval_rejection_remarks':
          permissionApprovalRejectionRemarks,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
      if (requesterDetails != null) 'requester_details': requesterDetails,
      if (approverDetails != null) 'approver_details': approverDetails,
      if (rejecterDetails != null) 'rejecter_details': rejecterDetails,
    };
  }

  /// Convert to map for database insert
  Map<String, dynamic> toInsertMap() {
    return {
      'requester_id': requesterId,
      'requester_type': requesterType,
      'permission_date': permissionDate.toIso8601String().split('T').first,
      'permission_from_time': permissionFromTime,
      'permission_to_time': permissionToTime,
      'permission_status': permissionStatus,
      'permission_remarks': permissionRemarks,
      'created_by': createdBy,
    };
  }

  /// Copy with new values
  PermissionRequest copyWith({
    String? permissionId,
    String? requesterId,
    String? requesterType,
    DateTime? permissionDate,
    String? permissionFromTime,
    String? permissionToTime,
    int? permissionStatus,
    String? permissionRemarks,
    String? permissionApprovalRejectionRemarks,
    String? approvedBy,
    String? rejectedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return PermissionRequest(
      permissionId: permissionId ?? this.permissionId,
      requesterId: requesterId ?? this.requesterId,
      requesterType: requesterType ?? this.requesterType,
      permissionDate: permissionDate ?? this.permissionDate,
      permissionFromTime: permissionFromTime ?? this.permissionFromTime,
      permissionToTime: permissionToTime ?? this.permissionToTime,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      permissionRemarks: permissionRemarks ?? this.permissionRemarks,
      permissionApprovalRejectionRemarks:
          permissionApprovalRejectionRemarks ??
          this.permissionApprovalRejectionRemarks,
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
