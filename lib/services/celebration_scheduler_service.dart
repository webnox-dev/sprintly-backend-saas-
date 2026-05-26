import 'dart:async';
import '../core/utils/logger.dart';
import '../data/database/connection.dart';
import 'unified_notification_service.dart';
import 'employee_of_the_month_service.dart';

/// Celebration and System Scheduler Service
/// Runs daily to check for celebrations and perform EOM calculations.
class CelebrationSchedulerService {
  static final AppLogger _logger = AppLogger('CelebrationSchedulerService');
  static final EmployeeOfTheMonthService _eomService =
      EmployeeOfTheMonthService();
  static Timer? _dailyTimer;
  static bool _isRunning = false;

  /// Start the daily scheduler
  static void startScheduler() {
    if (_isRunning) {
      _logger.info('Scheduler is already running');
      return;
    }

    _isRunning = true;
    _logger.info('Starting system scheduler');

    // Run tasks if not already run today
    _runTasksIfNecessary();

    // Schedule next run (early morning)
    _scheduleNextRun();
  }

  /// Stop the scheduler
  static void stopScheduler() {
    _dailyTimer?.cancel();
    _dailyTimer = null;
    _isRunning = false;
    _logger.info('System scheduler stopped');
  }

  /// Schedule the next daily run (at 12:05 AM)
  static void _scheduleNextRun() {
    final now = DateTime.now();
    // Run at 00:05:00 next day
    var nextRun = DateTime(now.year, now.month, now.day, 0, 5, 0);

    if (now.isAfter(nextRun)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    final duration = nextRun.difference(now);
    _logger.info(
      'Next system heartbeat scheduled for: ${nextRun.toIso8601String()} (in ${duration.inHours}h ${duration.inMinutes % 60}m)',
    );

    _dailyTimer = Timer(duration, () async {
      await _onDailyHeartbeat();
      // Reschedule for next day
      _scheduleNextRun();
    });
  }

  /// Run daily tasks if they haven't been completed yet today
  static Future<void> _runTasksIfNecessary() async {
    final today = DateTime.now();
    final dateStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      final results = await DatabaseConnection.query(
        'SELECT status FROM system_task_logs WHERE task_name = @name AND run_date = @date',
        values: {'name': 'daily_celebrations', 'date': dateStr},
      );

      if (results.isEmpty) {
        _logger.info('Tasks not run today yet, executing now...');
        await _onDailyHeartbeat();
      } else {
        _logger.info('Daily tasks already completed for today ($dateStr)');
      }
    } catch (e) {
      _logger.error('Error checking task status: $e');
      // On error, we fallback to running it to be safe, but this shouldn't happen
      await _onDailyHeartbeat();
    }
  }

