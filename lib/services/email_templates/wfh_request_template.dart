/// WFH (Work From Home) Request Email Templates
/// Handles: Approved, Rejected
class WFHRequestEmailTemplate {
  /// Generate email for WFH approval
  static String generateApprovalEmail({
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String approvedBy,
    String? remarks,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>WFH Request Approved</title>
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
            background: linear-gradient(135deg, #1565c0, #1e88e5);
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
        }
        p {
            font-size: 15px;
            line-height: 1.7;
            margin-bottom: 16px;
            color: #4a4e57;
        }
        .status-badge {
            display: inline-block;
            background: #e3f2fd;
            color: #1565c0;
            padding: 8px 20px;
            border-radius: 25px;
            font-weight: 600;
            font-size: 14px;
            margin: 15px 0;
        }
        .section-title {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin-bottom: 18px;
            border-bottom: 2px solid #e6e9ef;
            padding-bottom: 6px;
        }
        .wfh-details {
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
        .detail-row:last-child {
            border-bottom: none;
        }
        .detail-label {
            font-weight: 600;
            color: #666;
        }
        .detail-value {
            font-weight: 500;
            color: #333;
        }
        .reason-box {
            margin: 28px 0;
            background: #e3f2fd;
            border-left: 4px solid #1565c0;
            padding: 20px;
            border-radius: 10px;
            font-size: 14px;
            line-height: 1.6;
        }
        .info-box {
            margin: 20px 0;
            background: #fff3e0;
            border-left: 4px solid #ff9800;
            padding: 18px;
            border-radius: 10px;
            font-size: 14px;
            color: #e65100;
            line-height: 1.6;
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
        <h1>Work From Home Request Approved</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>Your Work From Home request has been approved.</p>

        <div class="status-badge">APPROVED</div>

        <h3 class="section-title">WFH Details</h3>

        <div class="wfh-details">
            <div class="detail-row">
                <span class="detail-label">From Date:</span>
                <span class="detail-value">$fromDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">To Date:</span>
                <span class="detail-value">$toDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Total Days:</span>
                <span class="detail-value">$totalDays</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Approved By:</span>
                <span class="detail-value">$approvedBy</span>
            </div>
        </div>

        <div class="reason-box">
            <strong>Your Reason:</strong><br><br>
            $reason
        </div>

        ${remarks != null && remarks.isNotEmpty ? '''
        <div class="reason-box" style="background: #e8f5e9; border-color: #2e7d32;">
            <strong>Admin Remarks:</strong><br><br>
            $remarks
        </div>
        ''' : ''}

        <div class="info-box">
            <strong>Important Reminders:</strong>
            <ul style="margin: 10px 0 0 0; padding-left: 20px;">
                <li>Please be available during working hours</li>
                <li>Ensure you have a stable internet connection</li>
                <li>Log your attendance daily</li>
                <li>Stay connected on team communication channels</li>
            </ul>
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

  /// Generate email for WFH rejection
  static String generateRejectionEmail({
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String rejectedBy,
    String? rejectionReason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>WFH Request Rejected</title>
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
            background: linear-gradient(135deg, #c62828, #ef5350);
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
        }
        p {
            font-size: 15px;
            line-height: 1.7;
            margin-bottom: 16px;
            color: #4a4e57;
        }
        .status-badge {
            display: inline-block;
            background: #ffebee;
            color: #c62828;
            padding: 8px 20px;
            border-radius: 25px;
            font-weight: 600;
            font-size: 14px;
            margin: 15px 0;
        }
        .section-title {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin-bottom: 18px;
            border-bottom: 2px solid #e6e9ef;
            padding-bottom: 6px;
        }
        .wfh-details {
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
        .detail-row:last-child {
            border-bottom: none;
        }
        .detail-label {
            font-weight: 600;
            color: #666;
        }
        .detail-value {
            font-weight: 500;
            color: #333;
        }
        .reason-box {
            margin: 28px 0;
            background: #ffebee;
            border-left: 4px solid #c62828;
            padding: 20px;
            border-radius: 10px;
            font-size: 14px;
            line-height: 1.6;
            color: #b71c1c;
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
        <h1>Work From Home Request Rejected</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>We regret to inform you that your Work From Home request has been rejected.</p>

        <div class="status-badge">REJECTED</div>

        <h3 class="section-title">WFH Details</h3>

        <div class="wfh-details">
            <div class="detail-row">
                <span class="detail-label">From Date:</span>
                <span class="detail-value">$fromDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">To Date:</span>
                <span class="detail-value">$toDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Total Days:</span>
                <span class="detail-value">$totalDays</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Rejected By:</span>
                <span class="detail-value">$rejectedBy</span>
            </div>
        </div>

        <div class="reason-box">
            <strong>Rejection Reason:</strong><br><br>
            ${rejectionReason ?? 'No specific reason provided. Please contact your manager for more details.'}
        </div>

        <p>Please report to the office as per your regular schedule. If you have any concerns, please discuss with your manager.</p>
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

  /// Generate email for WFH request (sent to HR/Admins)
  static String generateRequestEmail({
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    String? employeeRole,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>New WFH Request</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { background: linear-gradient(135deg, #0d47a1, #1976d2); padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; }
        p { font-size: 15px; line-height: 1.7; margin-bottom: 16px; color: #4a4e57; }
        .section-title { font-size: 18px; font-weight: 600; color: #0d47a1; margin-bottom: 18px; border-bottom: 2px solid #e6e9ef; padding-bottom: 6px; }
        .wfh-details { background: #f8f9fc; padding: 22px; border-radius: 12px; border: 1px solid #e5e8ef; }
        .detail-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #e1e4ea; }
        .detail-row:last-child { border-bottom: none; }
        .detail-label { font-weight: 600; color: #666; }
        .detail-value { font-weight: 500; color: #333; }
        .reason-box { margin: 28px 0; background: #e3f2fd; border-left: 4px solid #1976d2; padding: 20px; border-radius: 10px; font-size: 14px; line-height: 1.6; }
        .cta-container { text-align: center; margin-top: 35px; }
        .dashboard-btn { background: #0d47a1; color: #ffffff; padding: 14px 36px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block; }
        .footer { margin-top: 40px; text-align: center; padding: 24px; background: #f0f2f6; }
        .footer p { font-size: 13px; color: #7a7e87; margin: 5px 0; }
    </style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>New WFH Request</h1>
    </div>
    <div class="content">
        <div class="greeting">Hello HR / Admin,</div>
        <p><strong>$employeeName</strong> has submitted a new Work From Home request. Details are below:</p>
        <h3 class="section-title">WFH Details</h3>
        <div class="wfh-details">
            <div class="detail-row"><span class="detail-label">Employee:</span> <span class="detail-value">$employeeName</span></div>
            ${employeeRole != null ? '<div class="detail-row"><span class="detail-label">Role:</span> <span class="detail-value">$employeeRole</span></div>' : ''}
            <div class="detail-row"><span class="detail-label">From Date:</span> <span class="detail-value">$fromDate</span></div>
            <div class="detail-row"><span class="detail-label">To Date:</span> <span class="detail-value">$toDate</span></div>
            <div class="detail-row"><span class="detail-label">Total Days:</span> <span class="detail-value">$totalDays</span></div>
        </div>
        <div class="reason-box"><strong>Reason:</strong><br><br>$reason</div>
        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" target="_blank" class="dashboard-btn">Open Admin Dashboard</a>
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

  /// Generate subject lines
  static String generateApprovalSubject(String dateRange) {
    return 'WFH Request Approved: $dateRange';
  }

  static String generateRejectionSubject(String dateRange) {
    return 'WFH Request Rejected: $dateRange';
  }

  static String generateRequestSubject(String employeeName) {
    return 'New WFH Request: $employeeName';
  }
}
