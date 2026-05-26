/// Chat Email Templates
class ChatEmailTemplate {
  /// Generate email for group creation notification
  static String generateGroupCreatedEmail({
    required String recipientName,
    required String groupName,
    required String createdBy,
    String? description,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>New Group Invitation</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
<style>
    body { font-family: 'Poppins', sans-serif; background-color: #f4f7f6; margin: 0; padding: 40px 0; color: #2b2d33; }
    .container { max-width: 680px; margin: 0 auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 8px 28px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #6366F1, #4F46E5); padding: 35px 40px; text-align: center; }
    .header h1 { color: #fff; margin: 0; font-size: 28px; font-weight: 700; }
    .content { padding: 40px; }
    p { font-size: 15px; line-height: 1.7; margin-bottom: 16px; }
    .group-box { background: #EEF2FF; border: 1px solid #C7D2FE; border-radius: 12px; padding: 24px; margin: 25px 0; }
    .group-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #E0E7FF; }
    .group-row:last-child { border-bottom: none; }
    .label { font-weight: 500; color: #4a5568; }
    .value { font-weight: 600; color: #2b2d33; text-align: right; max-width: 70%; word-break: break-word; }
    .cta-container { text-align: center; margin-top: 30px; }
    .cta-button { background: #6366F1; color: #ffffff; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; box-shadow: 0 4px 18px rgba(99, 102, 241, 0.25); display: inline-block; }
    .footer { background: #f7fafc; padding: 24px 40px; text-align: center; font-size: 12px; color: #7a7e87; border-top: 1px solid #e4e7ed; }
</style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>💬 New TeamSync Group</h1>
        </div>

        <!-- Content -->
        <div class="content">
            <p>Hello <strong>$recipientName</strong>,</p>
            <p>You have been added to a new group in TeamSync! Stay connected and collaborate with your team in real-time.</p>

            <!-- Group Info -->
            <div class="group-box">
                <div class="group-row">
                    <span class="label">Group Name:</span>
                    <span class="value">$groupName</span>
                </div>
                <div class="group-row">
                    <span class="label">Created By:</span>
                    <span class="value">$createdBy</span>
                </div>
                ${description != null && description.isNotEmpty ? '''
                <div class="group-row">
                    <span class="label">Description:</span>
                    <span class="value">$description</span>
                </div>
                ''' : ''}
            </div>

            <p>Log in to Sprintly to join the conversation!</p>

            <!-- CTA Button -->
            <div class="cta-container">
                <a href="https://employee-sprintly.webnoxdigital.com/team-sync" class="cta-button">Open TeamSync</a>
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            &copy; 2026 Webnox Technologies Pvt Ltd.<br>
            A Product by Mobile App Team
        </div>
    </div>
</body>
</html>
''';
  }
}
