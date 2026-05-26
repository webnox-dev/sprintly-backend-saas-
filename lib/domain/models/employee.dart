/// Employee domain model
class Employee {
  final String? employeeUUID;
  final String employeeId;
  final String employeeRole;
  final String employeeImg;
  final String employeeName;
  final String employeePhoneNum;
  final String employeeGender;
  final String employeePersonalEmail;
  final String employeeCompanyEmail;
  final String? employeeAddress;
  final String? employeeDesignation;
  final String? employeeQualification;
  final String? employeeSpecialization;
  final String employeeDOB;
  final int employeeAge;
  final String employeeDOJ;
  final String employeeBloodGroup;
  final String employeeEmergencyContactNumber;
  final double employeeActualSalary;
  final double employeeTotalLeaveDaysInYear;
  final double employeePendingLeaveCount;
  final bool? status;
  final String? changedBy;
  final DateTime? changedAt;
  final String? employeeDoe;
  final String? exitReason;
  final String? exitedBy;
  final DateTime? exitedAt;
  final String? organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Employee({
    this.employeeUUID,
    required this.employeeId,
    required this.employeeRole,
    required this.employeeImg,
    required this.employeeName,
    required this.employeePhoneNum,
    required this.employeeGender,
    required this.employeePersonalEmail,
    required this.employeeCompanyEmail,
    this.employeeAddress,
    this.employeeDesignation,
    this.employeeQualification,
    this.employeeSpecialization,
    required this.employeeDOB,
    required this.employeeAge,
    required this.employeeDOJ,
    required this.employeeBloodGroup,
    required this.employeeEmergencyContactNumber,
    required this.employeeActualSalary,
    required this.employeeTotalLeaveDaysInYear,
    required this.employeePendingLeaveCount,
    this.status,
    this.changedBy,
    this.changedAt,
    this.employeeDoe,
    this.exitReason,
    this.exitedBy,
    this.exitedAt,
    this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from database row
  factory Employee.fromMap(Map<String, dynamic> map) {
    // Helper to safe parse numbers
    num? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val;
      if (val is String) return num.tryParse(val);
      return null;
    }

    return Employee(
      employeeUUID: map['employee_uuid']?.toString(),
      employeeId: map['employee_id']?.toString() ?? '',
      employeeRole: map['employee_role']?.toString() ?? '',
      employeeImg: map['employee_img']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      employeePhoneNum: map['employee_phone_num']?.toString() ?? '',
      employeeGender: map['employee_gender']?.toString() ?? '',
      employeePersonalEmail: map['employee_personal_email']?.toString() ?? '',
      employeeCompanyEmail: map['employee_company_email']?.toString() ?? '',
      employeeAddress: map['employee_address']?.toString(),
      employeeDesignation: map['employee_designation']?.toString(),
      employeeQualification: map['employee_qualification']?.toString(),
      employeeSpecialization: map['employee_specialization']?.toString(),
      employeeDOB: map['employee_dob']?.toString() ?? '',
      employeeAge: parseNum(map['employee_age'])?.toInt() ?? 0,
      employeeDOJ: map['employee_doj']?.toString() ?? '',
      employeeBloodGroup: map['employee_blood_group']?.toString() ?? '',
      employeeEmergencyContactNumber:
          map['employee_emergency_contact_number']?.toString() ?? '',
      employeeActualSalary:
          parseNum(map['employee_actual_salary'])?.toDouble() ?? 0.0,
      employeeTotalLeaveDaysInYear:
          parseNum(map['employee_total_leave_days_in_year'])?.toDouble() ?? 0.0,
      employeePendingLeaveCount:
          parseNum(map['employee_pending_leave_count'])?.toDouble() ?? 0.0,
      status: map['status'] == 1 || map['status'] == true,
      changedBy: map['changed_by']?.toString(),
      changedAt: map['changed_at'] != null
          ? DateTime.parse(map['changed_at'].toString())
          : null,
      employeeDoe: map['employee_doe']?.toString(),
      exitReason: map['reason_of_exit']?.toString(),
      exitedBy: map['exited_by']?.toString(),
      exitedAt: map['exited_at'] != null
          ? DateTime.parse(map['exited_at'].toString())
          : null,
      organizationId: map['organization_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
    );
  }

  /// Convert to JSON for API response
  Map<String, dynamic> toJson() {
    return {
      'employee_uuid': employeeUUID,
      'employee_id': employeeId,
      'employee_role': employeeRole,
      'employee_img': employeeImg,
      'employee_name': employeeName,
      'employee_phone_num': employeePhoneNum,
      'employee_gender': employeeGender,
      'employee_personal_email': employeePersonalEmail,
      'employee_company_email': employeeCompanyEmail,
      'employee_address': employeeAddress,
      'employee_designation': employeeDesignation,
      'employee_qualification': employeeQualification,
      'employee_specialization': employeeSpecialization,
      'employee_dob': employeeDOB,
      'employee_age': employeeAge,
      'employee_doj': employeeDOJ,
      'employee_blood_group': employeeBloodGroup,
      'employee_emergency_contact_number': employeeEmergencyContactNumber,
      'employee_actual_salary': employeeActualSalary,
      'employee_total_leave_days_in_year': employeeTotalLeaveDaysInYear,
      'employee_pending_leave_count': employeePendingLeaveCount,
      'status': status,
      'changed_by': changedBy,
      'changed_at': changedAt?.toIso8601String(),
      'employee_doe': employeeDoe,
      'reason_of_exit': exitReason,
      'exited_by': exitedBy,
      'exited_at': exitedAt?.toIso8601String(),
      'organization_id': organizationId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'experience_formatted': _calculateExperienceFormatted(),
      'total_days': _calculateTotalDays(),
    };
  }

  String _calculateExperienceFormatted() {
    try {
      if (employeeDOJ.isEmpty) return '0 Days';

      // Try parsing YYYY-MM-DD directly first (Standard ISO)
      DateTime? doj = DateTime.tryParse(employeeDOJ);

      // If failed, try DD-MM-YYYY
      if (doj == null) {
        final parts = employeeDOJ.split('-');
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
      if (employeeDOJ.isEmpty) return 0;

      // Try parsing YYYY-MM-DD directly first (Standard ISO)
      DateTime? doj = DateTime.tryParse(employeeDOJ);

      // If failed, try DD-MM-YYYY
      if (doj == null) {
        final parts = employeeDOJ.split('-');
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

  /// Convert to map for database insert
  Map<String, dynamic> toInsertMap() {
    return {
      'employee_id': employeeId,
      'employee_uuid': employeeUUID,
      'employee_name': employeeName,
      'employee_role': employeeRole,
      'employee_img': employeeImg,
      'employee_phone_num': employeePhoneNum,
      'employee_gender': employeeGender,
      'employee_personal_email': employeePersonalEmail,
      'employee_company_email': employeeCompanyEmail,
      'employee_address': employeeAddress,
      'employee_designation': employeeDesignation,
      'employee_qualification': employeeQualification,
      'employee_specialization': employeeSpecialization,
      'employee_dob': employeeDOB,
      'employee_age': employeeAge,
      'employee_doj': employeeDOJ,
      'employee_blood_group': employeeBloodGroup,
      'employee_emergency_contact_number': employeeEmergencyContactNumber,
      'employee_actual_salary': employeeActualSalary,
      'employee_total_leave_days_in_year': employeeTotalLeaveDaysInYear,
      'employee_pending_leave_count': employeePendingLeaveCount,
      'organization_id': organizationId,
      'status': status == true ? 1 : 0,
    };
  }
}
