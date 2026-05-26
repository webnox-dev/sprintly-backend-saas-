/// Project Email Templates
/// Handles: Created, Updated, Deleted, Discontinued
class ProjectEmailTemplate {
  /// Generate email for project creation
  static String generateProjectCreatedEmail({
    required String recipientName,
    required String projectName,
    required String projectDescription,
    required String priorityLevel,
    required String status,
    required String startDate,
    required String endDate,
    required String projectManager,
    required String teamLead,
    required String createdBy,
    String recipientRole = 'Team Member',
  }) {
    return _generateBaseTemplate(
      headerTitle: 'New Project Created',
      headerGradient: 'linear-gradient(135deg, #1565c0, #1e88e5)',
      greeting: 'Hello $recipientName,',
      introText:
          'A new project has been created and you have been assigned as <strong>$recipientRole</strong>.',
      projectName: projectName,
      projectDescription: projectDescription,
      priorityLevel: priorityLevel,
      status: status,
      startDate: startDate,
      endDate: endDate,
      projectManager: projectManager,
      teamLead: teamLead,
      actionBy: createdBy,
      actionByLabel: 'Created By',
      actionText:
          'Please log in to your dashboard to view the complete project details and start collaborating with your team.',
    );
  }

  /// Generate email for project update
  static String generateProjectUpdatedEmail({
    required String recipientName,
    required String projectName,
    required String projectDescription,
    required String priorityLevel,
    required String status,
    required String startDate,
    required String endDate,
    required String projectManager,
    required String teamLead,
    required String updatedBy,
    String? changesDescription,
    String recipientRole = 'Team Member',
  }) {
    return _generateBaseTemplate(
      headerTitle: 'Project Updated',
      headerGradient: 'linear-gradient(135deg, #ff6f00, #ffa000)',
      greeting: 'Hello $recipientName,',
      introText:
          'The project "<strong>$projectName</strong>" has been updated${changesDescription != null ? ": $changesDescription" : "."}',
      projectName: projectName,
      projectDescription: projectDescription,
      priorityLevel: priorityLevel,
      status: status,
      startDate: startDate,
      endDate: endDate,
      projectManager: projectManager,
      teamLead: teamLead,
      actionBy: updatedBy,
      actionByLabel: 'Updated By',
      actionText:
          'Please review the updated project details in your dashboard.',
    );
  }

