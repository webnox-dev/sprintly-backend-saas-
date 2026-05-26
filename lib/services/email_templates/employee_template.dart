/// Employee Email Templates
/// Handles: Welcome with credentials, Deactivated, Exit
class EmployeeEmailTemplate {
  /// Generate welcome email for new employee with login credentials
  /// Generate welcome email for new employee with login credentials
  /// Generate welcome email for new employee with login credentials
  static String generateWelcomeEmail({
    required String employeeName,
    required String email,
    required String employeeId,
    required String designation,
    required String defaultPassword,
    String? department,
    String? reportingTo,
    String? joiningDate,
    String? otp,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Welcome to Webnox Sprintly</title>

<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>

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
    background: linear-gradient(135deg, #003d80, #0073d4);
    padding: 40px;
    text-align: left;
}
.header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 600;
    color: #ffffff;
}
.header p {
    margin: 8px 0 0;
    font-size: 14px;
    color: #dbeafe;
}
.content { padding: 40px; }

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

.section-title {
    font-size: 18px;
    font-weight: 600;
    color: #0066cc;
    margin: 30px 0 18px;
    padding-bottom: 6px;
    border-bottom: 2px solid #e6e9ef;
}

/* OTP */
.otp-box {
    background: #e3f2fd;
    border: 1px dashed #2196f3;
    border-radius: 10px;
    padding: 18px;
    text-align: center;
    margin-bottom: 12px;
}
.otp-value {
    font-size: 26px;
    font-weight: 700;
    letter-spacing: 6px;
    color: #0d47a1;
}
.otp-note {
    margin-top: 8px;
    font-size: 13px;
    color: #b71c1c;
    background: #ffebee;
    padding: 6px 10px;
    border-radius: 6px;
    display: inline-block;
    font-weight: 600;
}

/* Credentials */
.credentials-box {
    background: #f8f9fc;
    padding: 22px;
    border-radius: 12px;
    border: 1px solid #e5e8ef;
    margin-bottom: 25px;
}
.cred-row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid #e1e4ea;
}
.cred-row:last-child { border-bottom: none; }
.cred-label { font-weight: 600; color: #333; }
.cred-value { font-weight: 500; color: #2b2d33; }

/* Steps */
.steps-box {
    background: #fff8e1;
    border: 1px solid #ffe082;
    border-radius: 10px;
    padding: 18px;
    margin: 25px 0;
}
.steps-box li {
    margin-bottom: 8px;
    font-size: 14px;
}

/* Features */
.features-section { margin-bottom: 32px; }
.feature-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
}
.feature-item {
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 16px;
}
.feature-name { font-weight: 600; color: #4a5568; font-size: 14px; margin-bottom: 4px; display: block; }
.feature-desc { font-size: 12px; color: #718096; line-height: 1.4; }

/* CTA */
.cta-container { text-align: center; margin-top: 32px; }
.cta-button {
    padding: 14px 34px;
    text-decoration: none;
    background: #0066cc;
    color: #ffffff;
    border-radius: 8px;
    font-weight: 600;
    font-size: 15px;
    box-shadow: 0 4px 18px rgba(0, 102, 204, 0.25);
}

/* Footer */
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
    <h1>Welcome to Webnox Sprintly</h1>
    <p>Your digital workplace starts here</p>
</div>

<div class="content">

    <div class="greeting">
        Hello <strong>$employeeName</strong>,
    </div>

    <p>
        Welcome aboard! We're thrilled to have you join Webnox Technologies. Sprintly is your all-in-one platform 
        for managing tasks, team communication, requests, and personal workflow. 
        <strong>Here you can request leaves, permissions, or work from home, chat with teammates, and stay updated with company announcements!</strong>
    </p>

    ${otp != null ? '''
    <div class="otp-box">
        <div>Verification Code</div>
        <div class="otp-value">$otp</div>
        <div class="otp-note">This code is valid for 15 minutes</div>
    </div>
    ''' : ''}

    <h3 class="section-title">Your Account Details</h3>

    <div class="credentials-box">
        <div class="cred-row"><span class="cred-label">Employee ID</span><span class="cred-value">$employeeId</span></div>
        <div class="cred-row"><span class="cred-label">Email</span><span class="cred-value">$email</span></div>
        ${department != null ? '<div class="cred-row"><span class="cred-label">Department</span><span class="cred-value">$department</span></div>' : ''}
        <div class="cred-row"><span class="cred-label">Designation</span><span class="cred-value">$designation</span></div>
        <div class="cred-row"><span class="cred-label">Temporary Password</span><span class="cred-value">$defaultPassword</span></div>
    </div>

    <h3 class="section-title">Getting Started</h3>
    <div class="steps-box">
        <ol style="padding-left:18px;margin:0;">
            <li>Log in using your credentials.</li>
            <li>Update your password for security.</li>
            <li>Complete your profile and settings.</li>
            <li>Check assigned tasks, leave requests, WFH requests, and announcements.</li>
            <li>Start collaborating by chatting with your team.</li>
        </ol>
    </div>

    <h3 class="section-title">Key Features</h3>
    <div class="feature-grid">
        <div class="feature-item">
            <span class="feature-name">📋 Manage Tasks</span>
            <span class="feature-desc">View, update, and track progress of your tasks daily.</span>
        </div>
        <div class="feature-item">
            <span class="feature-name">📅 Track Leaves & Permissions</span>
            <span class="feature-desc">Request leaves, permissions, and WFH directly from Sprintly.</span>
        </div>
        <div class="feature-item">
            <span class="feature-name">💬 Team Communication</span>
            <span class="feature-desc">Chat and collaborate with your teammates in real-time.</span>
        </div>
        <div class="feature-item">
            <span class="feature-name">📢 Announcements</span>
            <span class="feature-desc">Stay updated with company-wide news, alerts, and announcements.</span>
        </div>
    </div>

    <div class="cta-container">
        <a href="https://employee-sprintly.webnoxdigital.com/" target="_blank" class="cta-button">
            Go to Employee Dashboard
        </a>
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

  /// Generate email for employee deactivation
  static String generateDeactivatedEmail({
    required String employeeName,
    required String employeeId,
    required String designation,
    required String deactivatedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Account Deactivated</title>
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
    background: linear-gradient(135deg, #e65100, #ff6d00);
    padding: 35px 40px;
    text-align: left;
}
.header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 600;
    color: #ffffff;
}
.header p {
    margin: 8px 0 0;
    font-size: 14px;
    color: #ffe0b2;
}
.content {
    padding: 40px;
}
.greeting {
    font-size: 17px;
    font-weight: 500;
    margin-bottom: 15px;
}
p {
    font-size: 15px;
    line-height: 1.7;
    margin-bottom: 16px;
    color: #4a4e57;
}
.status-badge {
    display: inline-block;
    background: #fff3e0;
    color: #e65100;
    padding: 8px 22px;
    border-radius: 25px;
    font-weight: 600;
    font-size: 14px;
    margin: 15px 0;
    text-transform: uppercase;
}
.info-box {
    background: #fff7ed;
    border-left: 4px solid #e65100;
    padding: 22px;
    border-radius: 10px;
    margin: 25px 0;
}
.detail-row {
    padding: 12px 0;
    border-bottom: 1px solid #e1e4ea;
    display: flex;
    justify-content: space-between;
}
.detail-row:last-child { border-bottom: none; }
.detail-label {
    font-weight: 600;
    color: #666;
}
.detail-value {
    font-weight: 500;
    color: #333;
    text-align: right;
    max-width: 70%;
    word-break: break-word;
}
.contact-box {
    background: #e3f2fd;
    border-left: 4px solid #1976d2;
    padding: 20px;
    border-radius: 10px;
    margin: 25px 0;
}
.contact-box p {
    margin: 0;
    font-size: 14px;
    color: #0d47a1;
}
.contact-box strong { font-size: 15px; }

.additional-note {
    background: #fff3e0;
    border-left: 4px solid #e65100;
    padding: 18px;
    border-radius: 10px;
    margin-top: 20px;
    font-size: 14px;
    color: #e65100;
}
.footer {
    margin-top: 40px;
    text-align: center;
    padding: 24px;
    background: #f0f2f6;
}
.footer p {
    font-size: 13px;
    color: #7a7e87;
    margin: 5px 0;
}
</style>
</head>

<body>
<div class="email-wrapper">

    <div class="header">
        <h1>Account Deactivated</h1>
        <p>Important Security Notice</p>
    </div>

    <div class="content">
        <div class="greeting">
            Hello <strong>$employeeName</strong>,
        </div>

        <p>
            We want to inform you that your employee account has been <strong>deactivated</strong>. 
            This action has been taken to maintain security and compliance within our systems.
        </p>

        <div class="status-badge">ACCOUNT DEACTIVATED</div>

        <div class="info-box">
            <div class="detail-row">
                <span class="detail-label">Employee:</span>
                <span class="detail-value">$employeeName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Employee ID:</span>
                <span class="detail-value">$employeeId</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Designation:</span>
                <span class="detail-value">$designation</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Deactivated By:</span>
                <span class="detail-value">$deactivatedBy</span>
            </div>
            ${reason != null && reason.isNotEmpty ? '''
            <div class="detail-row">
                <span class="detail-label">Reason:</span>
                <span class="detail-value">$reason</span>
            </div>
            ''' : ''}
        </div>

        <p>
            You will no longer be able to access the employee portal. Please ensure you have saved any personal data you may need.
        </p>

        <div class="contact-box">
            <strong>Need Assistance?</strong>
            <p>If you believe this deactivation is an error or have any questions, please contact the HR department immediately.</p>
        </div>

        <div class="additional-note">
            <strong>Security Reminder:</strong> Your login credentials are now disabled. Please do not attempt to access the system until your account is reactivated.
        </div>

    </div>

    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>Webnox Technologies Pvt Ltd</p>
    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate email for employee exit
  static String generateExitEmail({
    required String employeeName,
    required String employeeId,
    required String designation,
    required String department,
    required String exitDate,
    required String processedBy,
    String? exitType,
    String? remarks,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Exit Confirmation</title>
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
    background: linear-gradient(135deg, #455a64, #607d8b);
    padding: 35px 40px;
}
.header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 600;
    color: #ffffff;
}
.header p {
    margin: 8px 0 0;
    font-size: 14px;
    color: #cfd8dc;
}
.content {
    padding: 40px;
}
.greeting {
    font-size: 17px;
    font-weight: 500;
    margin-bottom: 15px;
}
p {
    font-size: 15px;
    line-height: 1.7;
    margin-bottom: 16px;
    color: #4a4e57;
}
.section-title {
    font-size: 18px;
    font-weight: 600;
    color: #333;
    margin-bottom: 18px;
    border-bottom: 2px solid #e6e9ef;
    padding-bottom: 6px;
}
.details-box {
    background: #f8f9fc;
    padding: 22px;
    border-radius: 12px;
    border: 1px solid #e5e8ef;
}
.detail-row {
    display: flex;
    justify-content: space-between;
    padding: 12px 0;
    border-bottom: 1px solid #e1e4ea;
}
.detail-row:last-child { border-bottom: none; }
.detail-label {
    font-weight: 600;
    color: #666;
}
.detail-value {
    font-weight: 500;
    color: #333;
    max-width: 70%;
    word-break: break-word;
    text-align: right;
}
.remarks-box {
    margin: 28px 0;
    background: #fff3e0;
    border-left: 4px solid #e65100;
    padding: 20px;
    border-radius: 10px;
    font-size: 14px;
    line-height: 1.6;
}
.farewell-box {
    margin: 28px 0;
    background: #e3f2fd;
    border-left: 4px solid #1976d2;
    padding: 20px;
    border-radius: 10px;
    font-size: 14px;
    line-height: 1.6;
}
.motivational-note {
    margin: 28px 0;
    background: #e8f5e9;
    border-left: 4px solid #2e7d32;
    padding: 20px;
    border-radius: 10px;
    font-size: 14px;
    line-height: 1.6;
    color: #2e7d32;
}
.footer {
    margin-top: 40px;
    text-align: center;
    padding: 24px;
    background: #f0f2f6;
}
.footer p {
    font-size: 13px;
    color: #7a7e87;
    margin: 5px 0;
}
</style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>Exit Confirmation</h1>
        <p>Finalizing Your Employment Separation</p>
    </div>
    <div class="content">
        <div class="greeting">
            Dear <strong>$employeeName</strong>,
        </div>

        <p>
            This email confirms that your employment separation with Webnox Technologies has been processed successfully.
        </p>

        <h3 class="section-title">Exit Details</h3>
        <div class="details-box">
            <div class="detail-row">
                <span class="detail-label">Employee Name:</span>
                <span class="detail-value">$employeeName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Employee ID:</span>
                <span class="detail-value">$employeeId</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Designation:</span>
                <span class="detail-value">$designation</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Department:</span>
                <span class="detail-value">$department</span>
            </div>
            ${exitType != null ? '''
            <div class="detail-row">
                <span class="detail-label">Exit Type:</span>
                <span class="detail-value">$exitType</span>
            </div>
            ''' : ''}
            <div class="detail-row">
                <span class="detail-label">Exit Date:</span>
                <span class="detail-value">$exitDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Processed By:</span>
                <span class="detail-value">$processedBy</span>
            </div>
        </div>

        ${remarks != null && remarks.isNotEmpty ? '''
        <div class="remarks-box">
            <strong>Remarks:</strong><br><br>
            $remarks
        </div>
        ''' : ''}

        <div class="farewell-box">
            <strong>Farewell Message:</strong><br><br>
            We sincerely appreciate your contributions during your tenure. Your hard work and dedication have made a significant impact. 
            We wish you success in all your future endeavors and hope our paths cross again.
        </div>

        <div class="motivational-note">
            <strong>Advice & Motivation:</strong><br><br>
            Remember, every ending opens a new beginning. Continue to learn, grow, and excel in your future career. Stay connected and keep striving for excellence!
        </div>

        <p>
            For any queries regarding your final settlement, experience letter, or exit formalities, please contact the HR department.
        </p>
    </div>

    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>Webnox Technologies Pvt Ltd</p>
    </div>
</div>
</body>
</html>
    ''';
  }

  /// Generate subject lines
  static String generateWelcomeSubject() {
    return 'Welcome to Webnox Technologies - Your Account Details';
  }

  static String generateDeactivatedSubject() {
    return 'Your Webnox Employee Account Has Been Deactivated';
  }

  static String generateExitSubject(String employeeName) {
    return 'Exit Confirmation - $employeeName';
  }

  /// Generate notification email when a new employee is added (for admins)
  static String generateNewEmployeeNotificationEmail({
    required String recipientName,
    required String employeeName,
    required String employeeId,
    required String employeeEmail,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>New Employee Joined</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
<style>
    body { font-family: 'Poppins', sans-serif; background-color: #f4f7f6; margin: 0; padding: 40px 0; color: #2b2d33; }
    .container { max-width: 680px; margin: 0 auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 8px 28px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #10b981, #059669); padding: 35px 40px; text-align: center; }
    .header h1 { color: #fff; margin: 0; font-size: 28px; font-weight: 700; }
    .content { padding: 40px; }
    p { font-size: 15px; line-height: 1.7; margin-bottom: 16px; }
    .info-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px; padding: 24px; margin: 25px 0; }
    .info-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #dcfce7; }
    .info-row:last-child { border-bottom: none; }
    .label { font-weight: 500; color: #4a5568; }
    .value { font-weight: 600; color: #2b2d33; text-align: right; max-width: 70%; word-break: break-word; }
    .cta-container { text-align: center; margin-top: 30px; }
    .cta-button { background: #10b981; color: #ffffff; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; box-shadow: 0 4px 18px rgba(16, 185, 129, 0.25); display: inline-block; }
    .footer { background: #f7fafc; padding: 24px 40px; text-align: center; font-size: 12px; color: #7a7e87; border-top: 1px solid #e4e7ed; }
</style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>🎉 New Employee Joined</h1>
        </div>

        <!-- Content -->
        <div class="content">
            <p>Hello <strong>$recipientName</strong>,</p>
            <p>We’re excited to announce that a new employee has joined the Webnox team! Please join us in giving them a warm welcome.</p>

            <!-- Employee Info -->
            <div class="info-box">
                <div class="info-row">
                    <span class="label">Name:</span>
                    <span class="value">$employeeName</span>
                </div>
                <div class="info-row">
                    <span class="label">Employee ID:</span>
                    <span class="value">$employeeId</span>
                </div>
                <div class="info-row">
                    <span class="label">Email:</span>
                    <span class="value">$employeeEmail</span>
                </div>
            </div>

            <p>Let’s make them feel at home and support them as they start this exciting journey with us!</p>

            <!-- CTA Button -->
            <div class="cta-container">
                <a href="https://employee-sprintly.webnoxdigital.com/" class="cta-button">View Employee Dashboard</a>
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            &copy; 2026 Webnox Technologies Pvt Ltd.<br>
            You received this email because you are part of the Webnox team.
        </div>
    </div>
</body>
</html>

    ''';
  }

  /// Generate email for employee status change (activated/deactivated)
  static String generateStatusChangeEmail({
    required String employeeName,
    required bool isActive,
  }) {
    final statusText = isActive ? 'Activated' : 'Deactivated';
    final statusColor = isActive ? '#10b981' : '#ef4444';
    final bgColor = isActive ? '#f0fdf4' : '#fef2f2';
    final borderColor = isActive ? '#bbf7d0' : '#fecaca';
    final message = isActive
        ? 'You can now access the employee portal and all associated features.'
        : 'Your access to the employee portal has been temporarily suspended. Please contact HR if you have any questions.';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Account Status Updated</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
    body {
        font-family: 'Poppins', sans-serif;
        background-color: #f4f7f6;
        margin: 0;
        padding: 40px 0;
        color: #2b2d33;
    }
    .container {
        max-width: 680px;
        margin: 0 auto;
        background: #ffffff;
        border-radius: 16px;
        overflow: hidden;
        box-shadow: 0 8px 28px rgba(0,0,0,0.08);
    }
    .header {
        padding: 35px 40px;
        text-align: left;
        background: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%);
        color: #ffffff;
    }
    .header h1 {
        margin: 0;
        font-size: 28px;
        font-weight: 700;
    }
    .header p {
        margin: 6px 0 0 0;
        font-size: 14px;
        font-weight: 400;
        color: rgba(255,255,255,0.9);
    }
    .content {
        padding: 40px;
    }
    .greeting {
        font-size: 16px;
        font-weight: 500;
        margin-bottom: 16px;
    }
    p {
        font-size: 15px;
        line-height: 1.7;
        margin-bottom: 16px;
        color: #4a4e57;
    }
    .status-box {
        border-radius: 12px;
        padding: 22px;
        margin: 20px 0;
        text-align: center;
        font-size: 22px;
        font-weight: 700;
        color: #ffffff;
        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    .info-box {
        background: #f0f4f8;
        border: 1px solid #d1d5db;
        border-radius: 12px;
        padding: 20px;
        margin: 25px 0;
    }
    .info-row {
        display: flex;
        justify-content: space-between;
        padding: 12px 0;
        border-bottom: 1px solid #e1e4ea;
    }
    .info-row:last-child {
        border-bottom: none;
    }
    .label {
        font-weight: 500;
        color: #4a5568;
    }
    .value {
        font-weight: 600;
        color: #2b2d33;
        text-align: right;
        max-width: 70%;
        word-break: break-word;
    }
    .cta-container {
        text-align: center;
        margin-top: 30px;
    }
    .cta-button {
        background: #4f46e5;
        color: #ffffff;
        padding: 12px 28px;
        border-radius: 8px;
        text-decoration: none;
        font-weight: 600;
        font-size: 15px;
        display: inline-block;
        box-shadow: 0 4px 18px rgba(79,70,229,0.25);
        transition: background 0.3s;
    }
    .cta-button:hover {
        background: #6366f1;
    }
    .footer {
        background: #f7fafc;
        padding: 24px 40px;
        text-align: center;
        font-size: 12px;
        color: #7a7e87;
        border-top: 1px solid #e4e7ed;
    }
    .footer p {
        margin: 4px 0;
    }
</style>
</head>
<body>
<div class="container">

    <!-- Header -->
    <div class="header">
        <h1>Account Status Updated</h1>
        <p>Webnox Technologies Employee Portal - Sprintly</p>
    </div>

    <!-- Content -->
    <div class="content">
        <div class="greeting">
            Hello <strong>$employeeName</strong>,
        </div>

        <p>Your employee account status has been updated successfully.</p>

        <!-- Status Box -->
        <div class="status-box" style="
            background: {{statusColor}};
        ">
            $statusText
        </div>

        <!-- Additional Message -->
        <p>$message</p>

        <!-- CTA -->
        <div class="cta-container">
            <a href="https://employee-sprintly.webnoxdigital.com/" class="cta-button">View Employee Dashboard</a>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>© 2026 Webnox Technologies Pvt Ltd.</p>
        <p>A Product by Webnox Mobile App Team.</p>
        <p>This is an automated message. Please do not reply.</p>
    </div>
</div>
</body>
</html>
    ''';
  }

  /// Generate email when employee account is removed
  static String generateAccountRemovedEmail({required String employeeName}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Account Removed</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
    body {
        font-family: 'Poppins', sans-serif;
        background-color: #f4f7f6;
        margin: 0;
        padding: 40px 0;
        color: #2b2d33;
    }
    .container {
        max-width: 680px;
        margin: 0 auto;
        background: #fff;
        border-radius: 16px;
        overflow: hidden;
        box-shadow: 0 8px 28px rgba(0,0,0,0.08);
    }
    .header {
        padding: 35px 40px;
        text-align: center;
        background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
    }
    .header h1 {
        color: #fff;
        margin: 0;
        font-size: 28px;
        font-weight: 700;
    }
    .header p {
        margin-top: 8px;
        color: rgba(255,255,255,0.85);
        font-size: 14px;
        font-weight: 400;
    }
    .content {
        padding: 40px;
    }
    .greeting {
        font-size: 16px;
        font-weight: 500;
        margin-bottom: 16px;
    }
    .info-box {
        background: #fff1f0;
        border-left: 4px solid #e53e3e;
        padding: 20px;
        border-radius: 10px;
        margin: 25px 0;
        color: #9b2c2c;
        font-size: 15px;
        line-height: 1.6;
    }
    p {
        font-size: 15px;
        line-height: 1.7;
        margin-bottom: 16px;
        color: #4a4e57;
    }
    .cta-button {
        display: inline-block;
        background: #e53e3e;
        color: #ffffff;
        font-weight: 600;
        font-size: 15px;
        padding: 12px 28px;
        border-radius: 8px;
        text-decoration: none;
        box-shadow: 0 4px 18px rgba(229,62,62,0.25);
        transition: background 0.3s;
    }
    .cta-button:hover {
        background: #c53030;
    }
    .footer {
        background: #f7fafc;
        padding: 24px 40px;
        text-align: center;
        font-size: 12px;
        color: #7a7e87;
        border-top: 1px solid #e4e7ed;
    }
    .footer p {
        margin: 4px 0;
    }
</style>
</head>
<body>
<div class="container">

    <!-- Header -->
    <div class="header">
        <h1>Account Removed</h1>
        <p>Webnox Sprintly System Notification</p>
    </div>

    <!-- Content -->
    <div class="content">
        <div class="greeting">
            Hello <strong>$employeeName</strong>,
        </div>

        <p>We want to inform you that your employee account has been <strong>removed</strong> from the Webnox Sprintly system.</p>

        <div class="info-box">
            This action is permanent. If you believe this was done in error or require assistance, please contact the HR department immediately.
        </div>

        <p>We appreciate your contributions and wish you all the best in your future endeavors.</p>

        <div style="text-align: center; margin-top: 30px;">
            <a href="mailto:hr@webnox.in" class="cta-button">Contact HR</a>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>© 2026 Webnox Technologies Pvt Ltd.</p>
        <p>A Product by Webnox Mobile App Team.</p>
        <p>This is an automated message. Please do not reply.</p>
    </div>

</div>
</body>
</html>
    ''';
  }

  /// Generate email when a task is assigned
  static String generateTaskAssignedEmail({
    required String employeeName,
    required String taskName,
    required String projectName,
    required String assignedBy,
    String? dueDate,
    String? priority,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>New Task Assigned</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
    body { 
        font-family: 'Poppins', sans-serif; 
        background-color: #f4f7f6; 
        margin: 0; 
        padding: 40px 0; 
        color: #2b2d33;
    }
    .container { 
        max-width: 680px; 
        margin: 0 auto; 
        background: #fff; 
        border-radius: 16px; 
        overflow: hidden; 
        box-shadow: 0 8px 28px rgba(0,0,0,0.08);
    }
    .header { 
        background: linear-gradient(135deg, #3b82f6, #2563eb); 
        padding: 35px 40px; 
        text-align: center; 
    }
    .header h1 { 
        color: #fff; 
        margin: 0; 
        font-size: 28px; 
        font-weight: 700; 
    }
    .header p {
        color: rgba(255,255,255,0.85);
        font-size: 14px;
        margin-top: 8px;
        font-weight: 400;
    }
    .content { 
        padding: 40px; 
    }
    .greeting { 
        font-size: 16px; 
        font-weight: 500; 
        margin-bottom: 16px; 
    }
    p { 
        font-size: 15px; 
        line-height: 1.7; 
        margin-bottom: 16px; 
    }
    .task-box { 
        background: #eff6ff; 
        border: 1px solid #dbeafe; 
        border-radius: 12px; 
        padding: 24px; 
        margin: 24px 0; 
    }
    .task-title { 
        font-size: 20px; 
        font-weight: 700; 
        color: #1e3a8a; 
        margin-bottom: 16px; 
    }
    .info-row { 
        display: flex; 
        justify-content: space-between; 
        padding: 10px 0; 
        border-bottom: 1px solid #bfdbfe; 
    }
    .info-row:last-child { border-bottom: none; }
    .label { 
        color: #64748b; 
        font-size: 14px; 
        font-weight: 500;
    }
    .value { 
        font-weight: 600; 
        color: #1e293b; 
        font-size: 14px; 
        text-align: right;
        max-width: 70%;
        word-break: break-word;
    }
    .motivation-box {
        background: #f0f9ff;
        border-left: 4px solid #3b82f6;
        border-radius: 10px;
        padding: 20px;
        font-size: 15px;
        line-height: 1.6;
        margin: 20px 0;
        color: #1e3a8a;
    }
    .action-btn { 
        display: inline-block; 
        background: #2563eb; 
        color: #fff; 
        text-decoration: none; 
        padding: 14px 28px; 
        border-radius: 8px; 
        font-weight: 600; 
        font-size: 15px; 
        margin-top: 24px;
        box-shadow: 0 4px 18px rgba(37,99,235,0.25);
        transition: background 0.3s;
    }
    .action-btn:hover { background: #1e40af; }
    .footer { 
        background: #f7fafc; 
        padding: 5px 40px; 
        text-align: center; 
        font-size: 12px; 
        color: #7a7e87; 
        border-top: 1px solid #e4e7ed; 
    }
</style>
</head>
<body>
<div class="container">

    <!-- Header -->
    <div class="header">
        <h1>📋 New Task Assigned</h1>
        <p>Stay on top of your work and deadlines</p>
    </div>

    <!-- Content -->
    <div class="content">
        <div class="greeting">
            Hello <strong>$employeeName</strong>,
        </div>
        <p>You have been assigned a new task by <strong>$assignedBy</strong>. Please review the details below and start working on it promptly.</p>

        <!-- Task Details -->
        <div class="task-box">
            <div class="task-title">$taskName</div>
            
            <div class="info-row">
                <span class="label">Project</span>
                <span class="value">$projectName</span>
            </div>
            ${priority != null ? '''
            <div class="info-row">
                <span class="label">Priority</span>
                <span class="value">$priority</span>
            </div>
            ''' : ''}
            ${dueDate != null ? '''
            <div class="info-row">
                <span class="label">Due Date</span>
                <span class="value">$dueDate</span>
            </div>
            ''' : ''}
        </div>

        <!-- Motivational Note -->
        <div class="motivation-box">
            Remember, every task is an opportunity to showcase your skills and contribute to our team's success. Stay focused, manage your time wisely, and reach out if you need any assistance!
        </div>

        <!-- CTA Button -->
        <div style="text-align: center;">
            <a href="https://employee-sprintly.webnoxdigital.com/" class="action-btn">View Task</a>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>© 2026 Webnox Technologies Pvt Ltd. All rights reserved.</p>
        <p>A Product by Webnox Mobile App Team.</p>
        <p>You are receiving this email because you are part of the Webnox team.</p>
    </div>

</div>
</body>
</html>
    ''';
  }
}
