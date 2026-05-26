class TaskCardRequestEmailTemplate {
  static String generateEmailContent({
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String priorityLevel,
    required String projectName,
    required String assignedBy,
    required String fromDate,
    required String toDate,
    required String taskDuration,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Task Request Notification</title>
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
            background: linear-gradient(135deg, #4a148c, #7b1fa2);
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
        .section-title {
            font-size: 18px;
            font-weight: 600;
            color: #6a1b9a;
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
        }
        .detail-value {
            font-weight: 500;
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
            background: #6a1b9a;
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
        }
    </style>
</head>

<body>
<div class="email-wrapper">
    <div class="header">
        <h1>New Task Request Notification</h1>
    </div>

    <div class="content">
        <div class="greeting">
            Hello Webnox Admins,
        </div>

        <p>
            <strong>$employeeName</strong> has requested a new task card.
            Please review the task details below and take the necessary action
            from the Admin Dashboard.
        </p>

        <h3 class="section-title">Requested Task Details</h3>

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
                    <span class="priority-${priorityLevel.toLowerCase()}">
                        $priorityLevel
                    </span>
                </span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Requested Duration:</span>
                <span class="detail-value">$taskDuration</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Proposed Start:</span>
                <span class="detail-value">$fromDate</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Proposed End:</span>
                <span class="detail-value">$toDate</span>
            </div>
        </div>

        <div class="description-box">
            <strong>Task Description:</strong><br><br>
            $taskDescription
        </div>

        <p>
            To approve, modify, or manage this request, please visit the Admin Dashboard.
        </p>

        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" 
               target="_blank"
               class="dashboard-btn">
                Go to Admin Dashboard
            </a>
        </div>
    </div>

    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>© Webnox Technologies Pvt Ltd</p>
    </div>
</div>
</body>
</html>
    ''';
  }

  static String generateEmailSubject({
    required String taskName,
    required String projectName,
  }) {
    return 'New Task Assigned: $taskName - $projectName';
  }
}
