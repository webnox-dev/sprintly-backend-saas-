import 'dart:async';
import '../core/utils/logger.dart';
import '../data/repositories/calendar_meeting_repository.dart';
import 'unified_notification_service.dart';

/// Meeting Reminder Scheduler Service
/// Runs every 1 minute to check for upcoming meetings
/// and sends reminders at 15m, 10m, 5m, and 2m before meeting start time.
/// Only notifies members of the specific meeting, NOT all employees/admins.
class MeetingReminderService {
  static final AppLogger _logger = AppLogger('MeetingReminderService');
  static final CalendarMeetingRepository _repository =
      CalendarMeetingRepository();
  static Timer? _reminderTimer;
  static bool _isRunning = false;
  static bool _isProcessing = false;

  /// Reminder intervals in minutes
  static const List<int> _reminderIntervals = [15, 10, 5, 2];

  /// Start the reminder scheduler
  static void startScheduler() {
    if (_isRunning) {
      _logger.info('Meeting reminder scheduler is already running');
      return;
    }

    _isRunning = true;
    _logger.info('Starting meeting reminder scheduler (1-minute interval)');

    // Run immediately on startup
    _checkAndSendReminders();

    // Schedule to run every 1 minute
    _reminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndSendReminders(),
    );
  }

  /// Stop the scheduler
  static void stopScheduler() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _isRunning = false;
    _logger.info('Meeting reminder scheduler stopped');
  }

  /// Check for upcoming meetings and send reminders
  static Future<void> _checkAndSendReminders() async {
    if (_isProcessing) return; // Prevent overlapping checks
    _isProcessing = true;

    try {
      final now = DateTime.now();
      final meetings = await _repository.getUpcomingMeetingsForReminders();

      if (meetings.isEmpty) {
        _isProcessing = false;
        return;
      }

      _logger.info(
        'Checking ${meetings.length} upcoming meetings for reminders',
      );

      for (final meeting in meetings) {
        try {
          // Parse meeting start time
          final startTimeParts = meeting.meetingStartTime.split(':');
          if (startTimeParts.length < 2) continue;

          final meetingStartHour = int.parse(startTimeParts[0]);
          final meetingStartMinute = int.parse(startTimeParts[1]);

          // Create full DateTime for meeting start
          final meetingDate = DateTime.tryParse(meeting.meetingDate);
          if (meetingDate == null) continue;

          final meetingStartDateTime = DateTime(
            meetingDate.year,
            meetingDate.month,
            meetingDate.day,
            meetingStartHour,
            meetingStartMinute,
          );

          // Calculate minutes until meeting
          final minutesUntilMeeting = meetingStartDateTime
              .difference(now)
              .inMinutes;

          // Check each reminder interval
          for (final interval in _reminderIntervals) {
            final reminderKey = '${interval}min';
            final alreadySent = meeting.remindersSent[reminderKey] == true;

            if (alreadySent) continue;

            // Send reminder if within the window (±1 minute tolerance)
            if (minutesUntilMeeting <= interval &&
                minutesUntilMeeting >= (interval - 1) &&
                minutesUntilMeeting > 0) {
              _logger.info(
                'Sending ${interval}min reminder for "${meeting.meetingName}" '
                '(starts in $minutesUntilMeeting min)',
              );

              // Send reminder to meeting members ONLY (not all users)
              await UnifiedNotificationService.notifyMeetingReminder(
                meetingId: meeting.meetingId ?? '',
                meetingName: meeting.meetingName,
                hostName: meeting.hostName ?? '',
                venue: meeting.meetingVenue,
                meetingDate: meeting.meetingDate,
                startTime: meeting.meetingStartTime,
                endTime: meeting.meetingEndTime,
                reminderMinutes: interval.toString(),
                gmeetLink: meeting.gmeetLink,
                participants: meeting.meetingMembers,
                declinedMembers: meeting.meetingDeclinedMembers,
              );

              // Mark reminder as sent
              await _repository.updateReminderStatus(
                meeting.meetingId!,
                reminderKey,
              );

              _logger.info(
                '✅ ${interval}min reminder sent for "${meeting.meetingName}"',
              );
            }
          }

          // Auto-complete meetings that have already ended
          final meetingEndParts = meeting.meetingEndTime.split(':');
          if (meetingEndParts.length >= 2) {
            final meetingEndDateTime = DateTime(
              meetingDate.year,
              meetingDate.month,
              meetingDate.day,
              int.parse(meetingEndParts[0]),
              int.parse(meetingEndParts[1]),
            );

            if (now.isAfter(meetingEndDateTime) &&
                meeting.meetingStatus == 'scheduled') {
              _logger.info(
                'Auto-completing meeting "${meeting.meetingName}" (ended)',
              );
              await _repository.completeMeeting(meeting.meetingId!);
            }
          }
        } catch (e, st) {
          _logger.error(
            'Error processing reminders for meeting ${meeting.meetingId}: $e',
            e,
            st,
          );
        }
      }
    } catch (e, st) {
      _logger.error('Error in reminder check cycle: $e', e, st);
    } finally {
      _isProcessing = false;
    }
  }

  /// Manually trigger a reminder check (for testing or admin use)
  static Future<Map<String, dynamic>> runManualCheck() async {
    _logger.info('Manual meeting reminder check triggered');

    final result = <String, dynamic>{
      'success': true,
      'message': 'Meeting reminder check completed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await _checkAndSendReminders();
    } catch (e) {
      result['success'] = false;
      result['error'] = e.toString();
    }

    return result;
  }
}
