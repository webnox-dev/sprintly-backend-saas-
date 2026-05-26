/// Email templates for Calendar Meeting notifications
class CalendarMeetingEmailTemplate {
  /// Generate meeting invitation email
  static String generateMeetingInvitationEmail({
    required String participantName,
    required String meetingName,
    required String meetingDescription,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    String? gmeetLink,
  }) {
    final meetLinkSection = gmeetLink != null && gmeetLink.isNotEmpty
        ? '''
            <div style="text-align:center; margin:28px 0;">
                <a href="$gmeetLink" style="display:inline-block; padding:14px 36px; background:linear-gradient(135deg,#1a73e8 0%,#4285f4 100%); color:#ffffff; text-decoration:none; border-radius:10px; font-size:16px; font-weight:600; box-shadow:0 4px 14px rgba(66,133,244,0.35);">
                    🔗 Join Google Meet
                </a>
                <p style="font-size:12px; color:#999; margin-top:10px;">$gmeetLink</p>
            </div>
          '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meeting Invitation</title>
</head>

<body style="margin:0; padding:0; background:#667eea; background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); padding:45px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">📅</div>
            <h1 style="color:#ffffff; margin:0; font-size:26px; font-weight:600;">Meeting Invitation</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:15px;">You've been invited to a meeting</p>
        </div>

        <!-- Content -->
        <div style="padding:40px 32px;">

            <p style="font-size:18px; margin:0 0 20px; color:#333;">
                Hello <strong style="color:#667eea;">$participantName</strong>,
            </p>

            <p style="font-size:16px; line-height:1.7; color:#555; margin:0 0 28px;">
                <strong>$hostName</strong> has scheduled a meeting and invited you to attend.
            </p>

            <!-- Meeting Details Box -->
            <div style="background:linear-gradient(135deg,#f5f7fa 0%,#e8ecf3 100%); border-radius:14px; padding:24px; margin:28px 0; border-left:4px solid #667eea;">
                <h3 style="margin:0 0 18px; font-size:16px; color:#333;">📋 Meeting Details</h3>
                <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Meeting:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$meetingName</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Date:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$meetingDate</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Time:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$startTime - $endTime</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Venue:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$venue</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Host:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$hostName</td>
                    </tr>
                </table>
            </div>

            ${meetingDescription.isNotEmpty ? '''
            <!-- Description -->
            <div style="background:#f8f9ff; border-radius:10px; padding:18px; margin:16px 0;">
                <p style="font-size:13px; color:#666; margin:0 0 6px;"><strong>Agenda:</strong></p>
                <p style="font-size:14px; color:#444; margin:0; line-height:1.6;">$meetingDescription</p>
            </div>
            ''' : ''}

            $meetLinkSection

            <!-- Action Notice -->
            <div style="background:linear-gradient(135deg,#e8f5e9 0%,#c8e6c9 100%); border-radius:14px; padding:22px; margin:24px 0; border-left:4px solid #4caf50;">
                <p style="color:#2e7d32; font-size:14px; margin:0;">
                    ✅ Please confirm your attendance in the Sprintly App.
                </p>
            </div>

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:26px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0 0 8px;">
                This email was sent by Webnox Sprintly Admin System.
            </p>
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

    <div style="text-align:center; margin-top:22px; color:rgba(255,255,255,0.75); font-size:11px;">
        A Product by Mobile App Team
    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate meeting reminder email
  static String generateMeetingReminderEmail({
    required String participantName,
    required String meetingName,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    required String reminderMinutes,
    String? gmeetLink,
  }) {
    final meetLinkButton = gmeetLink != null && gmeetLink.isNotEmpty
        ? '''
            <div style="text-align:center; margin:24px 0 16px;">
                <a href="$gmeetLink" style="display:inline-block; padding:14px 36px; background:linear-gradient(135deg,#1a73e8 0%,#4285f4 100%); color:#ffffff; text-decoration:none; border-radius:10px; font-size:16px; font-weight:600; box-shadow:0 4px 14px rgba(66,133,244,0.35);">
                    🔗 Join Google Meet Now
                </a>
            </div>
          '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meeting Reminder</title>
</head>

<body style="margin:0; padding:0; background:#ff6b6b; background:linear-gradient(135deg,#ff6b6b 0%,#ee5a24 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#ff6b6b 0%,#ee5a24 100%); padding:40px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">⏰</div>
            <h1 style="color:#ffffff; margin:0; font-size:24px; font-weight:600;">Meeting in $reminderMinutes Minutes!</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:15px;">$meetingName</p>
        </div>

        <!-- Content -->
        <div style="padding:36px 32px;">

            <p style="font-size:16px; margin:0 0 24px; color:#333;">
                Hi <strong style="color:#ee5a24;">$participantName</strong>, your meeting is about to start!
            </p>

            <div style="background:linear-gradient(135deg,#fff3e0 0%,#ffe0b2 100%); border-radius:14px; padding:24px; margin:20px 0; border-left:4px solid #ff9800;">
                <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="color:#666; padding:8px 0; font-size:14px;">Meeting:</td>
                        <td style="color:#333; padding:8px 0; font-size:14px; font-weight:600; text-align:right;">$meetingName</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:8px 0; font-size:14px;">Time:</td>
                        <td style="color:#333; padding:8px 0; font-size:14px; font-weight:600; text-align:right;">$startTime - $endTime</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:8px 0; font-size:14px;">Venue:</td>
                        <td style="color:#333; padding:8px 0; font-size:14px; font-weight:600; text-align:right;">$venue</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:8px 0; font-size:14px;">Host:</td>
                        <td style="color:#333; padding:8px 0; font-size:14px; font-weight:600; text-align:right;">$hostName</td>
                    </tr>
                </table>
            </div>

            $meetLinkButton

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:22px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate meeting postponed email
  static String generateMeetingPostponedEmail({
    required String participantName,
    required String meetingName,
    required String hostName,
    required String oldDate,
    required String oldStartTime,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    required String reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meeting Postponed</title>
</head>

<body style="margin:0; padding:0; background:#fbbc04; background:linear-gradient(135deg,#fbbc04 0%,#f57f17 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#fbbc04 0%,#f57f17 100%); padding:40px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">🗓️</div>
            <h1 style="color:#ffffff; margin:0; font-size:24px; font-weight:600;">Meeting Postponed</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:15px;">$meetingName has been rescheduled</p>
        </div>

        <!-- Content -->
        <div style="padding:36px 32px;">

            <p style="font-size:16px; margin:0 0 24px; color:#333;">
                Hi <strong style="color:#f57f17;">$participantName</strong>,
            </p>
            
            <p style="font-size:16px; line-height:1.6; color:#555; margin:0 0 24px;">
                The meeting <strong>$meetingName</strong> hosted by <strong>$hostName</strong> has been postponed.
            </p>

            <!-- Reason Box -->
            <div style="background:#fff3e0; border-radius:10px; padding:18px; margin:0 0 24px;">
                <p style="font-size:13px; color:#ef6c00; margin:0 0 6px;"><strong>Reason for Postponement:</strong></p>
                <p style="font-size:15px; color:#e65100; margin:0; font-weight:500;">$reason</p>
            </div>

            <!-- Comparison Box -->
            <div style="display:flex; margin-bottom:24px;">
                <div style="flex:1; background:#f5f5f5; border-radius:10px; padding:15px; margin-right:10px;">
                    <p style="font-size:12px; color:#999; margin:0 0 4px; text-transform:uppercase;">Previous Time</p>
                    <p style="font-size:14px; color:#666; margin:0 0 4px; text-decoration:line-through;">$oldDate</p>
                    <p style="font-size:14px; color:#666; margin:0; text-decoration:line-through;">$oldStartTime</p>
                </div>
                <div style="flex:1; background:#e8f5e9; border-radius:10px; padding:15px; margin-left:10px; border:1px solid #4caf50;">
                    <p style="font-size:12px; color:#2e7d32; margin:0 0 4px; text-transform:uppercase; font-weight:bold;">New Time</p>
                    <p style="font-size:14px; color:#1b5e20; margin:0 0 4px; font-weight:600;">$newDate</p>
                    <p style="font-size:14px; color:#1b5e20; margin:0; font-weight:600;">$newStartTime - $newEndTime</p>
                </div>
            </div>

            <p style="font-size:14px; color:#666; margin:0; text-align:center;">
                Please update your calendar accordingly.
            </p>

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:22px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate invitation subject
  static String generateInvitationSubject(String meetingName) {
    return '📅 Meeting Invitation: $meetingName - Webnox Sprintly';
  }

  /// Generate reminder subject
  static String generateReminderSubject(
    String meetingName,
    String minutesBefore,
  ) {
    return '⏰ Reminder: $meetingName starts in $minutesBefore minutes!';
  }

  /// Generate postponed subject
  static String generatePostponedSubject(String meetingName) {
    return '📅 Meeting Postponed: $meetingName - Webnox Sprintly';
  }

  /// Generate meeting cancelled email
  static String generateMeetingCancelledEmail({
    required String participantName,
    required String meetingName,
    required String hostName,
    required String meetingDate,
    required String startTime,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meeting Cancelled</title>
</head>

<body style="margin:0; padding:0; background:#e53935; background:linear-gradient(135deg,#e53935 0%,#b71c1c 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#e53935 0%,#b71c1c 100%); padding:40px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">🚫</div>
            <h1 style="color:#ffffff; margin:0; font-size:24px; font-weight:600;">Meeting Cancelled</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:15px;">$meetingName has been cancelled</p>
        </div>

        <!-- Content -->
        <div style="padding:36px 32px;">

            <p style="font-size:16px; margin:0 0 24px; color:#333;">
                Hi <strong style="color:#b71c1c;">$participantName</strong>,
            </p>
            
            <p style="font-size:16px; line-height:1.6; color:#555; margin:0 0 24px;">
                The meeting <strong>$meetingName</strong> scheduled for <strong>$meetingDate at $startTime</strong> has been cancelled by <strong>$hostName</strong>.
            </p>

            <div style="background:#ffebee; border-radius:10px; padding:18px; margin:0 0 24px; border-left:4px solid #f44336;">
                <p style="font-size:14px; color:#c62828; margin:0;">
                    This meeting has been removed from your calendar. You don't need to take any further action.
                </p>
            </div>

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:22px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate meeting updated email
  static String generateMeetingUpdatedEmail({
    required String participantName,
    required String meetingName,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    String? gmeetLink,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meeting Updated</title>
</head>

<body style="margin:0; padding:0; background:#2196f3; background:linear-gradient(135deg,#2196f3 0%,#0d47a1 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#2196f3 0%,#0d47a1 100%); padding:40px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">📝</div>
            <h1 style="color:#ffffff; margin:0; font-size:24px; font-weight:600;">Meeting Updated</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:15px;">Details for $meetingName have changed</p>
        </div>

        <!-- Content -->
        <div style="padding:36px 32px;">

            <p style="font-size:16px; margin:0 0 24px; color:#333;">
                Hi <strong style="color:#0d47a1;">$participantName</strong>,
            </p>
            
            <p style="font-size:16px; line-height:1.6; color:#555; margin:0 0 24px;">
                The details for meeting <strong>$meetingName</strong> have been updated by <strong>$hostName</strong>.
            </p>

            <div style="background:#e3f2fd; border-radius:14px; padding:24px; margin:20px 0; border-left:4px solid #2196f3;">
                <h3 style="margin:0 0 18px; font-size:16px; color:#333;">📋 New Details</h3>
                <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Date:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$meetingDate</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Time:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$startTime - $endTime</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Venue:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$venue</td>
                    </tr>
                </table>
            </div>

            ${gmeetLink != null && gmeetLink.isNotEmpty ? '''
            <div style="text-align:center; margin-top:24px;">
                <a href="$gmeetLink" style="display:inline-block; padding:12px 30px; background:#2196f3; color:#ffffff; text-decoration:none; border-radius:8px; font-weight:600;">Join Meeting</a>
            </div>
            ''' : ''}

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:22px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate cancelled subject
  static String generateCancelledSubject(String meetingName) {
    return '🚫 Meeting Cancelled: $meetingName - Webnox Sprintly';
  }

  /// Generate updated subject
  static String generateUpdatedSubject(String meetingName) {
    return '📝 Meeting Updated: $meetingName - Webnox Sprintly';
  }
}
