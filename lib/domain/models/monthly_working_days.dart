import 'dart:convert';

class MonthlyWorkingDays {
  final String? id;
  final int month;
  final int year;
  final double workingDays;
  final double nonWorkingDays;
  final int totalDays;
  final List<String> workingDateList;
  final String? remarks;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MonthlyWorkingDays({
    this.id,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.nonWorkingDays,
    required this.totalDays,
    required this.workingDateList,
    this.remarks,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory MonthlyWorkingDays.fromJson(Map<String, dynamic> json) {
    return MonthlyWorkingDays(
      id: json['working_days_id'],
      month: json['month'],
      year: json['year'],
      workingDays: (json['working_days'] as num).toDouble(),
      nonWorkingDays: (json['non_working_days'] as num?)?.toDouble() ?? 0.0,
      totalDays: json['total_days'],
      workingDateList: json['working_date_list'] != null
          ? (json['working_date_list'] is String
              ? List<String>.from(
                  jsonDecode(json['working_date_list'] as String) as Iterable)
              : List<String>.from(json['working_date_list'] as Iterable))
          : [],
      remarks: json['remarks'],
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
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
      if (id != null) 'working_days_id': id,
      'month': month,
      'year': year,
      'working_days': workingDays,
      'non_working_days': nonWorkingDays,
      'total_days': totalDays,
      'working_date_list': workingDateList,
      'remarks': remarks,
      'created_by': createdBy,
      'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