  /// Orchestrates daily tasks
  static Future<void> _onDailyHeartbeat() async {
    _logger.info('System heartbeat pulse triggered');
    final today = DateTime.now();
    final dateStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      // 1. Check for Celebrations (Birthdays/Anniversaries)
      await _checkCelebrations();

      // Log success for celebrations
      await _recordTaskCompletion('daily_celebrations', dateStr);

      // 2. Compute EOM Daily Points
      _logger.info('EOM: Running EOD daily points computation...');
      await _eomService.computeDailyPointsForDate(today);

      // 3. If it's the last day of the month, trigger Monthly Award
      final isLastDay =
          today.day == DateTime(today.year, today.month + 1, 0).day;
      if (isLastDay) {
        _logger.info(
          'EOM: Last day of month detected. Running monthly award...',
        );
        await _eomService.runMonthlyAward(month: today.month, year: today.year);
      }
    } catch (e, st) {
      _logger.error('Error during scheduled daily tasks: $e', e, st);
    }
  }

  /// Records that a task was completed today
  static Future<void> _recordTaskCompletion(String name, String date) async {
    try {
      await DatabaseConnection.query(
        '''
        INSERT INTO system_task_logs (task_name, run_date, status)
        VALUES (@name, @date, 'success')
        ON CONFLICT (task_name, run_date) DO UPDATE SET run_at = CURRENT_TIMESTAMP
        ''',
        values: {'name': name, 'date': date},
      );
    } catch (e) {
      _logger.error('Failed to record task completion: $e');
    }
  }

  /// Check for birthdays and work anniversaries today
  static Future<void> _checkCelebrations() async {
    _logger.info('Running daily celebration check');
    try {
      await _checkBirthdays();
      await _checkWorkAnniversaries();
      _logger.info('Daily celebration check completed');
    } catch (e, stackTrace) {
      _logger.error('Error during celebration check: $e', e, stackTrace);
    }
  }

  /// Check for employee and admin birthdays today
  static Future<void> _checkBirthdays() async {
    try {
      final today = DateTime.now();
      final todayDayMonth =
          '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}';

      _logger.info('Checking birthdays for: $todayDayMonth');

      // Check employees with birthdays today (format: DD-MM-YYYY)
      final employees = await DatabaseConnection.query(
        '''
        SELECT employee_id, employee_name, employee_personal_email, employee_dob
        FROM employees 
        WHERE status = 1 
        AND SUBSTRING(employee_dob, 1, 5) = @today_dm
      ''',
        values: {'today_dm': todayDayMonth},
      );

      _logger.info('Found ${employees.length} employees with birthdays today');

      for (final emp in employees) {
        UnifiedNotificationService.notifyBirthday(
          personId: emp['employee_id'] as String,
          personName: emp['employee_name'] as String,
          personEmail: emp['employee_personal_email'] as String? ?? '',
          personType: 'Employee',
        ).catchError((e, st) {
          _logger.warning('Birthday notification failed: $e');
        });
      }

      // Check admins with birthdays today
      final admins = await DatabaseConnection.query(
        '''
        SELECT admin_id, admin_name, admin_personal_email, admin_dob
        FROM admins 
        WHERE status = 1 
        AND SUBSTRING(admin_dob, 1, 5) = @today_dm
      ''',
        values: {'today_dm': todayDayMonth},
      );

      _logger.info('Found ${admins.length} admins with birthdays today');

      for (final admin in admins) {
        UnifiedNotificationService.notifyBirthday(
          personId: admin['admin_id'] as String,
          personName: admin['admin_name'] as String,
          personEmail: admin['admin_personal_email'] as String? ?? '',
          personType: 'Admin',
        ).catchError((e, st) {
          _logger.warning('Birthday notification failed: $e');
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Error checking birthdays: $e', e, stackTrace);
    }
  }

  /// Check for employee and admin work anniversaries today
  static Future<void> _checkWorkAnniversaries() async {
    try {
      final today = DateTime.now();
      final todayDayMonth =
          '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}';

      _logger.info('Checking work anniversaries for: $todayDayMonth');

      // Check employees with work anniversaries today (format: DD-MM-YYYY for employee_doj)
      final employees = await DatabaseConnection.query(
        '''
        SELECT employee_id, employee_name, employee_personal_email, employee_doj
        FROM employees 
        WHERE status = 1 
        AND SUBSTRING(employee_doj, 1, 5) = @today_dm
      ''',
        values: {'today_dm': todayDayMonth},
      );

      _logger.info(
        'Found ${employees.length} employees with work anniversaries today',
      );

      for (final emp in employees) {
        final dojString = emp['employee_doj'] as String?;
        if (dojString == null) continue;

        final yearsCompleted = _calculateYearsFromDDMMYYYY(dojString, today);
        if (yearsCompleted > 0) {
          UnifiedNotificationService.notifyWorkAnniversary(
            personId: emp['employee_id'] as String,
            personName: emp['employee_name'] as String,
            personEmail: emp['employee_personal_email'] as String? ?? '',
            personType: 'Employee',
            yearsCompleted: yearsCompleted,
          ).catchError((e, st) {
            _logger.warning('Work anniversary notification failed: $e');
          });
        }
      }

      // Check admins with work anniversaries today
      final admins = await DatabaseConnection.query(
        '''
        SELECT admin_id, admin_name, admin_personal_email, admin_doj
        FROM admins 
        WHERE status = 1 
        AND SUBSTRING(admin_doj, 1, 5) = @today_dm
      ''',
        values: {'today_dm': todayDayMonth},
      );

      _logger.info(
        'Found ${admins.length} admins with work anniversaries today',
      );

      for (final admin in admins) {
        final dojString = admin['admin_doj'] as String?;
        if (dojString == null) continue;

        final yearsCompleted = _calculateYearsFromDDMMYYYY(dojString, today);
        if (yearsCompleted > 0) {
          UnifiedNotificationService.notifyWorkAnniversary(
            personId: admin['admin_id'] as String,
            personName: admin['admin_name'] as String,
            personEmail: admin['admin_personal_email'] as String? ?? '',
            personType: 'Admin',
            yearsCompleted: yearsCompleted,
          ).catchError((e, st) {
            _logger.warning('Work anniversary notification failed: $e');
          });
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error checking work anniversaries: $e', e, stackTrace);
    }
  }

  /// Calculate years from DD-MM-YYYY format date
  static int _calculateYearsFromDDMMYYYY(String dateStr, DateTime today) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return 0;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final doj = DateTime(year, month, day);

      int years = today.year - doj.year;

      // Adjust if anniversary hasn't occurred yet this year
      if (today.month < doj.month ||
          (today.month == doj.month && today.day < doj.day)) {
        years--;
      }

      return years;
    } catch (e) {
      _logger.error('Error parsing date: $dateStr - $e');
      return 0;
    }
  }

  /// Manually trigger celebration check (for testing or admin use)
  static Future<Map<String, dynamic>> runManualCheck() async {
    _logger.info('Manual celebration check triggered');

    final result = <String, dynamic>{
      'success': true,
      'message': 'Celebration check completed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await _checkCelebrations();
    } catch (e) {
      result['success'] = false;
      result['error'] = e.toString();
    }

    return result;
  }
}
