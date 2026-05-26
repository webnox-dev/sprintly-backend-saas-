/// Permission model representing a permission request in the system
/// Matches exact database schema for permissions table
class Permission {
  final String permissionId;
  final String employeeId;
  final String requesterType; // 'Admin' or 'Employee'
  final DateTime permissionDate;
  final String permissionFromTime; // HH:MM:SS format
  final String permissionToTime; // HH:MM:SS format
  final int permissionStatus; // 0 = pending, 1 = approved, 2 = rejected
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

  // Joined fields
  final String? employeeName;
  final String? employeeRole;
  final String? employeeDesignation;
  final String? employeeProfileImage;
  final Map<String, dynamic>? approverDetails;

  Permission({
    required this.permissionId,
    required this.employeeId,
    this.requesterType = 'Employee',
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
    this.employeeName,
    this.employeeRole,
    this.employeeDesignation,
    this.employeeProfileImage,
    this.approverDetails,
  });

  // ... (keep static methods)

  /// Helper function to parse date that could be DateTime or String
  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid date type: ${value.runtimeType}');
  }

  /// Helper function to parse optional date that could be DateTime or String
  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Helper function to parse time from PostgreSQL Time type or string
  /// Converts Time(hour, minute, second) or HH:MM:SS to a standard HH:MM:SS format
  static String _parseTimeToString(dynamic value) {
    if (value == null) return '00:00:00';

    if (value is DateTime) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
    }

    final str = value.toString();

    // Handle PostgreSQL Time type: "Time(10, 30, 0)" or "Time(10,30,0)"
    if (str.startsWith('Time(') || str.contains('Time(')) {
      final regex = RegExp(r'Time\((\d+),?\s*(\d+)?,?\s*(\d+)?');
      final match = regex.firstMatch(str);
      if (match != null) {
        final hour = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
        final second = int.tryParse(match.group(3) ?? '0') ?? 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
      }
    }

    // If already in HH:MM:SS or HH:MM format, return as-is or normalize
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        // Try parsing relevant parts, handling potential date prefix in string
        String hourPart = parts[0];
        if (hourPart.contains(' ')) {
          hourPart = hourPart.split(' ').last;
        }

        final hour = int.tryParse(hourPart) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final second = parts.length > 2
            ? (double.tryParse(parts[2])?.toInt() ?? 0)
            : 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
      }
    }

    return '00:00:00';
  }

  /// Helper to parse int from various types
  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Create Permission from database row
  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      permissionId: json['permission_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      requesterType: json['requester_type']?.toString() ?? 'Employee',
      permissionDate: _parseDate(json['permission_date']),
      permissionFromTime: _parseTimeToString(json['permission_from_time']),
      permissionToTime: _parseTimeToString(json['permission_to_time']),
      permissionStatus: _parseInt(json['permission_status']),
      permissionRemarks: json['permission_remarks']?.toString(),
      permissionApprovalRejectionRemarks:
          json['permission_approval_rejection_remarks']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      rejectedBy: json['rejected_by']?.toString(),
      approvedAt: _parseOptionalDate(json['approved_at']),
      rejectedAt: _parseOptionalDate(json['rejected_at']),
      createdBy: json['created_by']?.toString(),
      createdAt: _parseOptionalDate(json['created_at']),
      updatedBy: json['updated_by']?.toString(),
      updatedAt: _parseOptionalDate(json['updated_at']),
      // Joined fields
      employeeName: json['employee_name']?.toString(),
      employeeRole: json['employee_role']?.toString(),
      employeeDesignation: json['employee_designation']?.toString(),
      employeeProfileImage: json['employee_profile_image']?.toString(),
      approverDetails: json['approver_details'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'permission_id': permissionId,
      'employee_id': employeeId,
      'requester_type': requesterType,
      'permission_date': permissionDate.toIso8601String().split('T')[0],
      'permission_from_time': permissionFromTime,
      'permission_to_time': permissionToTime,
      'permission_status': permissionStatus,
      'status': statusString, // Alias for client
      'is_permission_approved': permissionStatus, // Legacy alias
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
      'duration_minutes': duration.inMinutes,
      'duration_formatted': formattedDuration,
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
  Permission copyWith({
    String? permissionId,
    String? employeeId,
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
    return Permission(
      permissionId: permissionId ?? this.permissionId,
      employeeId: employeeId ?? this.employeeId,
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

  /// Get status as string
  String get statusString {
    switch (permissionStatus) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  /// Check if permission is approved
  bool get isApproved => permissionStatus == 1;

  /// Check if permission is rejected
  bool get isRejected => permissionStatus == 2;

  /// Check if permission is pending
  bool get isPending => permissionStatus == 0;

  /// Calculate duration between from and to time
  Duration get duration {
    try {
      final fromParts = permissionFromTime.split(':');
      final toParts = permissionToTime.split(':');

      final fromMinutes =
          (int.tryParse(fromParts[0]) ?? 0) * 60 +
          (int.tryParse(fromParts[1]) ?? 0);
      final toMinutes =
          (int.tryParse(toParts[0]) ?? 0) * 60 +
          (int.tryParse(toParts[1]) ?? 0);

      return Duration(minutes: toMinutes - fromMinutes);
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];
    if (hours > 0) parts.add('$hours hrs');
    if (minutes > 0) parts.add('$minutes mins');

    return parts.isEmpty ? '0 mins' : parts.join(' ');
  }

  @override
  String toString() {
    return 'Permission(permissionId: $permissionId, employeeId: $employeeId, status: $statusString)';
  }
}
