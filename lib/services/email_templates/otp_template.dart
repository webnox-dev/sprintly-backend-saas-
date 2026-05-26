/// OTP Email Template
class OTPEmailTemplate {
  /// Generate OTP email HTML template
  static String generateOTPEmailTemplate({
    required String userName,
    required String otp,
    required String userType, // 'admin' or 'employee'
  }) {
    // Determine user type label and dashboard URL
    final userTypeLabel = userType.toLowerCase() == 'admin' ? 'Admin' : 'Employee';
    final dashboardUrl = userType.toLowerCase() == 'admin'
        ? 'https://sprintlyadmin.webnoxdigital.com/'
        : 'https://sprintly.webnoxdigital.com/';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Email Verification Code</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
    body {
        margin: 0;
        background: #eef1f5;
        padding: 30px 0;
        font-family: 'Poppins', sans-serif;
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
        background: linear-gradient(135deg, #4F46E5, #7C3AED);
        padding: 35px 40px;
        text-align: center;
    }
    .header h1 {
        margin: 0;
        font-size: 26px;
        font-weight: 600;
        color: #ffffff;
    }
    .header p {
        margin-top: 8px;
        font-size: 16px;
        color: rgba(255,255,255,0.85);
        font-weight: 400;
    }
    .content {
        padding: 40px;
    }
    .greeting {
        font-size: 17px;
        font-weight: 500;
        margin-bottom: 15px;
        color: #222;
    }
    p {
        font-size: 15px;
        line-height: 1.7;
        margin: 0 0 16px 0;
        color: #4a4e57;
    }
    .otp-container {
        margin: 30px 0;
        text-align: center;
    }
    .otp-box {
        display: inline-block;
        background: linear-gradient(135deg, #4F46E5, #7C3AED);
        padding: 25px 40px;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
    }
    .otp-label {
        font-size: 14px;
        font-weight: 500;
        color: rgba(255,255,255,0.9);
        margin-bottom: 12px;
        text-transform: uppercase;
        letter-spacing: 1px;
    }
    .otp-code {
        font-size: 42px;
        font-weight: 700;
        color: #ffffff;
        letter-spacing: 12px;
        font-family: 'Courier New', monospace;
    }
    .dashboard-btn {
        display: inline-block;
        margin-top: 20px;
        padding: 12px 28px;
        background: #4F46E5;
        color: #fff;
        font-weight: 600;
        text-decoration: none;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
    }
    .warning-box {
        margin: 28px 0;
        background: #fff3cd;
        border-left: 4px solid #ffc107;
        padding: 20px;
        border-radius: 10px;
        font-size: 14px;
        color: #856404;
        line-height: 1.6;
    }
    .info-box {
        margin: 20px 0;
        background: #e7f3ff;
        border-left: 4px solid #4F46E5;
        padding: 18px;
        border-radius: 10px;
        font-size: 14px;
        color: #004085;
        line-height: 1.6;
    }
    .signature {
        margin-top: 20px;
        font-size: 14px;
        color: #4a4e57;
        font-weight: 500;
    }
    .footer {
        margin-top: 40px;
        text-align: center;
        padding: 24px 35px;
        background: #f0f2f6;
        border-top: 1px solid #e4e7ed;
        font-size: 12px;
        color: #7a7e87;
    }
    .watermark {
        margin-top: 12px;
        font-size: 12px;
        color: #9aa0a9;
    }
    @media only screen and (max-width: 600px) {
        body { padding: 10px 0; }
        .email-wrapper { max-width: 100%; margin: 0 10px; border-radius: 8px; }
        .header { padding: 25px 20px; }
        .header h1 { font-size: 22px; }
        .header p { font-size: 14px; }
        .content { padding: 25px 20px; }
        .otp-code { font-size: 32px; letter-spacing: 8px; }
    }
</style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>Email Verification</h1>
        <p>Secure your account with this verification code</p>
    </div>
    <div class="content">
        <div class="greeting">
            Hello <strong>$userName</strong>,
        </div>
        <p>
            Welcome to <strong>Webnox Sprintly</strong>! You have been registered as a <strong>$userTypeLabel</strong>.
            Please use the verification code below to verify your email address.
        </p>

        <div class="otp-container">
            <div class="otp-box">
                <div class="otp-label">Your Verification Code</div>
                <div class="otp-code">$otp</div>
            </div>
        </div>

        <!-- Go to Dashboard Button -->
        <div style="text-align:center;">
            <a href="$dashboardUrl" class="dashboard-btn">Go to Dashboard</a>
        </div>

        <div class="warning-box">
            <strong>Important:</strong> This code expires in <strong>15 minutes</strong>. If you didn't request this, please ignore this email.
        </div>

        <div class="info-box">
            <strong>Security Tip:</strong> Never share this code with anyone.
        </div>

        <div class="signature">
            Best regards,<br>
            <strong>Webnox Sprintly Admin Team</strong><br>
            Webnox Technologies Pvt Ltd
        </div>
    </div>
    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <div class="watermark">
            © 2026 Webnox Technologies Pvt Ltd<br>
            A Product by Mobile App Team
        </div>
    </div>
</div>
</body>
</html>
    ''';
  }
}
