import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Repository for tracking daily status notifications
class StatusNotificationRepository {
  final AppLogger _logger = AppLogger('StatusNotificationRepository');

  /// Check if the daily notification email has been sent for a specific date
  Future<bool> isEmailSentForDate(String date) async {
    try {
      final sql = 'SELECT is_email_sent FROM daily_status_notifications WHERE notification_date = @date';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'date': date},
      );

      if (result != null) {
        return (result['is_email_sent'] as bool? ?? false);
      }
      return false;
    } catch (e) {
      _logger.error('Error checking if email sent for date: $e');
      return false;
    }
  }

  /// Mark the daily notification email as sent for a specific date
  Future<void> markEmailAsSent(String date) async {
    try {
      final sql = '''
        INSERT INTO daily_status_notifications (notification_date, is_email_sent, sent_at)
        VALUES (@date, true, CURRENT_TIMESTAMP)
        ON CONFLICT (notification_date) 
        DO UPDATE SET is_email_sent = true, sent_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      ''';
      
      await DatabaseConnection.execute(
        sql,
        values: {'date': date},
      );
      _logger.info('Marked daily status email as sent for $date');
    } catch (e) {
      _logger.error('Error marking email as sent for date: $e');
    }
  }
}
