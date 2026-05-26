import 'dart:convert';

/// Admin domain model
class Admin {
  final String? adminUUID;
  final String adminId;
  final String adminRole;
  final String adminImg;
  final String? adminCoverImg;
  final String adminName;
  final String adminPhoneNum;
  final String adminGender;
  final String adminPersonalEmail;
  final String adminCompanyEmail;
  final String? adminAddress;
  final String? adminDesignation;
  final String? adminQualification;
  final String? adminDOB;
  final int? adminAge;
  final String? adminDOJ;
  final String adminBloodGroup;
  final String adminEmergencyContactNumber;
  final double adminActualSalary;
  final double adminTotalLeaveDaysInYear;
  final double adminPendingLeaveCount;
  final bool? status;
  final String? changedBy;
  final DateTime? changedAt;
  final String? adminDoe;
  final String? exitReason;
  final String? exitedBy;
  final DateTime? exitedAt;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<String>? accessPermissions;
  final String? roleType;
  final Map<String, dynamic>? sidebarConfig;
  final String? organizationId;

  Admin({
    this.adminUUID,
    required this.adminId,
    required this.adminRole,
    required this.adminImg,
    this.adminCoverImg,
    required this.adminName,
    required this.adminPhoneNum,
    required this.adminGender,
    required this.adminPersonalEmail,
    required this.adminCompanyEmail,
    this.adminAddress,
    this.adminDesignation,
    this.adminQualification,
    this.adminDOB,
    this.adminAge,
    this.adminDOJ,
    required this.adminBloodGroup,
    required this.adminEmergencyContactNumber,
    required this.adminActualSalary,
    required this.adminTotalLeaveDaysInYear,
    required this.adminPendingLeaveCount,
    this.status,
    this.changedBy,
    this.changedAt,
    this.adminDoe,
    this.exitReason,
    this.exitedBy,
    this.exitedAt,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.accessPermissions,
    this.roleType,
    this.sidebarConfig,
    this.organizationId,
  });

  /// Create from database row
  factory Admin.fromMap(Map<String, dynamic> map) {
    return Admin(
      adminUUID: map['admin_uuid']?.toString(),
      adminId: map['admin_id']?.toString() ?? '',
      adminRole: map['admin_role']?.toString() ?? '',
      adminImg: map['admin_img']?.toString() ?? '',
      adminCoverImg: map['admin_cover_img']?.toString(),
      adminName: map['admin_name']?.toString() ?? '',
      adminPhoneNum: map['admin_phone_num']?.toString() ?? '',
      adminGender: map['admin_gender']?.toString() ?? '',
      adminPersonalEmail: map['admin_personal_email']?.toString() ?? '',
      adminCompanyEmail: map['admin_company_email']?.toString() ?? '',
      adminAddress: map['admin_address']?.toString(),
      adminDesignation: map['admin_designation']?.toString(),
      adminQualification: map['admin_qualification']?.toString(),
      adminDOB: map['admin_dob']?.toString(),
      adminAge: map['admin_age'] is String
          ? int.tryParse(map['admin_age'])
          : (map['admin_age'] as num?)?.toInt(),
      adminDOJ: map['admin_doj']?.toString(),
      adminBloodGroup: map['admin_blood_group']?.toString() ?? '',
      adminEmergencyContactNumber:
          map['admin_emergency_contact_number']?.toString() ?? '',
      adminActualSalary: map['admin_actual_salary'] is String
          ? double.tryParse(map['admin_actual_salary']) ?? 0.0
          : (map['admin_actual_salary'] as num?)?.toDouble() ?? 0.0,
      adminTotalLeaveDaysInYear: map['admin_total_leave_days_in_year'] is String
          ? double.tryParse(map['admin_total_leave_days_in_year']) ?? 0.0
          : (map['admin_total_leave_days_in_year'] as num?)?.toDouble() ?? 0.0,
      adminPendingLeaveCount: map['admin_pending_leave_count'] is String
          ? double.tryParse(map['admin_pending_leave_count']) ?? 0.0
          : (map['admin_pending_leave_count'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] == 1 || map['status'] == true,
      changedBy: map['changed_by']?.toString(),
      changedAt: map['changed_at'] != null
          ? DateTime.parse(map['changed_at'].toString())
          : null,
      adminDoe: map['admin_doe']?.toString(),
      exitReason: map['reason_of_exit']?.toString(),
      exitedBy: map['exited_by']?.toString(),
      exitedAt: map['exited_at'] != null
          ? DateTime.parse(map['exited_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      accessPermissions: _parsePermissions(map['access_permissions']),
      roleType: map['role_type']?.toString(),
      sidebarConfig: _parseJson(map['sidebar_config']),
      organizationId: map['organization_id']?.toString(),
    );
  }

  /// Parse dynamic JSON value
  static Map<String, dynamic>? _parseJson(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {}
    }
    return null;
  }

  /// Parse access_permissions from JSONB column value
  static List<String>? _parsePermissions(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return null;
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'admin_uuid': adminUUID,
      'admin_id': adminId,
      'admin_role': adminRole,
      'admin_img': adminImg,
      'admin_cover_img': adminCoverImg,
      'admin_name': adminName,
      'admin_phone_num': adminPhoneNum,
      'admin_gender': adminGender,
      'admin_personal_email': adminPersonalEmail,
      'admin_company_email': adminCompanyEmail,
      'admin_address': adminAddress,
      'admin_designation': adminDesignation,
      'admin_qualification': adminQualification,
      'admin_dob': adminDOB,
      'admin_age': adminAge,
      'admin_doj': adminDOJ,
      'admin_blood_group': adminBloodGroup,
      'admin_emergency_contact_number': adminEmergencyContactNumber,
      'admin_actual_salary': adminActualSalary,
      'admin_total_leave_days_in_year': adminTotalLeaveDaysInYear,
      'admin_pending_leave_count': adminPendingLeaveCount,
      'status': status,
      'changed_by': changedBy,
      'changed_at': changedAt?.toIso8601String(),
      'admin_doe': adminDoe,
      'reason_of_exit': exitReason,
      'exited_by': exitedBy,
      'exited_at': exitedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'access_permissions': accessPermissions,
      'role_type': roleType,
      'sidebar_config': sidebarConfig,
      'organization_id': organizationId,
      'experience_formatted': _calculateExperienceFormatted(),
      'total_days': _calculateTotalDays(),
    };
  }

  String _calculateExperienceFormatted() {
    try {
      if (adminDOJ == null || adminDOJ!.isEmpty) return '0 Days';

      // Try parsing YYYY-MM-DD directly first (Standard ISO)
      DateTime? doj = DateTime.tryParse(adminDOJ!);

      // If failed, try DD-MM-YYYY
      if (doj == null) {
        final parts = adminDOJ!.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          doj = DateTime(year, month, day);
        }
      }

      if (doj == null) return '0 Days';
      final now = DateTime.now();

      if (now.isBefore(doj)) return '0 Days';

      int years = now.year - doj.year;
      int months = now.month - doj.month;
      int days = now.day - doj.day;

      if (days < 0) {
        months--;
        final lastDayPrevMonth = DateTime(now.year, now.month, 0);
        days += lastDayPrevMonth.day;
      }

      if (months < 0) {
        years--;
        months += 12;
      }

      final List<String> result = [];
      if (years > 0) result.add('$years Year${years > 1 ? 's' : ''}');
      if (months > 0) result.add('$months Month${months > 1 ? 's' : ''}');
      if (days > 0) result.add('$days Day${days > 1 ? 's' : ''}');

      return result.isEmpty ? '0 Days' : result.join(' ');
    } catch (e) {
      return '0 Days';
    }
  }

