class CompanyHoliday {
  final String? holidayId;
  final String holidayName;
  final DateTime fromDate;
  final DateTime? toDate;
  final int totalDays;
  final String? holidayRemarks;
  final bool isOptional;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CompanyHoliday({
    this.holidayId,
    required this.holidayName,
    required this.fromDate,
    this.toDate,
    this.totalDays = 1,
    this.holidayRemarks,
    this.isOptional = false,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CompanyHoliday.fromJson(Map<String, dynamic> json) {
    return CompanyHoliday(
      holidayId: json['holiday_id'] as String?,
      holidayName: json['holiday_name'] as String? ?? '',
      fromDate: json['from_date'] != null
          ? DateTime.parse(json['from_date'].toString())
          : DateTime.now(),
      toDate: json['to_date'] != null
          ? DateTime.parse(json['to_date'].toString())
          : null,
      totalDays: json['total_days'] as int? ?? 1,
      holidayRemarks: json['holiday_remarks'] as String?,
      isOptional: json['is_optional'] == true || json['is_optional'] == 1,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holiday_id': holidayId,
      'holiday_name': holidayName,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
      'total_days': totalDays,
      'holiday_remarks': holidayRemarks,
      'is_optional': isOptional,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