  /// Generate email for project deletion
  static String generateProjectDeletedEmail({
    required String recipientName,
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
    <title>Project Deleted</title>
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
        .info-box {
            background: #fff3e0;
            border-left: 4px solid #ff9800;
            padding: 20px;
            border-radius: 10px;
            margin: 25px 0;
        }
        .detail-row {
            padding: 12px 0;
            border-bottom: 1px solid #e1e4ea;
        }
        .detail-label {
            font-weight: 600;
            color: #666;
        }
        .detail-value {
            font-weight: 500;
            color: #333;
            margin-left: 10px;
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
        <h1>Project Deleted</h1>
    </div>
    <div class="content">
        <div class="greeting">
            Hello $recipientName,
        </div>
        <p>
            The project "<strong>$projectName</strong>" has been deleted from the system.
        </p>
        <div class="info-box">
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Deleted By:</span>
                <span class="detail-value">$deletedBy</span>
            </div>
            ${reason != null && reason.isNotEmpty ? '''
            <div class="detail-row" style="border-bottom: none;">
                <span class="detail-label">Reason:</span>
                <span class="detail-value">$reason</span>
            </div>
            ''' : ''}
        </div>
        <p>
            All associated tasks and resources have been archived. If you have any questions, please contact your manager.
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

  /// Generate email for project discontinuation
  static String generateProjectDiscontinuedEmail({
    required String recipientName,
    required String projectName,
    required String discontinuedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Project Discontinued</title>
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
            background: #fff3e0;
            color: #e65100;
            padding: 8px 20px;
            border-radius: 25px;
            font-weight: 600;
            font-size: 14px;
            margin: 15px 0;
        }
        .info-box {
            background: #fff3e0;
            border-left: 4px solid #e65100;
            padding: 20px;
            border-radius: 10px;
            margin: 25px 0;
        }
        .detail-row {
            padding: 12px 0;
            border-bottom: 1px solid #e1e4ea;
        }
        .detail-label {
            font-weight: 600;
            color: #666;
        }
        .detail-value {
            font-weight: 500;
            color: #333;
            margin-left: 10px;
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
        <h1>Project Discontinued</h1>
    </div>
    <div class="content">
        <div class="greeting">
            Hello $recipientName,
        </div>
        <p>
            We would like to inform you that the project you were associated with has been discontinued.
        </p>
        
        <div class="status-badge">DISCONTINUED</div>
        
        <div class="info-box">
            <div class="detail-row">
                <span class="detail-label">Project:</span>
                <span class="detail-value">$projectName</span>
            </div>
            <div class="detail-row">
                <span class="detail-label">Discontinued By:</span>
                <span class="detail-value">$discontinuedBy</span>
            </div>
            ${reason != null && reason.isNotEmpty ? '''
            <div class="detail-row" style="border-bottom: none;">
                <span class="detail-label">Reason:</span>
                <span class="detail-value">$reason</span>
            </div>
            ''' : ''}
        </div>
        <p>
            Your active tasks on this project will be reviewed by your manager. Please await further instructions regarding task reassignment.
        </p>
        <p>
            If you have any questions, please contact your project manager or HR.
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

  /// Base template for project emails
  static String _generateBaseTemplate({
    required String headerTitle,
    required String headerGradient,
    required String greeting,
    required String introText,
    required String projectName,
    required String projectDescription,
    required String priorityLevel,
    required String status,
    required String startDate,
    required String endDate,
    required String projectManager,
    required String teamLead,
    required String actionBy,
    required String actionByLabel,
    required String actionText,
  }) {
    final priorityClass = 'priority-${priorityLevel.toLowerCase()}';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$headerTitle</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
    body {
        margin:0;
        padding:0;
        font-family:'Poppins', sans-serif;
        background:#f4f6fa;
        color:#4a4e57;
    }

    .email-wrapper {
        max-width:600px;
        margin:50px auto;
        background:#fff;
        border-radius:12px;
        overflow:hidden;
        box-shadow:0 6px 25px rgba(0,0,0,0.08);
        position: relative;
    }

    /* Header */
    .header {
        background: linear-gradient(135deg, #1565c0, #42a5f5);
        padding:50px 20px;
        text-align:center;
        border-bottom-left-radius:12px;
        border-bottom-right-radius:12px;
    }
    .header h1 {
        color:#fff;
        margin:0;
        font-size:28px;
        font-weight:700;
    }
    .header p {
        color:rgba(255,255,255,0.9);
        font-size:16px;
        margin-top:10px;
        line-height:1.4;
    }

    /* Content */
    .content {
        padding:30px 25px;
    }
    .greeting {
        font-size:16px;
        font-weight:500;
        margin-bottom:20px;
    }
    p {
        font-size:15px;
        line-height:1.7;
        margin-bottom:18px;
        color:#4a4e57;
    }
    .section-title {
        font-size:18px;
        font-weight:600;
        margin-bottom:12px;
        color:#333;
        border-left:4px solid #1565c0;
        padding-left:10px;
    }

    /* Project details */
    .project-details {
        background:#f8f9fc;
        border-radius:10px;
        padding:20px;
        border:1px solid #e2e5eb;
        margin-bottom:20px;
    }
    .detail-row {
        display:flex;
        justify-content:space-between;
        padding:12px 0;
        border-bottom:1px solid #e1e4ea;
    }
    .detail-row:last-child { border-bottom:none; }
    .detail-label { font-weight:600; color:#555; }
    .detail-value { font-weight:500; color:#333; text-align:right; max-width:65%; word-break:break-word; }

    .status-badge {
        background:linear-gradient(90deg, #42a5f5, #1565c0);
        color:#fff;
        padding:6px 14px;
        border-radius:20px;
        font-size:12px;
        font-weight:600;
        display:inline-block;
    }
    .priority-high { background:#e53935; color:#fff; padding:6px 14px; border-radius:20px; font-size:12px; font-weight:600; }
    .priority-medium { background:#fb8c00; color:#fff; padding:6px 14px; border-radius:20px; font-size:12px; font-weight:600; }
    .priority-low { background:#43a047; color:#fff; padding:6px 14px; border-radius:20px; font-size:12px; font-weight:600; }

    /* Description box */
    .description-box {
        background:#fff;
        border:1px solid #e2e5eb;
        border-radius:10px;
        padding:20px;
        margin:20px 0;
        font-size:14px;
        line-height:1.7;
        box-shadow:0 2px 6px rgba(0,0,0,0.05);
    }

    /* CTA button */
    .cta-container { text-align:center; margin-top:30px; }
    .dashboard-btn {
        background:#1565c0;
        color:#fff;
        padding:14px 40px;
        border-radius:8px;
        text-decoration:none;
        font-weight:600;
        display:inline-block;
        box-shadow:0 4px 15px rgba(21,101,192,0.3);
        transition: all 0.3s ease;
        cursor:pointer;
    }
    .dashboard-btn:hover {
        background:#0f4a99;
        transform: translateY(-2px);
        box-shadow:0 6px 20px rgba(21,101,192,0.4);
    }

    /* Footer */
    .footer {
        text-align:center;
        padding:25px 20px;
        font-size:12px;
        color:#7a7e87;
        border-top:1px solid #e4e7ed;
    }

    /* Dialog overlay */
    .dialog-overlay {
        position: fixed;
        top:0; left:0; right:0; bottom:0;
        background: rgba(0,0,0,0.4);
        display:none;
        align-items:center;
        justify-content:center;
        z-index:1000;
    }
    .dialog-box {
        background:#fff;
        padding:30px 25px;
        border-radius:12px;
        text-align:center;
        max-width:400px;
        width:90%;
        box-shadow:0 6px 25px rgba(0,0,0,0.15);
    }
    .dialog-box h2 { margin-bottom:20px; color:#333; }
    .dialog-btn {
        display:inline-block;
        padding:12px 28px;
        margin:10px;
        border-radius:8px;
        text-decoration:none;
        font-weight:600;
        color:#fff;
        transition:0.3s;
    }
    .admin-btn { background:#1565c0; }
    .admin-btn:hover { background:#0f4a99; }
    .employee-btn { background:#43a047; }
    .employee-btn:hover { background:#2e7d32; }

    @media(max-width:600px) {
        .email-wrapper { width:100%; margin:20px 10px; }
        .header h1 { font-size:22px; }
        .header p { font-size:14px; }
        .content { padding:20px; }
    }
</style>
</head>
<body>

<div class="email-wrapper">

    <!-- Header -->
    <div class="header">
        <h1>$headerTitle</h1>
        <p>'A new project has been added to our daily progress'</p>
    </div>

    <!-- Content -->
    <div class="content">
        <div class="greeting">$greeting</div>
        <p>$introText</p>

        <div class="section-title">Project Details</div>
        <div class="project-details">
            <div class="detail-row"><span class="detail-label">Project Name:</span><span class="detail-value">$projectName</span></div>
            <div class="detail-row"><span class="detail-label">Status:</span><span class="detail-value"><span class="status-badge">$status</span></span></div>
            <div class="detail-row"><span class="detail-label">Priority:</span><span class="detail-value"><span class="$priorityClass">$priorityLevel</span></span></div>
            <div class="detail-row"><span class="detail-label">Start Date:</span><span class="detail-value">$startDate</span></div>
            <div class="detail-row"><span class="detail-label">End Date:</span><span class="detail-value">$endDate</span></div>
            <div class="detail-row"><span class="detail-label">Project Manager:</span><span class="detail-value">$projectManager</span></div>
            <div class="detail-row"><span class="detail-label">Team Lead:</span><span class="detail-value">$teamLead</span></div>
            <div class="detail-row"><span class="detail-label">$actionByLabel:</span><span class="detail-value">$actionBy</span></div>
        </div>

        <div class="section-title">Project Description</div>
        <div class="description-box">$projectDescription</div>

        <p>$actionText</p>

        <div class="cta-container">
            <div class="dashboard-btn" onclick="showDialog()">Go to Dashboard</div>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>This is an automated message. Please do not reply.</p>
        <p>Webnox Technologies Pvt Ltd</p>
    </div>
</div>

<!-- Dialog -->
<div class="dialog-overlay" id="dashboardDialog">
    <div class="dialog-box">
        <h2>Choose Your Dashboard</h2>
        <a href="https://admin-sprintly.webnoxdigital.com" class="dialog-btn admin-btn">Admin Dashboard</a>
        <a href="https://employee-sprintly.webnoxdigital.com" class="dialog-btn employee-btn">Employee Dashboard</a>
        <br><br>
        <button onclick="closeDialog()" style="padding:6px 14px; border:none; background:#ccc; border-radius:6px; cursor:pointer;">Cancel</button>
    </div>
</div>

<script>
function showDialog() {
    document.getElementById('dashboardDialog').style.display = 'flex';
}
function closeDialog() {
    document.getElementById('dashboardDialog').style.display = 'none';
}
</script>

</body>
</html>
    ''';
  }

  /// Generate subject lines
  static String generateCreatedSubject(String projectName) {
    return 'New Project Created: $projectName';
  }

  static String generateUpdatedSubject(String projectName) {
    return 'Project Updated: $projectName';
  }

  static String generateDeletedSubject(String projectName) {
    return 'Project Deleted: $projectName';
  }

  static String generateDiscontinuedSubject(String projectName) {
    return 'Project Discontinued: $projectName';
  }
}
