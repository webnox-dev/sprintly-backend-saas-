import 'dart:async';
import '../core/utils/logger.dart';
import '../data/database/connection.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/status_notification_repository.dart';
import 'email_service.dart';
import 'email_templates/attendance_template.dart';

/// Service for monitoring and notifying about 'No Status Today' employees
/// Runs at 10:30 AM every day to check for employees who:
/// 1. Haven't punched in
/// 2. Don't have any approved/pending requests (Leave, Permission, WFH)
class AttendanceNotificationService {
  static final AppLogger _logger = AppLogger('AttendanceNotificationService');
  static final EmployeeRepository _employeeRepo = EmployeeRepository();
  static final StatusNotificationRepository _notificationRepo =
      StatusNotificationRepository();
  static final EmailService _emailService = EmailService();
  static Timer? _checkTimer;
  static bool _isRunning = false;
  static bool _isProcessing = false;

  /// Start the monitoring scheduler
  static void startScheduler() {
    if (_isRunning) {
      _logger.info('Attendance notification service is already running');
      return;
    }

    _isRunning = true;
    _logger.info('Starting attendance notification service (5-minute interval)');

    // Run check immediately on startup (it's safe as it checks the 10:30 condition)
    _checkAndTriggerNotification();

    // Schedule to run every 5 minutes
    _checkTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkAndTriggerNotification(),
    );
  }

  /// Stop the scheduler
  static void stopScheduler() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    _logger.info('Attendance notification service stopped');
  }

  /// Check conditions and trigger notification if necessary
  static Future<void> _checkAndTriggerNotification() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now();
      
      // Only run after 10:30 AM
      if (now.hour < 10 || (now.hour == 10 && now.minute < 30)) {
        _isProcessing = false;
        return;
      }

      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Check if already sent for today
      final alreadySent = await _notificationRepo.isEmailSentForDate(dateStr);
      if (alreadySent) {
        _isProcessing = false;
        return;
      }

      _logger.info('Triggering "No Status Today" check for $dateStr');

      // Fetch employees with no status
      final noStatusEmployees = await _employeeRepo.getNoStatusEmployees(dateStr);

      if (noStatusEmployees.isEmpty) {
        _logger.info('No employees found with "No Status" for today. Skipping email.');
        // Still mark as sent so we don't keep checking (or we can just skip marking if we want to re-check)
        // Better to mark as sent so it runs only once.
        await _notificationRepo.markEmailAsSent(dateStr);
        _isProcessing = false;
        return;
      }

      _logger.info('Found ${noStatusEmployees.length} employees with "No Status". Sending email to admins.');

      // Get all active admins
      final adminResults = await DatabaseConnection.query(
        'SELECT admin_name, admin_personal_email FROM admins WHERE status = 1',
      );

      if (adminResults.isEmpty) {
        _logger.warning('No active admins found to receive notification.');
        _isProcessing = false;
        return;
      }

      // Generate email content
      final htmlContent = AttendanceEmailTemplate.generateNoStatusNoticeEmail(
        employees: noStatusEmployees,
        date: dateStr,
      );

      // Send email to all admins
      for (final adminRow in adminResults) {
        final adminEmail = adminRow['admin_personal_email'] as String?;
        if (adminEmail == null || adminEmail.isEmpty) continue;

        await _emailService.sendEmail(
          toEmail: adminEmail,
          subject: '⚠️ Alert: No Status Today - ${noStatusEmployees.length} Employees identified',
          htmlContent: htmlContent,
        );
      }

      // Mark as sent for today
      await _notificationRepo.markEmailAsSent(dateStr);
      _logger.info('Daily "No Status Today" notification triggered successfully.');
      
    } catch (e, st) {
      _logger.error('Error in attendance notification cycle: $e', e, st);
    } finally {
      _isProcessing = false;
    }
  }

  /// Manually trigger a check (for testing or admin use)
  static Future<Map<String, dynamic>> runManualCheck() async {
    _logger.info('Manual "No Status Today" check triggered');

    final result = <String, dynamic>{
      'success': true,
      'message': 'Attendance alert check completed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Temporarily bypass the 10:30 AM check for manual trigger if needed?
      // For now, let's just run the internal method.
      await _checkAndTriggerNotification();
    } catch (e) {
      result['success'] = false;
      result['error'] = e.toString();
    }

    return result;
  }
}
