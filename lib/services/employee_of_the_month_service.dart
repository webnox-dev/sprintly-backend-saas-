import '../core/utils/logger.dart';
import '../data/repositories/employee_of_the_month_repository.dart';
import '../data/repositories/employee_repository.dart';
import 'email_service.dart';
import 'email_templates/employee_of_the_month_template.dart';

/// Service for Employee of the Month (EOM) module.
/// Handles daily points calculation, monthly ranking, award, and APIs.
/// Points are precomputed and stored; APIs read from storage only.
class EmployeeOfTheMonthService {
  final AppLogger _logger = AppLogger('EmployeeOfTheMonthService');
  final EmployeeOfTheMonthRepository _repo = EmployeeOfTheMonthRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final EmailService _emailService = EmailService();

  /// Default point weights when config table is missing or empty.
  static const double defaultPointsTaskOnTime = 10.0;
  static const double defaultPointsTaskLate = 5.0;
  static const double defaultDeductionRedo = 5.0;
  static const double defaultPointsAttendanceOk = 5.0;
  static const double defaultDeductionLatePunch = 2.0;
  static const double defaultDeductionEarlyOut = 2.0;
  static const double defaultDeductionShortHours = 2.0;
  static const int punchInHour = 9;
  static const int punchInMinute = 0;
  static const int punchOutHour = 18;
  static const int punchOutMinute = 0;
  static const double minWorkHours = 9.0;

