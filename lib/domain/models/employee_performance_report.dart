
class EmployeePerformanceReport {
  final String employeeId;
  final String employeeName;
  final String? employeeImg;
  final String? designation;
  final List<DailyPerformance> dailyPerformance;
  final WeeklySummary weeklySummary;
  final MonthlySummary monthlySummary;
  final YearlySummary yearlySummary;

  EmployeePerformanceReport({
    required this.employeeId,
    required this.employeeName,
    this.employeeImg,
    this.designation,
    required this.dailyPerformance,
    required this.weeklySummary,
    required this.monthlySummary,
    required this.yearlySummary,
  });

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_img': employeeImg,
      'designation': designation,
      'daily_performance': dailyPerformance.map((e) => e.toJson()).toList(),
      'weekly_summary': weeklySummary.toJson(),
      'monthly_summary': monthlySummary.toJson(),
      'yearly_summary': yearlySummary.toJson(),
    };
  }
}

class DailyPerformance {
  final String date;
  final double workedHours;
  final String formattedWorkedHours;
  final String clockIn;
  final String? clockOut;
  final String status; // present, leave, permission, wfh, absent
  final bool isLate;
  final String? workStatus; // underwork, normal, overwork
  final int excessOrDeficitMinutes;
  final String? leaveType;
  final String? permissionDuration;
  final String? wfhReason;

  DailyPerformance({
    required this.date,
    required this.workedHours,
    required this.formattedWorkedHours,
    required this.clockIn,
    this.clockOut,
    required this.status,
    required this.isLate,
    this.workStatus,
    this.excessOrDeficitMinutes = 0,
    this.leaveType,
    this.permissionDuration,
    this.wfhReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'worked_hours': workedHours,
      'formatted_worked_hours': formattedWorkedHours,
      'clock_in': clockIn,
      'clock_out': clockOut,
      'status': status,
      'is_late': isLate,
      'work_status': workStatus,
      'excess_or_deficit_minutes': excessOrDeficitMinutes,
      'leave_type': leaveType,
      'permission_duration': permissionDuration,
      'wfh_reason': wfhReason,
    };
  }
}

class WeeklySummary {
  final double totalWorkedHours;
  final int presentDays;
  final int leaveDays;
  final int wfhDays;
  final int lateDays;
  final double permissionHours;
  final String formattedPermissionHours;
  final double pendingLeaves;
  final double pendingPermissionHours;
  final int pendingWfhDays;
  final int underworkDays;
  final int overtimeDays;
  final double totalOvertimeHours;
  final List<BarChartData> dailyHours;

  WeeklySummary({
    required this.totalWorkedHours,
    required this.presentDays,
    required this.leaveDays,
    required this.wfhDays,
    required this.lateDays,
    required this.permissionHours,
    required this.formattedPermissionHours,
    required this.pendingLeaves,
    required this.pendingPermissionHours,
    required this.pendingWfhDays,
    required this.underworkDays,
    required this.overtimeDays,
    required this.totalOvertimeHours,
    required this.dailyHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_worked_hours': totalWorkedHours,
      'present_days': presentDays,
      'leave_days': leaveDays,
      'wfh_days': wfhDays,
      'late_days': lateDays,
      'permission_hours': permissionHours,
      'formatted_permission_hours': formattedPermissionHours,
      'pending_leaves': pendingLeaves,
      'pending_permission_hours': pendingPermissionHours,
      'pending_wfh_days': pendingWfhDays,
      'underwork_days': underworkDays,
      'overtime_days': overtimeDays,
      'total_overtime_hours': totalOvertimeHours,
      'daily_hours': dailyHours.map((e) => e.toJson()).toList(),
    };
  }
}

class MonthlySummary {
  final double totalWorkedHours;
  final int presentDays;
  final int leaveDays;
  final int wfhDays;
  final double permissionHours;
  final String formattedPermissionHours;
  final double pendingLeaves;
  final double pendingPermissionHours;
  final int pendingWfhDays;
  final int underworkDays;
  final int overtimeDays;
  final double totalOvertimeHours;
  final List<BarChartData> weeklyHours;

  MonthlySummary({
    required this.totalWorkedHours,
    required this.presentDays,
    required this.leaveDays,
    required this.wfhDays,
    required this.permissionHours,
    required this.formattedPermissionHours,
    required this.pendingLeaves,
    required this.pendingPermissionHours,
    required this.pendingWfhDays,
    required this.underworkDays,
    required this.overtimeDays,
    required this.totalOvertimeHours,
    required this.weeklyHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_worked_hours': totalWorkedHours,
      'present_days': presentDays,
      'leave_days': leaveDays,
      'wfh_days': wfhDays,
      'permission_hours': permissionHours,
      'formatted_permission_hours': formattedPermissionHours,
      'pending_leaves': pendingLeaves,
      'pending_permission_hours': pendingPermissionHours,
      'pending_wfh_days': pendingWfhDays,
      'underwork_days': underworkDays,
      'overtime_days': overtimeDays,
      'total_overtime_hours': totalOvertimeHours,
      'weekly_hours': weeklyHours.map((e) => e.toJson()).toList(),
    };
  }
}

class YearlySummary {
  final double totalWorkedHours;
  final int totalPresentDays;
  final List<BarChartData> monthlyHours;

  YearlySummary({
    required this.totalWorkedHours,
    required this.totalPresentDays,
    required this.monthlyHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'total_worked_hours': totalWorkedHours,
      'total_present_days': totalPresentDays,
      'monthly_hours': monthlyHours.map((e) => e.toJson()).toList(),
    };
  }
}

class BarChartData {
  final String label; // e.g., "Mon", "Week 1", "Jan"
  final double value; // hours
  final String? fullDate; // For filtering

  BarChartData({required this.label, required this.value, this.fullDate});

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value, 'full_date': fullDate};
  }
}
