/// Task Card Email Templates
/// Handles: Created, Updated, Deleted, Duplicated, Reassigned
class TaskCardEmailTemplate {
  /// Generate email for task card creation
  static String generateTaskCreatedEmail({
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
    return _generateBaseTemplate(
      headerTitle: 'New Task Assigned',
      headerGradient: 'linear-gradient(135deg, #4a148c, #7b1fa2)',
      greeting: 'Hello $employeeName,',
      introText:
          'A new task has been assigned to you. Please review the details below and take necessary action.',
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: assignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      actionText:
          'Please log in to your Sprintly dashboard to accept or view this task.',
    );
  }

  /// Generate email for task card update
  static String generateTaskUpdatedEmail({
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String priorityLevel,
    required String projectName,
    required String updatedBy,
    required String fromDate,
    required String toDate,
    required String taskDuration,
    String? changesDescription,
  }) {
    return _generateBaseTemplate(
      headerTitle: 'Task Updated',
      headerGradient: 'linear-gradient(135deg, #1565c0, #1e88e5)',
      greeting: 'Hello $employeeName,',
      introText:
          'Your assigned task has been updated${changesDescription != null ? ': $changesDescription' : '.'}',
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: updatedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      actionText:
          'Please review the updated task details in your Sprintly dashboard.',
      assignedByLabel: 'Updated By',
    );
  }

  /// Generate email for task card deletion
  static String generateTaskDeletedEmail({
    required String employeeName,
    required String taskName,
    required String projectName,
    required String deletedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Task Deleted</title>
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
        text-align: center;
    }
    .header h1 {
        margin: 0;
        font-size: 28px;
        font-weight: 700;
        color: #ffffff;
    }
    .content {
        padding: 40px;
    }
    .greeting {
        font-size: 18px;
        font-weight: 500;
        margin-bottom: 20px;
    }
    p {
        font-size: 15px;
        line-height: 1.7;
        margin-bottom: 20px;
        color: #4a4e57;
    }
    .info-box {
        background: #fff7f6;
        border-left: 4px solid #ef5350;
        border-radius: 12px;
        padding: 20px;
        margin: 25px 0;
        box-shadow: 0 2px 6px rgba(0,0,0,0.03);
    }
    .detail-row {
        display: flex;
        justify-content: space-between;
        padding: 12px 0;
        border-bottom: 1px solid #f0f2f6;
    }
    .detail-row:nth-child(even) { background: #fff1f0; border-radius: 6px; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label {
        font-weight: 600;
        color: #666;
    }
    .detail-value {
        font-weight: 500;
        color: #333;
        text-align: right;
        word-break: break-word;
        max-width: 65%;
    }
    .cta-container {
        text-align: center;
        margin-top: 30px;
    }
    .dashboard-btn {
        background: #ef5350;
        color: #fff;
        padding: 14px 40px;
        border-radius: 8px;
        text-decoration: none;
        font-weight: 600;
        display: inline-block;
        box-shadow: 0 4px 15px rgba(239,83,80,0.3);
        transition: all 0.3s ease;
    }
    .dashboard-btn:hover {
        background: #c62828;
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(239,83,80,0.4);
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

    @media(max-width:600px) {
        .email-wrapper { width: 95%; margin: 20px auto; }
        .header h1 { font-size: 24px; }
        .content { padding: 25px; }
        .greeting { font-size: 16px; }
        .dashboard-btn { padding: 12px 28px; }
    }
</style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>Task Deleted</h1>
    </div>
    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>
        <p>
            A task that was assigned to you has been deleted from the system. Please review the details below.
        </p>

        <div class="info-box">
            <div class="detail-row">
                <span class="detail-label">Task Name:</span>
                <span class="detail-value">$taskName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Deleted By:</span>
                <span class="detail-value">$deletedBy</span>
            </div>
            ${reason != null ? '''
            <div class="detail-row">
                <span class="detail-label">Reason:</span>
                <span class="detail-value">$reason</span>
            </div>
            ''' : ''}
        </div>

        <p>
            If you have any questions about this action, please contact your project manager or admin.
        </p>

        <div class="cta-container">
            <a href="https://employee-sprintly.webnoxdigital.com/" target="_blank" class="dashboard-btn">Go to Employee Dashboard</a>
        </div>
    </div>
    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>A Product by Mobile App Team.</p>
        <p>Webnox Technologies Pvt Ltd</p>
    </div>
</div>
</body>
</html>

    ''';
  }

  /// Generate email for task card duplication
  static String generateTaskDuplicatedEmail({
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
    required String originalTaskName,
  }) {
    return _generateBaseTemplate(
      headerTitle: 'New Task Assigned (Duplicated)',
      headerGradient: 'linear-gradient(135deg, #6a1b9a, #ab47bc)',
      greeting: 'Hello $employeeName,',
      introText:
          'A new task has been created for you based on "$originalTaskName". Please review the details below.',
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: assignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      actionText:
          'Please log in to your Sprintly dashboard to view and accept this task.',
    );
  }

  /// Generate email for task reassignment (sent to new assignee)
  static String generateTaskReassignedToNewEmail({
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String priorityLevel,
    required String projectName,
    required String reassignedBy,
    required String fromDate,
    required String toDate,
    required String taskDuration,
    required String previousAssignee,
  }) {
    return _generateBaseTemplate(
      headerTitle: 'Task Reassigned to You',
      headerGradient: 'linear-gradient(135deg, #2e7d32, #43a047)',
      greeting: 'Hello $employeeName,',
      introText:
          'A task has been reassigned to you from $previousAssignee. Please review the details below.',
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: reassignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      actionText:
          'Please log in to your Sprintly dashboard to accept this task.',
      assignedByLabel: 'Reassigned By',
    );
  }

  /// Generate email for task reassignment (sent to previous assignee)
  static String generateTaskReassignedFromEmail({
    required String employeeName,
    required String taskName,
    required String projectName,
    required String reassignedBy,
    required String newAssignee,
    String? reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Task Reassigned</title>
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
    /* Header */
    .header {
        background: linear-gradient(135deg, #ff6f00, #ffa000);
        padding: 35px 40px;
        text-align: center;
        box-shadow: inset 0 -4px 0 rgba(0,0,0,0.05);
    }
    .header h1 {
        margin: 0;
        font-size: 28px;
        font-weight: 700;
        color: #ffffff;
    }
    /* Content */
    .content {
        padding: 40px;
    }
    .greeting {
        font-size: 18px;
        font-weight: 500;
        margin-bottom: 20px;
    }
    p {
        font-size: 15px;
        line-height: 1.7;
        margin-bottom: 20px;
        color: #4a4e57;
    }
    /* Info box */
    .info-box {
        background: #e3f2fd;
        border-left: 4px solid #1976d2;
        border-radius: 12px;
        padding: 20px;
        margin: 25px 0;
        box-shadow: 0 2px 6px rgba(0,0,0,0.03);
    }
    .detail-row {
        display: flex;
        justify-content: space-between;
        padding: 12px 0;
        border-bottom: 1px solid #f0f2f6;
    }
    .detail-row:nth-child(even) { background: #d0e3fc; border-radius: 6px; }
    .detail-row:last-child { border-bottom: none; }
    .detail-label {
        font-weight: 600;
        color: #666;
    }
    .detail-value {
        font-weight: 500;
        color: #333;
        text-align: right;
        word-break: break-word;
        max-width: 65%;
    }
    /* CTA button */
    .cta-container {
        text-align: center;
        margin-top: 30px;
    }
    .dashboard-btn {
        background: #1976d2;
        color: #fff;
        padding: 14px 40px;
        border-radius: 8px;
        text-decoration: none;
        font-weight: 600;
        display: inline-block;
        box-shadow: 0 4px 15px rgba(25,118,210,0.3);
        transition: all 0.3s ease;
    }
    .dashboard-btn:hover {
        background: #125aa1;
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(25,118,210,0.4);
    }
    /* Footer */
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
    /* Responsive */
    @media(max-width:600px) {
        .email-wrapper { width: 95%; margin: 20px auto; }
        .header h1 { font-size: 24px; }
        .content { padding: 25px; }
        .greeting { font-size: 16px; }
        .dashboard-btn { padding: 12px 28px; }
    }
</style>
</head>
<body>
<div class="email-wrapper">
    <div class="header">
        <h1>Task Reassigned</h1>
    </div>
    <div class="content">
        <div class="greeting">
            Hello $employeeName,
        </div>
        <p>
            A task previously assigned to you has been reassigned to another team member. Please find the details below.
        </p>

        <div class="info-box">
            <div class="detail-row">
                <span class="detail-label">Task Name:</span>
                <span class="detail-value">$taskName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">New Assignee:</span>
                <span class="detail-value">$newAssignee</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Reassigned By:</span>
                <span class="detail-value">$reassignedBy</span>
            </div>
            ${reason != null ? '''
            <div class="detail-row">
                <span class="detail-label">Reason:</span>
                <span class="detail-value">$reason</span>
            </div>
            ''' : ''}
        </div>

        <p>
            This task has been removed from your task list. If you have any questions, please contact your project manager.
        </p>

        <div class="cta-container">
            <a href="https://employee-sprintly.webnoxdigital.com" target="_blank" class="dashboard-btn">Go to Employee Dashboard</a>
        </div>
    </div>
    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>A Product by Webnox Mobile App Team</p>
        <p>Webnox Technologies Pvt Ltd</p>
    </div>
</div>
</body>
</html>
    ''';
  }

  /// Base template generator for task emails
  static String _generateBaseTemplate({
    required String headerTitle,
    required String headerGradient,
    required String greeting,
    required String introText,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String priorityLevel,
    required String projectName,
    required String assignedBy,
    required String fromDate,
    required String toDate,
    required String taskDuration,
    required String actionText,
    String assignedByLabel = 'Assigned By',
  }) {
    final priorityClass = 'priority-${priorityLevel.toLowerCase()}';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$headerTitle</title>
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
            background: $headerGradient;
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
            background: #4a148c;
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
        <h1>$headerTitle</h1>
    </div>

    <div class="content">
        <div class="greeting">
            $greeting
        </div>

        <p>$introText</p>

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
                <span class="detail-label">Duration:</span>
                <span class="detail-value">$taskDuration</span>
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
                <span class="detail-label">$assignedByLabel:</span>
                <span class="detail-value">$assignedBy</span>
            </div>
        </div>

        <div class="description-box">
            <strong>Task Description:</strong><br><br>
            $taskDescription
        </div>

        <p>$actionText</p>

        <div class="cta-container">
            <a href="https://sprintlyadmin.webnoxdigital.com/" 
               target="_blank"
               class="dashboard-btn">
                Go to Dashboard
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

  /// Generate subject lines
  static String generateCreatedSubject(String taskName, String projectName) {
    return 'New Task Assigned: $taskName - $projectName';
  }

  static String generateUpdatedSubject(String taskName, String projectName) {
    return 'Task Updated: $taskName - $projectName';
  }

  static String generateDeletedSubject(String taskName) {
    return 'Task Deleted: $taskName';
  }

  static String generateDuplicatedSubject(String taskName, String projectName) {
    return 'New Task Assigned (Duplicated): $taskName - $projectName';
  }

  static String generateReassignedSubject(String taskName, String projectName) {
    return 'Task Reassigned: $taskName - $projectName';
  }

  static String generateQaApprovedSubject(String taskName) {
    return 'Task Approved: $taskName';
  }

  static String generateQaRejectedSubject(String taskName) {
    return 'Task Sent for Redo: $taskName';
  }

  /// QA Approved – task passed QC
  static String generateTaskQaApprovedEmail({
    required String employeeName,
    required String taskName,
    required String projectName,
    required String approvedBy,
    String? notes,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>Task Approved</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>
<style>body{margin:0;background:#eef1f5;padding:30px 0;font-family:'Poppins',sans-serif;color:#2b2d33;}
.email-wrapper{max-width:680px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 8px 28px rgba(0,0,0,.08);}
.header{background:linear-gradient(135deg,#2e7d32,#43a047);padding:35px 40px;} .header h1{margin:0;font-size:26px;font-weight:600;color:#fff;}
.content{padding:40px;} .greeting{font-size:17px;font-weight:500;margin-bottom:15px;}
p{font-size:15px;line-height:1.7;margin-bottom:16px;color:#4a4e57;}
.status-badge{display:inline-block;background:#e8f5e9;color:#2e7d32;padding:8px 20px;border-radius:25px;font-weight:600;font-size:14px;margin:15px 0;}
.detail-row{display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid #e1e4ea;}
.detail-label{font-weight:500;color:#555;} .detail-value{color:#222;}
.cta-container{text-align:center;margin-top:28px;}
.dashboard-btn{display:inline-block;background:#2e7d32;color:#fff!important;padding:14px 28px;border-radius:8px;text-decoration:none;font-weight:600;}
.footer{text-align:center;padding:24px;color:#888;font-size:13px;}</style></head>
<body><div class="email-wrapper">
<div class="header"><h1>Task Approved</h1></div>
<div class="content">
<p class="greeting">Hello $employeeName,</p>
<p>Your task <strong>$taskName</strong> for project <strong>$projectName</strong> has been <strong>approved</strong> by QA.</p>
<div class="status-badge">APPROVED</div>
<div class="detail-row"><span class="detail-label">Approved by</span><span class="detail-value">$approvedBy</span></div>
${notes != null && notes.isNotEmpty ? '<div class="detail-row"><span class="detail-label">Notes</span><span class="detail-value">$notes</span></div>' : ''}
<p>Great work! Please log in to your Sprintly dashboard for more details.</p>
<div class="cta-container"><a href="https://employee-sprintly.webnoxdigital.com" class="dashboard-btn">Go to Dashboard</a></div>
</div><div class="footer"><p>Webnox Sprintly – automated notification</p></div></div></body></html>''';
  }

  /// QA Rejected – task sent for redo
  static String generateTaskQaRejectedEmail({
    required String employeeName,
    required String taskName,
    required String projectName,
    required String rejectedBy,
    required String notes,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>Task Sent for Redo</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>
<style>body{margin:0;background:#eef1f5;padding:30px 0;font-family:'Poppins',sans-serif;color:#2b2d33;}
.email-wrapper{max-width:680px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 8px 28px rgba(0,0,0,.08);}
.header{background:linear-gradient(135deg,#c62828,#ef5350);padding:35px 40px;} .header h1{margin:0;font-size:26px;font-weight:600;color:#fff;}
.content{padding:40px;} .greeting{font-size:17px;font-weight:500;margin-bottom:15px;}
p{font-size:15px;line-height:1.7;margin-bottom:16px;color:#4a4e57;}
.status-badge{display:inline-block;background:#ffebee;color:#c62828;padding:8px 20px;border-radius:25px;font-weight:600;font-size:14px;margin:15px 0;}
.detail-row{display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid #e1e4ea;}
.detail-label{font-weight:500;color:#555;} .detail-value{color:#222;}
.cta-container{text-align:center;margin-top:28px;}
.dashboard-btn{display:inline-block;background:#1565c0;color:#fff!important;padding:14px 28px;border-radius:8px;text-decoration:none;font-weight:600;}
.footer{text-align:center;padding:24px;color:#888;font-size:13px;}</style></head>
<body><div class="email-wrapper">
<div class="header"><h1>Task Sent for Redo</h1></div>
<div class="content">
<p class="greeting">Hello $employeeName,</p>
<p>Your task <strong>$taskName</strong> for project <strong>$projectName</strong> has been <strong>sent for redo</strong> by QA.</p>
<div class="status-badge">REDO</div>
<div class="detail-row"><span class="detail-label">Feedback by</span><span class="detail-value">$rejectedBy</span></div>
<div class="detail-row"><span class="detail-label">Reason / Notes</span><span class="detail-value">$notes</span></div>
<p>Please review the feedback, make the necessary changes, and resubmit. Log in to your Sprintly dashboard for details.</p>
<div class="cta-container"><a href="https://employee-sprintly.webnoxdigital.com" class="dashboard-btn">Go to Dashboard</a></div>
</div><div class="footer"><p>Webnox Sprintly – automated notification</p></div></div></body></html>''';
  }
}