  /// Computes and persists daily EOM points for all active employees for [date].
  /// Call this once per day (e.g. via cron) for the previous day.
  /// [date] should be the calendar day to compute (e.g. yesterday).
  Future<void> computeDailyPointsForDate(DateTime date) async {
    final dateStr = _dateStr(date);
    _logger.info('EOM: Computing daily points for $dateStr');

    Map<String, dynamic> config = {};
    try {
      config = await _repo.getPointsConfig();
    } catch (_) {}

    final pointsTaskOnTime = _num(
      config,
      'points_per_task_completed_on_time',
      defaultPointsTaskOnTime,
    );
    final pointsTaskLate = _num(
      config,
      'points_per_task_completed_late',
      defaultPointsTaskLate,
    );
    final deductionRedo = _num(
      config,
      'points_deduction_per_redo',
      defaultDeductionRedo,
    );
    final pointsAttendanceOk = _num(
      config,
      'points_per_day_attendance_ok',
      defaultPointsAttendanceOk,
    );
    final deductionLatePunch = _num(
      config,
      'points_deduction_per_late_punch',
      defaultDeductionLatePunch,
    );
    final deductionEarlyOut = _num(
      config,
      'points_deduction_per_early_out',
      defaultDeductionEarlyOut,
    );
    final deductionShortHours = _num(
      config,
      'points_deduction_per_short_hours',
      defaultDeductionShortHours,
    );

    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isHoliday = await _repo.isCompanyHoliday(dateStr);

    List<String> employeeIds;
    try {
      employeeIds = await _repo.getActiveEmployeeIds();
    } catch (e, st) {
      _logger.error('EOM: Failed to get active employees', e, st);
      rethrow;
    }

    for (final employeeId in employeeIds) {
      try {
        final onLeave = await _repo.isOnLeave(
          employeeId: employeeId,
          dateStr: dateStr,
        );
        final onPermission = await _repo.isOnPermission(
          employeeId: employeeId,
          dateStr: dateStr,
        );
        final onWfh = await _repo.isOnWfh(
          employeeId: employeeId,
          dateStr: dateStr,
        );

        if (isWeekend || isHoliday) {
          await _repo.upsertDailyPoints(
            employeeId: employeeId,
            pointsDate: date,
            taskPoints: 0,
            attendancePoints: 0,
            breakdown: {
              'task': {'reason': 'weekend_or_holiday', 'points': 0},
              'attendance': {'reason': 'weekend_or_holiday', 'points': 0},
            },
          );
          continue;
        }

        if (onLeave || onWfh) {
          await _repo.upsertDailyPoints(
            employeeId: employeeId,
            pointsDate: date,
            taskPoints: 0,
            attendancePoints: 0,
            breakdown: {
              'task': {'reason': onLeave ? 'on_leave' : 'on_wfh', 'points': 0},
              'attendance': {
                'reason': onLeave ? 'on_leave' : 'on_wfh',
                'points': 0,
              },
            },
          );
          continue;
        }

        double taskPoints = 0;
        final taskStats = await _repo.getTaskStatsForDate(
          employeeId: employeeId,
          dateStr: dateStr,
        );
        final completed = (taskStats['completed_count'] as int?) ?? 0;
        final completedOnTime =
            (taskStats['completed_on_time_count'] as int?) ?? 0;
        final redoCount = (taskStats['redo_count'] as int?) ?? 0;
        final completedLate = completed - completedOnTime;
        taskPoints =
            completedOnTime * pointsTaskOnTime +
            completedLate * pointsTaskLate -
            redoCount * deductionRedo;

        final taskBreakdown = {
          'assigned_count': 0,
          'completed_count': completed,
          'completed_on_time_count': completedOnTime,
          'redo_count': redoCount,
          'points_earned':
              completedOnTime * pointsTaskOnTime +
              completedLate * pointsTaskLate,
          'points_deducted': redoCount * deductionRedo,
          'points': taskPoints,
        };

        double attendancePoints = 0;
        Map<String, dynamic> attendanceBreakdown = {
          'reason': 'no_attendance',
          'points': 0,
        };

        if (onPermission) {
          attendanceBreakdown = {'reason': 'on_permission', 'points': 0};
        } else {
          final att = await _repo.getAttendanceForDate(
            employeeId: employeeId,
            dateStr: dateStr,
          );
          if (att != null) {
            final clockOn = att['clock_on_for_the_day']?.toString();
            final clockOff = att['clock_off_for_the_day']?.toString();
            final workedHrs = (att['worked_hrs'] as num?)?.toDouble();

            bool punchInOnTime = true;
            bool punchOutOnTime = true;
            bool workHoursMet = true;
            double deductions = 0;

            if (clockOn != null && clockOn.isNotEmpty) {
              try {
                final t = DateTime.parse(clockOn);
                final deadline = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  punchInHour,
                  punchInMinute,
                );
                if (t.isAfter(deadline)) {
                  punchInOnTime = false;
                  deductions += deductionLatePunch;
                }
              } catch (_) {}
            } else {
              punchInOnTime = false;
              deductions += deductionLatePunch;
            }

            if (clockOff != null && clockOff.isNotEmpty) {
              try {
                final t = DateTime.parse(clockOff);
                final deadline = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  punchOutHour,
                  punchOutMinute,
                );
                if (t.isBefore(deadline)) {
                  punchOutOnTime = false;
                  deductions += deductionEarlyOut;
                }
              } catch (_) {}
            } else {
              punchOutOnTime = false;
              deductions += deductionEarlyOut;
            }

            if (workedHrs != null && workedHrs < minWorkHours) {
              workHoursMet = false;
              deductions += deductionShortHours;
            } else if (workedHrs == null) {
              workHoursMet = false;
              deductions += deductionShortHours;
            }

            attendancePoints = pointsAttendanceOk - deductions;
            if (attendancePoints < 0) attendancePoints = 0;

            attendanceBreakdown = {
              'punch_in_on_time': punchInOnTime,
              'punch_out_on_time': punchOutOnTime,
              'work_hours_met': workHoursMet,
              'worked_hrs': workedHrs,
              'points_earned': pointsAttendanceOk,
              'points_deducted': deductions,
              'points': attendancePoints,
            };
          }
        }

        await _repo.upsertDailyPoints(
          employeeId: employeeId,
          pointsDate: date,
          taskPoints: taskPoints,
          attendancePoints: attendancePoints,
          breakdown: {'task': taskBreakdown, 'attendance': attendanceBreakdown},
        );
      } catch (e, _) {
        _logger.warning(
          'EOM: Failed to compute daily points for $employeeId on $dateStr: $e',
        );
        // Continue with next employee
      }
    }

    _logger.info('EOM: Daily points computed for $dateStr');
  }

  /// Runs the monthly EOM job: aggregates points, builds rankings, saves winner, sends certificate email.
  /// Call on the last day of the month or first day of next month.
  /// [month] and [year] are the calendar month that just ended (e.g. February 2026).
  Future<Map<String, dynamic>> runMonthlyAward({
    required int month,
    required int year,
  }) async {
    _logger.info('EOM: Running monthly award for $year-$month');

    final totals = await _repo.getMonthlyTotalsByEmployee(
      month: month,
      year: year,
    );
    if (totals.isEmpty) {
      _logger.info('EOM: No daily points for $year-$month; skipping award');
      return {'winner': null, 'rankings_count': 0};
    }

    final ranked = <Map<String, dynamic>>[];
    int rank = 1;
    for (final r in totals) {
      ranked.add({
        'employee_id': r['employee_id'],
        'total_points': _toDouble(r['total_points']),
        'rank': rank++,
        'task_summary': <String, dynamic>{},
        'attendance_summary': <String, dynamic>{},
      });
    }

    await _repo.upsertMonthlyRankings(
      month: month,
      year: year,
      rankings: ranked,
    );

    final winner = ranked.first;
    final winnerId = winner['employee_id'] as String?;
    final winnerPoints = _toDouble(winner['total_points']);

    if (winnerId == null || winnerId.isEmpty) {
      _logger.info('EOM: No winner for $year-$month');
      return {'winner': null, 'rankings_count': ranked.length};
    }

    await _repo.setWinner(
      employeeId: winnerId,
      month: month,
      year: year,
      totalPoints: winnerPoints,
    );

    try {
      final sent = await _sendCertificateEmail(month: month, year: year);
      if (sent) {
        await _repo.markCertificateEmailSent(month: month, year: year);
      }
    } catch (e, _) {
      _logger.warning('EOM: Certificate email failed: $e', e);
    }

    _logger.info(
      'EOM: Monthly award completed for $year-$month. Winner: $winnerId',
    );
    return {
      'winner': {'employee_id': winnerId, 'total_points': winnerPoints},
      'rankings_count': ranked.length,
    };
  }

  /// Returns paginated employee rankings for the given [month] and [year].
  /// Uses cached monthly rankings when available; otherwise aggregates from daily table.
  Future<Map<String, dynamic>> getEmployeeRankings({
    required int month,
    required int year,
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    final hasCached = await _repo.hasMonthlyRankingsFor(month, year);
    final result = hasCached
        ? await _repo.getRankingsPaginated(
            month: month,
            year: year,
            page: page,
            limit: limit,
            search: search,
          )
        : await _repo.getRankingsFromDailyPaginated(
            month: month,
            year: year,
            page: page,
            limit: limit,
            search: search,
          );

    final winner = await _repo.getWinner(month: month, year: year);
    return {
      'month': month,
      'year': year,
      'rankings': result['data'],
      'pagination': result['pagination'],
      'employee_of_the_month': winner != null
          ? {
              'employee_id': winner['employee_id'],
              'employee_name': winner['employee_name'],
              'employee_img': winner['employee_img'],
              'total_points': _toDouble(winner['total_points']),
              'awarded_at': winner['awarded_at']?.toString(),
            }
          : null,
    };
  }

  /// Returns the full points breakdown for [employeeId] for [month] and [year],
  /// suitable for admin "how did we calculate" view.
  Future<Map<String, dynamic>> getEmployeePointsBreakdown({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    final dailyRows = await _repo.getDailyPointsForEmployeeMonth(
      employeeId: employeeId,
      month: month,
      year: year,
    );

    double totalTaskPoints = 0;
    double totalAttendancePoints = 0;
    int daysOnTime = 0;
    int daysLatePunchIn = 0;
    int daysEarlyPunchOut = 0;
    int daysShortHours = 0;
    int daysLeaveOrPermission = 0;
    int totalCompletedOnTime = 0;
    int totalCompletedLate = 0;
    int totalRedo = 0;

    final dailyBreakdown = <Map<String, dynamic>>[];

    for (final row in dailyRows) {
      final taskPoints = _toDouble(row['task_points']);
      final attPoints = _toDouble(row['attendance_points']);
      totalTaskPoints += taskPoints;
      totalAttendancePoints += attPoints;

      final breakdown = row['breakdown'];
      if (breakdown is Map<String, dynamic>) {
        final task = breakdown['task'] as Map<String, dynamic>?;
        final att = breakdown['attendance'] as Map<String, dynamic>?;
        if (task != null) {
          final onTime = _toDouble(task['completed_on_time_count']).toInt();
          final completed = _toDouble(task['completed_count']).toInt();
          totalCompletedOnTime += onTime;
          totalCompletedLate += (completed - onTime) > 0
              ? completed - onTime
              : 0;
          totalRedo += _toDouble(task['redo_count']).toInt();
        }
        if (att != null) {
          final reason = att['reason']?.toString();
          if (reason == 'on_leave' ||
              reason == 'on_permission' ||
              reason == 'on_wfh' ||
              reason == 'weekend_or_holiday') {
            daysLeaveOrPermission++;
          } else if (att['punch_in_on_time'] == false) {
            daysLatePunchIn++;
          } else if (att['punch_out_on_time'] == false) {
            daysEarlyPunchOut++;
          } else if (att['work_hours_met'] == false) {
            daysShortHours++;
          } else {
            daysOnTime++;
          }
        }
      }

      dailyBreakdown.add({
        'date': row['points_date']?.toString(),
        'task_points': taskPoints,
        'attendance_points': attPoints,
        'total_points': taskPoints + attPoints,
        'breakdown': breakdown,
      });
    }

    final employee = await _getEmployeeBasic(employeeId);

    return {
      'employee_id': employeeId,
      'employee_name': employee['employee_name'],
      'month': month,
      'year': year,
      'total_points': totalTaskPoints + totalAttendancePoints,
      'summary': {
        'task': {
          'total_task_points': totalTaskPoints,
          'completed_on_time_count': totalCompletedOnTime,
          'completed_late_count': totalCompletedLate,
          'redo_count': totalRedo,
          'explanation':
              'Tasks completed on time and late, minus redo deductions.',
        },
        'attendance': {
          'total_attendance_points': totalAttendancePoints,
          'days_on_time': daysOnTime,
          'days_late_punch_in': daysLatePunchIn,
          'days_early_punch_out': daysEarlyPunchOut,
          'days_work_hours_short': daysShortHours,
          'days_leave_or_permission': daysLeaveOrPermission,
          'explanation':
              'Daily attendance: punch in by 9 AM, punch out by 6 PM, 9+ hours. Leave/permission days not scored.',
        },
      },
      'daily_breakdown': dailyBreakdown,
    };
  }

  Future<Map<String, dynamic>> _getEmployeeBasic(String employeeId) async {
    try {
      final emp = await _employeeRepo.getById(employeeId);
      if (emp != null) {
        return {
          'employee_name': emp.employeeName,
          'employee_designation': emp.employeeDesignation,
        };
      }
    } catch (_) {}
    return {'employee_name': employeeId};
  }

  Future<bool> _sendCertificateEmail({
    required int month,
    required int year,
  }) async {
    final winner = await _repo.getWinner(month: month, year: year);
    if (winner == null) return false;
    final email = winner['employee_personal_email']?.toString();
    final name = winner['employee_name']?.toString() ?? 'Employee';
    if (email == null || email.isEmpty) return false;

    final monthName = _monthName(month);
    final html = EmployeeOfTheMonthTemplate.generateCertificateEmail(
      employeeName: name,
      month: monthName,
      year: year.toString(),
      totalPoints: _toDouble(winner['total_points']),
    );

    return await _emailService.sendEmail(
      toEmail: email,
      subject:
          'Congratulations! You are Employee of the Month - $monthName $year',
      htmlContent: html,
    );
  }

  double _num(Map<String, dynamic> m, String key, double fallback) {
    final v = m[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const names = [
      '',
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
    return month >= 1 && month <= 12 ? names[month] : 'Month';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
