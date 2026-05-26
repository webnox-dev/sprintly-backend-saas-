/// Announcement Email Templates
/// Handles: Created, Updated
class AnnouncementEmailTemplate {
  /// Generate email for new announcement
  static String generateAnnouncementCreatedEmail({
    required String recipientName,
    required String announcementTitle,
    required String announcementContent,
    required String createdBy,
    required String createdDate,
    String? priority,
    String? expiryDate,
  }) {
    final priorityColor = _getPriorityColor(priority);

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>New Announcement</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
<style>
body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', Arial, sans-serif; color: #2b2d33; }
.email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 35px rgba(0, 0, 0, 0.08); }
.header { background: linear-gradient(135deg, #003d80, #0073d4); padding: 38px 42px; }
.header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; letter-spacing: 0.4px; font-family: 'Poppins', Arial, sans-serif; }
.content { padding: 42px; font-family: 'Poppins', Arial, sans-serif; }
.greeting { font-size: 17px; font-weight: 500; margin-bottom: 14px; color: #222; }
p { font-size: 15px; line-height: 1.75; margin: 0 0 18px 0; color: #4a4e57; }
.section-title { font-size: 18px; font-weight: 600; color: #0066cc; margin-bottom: 18px; padding-bottom: 8px; border-bottom: 2px solid #e6e9ef; }
.info-box { background: #f9fbff; padding: 24px; border-radius: 14px; border: 1px solid #e4e8f0; }
.detail-row { display: flex; justify-content: space-between; padding: 13px 0; border-bottom: 1px solid #e6e9ef; }
.detail-row:last-child { border-bottom: none; }
.detail-label { font-size: 15px; font-weight: 600; color: #333; }
.detail-value { font-size: 15px; font-weight: 500; color: #2b2d33; text-align: right; }
.priority-badge { background: $priorityColor; color: #ffffff; padding: 5px 14px; border-radius: 20px; font-size: 11px; font-weight: 600; letter-spacing: 0.5px; text-transform: uppercase; }
.description-box { margin: 32px 0; background: #ffffff; border: 1px solid #dfe3eb; padding: 22px; border-radius: 12px; font-size: 14px; color: #4f535b; line-height: 1.75; }
.highlight-bar { background: #eaf3ff; border-left: 4px solid #0066cc; padding: 14px 18px; border-radius: 8px; font-size: 14px; color: #2b2d33; margin-bottom: 22px; }
.cta-container { text-align: center; margin-top: 34px; }
.cta-button { padding: 15px 38px; display: inline-block; text-decoration: none; background: #0066cc; color: #ffffff; border-radius: 10px; font-weight: 600; font-size: 15px; box-shadow: 0 6px 20px rgba(0, 102, 204, 0.25); font-family: 'Poppins', Arial, sans-serif; }
.footer { margin-top: 42px; text-align: center; padding: 26px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; font-family: 'Poppins', Arial, sans-serif; }
.footer p { margin: 6px 0; font-size: 13px; color: #7a7e87; }
.watermark { margin-top: 12px; font-size: 12px; color: #9aa0a9; }
@media only screen and (max-width: 600px) {
    .content { padding: 28px; }
    .header { padding: 28px; }
    .detail-row { flex-direction: column; align-items: flex-start; }
    .detail-value { text-align: left; margin-top: 4px; }
}
</style>
</head>
<body>
<div class="email-wrapper">
<div class="header"><h1>New Announcement</h1></div>
<div class="content">
    <div class="greeting">Hello <strong>$recipientName</strong>,</div>
    <div class="highlight-bar">A new announcement has been published. Please review the details below.</div>
    <h3 class="section-title">Announcement Details</h3>
    <div class="info-box">
        <div class="detail-row"><span class="detail-label">Title:</span><span class="detail-value">$announcementTitle</span></div>
        ${priority != null && priority.isNotEmpty ? '<div class="detail-row"><span class="detail-label">Priority:</span><span class="detail-value"><span class="priority-badge">$priority</span></span></div>' : ''}
        <div class="detail-row"><span class="detail-label">Posted By:</span><span class="detail-value">$createdBy</span></div>
        <div class="detail-row"><span class="detail-label">Posted On:</span><span class="detail-value">$createdDate</span></div>
        ${expiryDate != null ? '<div class="detail-row"><span class="detail-label">Valid Until:</span><span class="detail-value">$expiryDate</span></div>' : ''}
    </div>
    <div class="description-box"><strong>Announcement Message:</strong><br><br>$announcementContent</div>
    <div class="cta-container"><a href="https://sprintlyadmin.webnoxdigital.com/" target="_blank" class="cta-button">View in Dashboard</a></div>
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

  /// Get priority color
  static String _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
      case 'urgent':
        return '#c62828';
      case 'medium':
        return '#f9a825';
      case 'low':
        return '#2e7d32';
      default:
        return '#1976d2';
    }
  }

  /// Generate subject lines
  static String generateCreatedSubject(String title) {
    return 'New Announcement: $title';
  }

  static String generateUpdatedSubject(String title) {
    return 'Announcement Updated: $title';
  }

  static String generateDeletedSubject(String title) {
    return 'Announcement Removed: $title';
  }

  static String generateAnnouncementUpdatedEmail({
    required String recipientName,
    required String announcementTitle,
    required String announcementContent,
    required String updatedBy,
    required String updatedDate,
    String? priority,
    String? expiryDate,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Announcement Updated</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#ff6f00,#ffa000);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Announcement Updated</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>The following announcement has been <strong>updated</strong>.</p>
<div style="background:#f8f9fc;padding:22px;border-radius:10px;margin:20px 0;">
<div><strong>Title:</strong> $announcementTitle</div>
${priority != null && priority.isNotEmpty ? '<div><strong>Priority:</strong> $priority</div>' : ''}
<div><strong>Updated by:</strong> $updatedBy</div>
<div><strong>Updated on:</strong> $updatedDate</div>
${expiryDate != null && expiryDate.isNotEmpty ? '<div><strong>Valid until:</strong> $expiryDate</div>' : ''}
</div>
<div style="background:#fff;border:1px solid #e5e8ef;padding:22px;border-radius:12px;margin:20px 0;">$announcementContent</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateAnnouncementDeletedEmail({
    required String recipientName,
    required String announcementTitle,
    required String deletedBy,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Announcement Removed</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#c62828,#ef5350);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Announcement Removed</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>The announcement <strong>$announcementTitle</strong> has been removed.</p>
<div style="background:#ffebee;padding:22px;border-radius:10px;margin:20px 0;"><strong>Removed by:</strong> $deletedBy</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }
}
