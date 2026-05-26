/// Helper function to parse nullable strings from database
/// Handles cases where "null" is stored as string or empty string
String? _parseNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty || str == 'null') return null;
  return str;
}

/// Employee Attendance model
class EmployeeAttendance {
  final String attendanceId;
  final String employeeId;
  final String workDate;
  final String clockOnForTheDay;
  final String? clockOffForTheDay;
  final String clockOnTime;
  final String? clockOffTime;
  final String? taskId;
  final double? workedHrs;
  final String? sessionDuration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;
  final List<dynamic> tasksForTheDay;
  // Newly added fields
  final bool? isRemoteOverride;
  final String? remoteReason;

  EmployeeAttendance({
    required this.attendanceId,
    required this.employeeId,
    required this.workDate,
    required this.clockOnForTheDay,
    this.clockOffForTheDay,
    required this.clockOnTime,
    this.clockOffTime,
    this.taskId,
    this.workedHrs,
    this.sessionDuration,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.tasksForTheDay,
    this.isRemoteOverride,
    this.remoteReason,
  });

  /// Factory to parse from JSON/Map
  factory EmployeeAttendance.fromJson(Map<String, dynamic> json) {
    // Handle tasks_for_the_day safely
    List<dynamic> tasksForTheDay = [];
    if (json['tasks_for_the_day'] != null) {
      if (json['tasks_for_the_day'] is List) {
        tasksForTheDay = json['tasks_for_the_day'] as List<dynamic>;
      } else if (json['tasks_for_the_day'] is Map) {
        tasksForTheDay = [json['tasks_for_the_day']];
      } else if (json['tasks_for_the_day'] is String) {
        // Handle if it's stored as JSON string in database
        try {
          final decoded = json['tasks_for_the_day'];
          if (decoded is List) {
            tasksForTheDay = decoded;
          }
        } catch (_) {
          tasksForTheDay = [];
        }
      }
    }

    return EmployeeAttendance(
      attendanceId: json['attendance_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      workDate: json['work_date']?.toString() ?? '',
      clockOnForTheDay: json['clock_on_for_the_day']?.toString() ?? '',
      clockOffForTheDay: _parseNullableString(json['clock_off_for_the_day']),
      clockOnTime:
          json['clock_on_time']?.toString() ??
          (json['clock_on_for_the_day'] != null
              ? DateTime.parse(
                  json['clock_on_for_the_day'].toString(),
                ).toLocal().toString().split(' ')[1].split('.')[0]
              : ''),
      clockOffTime:
          _parseNullableString(json['clock_off_time']) ??
          (_parseNullableString(json['clock_off_for_the_day']) != null
              ? DateTime.parse(
                  json['clock_off_for_the_day'].toString(),
                ).toLocal().toString().split(' ')[1].split('.')[0]
              : null),
      taskId: json['task_id']?.toString(),
      workedHrs: json['worked_hrs'] != null
          ? double.tryParse(json['worked_hrs'].toString()) ?? 0.0
          : null,
      sessionDuration: _parseNullableString(json['session_duration']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString() ?? '',
      tasksForTheDay: tasksForTheDay,
      isRemoteOverride: json['is_remote_override'] as bool?,
      remoteReason: json['remote_reason']?.toString(),
    );
  }

  /// Alias for fromJson to match other models
  factory EmployeeAttendance.fromMap(Map<String, dynamic> map) =>
      EmployeeAttendance.fromJson(map);

  /// Convert model to JSON (for reading/returning)
  Map<String, dynamic> toJson() {
    return {
      'attendance_id': attendanceId,
      'employee_id': employeeId,
      'work_date': workDate,
      'clock_on_for_the_day': clockOnForTheDay,
      'clock_off_for_the_day': clockOffForTheDay,
      'clock_on_time': clockOnTime,
      'clock_off_time': clockOffTime,
      'task_id': taskId,
      'worked_hrs': workedHrs,
      'session_duration': sessionDuration,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'tasks_for_the_day': tasksForTheDay,
      'is_remote_override': isRemoteOverride,
      'remote_reason': remoteReason,
    };
  }

  /// Convert model to JSON for creating a new row
  Map<String, dynamic> toCreateJson() {
    return {
      'employee_id': employeeId,
      'work_date': workDate,
      'clock_on_for_the_day': clockOnForTheDay,
      'clock_off_for_the_day': clockOffForTheDay,
      'clock_on_time': clockOnTime,
      'clock_off_time': clockOffTime,
      'task_id': taskId,
      'worked_hrs': workedHrs,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'tasks_for_the_day': tasksForTheDay,
      'is_remote_override': isRemoteOverride,
      'remote_reason': remoteReason,
    };
  }

  /// Convert model to Map for database insert
  Map<String, dynamic> toInsertMap() {
    return {
      'employee_id': employeeId,
      'work_date': workDate,
      'clock_on_for_the_day': clockOnForTheDay,
      'clock_off_for_the_day': clockOffForTheDay,
      'clock_on_time': clockOnTime,
      'clock_off_time': clockOffTime,
      'task_id': taskId,
      'worked_hrs': workedHrs,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'tasks_for_the_day': tasksForTheDay,
      'is_remote_override': isRemoteOverride,
      'remote_reason': remoteReason,
    };
  }
}
