/// Leave model representing a leave request in the system
/// Matches the exact schema of leave_zone table
class Leave {
  final String leaveId;
  final String employeeId;
  final DateTime? leaveFromDate;
  final DateTime? leaveToDate;
  final String? leaveRemarks;
  final bool? isPaidLeave;
  final String? leaveApprovalRejectionRemarks;
  final String? approvedBy;
  final String? rejectedBy;
  final DateTime? approvedAt;
  final DateTime? approvedTime;
  final DateTime? rejectedAt;
  final DateTime? rejectedTime;
  final DateTime? createdAt;
  final int? leaveStatus; // 0 = pending, 1 = approved, 2 = rejected
  final String? leaveType;
  final List<dynamic>? selectedDates; // jsonb array
  final num? totalLeaveDays; // numeric
  final bool? isHalfDay;
  final String? halfDayType;

  // Joined fields
  final String? employeeName;
  final String? employeeRole;
  final String? employeeDesignation;
  final String? employeeProfileImage;
  final Map<String, dynamic>? approverDetails;

  Leave({
    required this.leaveId,
    required this.employeeId,
    this.leaveFromDate,
    this.leaveToDate,
    this.leaveRemarks,
    this.isPaidLeave = false,
    this.leaveApprovalRejectionRemarks,
    this.approvedBy,
    this.rejectedBy,
    this.approvedAt,
    this.approvedTime,
    this.rejectedAt,
    this.rejectedTime,
    this.createdAt,
    this.leaveStatus = 0,
    this.leaveType,
    this.selectedDates,
    this.totalLeaveDays = 0,
    this.isHalfDay = false,
    this.halfDayType,
    this.employeeName,
    this.employeeRole,
    this.employeeDesignation,
    this.employeeProfileImage,
    this.approverDetails,
  });

  /// Helper function to parse date that could be DateTime or String
  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Helper to parse num from various types
  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  /// Helper to parse int from various types
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Helper to parse bool from various types
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  /// Create Leave from database row
  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      leaveId: json['leave_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      leaveFromDate: _parseOptionalDate(json['leave_from_date']),
      leaveToDate: _parseOptionalDate(json['leave_to_date']),
      leaveRemarks: json['leave_remarks']?.toString(),
      isPaidLeave: _parseBool(json['is_paid_leave']),
      leaveApprovalRejectionRemarks: json['leave_approval_rejection_remarks']
          ?.toString(),
      approvedBy: json['approved_by']?.toString(),
      rejectedBy: json['rejected_by']?.toString(),
      approvedAt: _parseOptionalDate(json['approved_at']),
      approvedTime: _parseOptionalDate(json['approved_time']),
      rejectedAt: _parseOptionalDate(json['rejected_at']),
      rejectedTime: _parseOptionalDate(json['rejected_time']),
      createdAt: _parseOptionalDate(json['created_at']),
      leaveStatus: _parseInt(json['leave_status']) ?? 0,
      leaveType: json['leave_type']?.toString(),
      selectedDates: json['selected_dates'] as List<dynamic>?,
      totalLeaveDays: _parseNum(json['total_leave_days']) ?? 0,
      isHalfDay: _parseBool(json['is_half_day']),
      halfDayType: json['half_day_type']?.toString(),
      // Mapped from join
      employeeName: json['employee_name']?.toString(),
      employeeRole: json['role']?.toString(),
      employeeDesignation: json['designation']?.toString(),
      employeeProfileImage: json['profile_image']?.toString(),
      approverDetails: json['approver_details'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'leave_id': leaveId,
      'employee_id': employeeId,
      'leave_from_date': leaveFromDate?.toIso8601String().split('T')[0],
      'leave_to_date': leaveToDate?.toIso8601String().split('T')[0],
      'leave_remarks': leaveRemarks,
      'is_paid_leave': isPaidLeave,
      'leave_approval_rejection_remarks': leaveApprovalRejectionRemarks,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'approved_time': approvedTime?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejected_time': rejectedTime?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'leave_status': leaveStatus,
      'leave_type': leaveType,
      'selected_dates': selectedDates,
      'total_leave_days': totalLeaveDays,
      'is_half_day': isHalfDay,
      'half_day_type': halfDayType,
      if (employeeName != null) 'employee_name': employeeName,
      if (employeeRole != null) 'employee_role': employeeRole,
      if (employeeDesignation != null)
        'employee_designation': employeeDesignation,
      if (employeeProfileImage != null)
        'employee_profile_image': employeeProfileImage,
      // Add requester_details for consistent frontend parsing
      if (employeeName != null)
        'requester_details': {
          'id': employeeId,
          'name': employeeName,
          'role': employeeRole,
          'designation': employeeDesignation,
          'img': employeeProfileImage,
        },
      if (approverDetails != null) 'approver_details': approverDetails,
    };
  }

  /// Create a copy with updated fields
  Leave copyWith({
    String? leaveId,
    String? employeeId,
    DateTime? leaveFromDate,
    DateTime? leaveToDate,
    String? leaveRemarks,
    bool? isPaidLeave,
    String? leaveApprovalRejectionRemarks,
    String? approvedBy,
    String? rejectedBy,
    DateTime? approvedAt,
    DateTime? approvedTime,
    DateTime? rejectedAt,
    DateTime? rejectedTime,
    DateTime? createdAt,
    int? leaveStatus,
    String? leaveType,
    List<dynamic>? selectedDates,
    num? totalLeaveDays,
    bool? isHalfDay,
    String? halfDayType,
  }) {
    return Leave(
      leaveId: leaveId ?? this.leaveId,
      employeeId: employeeId ?? this.employeeId,
      leaveFromDate: leaveFromDate ?? this.leaveFromDate,
      leaveToDate: leaveToDate ?? this.leaveToDate,
      leaveRemarks: leaveRemarks ?? this.leaveRemarks,
      isPaidLeave: isPaidLeave ?? this.isPaidLeave,
      leaveApprovalRejectionRemarks:
          leaveApprovalRejectionRemarks ?? this.leaveApprovalRejectionRemarks,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedTime: approvedTime ?? this.approvedTime,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedTime: rejectedTime ?? this.rejectedTime,
      createdAt: createdAt ?? this.createdAt,
      leaveStatus: leaveStatus ?? this.leaveStatus,
      leaveType: leaveType ?? this.leaveType,
      selectedDates: selectedDates ?? this.selectedDates,
      totalLeaveDays: totalLeaveDays ?? this.totalLeaveDays,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDayType: halfDayType ?? this.halfDayType,
    );
  }

  /// Get status as string
  String get statusString {
    switch (leaveStatus) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  /// Check if leave is approved
  bool get isApproved => leaveStatus == 1;

  /// Check if leave is rejected
  bool get isRejected => leaveStatus == 2;

  /// Check if leave is pending
  bool get isPending => leaveStatus == 0;

  @override
  String toString() {
    return 'Leave(leaveId: $leaveId, employeeId: $employeeId, status: $statusString)';
  }
}