  int _calculateTotalDays() {
    try {
      if (adminDOJ == null || adminDOJ!.isEmpty) return 0;

      // Try parsing YYYY-MM-DD directly first (Standard ISO)
      DateTime? doj = DateTime.tryParse(adminDOJ!);

      // If failed, try DD-MM-YYYY
      if (doj == null) {
        final parts = adminDOJ!.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          doj = DateTime(year, month, day);
        }
      }

      if (doj == null) return 0;
      final now = DateTime.now();

      if (now.isBefore(doj)) return 0;

      return now.difference(doj).inDays;
    } catch (e) {
      return 0;
    }
  }

  /// Copy with updated fields
  Admin copyWith({
    String? adminUUID,
    String? adminId,
    String? adminRole,
    String? adminImg,
    String? adminCoverImg,
    String? adminName,
    String? adminPhoneNum,
    String? adminGender,
    String? adminPersonalEmail,
    String? adminCompanyEmail,
    String? adminAddress,
    String? adminDesignation,
    String? adminQualification,
    String? adminDOB,
    int? adminAge,
    String? adminDOJ,
    String? adminBloodGroup,
    String? adminEmergencyContactNumber,
    double? adminActualSalary,
    double? adminTotalLeaveDaysInYear,
    double? adminPendingLeaveCount,
    bool? status,
    String? changedBy,
    DateTime? changedAt,
    String? adminDoe,
    String? exitReason,
    String? exitedBy,
    DateTime? exitedAt,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    String? roleType,
    Map<String, dynamic>? sidebarConfig,
    String? organizationId,
  }) {
    return Admin(
      adminUUID: adminUUID ?? this.adminUUID,
      adminId: adminId ?? this.adminId,
      adminRole: adminRole ?? this.adminRole,
      adminImg: adminImg ?? this.adminImg,
      adminCoverImg: adminCoverImg ?? this.adminCoverImg,
      adminName: adminName ?? this.adminName,
      adminPhoneNum: adminPhoneNum ?? this.adminPhoneNum,
      adminGender: adminGender ?? this.adminGender,
      adminPersonalEmail: adminPersonalEmail ?? this.adminPersonalEmail,
      adminCompanyEmail: adminCompanyEmail ?? this.adminCompanyEmail,
      adminAddress: adminAddress ?? this.adminAddress,
      adminDesignation: adminDesignation ?? this.adminDesignation,
      adminQualification: adminQualification ?? this.adminQualification,
      adminDOB: adminDOB ?? this.adminDOB,
      adminAge: adminAge ?? this.adminAge,
      adminDOJ: adminDOJ ?? this.adminDOJ,
      adminBloodGroup: adminBloodGroup ?? this.adminBloodGroup,
      adminEmergencyContactNumber:
          adminEmergencyContactNumber ?? this.adminEmergencyContactNumber,
      adminActualSalary: adminActualSalary ?? this.adminActualSalary,
      adminTotalLeaveDaysInYear:
          adminTotalLeaveDaysInYear ?? this.adminTotalLeaveDaysInYear,
      adminPendingLeaveCount:
          adminPendingLeaveCount ?? this.adminPendingLeaveCount,
      status: status ?? this.status,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      adminDoe: adminDoe ?? this.adminDoe,
      exitReason: exitReason ?? this.exitReason,
      exitedBy: exitedBy ?? this.exitedBy,
      exitedAt: exitedAt ?? this.exitedAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      accessPermissions: accessPermissions ?? accessPermissions,
      roleType: roleType ?? this.roleType,
      sidebarConfig: sidebarConfig ?? this.sidebarConfig,
      organizationId: organizationId ?? this.organizationId,
    );
  }
}
