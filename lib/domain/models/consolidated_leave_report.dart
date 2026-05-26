/// Safe parsing helpers - handle both String and num types from database
int _parseIntSafe(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double _parseDoubleSafe(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

/// Leave Policy Configuration Model
/// Stores the allowed limits for leaves, permissions, and WFH per month
class LeavePolicyConfig {
  final String configId;
  final int allowedLeaveDaysPerMonth;
  final double allowedPermissionHoursPerMonth;
  final int allowedWfhDaysPerMonth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  LeavePolicyConfig({
    required this.configId,
    required this.allowedLeaveDaysPerMonth,
    required this.allowedPermissionHoursPerMonth,
    required this.allowedWfhDaysPerMonth,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  factory LeavePolicyConfig.fromJson(Map<String, dynamic> json) {
    return LeavePolicyConfig(
      configId: json['config_id']?.toString() ?? '',
      allowedLeaveDaysPerMonth: _parseIntSafe(
        json['allowed_leave_days_per_month'],
        2,
      ),
      allowedPermissionHoursPerMonth: _parseDoubleSafe(
        json['allowed_permission_hours_per_month'],
        2.0,
      ),
      allowedWfhDaysPerMonth: _parseIntSafe(
        json['allowed_wfh_days_per_month'],
        1,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config_id': configId,
      'allowed_leave_days_per_month': allowedLeaveDaysPerMonth,
      'allowed_permission_hours_per_month': allowedPermissionHoursPerMonth,
      'allowed_wfh_days_per_month': allowedWfhDaysPerMonth,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// Default policy configuration
  static LeavePolicyConfig defaultConfig() {
    return LeavePolicyConfig(
      configId: 'default',
      allowedLeaveDaysPerMonth: 2,
      allowedPermissionHoursPerMonth: 2.0,
      allowedWfhDaysPerMonth: 1,
    );
  }
}

/// Employee consolidated leave summary for a specific month
class EmployeeConsolidatedSummary {
  final String employeeId;
  final String? employeeUuid;
  final String employeeName;
  final String? employeeRole;
  final String? employeeDesignation;
  final String? employeeProfileImage;
  final int month;
  final int year;
  final double totalLeaveDays;
  final double paidLeaveDays;
  final double unpaidLeaveDays;
  final double excessLeaveDays;
  final double totalPermissionHours;
  final double excessPermissionHours;
  final int totalWfhDays;
  final int excessWfhDays;
  final bool isLeaveExceeded;
  final bool isPermissionExceeded;
  final bool isWfhExceeded;

  EmployeeConsolidatedSummary({
    required this.employeeId,
    this.employeeUuid,
    required this.employeeName,
    this.employeeRole,
    this.employeeDesignation,
    this.employeeProfileImage,
    required this.month,
    required this.year,
    this.totalLeaveDays = 0,
    this.paidLeaveDays = 0,
    this.unpaidLeaveDays = 0,
    this.excessLeaveDays = 0,
    this.totalPermissionHours = 0,
    this.excessPermissionHours = 0,
    this.totalWfhDays = 0,
    this.excessWfhDays = 0,
    this.isLeaveExceeded = false,
    this.isPermissionExceeded = false,
    this.isWfhExceeded = false,
  });

  factory EmployeeConsolidatedSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeConsolidatedSummary(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeUuid: json['employee_uuid']?.toString(),
      employeeName: json['employee_name']?.toString() ?? '',
      employeeRole: json['employee_role']?.toString(),
      employeeDesignation: json['employee_designation']?.toString(),
      employeeProfileImage: json['employee_profile_image']?.toString(),
      month: _parseIntSafe(json['month']),
      year: _parseIntSafe(json['year']),
      totalLeaveDays: _parseDoubleSafe(json['total_leave_days']),
      paidLeaveDays: _parseDoubleSafe(json['paid_leave_days']),
      unpaidLeaveDays: _parseDoubleSafe(json['unpaid_leave_days']),
      excessLeaveDays: _parseDoubleSafe(json['excess_leave_days']),
      totalPermissionHours: _parseDoubleSafe(json['total_permission_hours']),
      excessPermissionHours: _parseDoubleSafe(json['excess_permission_hours']),
      totalWfhDays: _parseIntSafe(json['total_wfh_days']),
      excessWfhDays: _parseIntSafe(json['excess_wfh_days']),
      isLeaveExceeded: json['is_leave_exceeded'] == true,
      isPermissionExceeded: json['is_permission_exceeded'] == true,
      isWfhExceeded: json['is_wfh_exceeded'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_uuid': employeeUuid,
      'employee_name': employeeName,
      'employee_role': employeeRole,
      'employee_designation': employeeDesignation,
      'employee_profile_image': employeeProfileImage,
      'month': month,
      'year': year,
      'total_leave_days': totalLeaveDays,
      'paid_leave_days': paidLeaveDays,
      'unpaid_leave_days': unpaidLeaveDays,
      'excess_leave_days': excessLeaveDays,
      'total_permission_hours': totalPermissionHours,
      'excess_permission_hours': excessPermissionHours,
      'total_wfh_days': totalWfhDays,
      'excess_wfh_days': excessWfhDays,
      'is_leave_exceeded': isLeaveExceeded,
      'is_permission_exceeded': isPermissionExceeded,
      'is_wfh_exceeded': isWfhExceeded,
    };
  }
}

/// Detailed leave record for an employee
class LeaveRecord {
  final String leaveId;
  final DateTime leaveFromDate;
  final DateTime leaveToDate;
  final double totalLeaveDays;
  final String? leaveType;
  final bool isPaidLeave;
  final int leaveStatus;
  final String? leaveRemarks;
  final String? adminRemarks;
  final int month;
  final int year;
  final DateTime? approvedAt;

  LeaveRecord({
    required this.leaveId,
    required this.leaveFromDate,
    required this.leaveToDate,
    required this.totalLeaveDays,
    this.leaveType,
    this.isPaidLeave = false,
    this.leaveStatus = 0,
    this.leaveRemarks,
    this.adminRemarks,
    required this.month,
    required this.year,
    this.approvedAt,
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      leaveId: json['leave_id']?.toString() ?? '',
      leaveFromDate: DateTime.parse(json['leave_from_date'].toString()),
      leaveToDate: DateTime.parse(json['leave_to_date'].toString()),
      totalLeaveDays: _parseDoubleSafe(json['total_leave_days']),
      leaveType: json['leave_type']?.toString(),
      isPaidLeave: json['is_paid_leave'] == true,
      leaveStatus: _parseIntSafe(json['leave_status']),
      leaveRemarks: json['leave_remarks']?.toString(),
      adminRemarks: json['admin_remarks']?.toString(),
      month: _parseIntSafe(json['month']),
      year: _parseIntSafe(json['year']),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leave_id': leaveId,
      'leave_from_date': leaveFromDate.toIso8601String().split('T')[0],
      'leave_to_date': leaveToDate.toIso8601String().split('T')[0],
      'total_leave_days': totalLeaveDays,
      'leave_type': leaveType,
      'is_paid_leave': isPaidLeave,
      'leave_status': leaveStatus,
      'leave_status_display': _getStatusDisplay(leaveStatus),
      'leave_remarks': leaveRemarks,
      'admin_remarks': adminRemarks,
      'month': month,
      'year': year,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  String _getStatusDisplay(int status) {
    switch (status) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

/// Detailed permission record for an employee
class PermissionRecord {
  final String permissionId;
  final DateTime permissionDate;
  final String permissionFromTime;
  final String permissionToTime;
  final double durationHours;
  final int permissionStatus;
  final String? permissionRemarks;
  final String? adminRemarks;
  final int month;
  final int year;
  final bool isExcess;
  final double excessHours;

  PermissionRecord({
    required this.permissionId,
    required this.permissionDate,
    required this.permissionFromTime,
    required this.permissionToTime,
    required this.durationHours,
    this.permissionStatus = 0,
    this.permissionRemarks,
    this.adminRemarks,
    required this.month,
    required this.year,
    this.isExcess = false,
    this.excessHours = 0,
  });

  factory PermissionRecord.fromJson(Map<String, dynamic> json) {
    return PermissionRecord(
      permissionId: json['permission_id']?.toString() ?? '',
      permissionDate: DateTime.parse(json['permission_date'].toString()),
      permissionFromTime: json['permission_from_time']?.toString() ?? '',
      permissionToTime: json['permission_to_time']?.toString() ?? '',
      durationHours: _parseDoubleSafe(json['duration_hours']),
      permissionStatus: _parseIntSafe(json['permission_status']),
      permissionRemarks: json['permission_remarks']?.toString(),
      adminRemarks: json['admin_remarks']?.toString(),
      month: _parseIntSafe(json['month']),
      year: _parseIntSafe(json['year']),
      isExcess: json['is_excess'] == true,
      excessHours: _parseDoubleSafe(json['excess_hours']),
    );
  }

  Map<String, dynamic> toJson() {
    final hours = durationHours.floor();
    final minutes = ((durationHours - hours) * 60).round();
    final durationFormatted = hours > 0
        ? '${hours}h ${minutes}m'
        : '${minutes}m';

    return {
      'permission_id': permissionId,
      'permission_date': permissionDate.toIso8601String().split('T')[0],
      'permission_from_time': permissionFromTime,
      'permission_to_time': permissionToTime,
      'duration_hours': durationHours,
      'duration_formatted': durationFormatted,
      'permission_status': permissionStatus,
      'permission_status_display': _getStatusDisplay(permissionStatus),
      'permission_remarks': permissionRemarks,
      'admin_remarks': adminRemarks,
      'month': month,
      'year': year,
      'is_excess': isExcess,
      'excess_hours': excessHours,
    };
  }

  String _getStatusDisplay(int status) {
    switch (status) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

/// Detailed WFH record for an employee
class WfhRecord {
  final String wfhId;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final int wfhStatus;
  final String? reason;
  final String? adminRemarks;
  final int month;
  final int year;
  final bool isExcess;
  final int excessDays;

  WfhRecord({
    required this.wfhId,
    required this.startDate,
    required this.endDate,
    this.totalDays = 1,
    this.wfhStatus = 0,
    this.reason,
    this.adminRemarks,
    required this.month,
    required this.year,
    this.isExcess = false,
    this.excessDays = 0,
  });

  factory WfhRecord.fromJson(Map<String, dynamic> json) {
    return WfhRecord(
      wfhId: json['wfh_id']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      totalDays: _parseIntSafe(json['total_days'], 1),
      wfhStatus: _parseIntSafe(json['wfh_status']),
      reason: json['reason']?.toString(),
      adminRemarks: json['admin_remarks']?.toString(),
      month: _parseIntSafe(json['month']),
      year: _parseIntSafe(json['year']),
      isExcess: json['is_excess'] == true,
      excessDays: _parseIntSafe(json['excess_days']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wfh_id': wfhId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'total_days': totalDays,
      'wfh_status': wfhStatus,
      'wfh_status_display': _getStatusDisplay(wfhStatus),
      'reason': reason,
      'admin_remarks': adminRemarks,
      'month': month,
      'year': year,
      'is_excess': isExcess,
      'excess_days': excessDays,
    };
  }

  String _getStatusDisplay(int status) {
    switch (status) {
      case 1:
        return 'Approved';
      case 2:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}

/// Monthly summary for an employee (used in detailed view)
class MonthlySummary {
  final int month;
  final int year;
  final String monthDisplay;
  final LeaveSummary leaveSummary;
  final PermissionSummary permissionSummary;
  final WfhSummary wfhSummary;

  MonthlySummary({
    required this.month,
    required this.year,
    required this.monthDisplay,
    required this.leaveSummary,
    required this.permissionSummary,
    required this.wfhSummary,
  });

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'year': year,
      'month_display': monthDisplay,
      'leave_summary': leaveSummary.toJson(),
      'permission_summary': permissionSummary.toJson(),
      'wfh_summary': wfhSummary.toJson(),
    };
  }
}

class LeaveSummary {
  final double totalDays;
  final double paidDays;
  final double unpaidDays;
  final double excessDays;
  final bool isExceeded;
  final double carryForwardAvailable;
  final double totalAvailable;
  final double carryForwardToNext;

  LeaveSummary({
    this.totalDays = 0,
    this.paidDays = 0,
    this.unpaidDays = 0,
    this.excessDays = 0,
    this.isExceeded = false,
    this.carryForwardAvailable = 0,
    this.totalAvailable = 0,
    this.carryForwardToNext = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_days': totalDays,
      'paid_days': paidDays,
      'unpaid_days': unpaidDays,
      'excess_days': excessDays,
      'is_exceeded': isExceeded,
      'carry_forward_available': carryForwardAvailable,
      'total_available': totalAvailable,
      'carry_forward_to_next': carryForwardToNext,
    };
  }
}

class PermissionSummary {
  final double totalHours;
  final double excessHours;
  final bool isExceeded;

  PermissionSummary({
    this.totalHours = 0,
    this.excessHours = 0,
    this.isExceeded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_hours': totalHours,
      'excess_hours': excessHours,
      'is_exceeded': isExceeded,
    };
  }
}

class WfhSummary {
  final int totalDays;
  final int excessDays;
  final bool isExceeded;

  WfhSummary({
    this.totalDays = 0,
    this.excessDays = 0,
    this.isExceeded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_days': totalDays,
      'excess_days': excessDays,
      'is_exceeded': isExceeded,
    };
  }
}

/// Employee details for the detailed report
class EmployeeDetails {
  final String employeeId;
  final String? employeeUuid;
  final String employeeName;
  final String? employeeRole;
  final String? employeeDesignation;
  final String? employeeProfileImage;
  final double? actualSalary;
  final double? totalLeaveDaysInYear;
  final double? pendingLeaveCount;

  EmployeeDetails({
    required this.employeeId,
    this.employeeUuid,
    required this.employeeName,
    this.employeeRole,
    this.employeeDesignation,
    this.employeeProfileImage,
    this.actualSalary,
    this.totalLeaveDaysInYear,
    this.pendingLeaveCount,
  });

  factory EmployeeDetails.fromJson(Map<String, dynamic> json) {
    return EmployeeDetails(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeUuid: json['employee_uuid']?.toString(),
      employeeName: json['employee_name']?.toString() ?? '',
      employeeRole: json['employee_role']?.toString(),
      employeeDesignation: json['employee_designation']?.toString(),
      employeeProfileImage: json['employee_img']?.toString(),
      actualSalary: _parseDoubleSafe(json['employee_actual_salary']),
      totalLeaveDaysInYear: _parseDoubleSafe(
        json['employee_total_leave_days_in_year'],
      ),
      pendingLeaveCount: _parseDoubleSafe(json['employee_pending_leave_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_uuid': employeeUuid,
      'employee_name': employeeName,
      'employee_role': employeeRole,
      'employee_designation': employeeDesignation,
      'employee_profile_image': employeeProfileImage,
      'actual_salary': actualSalary,
      'total_leave_days_in_year': totalLeaveDaysInYear,
      'pending_leave_count': pendingLeaveCount,
    };
  }
}

/// Helper to get month name
String getMonthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return 'Unknown';
  return months[month - 1];
}
