/// Admin Email Templates
/// Handles: Welcome with credentials, Deactivated, New Admin Notification, Removed, Status Change
class AdminEmailTemplate {
  /// Generate welcome email for new admin with login credentials
  static String generateWelcomeEmail({
    required String adminName,
    required String email,
    required String role,
    required String defaultPassword,
    String? adminId,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Welcome to Webnox Sprintly</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
<style>
body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
.email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
.header { background: linear-gradient(135deg, #003d80, #0073d4); padding: 35px 40px; text-align: left; }
.header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; letter-spacing: 0.5px; }
.content { padding: 40px; }
.greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; color: #222; }
p { font-size: 15px; line-height: 1.7; margin: 0 0 16px 0; color: #4a4e57; }
.section-title { font-size: 18px; font-weight: 600; color: #0066cc; margin-bottom: 18px; padding-bottom: 6px; border-bottom: 2px solid #e6e9ef; }
.info-box { background: #f8f9fc; padding: 22px; border-radius: 12px; border: 1px solid #e5e8ef; margin-bottom: 25px; }
.detail-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #e1e4ea; }
.detail-row:last-child { border-bottom: none; }
.detail-label { font-size: 15px; font-weight: 600; color: #333; min-width: 150px; }
.detail-value { font-size: 15px; font-weight: 500; color: #2b2d33; text-align: right; }
.feature-box { margin: 20px 0; background: #ffffff; border: 1px solid #dfe3eb; padding: 20px; border-radius: 10px; font-size: 14px; color: #4f535b; line-height: 1.7; }
.cta-container { text-align: center; margin-top: 32px; }
.cta-button { padding: 14px 34px; display: inline-block; text-decoration: none; background: #0066cc; color: #ffffff; border-radius: 8px; font-weight: 600; font-size: 15px; box-shadow: 0 4px 18px rgba(0, 102, 204, 0.25); }
.footer { margin-top: 40px; text-align: center; padding: 24px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; }
.footer p { margin: 5px 0; font-size: 13px; color: #7a7e87; }
.watermark { margin-top: 12px; font-size: 12px; color: #9aa0a9; }
</style>
</head>
<body>
<div class="email-wrapper">
    <div class="header"><h1>Welcome to Webnox Sprintly</h1></div>
    <div class="content">
        <div class="greeting">Hello <strong>$adminName</strong>,</div>
        <p>Your administrator account has been successfully created. You now have full access to manage workforce operations, projects, and system workflows.</p>
        <h3 class="section-title">About the Sprintly Platform</h3>
        <div class="feature-box">
            Webnox Sprintly is a unified enterprise system that combines:
            <br><br>
            🔹 <strong>JIRA-style Task & Sprint Tracking</strong> for structured project execution<br>
            🔹 <strong>Real-time Team Chat</strong> for seamless communication<br>
            🔹 <strong>Complete HRMS Automation</strong> including Leave, WFH, Permissions, Attendance, and Employee Records
        </div>
        <h3 class="section-title">Admin Account Details</h3>
        <div class="info-box">
            ${adminId != null ? '<div class="detail-row"><span class="detail-label">Admin ID:</span><span class="detail-value">$adminId</span></div>' : ''}
            <div class="detail-row"><span class="detail-label">Login Email:</span><span class="detail-value">$email</span></div>
            <div class="detail-row"><span class="detail-label">Role:</span><span class="detail-value">$role</span></div>
            <div class="detail-row"><span class="detail-label">Temporary Password:</span><span class="detail-value">$defaultPassword</span></div>
        </div>
        <h3 class="section-title">Your Capabilities</h3>
        <div class="feature-box">
            • Manage employees, roles, and departments<br>
            • Oversee projects, sprints, and task workflows<br>
            • Monitor approvals for leave, WFH, and permissions<br>
            • Enable organization-wide communication and collaboration
        </div>
        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" target="_blank" class="cta-button">Access Admin Dashboard</a>
        </div>
        <p style="margin-top:20px; font-size:13px; color:#a94442;">For security reasons, please change your temporary password after your first login.</p>
    </div>
    <div class="footer">
        <p>This is an automated message. Please do not reply to this email.</p>
        <div class="watermark">© Webnox Technologies Pvt Ltd<br>A Product by Mobile App Team</div>
    </div>
</div>
</body>
</html>
    ''';
  }

  static String generateWelcomeSubject() {
    return 'Welcome to Webnox Sprintly Admin';
  }

  static String generateDeactivatedSubject() {
    return 'Your Webnox Sprintly Admin Account Has Been Deactivated';
  }

  static String generateDeactivatedEmail({
    required String adminName,
    required String role,
    required String deactivatedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Account Deactivated</title></head><body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#c62828,#ef5350);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Account Deactivated</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $adminName,</p>
<p>Your administrator account has been <strong>deactivated</strong>. You will no longer be able to access the admin dashboard.</p>
<div style="background:#ffebee;padding:20px;border-radius:10px;margin:20px 0;">
<div><strong>Deactivated by:</strong> $deactivatedBy</div>
${reason != null && reason.isNotEmpty ? '<div style="margin-top:10px;"><strong>Reason:</strong> $reason</div>' : ''}
</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateNewAdminNotificationEmail({
    required String recipientName,
    required String newAdminName,
    required String newAdminId,
    required String newAdminEmail,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>New Admin Added</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#1565c0,#1e88e5);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">New Admin Added</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>A new administrator <strong>$newAdminName</strong> has been added to Webnox Sprintly.</p>
<div style="background:#e3f2fd;padding:22px;border-radius:10px;margin:20px 0;">
<div><strong>Admin ID:</strong> $newAdminId</div>
<div><strong>Email:</strong> $newAdminEmail</div>
</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateAdminRemovedNotificationEmail({
    required String recipientName,
    required String removedAdminName,
    required String removedAdminId,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Admin Removed</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#c62828,#ef5350);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Admin Removed</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>Administrator <strong>$removedAdminName</strong> ($removedAdminId) has been removed from Webnox Sprintly.</p>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateActivatedSubject() {
    return 'Your Webnox Sprintly Admin Account Has Been Activated';
  }

  static String generateActivatedEmail({
    required String adminName,
    required String role,
    required String activatedBy,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Account Activated</title></head><body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#2e7d32,#43a047);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Account Activated</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $adminName,</p>
<p>Your administrator account has been <strong>activated</strong>. You can now access the admin dashboard.</p>
<div style="background:#e8f5e9;padding:20px;border-radius:10px;margin:20px 0;"><strong>Activated by:</strong> $activatedBy</div>
<p><a href="https://sprintlyadmin.webnoxdigital.com/" style="display:inline-block;background:#2e7d32;color:#fff;padding:14px 28px;border-radius:8px;text-decoration:none;font-weight:600;">Access Admin Dashboard</a></p>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }
}
