class DailyReport {
  final String reportId;
  final String employeeId;
  final String employeeName;
  final String reportDate;
  final String reportTime;
  final List<Map<String, dynamic>> tasks;
  final double totalHours;
  final String status;
  final DateTime createdAt;
  final String? additionalNotes;
  final String? dailyClockIn;
  final String? dailyClockOff;
  final String? workType;

  DailyReport({
    required this.reportId,
    required this.employeeId,
    required this.employeeName,
    required this.reportDate,
    required this.reportTime,
    required this.tasks,
    required this.totalHours,
    required this.status,
    required this.createdAt,
    this.additionalNotes,
    this.dailyClockIn,
    this.dailyClockOff,
    this.workType,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      reportId: json['report_id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      reportDate: json['report_date'] as String,
      reportTime: json['report_time'] as String,
      tasks: (json['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      totalHours: (json['total_hours'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      additionalNotes: json['additional_notes'] as String?,
      dailyClockIn: json['daily_clock_in'] as String?,
      dailyClockOff: json['daily_clock_off'] as String?,
      workType: json['work_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'report_id': reportId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'report_date': reportDate,
      'report_time': reportTime,
      'tasks': tasks,
      'total_hours': totalHours,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'additional_notes': additionalNotes,
      'daily_clock_in': dailyClockIn,
      'daily_clock_off': dailyClockOff,
      'work_type': workType,
    };
  }
}
