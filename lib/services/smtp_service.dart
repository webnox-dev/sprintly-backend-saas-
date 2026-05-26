import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../core/utils/logger.dart';

/// Single Responsibility: Handle SMTP Email Sending
class SmtpService {
  final AppLogger logger = AppLogger('SmtpService');

  // SMTP Configuration
  static const String _smtpEmail = 'mdmwebnox@gmail.com';
  static const String _smtpPassword = 'yhzbnysojeragltl';

  /// Send email via SMTP
  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String htmlContent,
    List<String>? ccEmails,
    List<String>? attachments,
  }) async {
    try {
      // Create the SMTP server
      final smtpServer = gmail(_smtpEmail, _smtpPassword);

      // Create the message
      final message = Message()
        ..from = Address(_smtpEmail, 'Webnox Sprintly Admin')
        ..recipients.add(toEmail)
        ..subject = subject
        ..html = htmlContent;

      if (ccEmails != null && ccEmails.isNotEmpty) {
        message.ccRecipients.addAll(ccEmails);
      }

      logger.info(
        '----------------------------------------------------------------',
      );
      logger.info('🚀 INITIATING EMAIL SEND VIA SMTP');
      logger.info('📨 To: $toEmail');
      if (ccEmails != null && ccEmails.isNotEmpty) {
        logger.info('👥 CC: $ccEmails');
      }
      logger.info('📝 Subject: $subject');
      logger.info('📄 Content Length: ${htmlContent.length} chars');
      logger.info(
        '----------------------------------------------------------------',
      );

      final sendReport = await send(message, smtpServer);

      logger.info('✅ EMAIL SENT SUCCESSFULLY');
      logger.info('📧 Sent Details: ${sendReport.toString()}');
      logger.info(
        '----------------------------------------------------------------',
      );
      return true;
    } catch (e, stackTrace) {
      logger.error('❌ FAILED TO SEND EMAIL');
      logger.error('Error: $e', e, stackTrace);
      logger.info(
        '----------------------------------------------------------------',
      );
      return false;
    }
  }
}
