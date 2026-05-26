/// Leave Request Email Templates
/// Handles: Approved, Rejected
class LeaveRequestEmailTemplate {
  /// Generate email for leave approval
  static String generateApprovalEmail({
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String approvedBy,
    String? remarks,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Leave Request Approved</title>
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
            background: linear-gradient(135deg, #2e7d32, #43a047);
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
            background: #e8f5e9;
            color: #2e7d32;
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
        .leave-details {
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
        .remarks-box {
            margin: 28px 0;
            background: #e8f5e9;
            border-left: 4px solid #2e7d32;
            padding: 20px;
            border-radius: 10px;
            font-size: 14px;
            line-height: 1.6;
        }
        .cta-container {
            text-align: center;
            margin-top: 35px;
        }
        .dashboard-btn {
            background: #2e7d32;
            color: #ffffff;
            padding: 14px 36px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            font-size: 15px;
            display: inline-block;
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
        <h1>Leave Request Approved</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>Great news! Your leave request has been approved.</p>

        <div class="status-badge">APPROVED</div>

        <h3 class="section-title">Leave Details</h3>

        <div class="leave-details">
            <div class="detail-row">
                <span class="detail-label">Leave Type:</span>
                <span class="detail-value">$leaveType</span>
            </div>
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

        ${remarks != null && remarks.isNotEmpty ? '''
        <div class="remarks-box">
            <strong>Remarks:</strong><br><br>
            $remarks
        </div>
        ''' : ''}

        <p>Please ensure you complete any pending work and handover responsibilities before your leave begins.</p>

        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" 
               target="_blank"
               class="dashboard-btn">
                View in Dashboard
            </a>
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

  /// Generate email for leave rejection
  static String generateRejectionEmail({
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String rejectedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Leave Request Rejected</title>
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
        .leave-details {
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
        .cta-container {
            text-align: center;
            margin-top: 35px;
        }
        .dashboard-btn {
            background: #1976d2;
            color: #ffffff;
            padding: 14px 36px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            font-size: 15px;
            display: inline-block;
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
        <h1>Leave Request Rejected</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>We regret to inform you that your leave request has been rejected.</p>

        <div class="status-badge">REJECTED</div>

        <h3 class="section-title">Leave Details</h3>

        <div class="leave-details">
            <div class="detail-row">
                <span class="detail-label">Leave Type:</span>
                <span class="detail-value">$leaveType</span>
            </div>
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

        ${reason != null && reason.isNotEmpty ? '''
        <div class="reason-box">
            <strong>Reason for Rejection:</strong><br><br>
            $reason
        </div>
        ''' : '''
        <div class="reason-box">
            <strong>Reason for Rejection:</strong><br><br>
            No specific reason provided. Please contact your manager for more details.
        </div>
        '''}

        <p>If you have any questions or would like to discuss this further, please contact your manager or HR.</p>

        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" 
               target="_blank"
               class="dashboard-btn">
                View in Dashboard
            </a>
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

  /// Generate email for leave request (sent to HR/Admins)
  static String generateRequestEmail({
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    bool isPaidLeave = false,
    bool isHalfDay = false,
    String? halfDayType,
  }) {
    final paidText = isPaidLeave ? 'Yes' : 'No';
    final halfDayText = isHalfDay ? (halfDayType ?? 'Yes') : 'No';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>New Leave Request</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { background: linear-gradient(135deg, #1e40af, #3b82f6); padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; }
        p { font-size: 15px; line-height: 1.7; margin-bottom: 16px; color: #4a4e57; }
        .section-title { font-size: 18px; font-weight: 600; color: #1e40af; margin-bottom: 18px; border-bottom: 2px solid #e6e9ef; padding-bottom: 6px; }
        .leave-details { background: #f8f9fc; padding: 22px; border-radius: 12px; border: 1px solid #e5e8ef; }
        .detail-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #e1e4ea; }
        .detail-row:last-child { border-bottom: none; }
        .detail-label { font-weight: 600; color: #666; }
        .detail-value { font-weight: 500; color: #333; }
        .reason-box { margin: 28px 0; background: #f0f7ff; border-left: 4px solid #3b82f6; padding: 20px; border-radius: 10px; font-size: 14px; line-height: 1.6; }
        .cta-container { text-align: center; margin-top: 35px; }
        .dashboard-btn { background: #1e40af; color: #ffffff; padding: 14px 36px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block; }
        .footer { margin-top: 40px; text-align: center; padding: 24px; background: #f0f2f6; }
        .footer p { font-size: 13px; color: #7a7e87; margin: 5px 0; }
    </style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>New Leave Request</h1>
    </div>
    <div class="content">
        <div class="greeting">Hello HR / Admin,</div>
        <p><strong>$employeeName</strong> has submitted a new leave request. Details are below:</p>
        <h3 class="section-title">Leave Details</h3>
        <div class="leave-details">
            <div class="detail-row"><span class="detail-label">Employee:</span> <span class="detail-value">$employeeName</span></div>
            <div class="detail-row"><span class="detail-label">Leave Type:</span> <span class="detail-value">$leaveType</span></div>
            <div class="detail-row"><span class="detail-label">From Date:</span> <span class="detail-value">$fromDate</span></div>
            <div class="detail-row"><span class="detail-label">To Date:</span> <span class="detail-value">$toDate</span></div>
            <div class="detail-row"><span class="detail-label">Total Days:</span> <span class="detail-value">$totalDays</span></div>
            <div class="detail-row"><span class="detail-label">Paid Leave:</span> <span class="detail-value">$paidText</span></div>
            <div class="detail-row"><span class="detail-label">Half Day:</span> <span class="detail-value">$halfDayText</span></div>
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
  static String generateApprovalSubject(String leaveType) {
    return 'Leave Request Approved: $leaveType';
  }

  static String generateRejectionSubject(String leaveType) {
    return 'Leave Request Rejected: $leaveType';
  }

  static String generateRequestSubject(String employeeName, String leaveType) {
    return 'New Leave Request: $employeeName ($leaveType)';
  }
}
