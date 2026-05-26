/// Employee of the Month certificate email template.
/// Used when sending the virtual certificate to the monthly winner.
class EmployeeOfTheMonthTemplate {
  /// Generates HTML email body for EOM certificate notification.
  static String generateCertificateEmail({
    required String employeeName,
    required String month,
    required String year,
    required double totalPoints,
  }) {
    final pointsStr = totalPoints.toStringAsFixed(1);
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Employee of the Month - $month $year</title>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0; padding:0; font-family:'Poppins', Arial, sans-serif; background:#eef1f5;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#eef1f5; padding:30px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background:#ffffff; border-radius:18px; overflow:hidden; box-shadow:0 15px 45px rgba(0,0,0,0.12);">
          <tr>
            <td style="background:#c2185b; padding:18px 25px; text-align:center;">
              <p style="margin:0; font-size:14px; letter-spacing:1px; color:#ffffff; font-weight:600;">WEBNOX SPRINTLY</p>
            </td>
          </tr>
          <tr>
            <td style="background:linear-gradient(135deg,#c2185b 0%,#e91e63 100%); padding:35px 25px; text-align:center;">
              <div style="font-size:48px;">🏆</div>
              <h1 style="color:#ffffff; margin:10px 0 0 0; font-size:26px; font-weight:700;">Employee of the Month</h1>
              <p style="color:rgba(255,255,255,0.95); margin:8px 0 0 0; font-size:16px;">$month $year</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 30px; text-align:center;">
              <p style="color:#333; font-size:20px; margin:0 0 10px 0;">Congratulations,</p>
              <p style="color:#c2185b; font-size:28px; font-weight:700; margin:0 0 20px 0;">$employeeName</p>
              <p style="color:#555; font-size:16px; line-height:1.8; margin:20px 0;">
                You have been selected as <strong>Employee of the Month</strong> for <strong>$month $year</strong> based on your outstanding performance, attendance, and task completion.
              </p>
              <div style="background:linear-gradient(135deg,#fce4ec 0%,#f8bbd0 100%); border-radius:15px; padding:24px; margin:25px 0; border:2px dashed #c2185b;">
                <p style="color:#880e4f; font-size:18px; font-weight:600; margin:0;">Total Points: $pointsStr</p>
                <p style="color:#880e4f; font-size:14px; margin:8px 0 0 0;">Keep up the excellent work!</p>
              </div>
              <p style="color:#555; font-size:15px; line-height:1.7; margin:20px 0;">
                This virtual certificate recognizes your dedication, punctuality, and quality of work. Thank you for being an integral part of our team.
              </p>
              <p style="color:#555; font-size:14px; margin:30px 0 0 0;">
                — Webnox Sprintly Team
              </p>
            </td>
          </tr>
          <tr>
            <td style="background:#f5f5f5; padding:20px 25px; text-align:center;">
              <p style="margin:0; font-size:12px; color:#888;">This is an automated message. Please do not reply.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
