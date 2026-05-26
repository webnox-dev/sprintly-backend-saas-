import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  print('Starting email test...');

  const String smtpEmail = 'mdmwebnox@gmail.com';
  const String smtpPassword = 'yhzbnysojeragltl';

  final smtpServer = gmail(smtpEmail, smtpPassword);

  final message = Message()
    ..from = Address(smtpEmail, 'Test Sender')
    ..recipients.add(smtpEmail) // Send to self
    ..subject = 'Test Email - ${DateTime.now()}'
    ..text = 'This is a test email to verify SMTP settings.';

  try {
    print('Sending email to $smtpEmail...');
    final sendReport = await send(message, smtpServer);
    print('Email sent successfully!');
    print('Report: $sendReport');
  } catch (e) {
    print('Failed to send email.');
    print('Error: $e');
  }
}
