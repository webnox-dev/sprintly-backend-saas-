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
      configId: json['config_id']?.toString() ?? 'default',
      allowedLeaveDaysPerMonth: json['allowed_leave_days_per_month'] is int
          ? json['allowed_leave_days_per_month']
          : int.tryParse(
                  json['allowed_leave_days_per_month']?.toString() ?? '0',
                ) ??
                0,
      allowedPermissionHoursPerMonth:
          json['allowed_permission_hours_per_month'] is num
          ? (json['allowed_permission_hours_per_month'] as num).toDouble()
          : double.tryParse(
                  json['allowed_permission_hours_per_month']?.toString() ??
                      '0.0',
                ) ??
                0.0,
      allowedWfhDaysPerMonth: json['allowed_wfh_days_per_month'] is int
          ? json['allowed_wfh_days_per_month']
          : int.tryParse(
                  json['allowed_wfh_days_per_month']?.toString() ?? '0',
                ) ??
                0,
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
}
