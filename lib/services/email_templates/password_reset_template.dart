/// Password Reset Email Template
class PasswordResetEmailTemplate {
  /// Generate Password Reset email HTML template
  static String generatePasswordResetEmailTemplate({
    required String userName,
    required String otp,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Password Reset Request</title>
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
        background: linear-gradient(135deg, #EF4444, #DC2626);
        padding: 35px 40px;
        text-align: center;
    }
    .header h1 {
        margin: 0;
        font-size: 26px;
        font-weight: 700;
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
        background: linear-gradient(135deg, #EF4444, #DC2626);
        padding: 25px 40px;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3);
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
        background: #DC2626;
        color: #fff;
        font-weight: 600;
        text-decoration: none;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
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
        background: #fee2e2;
        border-left: 4px solid #EF4444;
        padding: 18px;
        border-radius: 10px;
        font-size: 14px;
        color: #991b1b;
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
        <h1>🔐 Password Reset Request</h1>
        <p>Reset your Webnox Sprintly password securely</p>
    </div>
    <div class="content">
        <div class="greeting">
            Hello <strong>$userName</strong>,
        </div>
        <p>
            We received a request to reset your password for your Webnox Sprintly account.
            Use the verification code below to complete the password reset process.
        </p>
        <div class="otp-container">
            <div class="otp-box">
                <div class="otp-label">Your Reset Code</div>
                <div class="otp-code">$otp</div>
            </div>
        </div>

        <!-- Go to Dashboard Button -->
        <div style="text-align:center;">
            <a href="https://sprintlyadmin.webnoxdigital.com/" class="dashboard-btn">Go to Dashboard</a>
        </div>

        <div class="warning-box">
            <strong>Important:</strong> This code expires in <strong>15 minutes</strong>. If you didn't request a password reset, please ignore this email or contact support.
        </div>

        <div class="info-box">
            <strong>Security Alert:</strong> Never share this code with anyone. Our team will never ask for your verification code.
        </div>

        <div class="signature">
            Best regards,<br>
            <strong>Webnox Sprintly Team</strong><br>
            Webnox Technologies Pvt Ltd
        </div>
    </div>
    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
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

  /// Generate Password Changed Confirmation email HTML template
  static String generatePasswordChangedEmailTemplate({
    required String userName,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Password Changed</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
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
            background: linear-gradient(135deg, #10B981, #059669);
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
            margin-bottom: 15px;
            color: #222;
        }
        p {
            font-size: 15px;
            line-height: 1.7;
            margin: 0 0 16px 0;
            color: #4a4e57;
        }
        .success-box {
            margin: 28px 0;
            background: #ecfdf5;
            border-left: 4px solid #10B981;
            padding: 20px;
            border-radius: 10px;
            font-size: 15px;
            color: #065f46;
            line-height: 1.6;
            display: flex;
            align-items: center;
        }
        .success-icon {
            font-size: 24px;
            margin-right: 15px;
        }
        .info-box {
            margin: 20px 0;
            background: #fee2e2;
            border-left: 4px solid #EF4444;
            padding: 18px;
            border-radius: 10px;
            font-size: 14px;
            color: #991b1b;
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
        @media only screen and (max-width: 600px) {
            body { padding: 10px 0; }
            .email-wrapper { max-width: 100%; margin: 0 10px; border-radius: 8px; }
            .header { padding: 25px 20px; }
            .header h1 { font-size: 22px; }
            .content { padding: 25px 20px; }
        }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="header">
            <h1>✅ Password Changed</h1>
        </div>
        <div class="content">
            <div class="greeting">
                Hello <strong>$userName</strong>,
            </div>
            
            <div class="success-box">
                <span class="success-icon">🎉</span>
                <div>
                    <strong>Success!</strong> Your password has been changed successfully.
                </div>
            </div>
            
            <p>
                You can now log in to your Webnox Sprintly Admin dashboard with your new password.
            </p>
            
            <div class="info-box">
                <strong>Security Alert:</strong> If you did not make this change, please contact your administrator immediately.
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
                © Webnox Technologies Pvt Ltd<br>
                A Product by Mobile App Team
            </div>
        </div>
    </div>
</body>
</html>
    ''';
  }
}
