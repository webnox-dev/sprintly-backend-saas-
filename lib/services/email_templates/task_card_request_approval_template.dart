/// Task Card Request Approval/Rejection Email Templates
/// Handles: Task request Approved, Rejected by admin
class TaskCardRequestApprovalTemplate {
  /// Generate email for task card request approval
  static String generateApprovalEmail({
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String priorityLevel,
    required String projectName,
    required String fromDate,
    required String toDate,
    required String approvedBy,
    String? remarks,
  }) {
    final priorityClass = 'priority-${priorityLevel.toLowerCase()}';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Task Request Approved</title>
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
        .task-details {
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
        .priority-high {
            background: #c62828;
            color: #fff;
            padding: 5px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .priority-medium {
            background: #f9a825;
            color: #2b2d33;
            padding: 5px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .priority-low {
            background: #2e7d32;
            color: #ffffff;
            padding: 5px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
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
        .description-box {
            margin: 28px 0;
            background: #ffffff;
            border: 1px solid #dfe3eb;
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
        <h1>Task Request Approved</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>Great news! Your task request has been approved and a task card has been created for you.</p>

        <div class="status-badge">APPROVED</div>

        <h3 class="section-title">Task Details</h3>

        <div class="task-details">
            <div class="detail-row">
                <span class="detail-label">Task Name:</span>
                <span class="detail-value">$taskName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Task Type:</span>
                <span class="detail-value">$taskType</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Priority:</span>
                <span class="detail-value">
                    <span class="$priorityClass">$priorityLevel</span>
                </span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Start Date:</span>
                <span class="detail-value">$fromDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">End Date:</span>
                <span class="detail-value">$toDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Approved By:</span>
                <span class="detail-value">$approvedBy</span>
            </div>
        </div>

        <div class="description-box">
            <strong>Task Description:</strong><br><br>
            $taskDescription
        </div>

        ${remarks != null && remarks.isNotEmpty ? '''
        <div class="remarks-box">
            <strong>Admin Remarks:</strong><br><br>
            $remarks
        </div>
        ''' : ''}

        <p>You can now find this task in your task list. Please review and start working on it.</p>

        <div class="cta-container">
            <a href="https://employee-sprintly.webnoxdigital.com/" 
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

  /// Generate email for task card request rejection
  static String generateRejectionEmail({
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String projectName,
    required String fromDate,
    required String toDate,
    required String rejectedBy,
    String? rejectionReason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Task Request Rejected</title>
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
        .task-details {
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
        .description-box {
            margin: 28px 0;
            background: #ffffff;
            border: 1px solid #dfe3eb;
            padding: 20px;
            border-radius: 10px;
            font-size: 14px;
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
        <h1>Task Request Rejected</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>

        <p>We regret to inform you that your task request has been rejected.</p>

        <div class="status-badge">REJECTED</div>

        <h3 class="section-title">Request Details</h3>

        <div class="task-details">
            <div class="detail-row">
                <span class="detail-label">Task Name:</span>
                <span class="detail-value">$taskName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Task Type:</span>
                <span class="detail-value">$taskType</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Requested Period:</span>
                <span class="detail-value">$fromDate - $toDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Rejected By:</span>
                <span class="detail-value">$rejectedBy</span>
            </div>
        </div>

        <div class="description-box">
            <strong>Task Description:</strong><br><br>
            $taskDescription
        </div>

        <div class="reason-box">
            <strong>Rejection Reason:</strong><br><br>
            ${rejectionReason ?? 'No specific reason provided. Please contact your manager for more details.'}
        </div>

        <p>If you have any questions or would like to submit a revised request, please contact your manager or team lead.</p>
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
  static String generateApprovalSubject(String taskName) {
    return 'Task Request Approved: $taskName';
  }

  static String generateRejectionSubject(String taskName) {
    return 'Task Request Rejected: $taskName';
  }
}
