/// Celebration Email Templates
/// Handles: Birthday Wishes, Work Anniversary
class CelebrationEmailTemplate {
  /// Generate birthday wishes email
  static String generateBirthdayEmail({
    String? recipientName,
    String? employeeName,
    String? birthDate,
    String? designation,
    String? department,
    bool isSelf = false,
  }) {
    final name = recipientName ?? employeeName ?? 'Team Member';
    return '''
<!DOCTYPE html>

<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Happy Birthday!</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
</head>

<body style="margin:0; padding:0; font-family:'Poppins', Arial, sans-serif; background:#eef1f5;">

<!-- Email Wrapper -->

<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#eef1f5; padding:30px 0; font-family:'Poppins', Arial, sans-serif;">
<tr>
<td align="center">

<table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background:#ffffff; border-radius:18px; overflow:hidden; box-shadow:0 15px 45px rgba(0,0,0,0.12);">

<!-- 🔷 EMAIL HEADER (Brand Bar) -->

<tr>
<td style="background:#c2185b; padding:18px 25px; text-align:center;">
<p style="margin:0; font-size:14px; letter-spacing:1px; color:#ffffff; font-weight:600;">
WEBNOX TECHNOLOGIES
</p>
</td>
</tr>

<!-- 🎂 HERO HEADER -->

<tr>
<td style="background:linear-gradient(135deg,#c2185b 0%,#e91e63 100%); padding:45px 25px; text-align:center;">
<div style="font-size:56px;">🎂</div>
<h1 style="color:#ffffff; margin:10px 0 0 0; font-size:30px; font-weight:700;">
Happy Birthday!
</h1>
</td>
</tr>

<!-- CONTENT -->

<tr>
<td style="padding:40px 30px; text-align:center;">

<p style="color:#333; font-size:20px; margin:0 0 10px 0;">
Dear <strong style="color:#c2185b;">$name</strong>,
</p>

<p style="color:#555; font-size:16px; line-height:1.8; margin:20px 0;">
Today we celebrate more than just your birthday — we celebrate your journey, your growth, and the positivity you bring to everyone around you.
</p>

<div style="background:linear-gradient(135deg,#fce4ec 0%,#f8bbd0 100%); border-radius:15px; padding:28px; margin:25px 0; border:2px dashed #c2185b;">
<p style="color:#880e4f; font-size:17px; font-weight:500; margin:0; line-height:1.7;">
May this year open doors to <strong>new opportunities</strong>, inspire bold dreams, and reward your hard work with success. Keep believing in yourself — you are capable of amazing things.
</p>
</div>

<p style="color:#555; font-size:16px; line-height:1.8; margin:20px 0;">
Your dedication and professionalism truly make a difference. The effort you put in every day does not go unnoticed, and we’re grateful to have you on the team.
</p>

<p style="color:#555; font-size:15px; line-height:1.7; margin:25px 0;">
May your day be filled with joy, appreciation, and special moments. Here’s to a year ahead full of achievements, good health, and happiness.
</p>

<div style="margin-top:30px; padding-top:20px; border-top:1px solid #eee;">
<p style="color:#c2185b; font-size:16px; font-weight:600; margin:0;">Best Wishes,</p>
<p style="color:#666; font-size:14px; margin:5px 0 0 0;">Webnox Technologies Family</p>
</div>

</td>
</tr>

<!-- 🔻 EMAIL FOOTER -->

<tr>
<td style="background:#f8f9fa; padding:25px; text-align:center; border-top:1px solid #e9ecef;">
<p style="margin:5px 0; font-size:13px; color:#777;">
This is an automated greeting from Webnox Technologies.
</p>
<p style="margin:5px 0; font-size:12px; color:#999;">
© 2026 Webnox Technologies Pvt Ltd<br>
                A Product by Mobile App Team
</p>
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

  /// Generate work anniversary email
  static String generateWorkAnniversaryEmail({
    String? recipientName,
    String? employeeName,
    required int yearsCompleted,
    String? joiningDate,
    String? designation,
    String? department,
    bool isSelf = false,
  }) {
    final name = recipientName ?? employeeName ?? 'Team Member';
    final yearText = yearsCompleted == 1 ? 'year' : 'years';
    final ordinalYear = _getOrdinal(yearsCompleted);

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Happy Work Anniversary</title>

<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />

<style>
body {
    margin: 0;
    background: #eef1f5;
    padding: 30px 0;
    font-family: 'Poppins', Arial, sans-serif;
    color: #2b2d33;
}
.email-wrapper {
    max-width: 680px;
    margin: 0 auto;
    background: #ffffff;
    border-radius: 14px;
    overflow: hidden;
    box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08);
}
.header {
    background: linear-gradient(135deg, #003d80, #0073d4);
    padding: 35px 40px;
}
.header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 600;
    color: #ffffff;
}
.content {
    padding: 40px;
}
.greeting {
    font-size: 17px;
    font-weight: 500;
    margin-bottom: 10px;
    color: #222;
}
.sub-info {
    font-size: 14px;
    color: #5c6068;
    margin-bottom: 18px;
    line-height: 1.6;
}
p {
    font-size: 15px;
    line-height: 1.7;
    margin: 0 0 16px 0;
    color: #4a4e57;
}
.anniversary-highlight {
    margin: 25px 0;
    background: linear-gradient(135deg, #fff8e1, #ffecb3);
    border: 1px solid #ffe082;
    padding: 25px;
    border-radius: 12px;
    text-align: center;
}
.year-number {
    font-size: 44px;
    font-weight: 700;
    color: #f9a825;
}
.year-text {
    font-size: 16px;
    font-weight: 600;
    color: #ff8f00;
    text-transform: uppercase;
}
.info-box {
    background: #f8f9fc;
    padding: 20px;
    border-radius: 12px;
    border: 1px solid #e5e8ef;
    margin: 20px 0;
}
.motivation-box {
    background: #e8f5e9;
    border-left: 4px solid #2e7d32;
    padding: 20px;
    border-radius: 10px;
    margin: 25px 0;
    color: #2e7d32;
}
.value-box {
    background: #e3f2fd;
    border: 1px solid #bbdefb;
    padding: 20px;
    border-radius: 10px;
    margin: 25px 0;
}
.quote-box {
    background: #f3e5f5;
    border-left: 4px solid #8e24aa;
    padding: 18px;
    border-radius: 10px;
    margin: 25px 0;
    font-style: italic;
    color: #6a1b9a;
}
.footer {
    margin-top: 40px;
    text-align: center;
    padding: 24px 35px;
    background: #f0f2f6;
    border-top: 1px solid #e4e7ed;
}
.footer p {
    margin: 5px 0;
    font-size: 13px;
    color: #7a7e87;
}
.watermark {
    margin-top: 12px;
    font-size: 12px;
    color: #9aa0a9;
}
</style>
</head>

<body>
<div class="email-wrapper">

<div class="header">
    <h1>🏆 Work Anniversary Celebration</h1>
</div>

<div class="content">

    <div class="greeting">
        Dear <strong>$name</strong>,
    </div>

    <p>
    Today marks a meaningful milestone in your professional journey with Webnox Technologies.
    Your continued dedication, hard work, and commitment are deeply valued and truly appreciated.
    The passion and responsibility you bring to your role inspire those around you and strengthen our team every day.
    Keep striving for excellence, embracing challenges, and believing in your abilities — your growth and success story are only getting better with time.
</p>


    <div class="anniversary-highlight">
        <div class="year-number">$yearsCompleted</div>
        <div class="year-text">Years of Excellence</div>
    </div>

    ${joiningDate != null ? '''
    <div class="info-box">
        <p><strong>Joined On:</strong> \$joiningDate</p>
        ${designation != null ? '<p><strong>Designation:</strong> \$designation</p>' : ''}
        ${department != null ? '<p><strong>Department:</strong> \$department</p>' : ''}
    </div>
    ''' : ''}

    <div class="motivation-box">
        Your dedication, consistency, and positive attitude have made a real difference.
        You are a valuable part of our success story.
    </div>

    <div class="value-box">
        Through your efforts, we have grown stronger as a team and as an organization.
        Your contribution continues to shape our future.
    </div>

    <div class="quote-box">
        “Success is built on dedication, teamwork, and perseverance — qualities you demonstrate every day.”
    </div>

    <p>
        We are proud to have you in the Webnox family and look forward to celebrating many more achievements together.
        Keep shining and inspiring! 🚀
    </p>

    <p style="margin-top:25px;">
        <strong>With Appreciation,</strong><br>
        Webnox Technologies Family
    </p>

</div>

<div class="footer">
    <p>This is an automated message from Webnox Technologies.</p>
    <div class="watermark">
        © Webnox Technologies Pvt Ltd<br>
        A Product by Mobile App Team
    </div>
</div>

</div>
</body>
</html>
    ''';
  }

