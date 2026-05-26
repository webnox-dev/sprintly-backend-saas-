import 'dart:convert';

/// Leave request status enum
enum LeaveStatus {
  pending(0),
  approved(1),
  rejected(2);

  const LeaveStatus(this.value);
  final int value;

  static LeaveStatus fromValue(int value) {
    return LeaveStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => LeaveStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Requester type enum
enum RequesterType {
  admin('Admin'),
  employee('Employee');

  const RequesterType(this.value);
  final String value;

  static RequesterType fromValue(String value) {
    return RequesterType.values.firstWhere(
      (type) => type.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RequesterType.employee,
    );
  }
}

/// Leave request domain model
class LeaveRequest {
  final String? leaveId;
  final String requesterId;
  final String requesterType;
  final DateTime leaveFromDate;
  final DateTime leaveToDate;
  final List<String>? selectedDates;
  final double totalLeaveDays;
  final String? leaveType;
  final int leaveStatus;
  final String? leaveRemarks;
  final bool isPaidLeave;
  final bool isHalfDay;
  final String? halfDayType;
  final String? leaveApprovalRejectionRemarks;
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

  LeaveRequest({
    this.leaveId,
    required this.requesterId,
    required this.requesterType,
    required this.leaveFromDate,
    required this.leaveToDate,
    this.selectedDates,
    this.totalLeaveDays = 0,
    this.leaveType,
    this.leaveStatus = 0,
    this.leaveRemarks,
    this.isPaidLeave = false,
    this.isHalfDay = false,
    this.halfDayType,
    this.leaveApprovalRejectionRemarks,
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

  /// Create from database row
  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    List<String>? parseDates(dynamic val) {
      if (val == null) return null;
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return null;
    }

    return LeaveRequest(
      leaveId: map['leave_id']?.toString(),
      requesterId: map['requester_id']?.toString() ?? '',
      requesterType: map['requester_type']?.toString() ?? 'Employee',
      leaveFromDate: DateTime.parse(map['leave_from_date'].toString()),
      leaveToDate: DateTime.parse(map['leave_to_date'].toString()),
      selectedDates: parseDates(map['selected_dates']),
      totalLeaveDays: (map['total_leave_days'] as num?)?.toDouble() ?? 0,
      leaveType: map['leave_type']?.toString(),
      leaveStatus: (map['leave_status'] as num?)?.toInt() ?? 0,
      leaveRemarks: map['leave_remarks']?.toString(),
      isPaidLeave: map['is_paid_leave'] == true || map['is_paid_leave'] == 1,
      isHalfDay: map['is_half_day'] == true || map['is_half_day'] == 1,
      halfDayType: map['half_day_type']?.toString(),
      leaveApprovalRejectionRemarks: map['leave_approval_rejection_remarks']
          ?.toString(),
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
      'leave_id': leaveId,
      'requester_id': requesterId,
      'requester_type': requesterType,
      'leave_from_date': leaveFromDate.toIso8601String().split('T').first,
      'leave_to_date': leaveToDate.toIso8601String().split('T').first,
      'selected_dates': selectedDates,
      'total_leave_days': totalLeaveDays,
      'leave_type': leaveType,
      'leave_status': leaveStatus,
      'leave_status_display': LeaveStatus.fromValue(leaveStatus).displayName,
      'leave_remarks': leaveRemarks,
      'is_paid_leave': isPaidLeave,
      'is_half_day': isHalfDay,
      'half_day_type': halfDayType,
      'leave_approval_rejection_remarks': leaveApprovalRejectionRemarks,
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
      'leave_from_date': leaveFromDate.toIso8601String().split('T').first,
      'leave_to_date': leaveToDate.toIso8601String().split('T').first,
      'selected_dates': jsonEncode(selectedDates ?? []),
      'leave_type': leaveType,
      'leave_status': leaveStatus,
      'leave_remarks': leaveRemarks,
      'is_paid_leave': isPaidLeave,
      'is_half_day': isHalfDay,
      'half_day_type': halfDayType,
      'created_by': createdBy,
    };
  }

  /// Copy with new values
  LeaveRequest copyWith({
    String? leaveId,
    String? requesterId,
    String? requesterType,
    DateTime? leaveFromDate,
    DateTime? leaveToDate,
    List<String>? selectedDates,
    double? totalLeaveDays,
    String? leaveType,
    int? leaveStatus,
    String? leaveRemarks,
    bool? isPaidLeave,
    bool? isHalfDay,
    String? halfDayType,
    String? leaveApprovalRejectionRemarks,
    String? approvedBy,
    String? rejectedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return LeaveRequest(
      leaveId: leaveId ?? this.leaveId,
      requesterId: requesterId ?? this.requesterId,
      requesterType: requesterType ?? this.requesterType,
      leaveFromDate: leaveFromDate ?? this.leaveFromDate,
      leaveToDate: leaveToDate ?? this.leaveToDate,
      selectedDates: selectedDates ?? this.selectedDates,
      totalLeaveDays: totalLeaveDays ?? this.totalLeaveDays,
      leaveType: leaveType ?? this.leaveType,
      leaveStatus: leaveStatus ?? this.leaveStatus,
      leaveRemarks: leaveRemarks ?? this.leaveRemarks,
      isPaidLeave: isPaidLeave ?? this.isPaidLeave,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDayType: halfDayType ?? this.halfDayType,
      leaveApprovalRejectionRemarks:
          leaveApprovalRejectionRemarks ?? this.leaveApprovalRejectionRemarks,
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