  /// Get ordinal suffix for number
  static String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Generate subject lines
  static String generateBirthdaySubject(String employeeName) {
    return 'Happy Birthday, $employeeName! - Webnox Technologies';
  }

  static String generateAnniversarySubject(String employeeName, int years) {
    return 'Happy ${_getOrdinal(years)} Work Anniversary, $employeeName!';
  }

  /// Generate birthday notification email (for admins about someone's birthday)
  static String generateBirthdayNotificationEmail({
    required String recipientName,
    required String birthdayPersonName,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Birthday Reminder</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Poppins', sans-serif; background: #f4f7f6;">
    <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
        <div style="background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05);">
            <div style="background: linear-gradient(135deg, #c2185b 0%, #e91e63 100%); padding: 30px 40px; text-align: center;">
                <h1 style="color: #fff; margin: 0; font-size: 24px;">🎂 Birthday Today!</h1>
            </div>
            <div style="padding: 40px;">
                <p>Hello $recipientName,</p>
                <p>Today is <strong>$birthdayPersonName</strong>'s birthday!</p>
                <div style="background: #fce4ec; border-radius: 12px; padding: 20px; margin: 20px 0; text-align: center;">
                    <p style="color: #c2185b; font-size: 18px; font-weight: 600; margin: 0;">
                        Don't forget to wish them a happy birthday! 🎉
                    </p>
                </div>
                <p>Send them your best wishes and make their day special.</p>
            </div>
            <div style="background: #f7fafc; padding: 20px; text-align: center; font-size: 12px; color: #a0aec0;">
                © 2026 Webnox Technologies Pvt Ltd
            </div>
        </div>
    </div>
</body>
</html>
    ''';
  }

  /// Generate work anniversary notification email (for admins about someone's anniversary)
  static String generateWorkAnniversaryNotificationEmail({
    required String recipientName,
    required String anniversaryPersonName,
    required int yearsCompleted,
  }) {
    final yearText = yearsCompleted == 1 ? 'year' : 'years';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Work Anniversary Reminder</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Poppins', sans-serif; background: #f4f7f6;">
    <div style="max-width: 600px; margin: 0 auto; padding: 40px 20px;">
        <div style="background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05);">
            <div style="background: linear-gradient(135deg, #f9a825 0%, #ffc107 100%); padding: 30px 40px; text-align: center;">
                <h1 style="color: #fff; margin: 0; font-size: 24px;">🎉 Work Anniversary Today!</h1>
            </div>
            <div style="padding: 40px;">
                <p>Hello $recipientName,</p>
                <p>Today marks <strong>$anniversaryPersonName</strong>'s <strong>$yearsCompleted $yearText</strong> work anniversary at Webnox!</p>
                <div style="background: #fff8e1; border-radius: 12px; padding: 20px; margin: 20px 0; text-align: center;">
                    <p style="color: #f9a825; font-size: 18px; font-weight: 600; margin: 0;">
                        Congratulate them on this milestone! 🎊
                    </p>
                </div>
                <p>Take a moment to appreciate their contributions to the team.</p>
            </div>
            <div style="background: #f7fafc; padding: 20px; text-align: center; font-size: 12px; color: #a0aec0;">
                © 2026 Webnox Technologies Pvt Ltd
            </div>
        </div>
    </div>
</body>
</html>
    ''';
  }
}
