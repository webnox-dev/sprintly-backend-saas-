import '../core/utils/logger.dart';
import 'smtp_service.dart';
import 'email_templates/task_card_template.dart';
import 'email_templates/task_card_request_approval_template.dart';
import 'email_templates/leave_request_template.dart';
import 'email_templates/permission_request_template.dart';
import 'email_templates/wfh_request_template.dart';
import 'email_templates/project_template.dart';
import 'email_templates/admin_template.dart';
import 'email_templates/employee_template.dart';
import 'email_templates/announcement_template.dart';
import 'email_templates/celebration_template.dart';
import 'email_templates/otp_template.dart';
import 'email_templates/password_reset_template.dart';
import 'email_templates/company_holiday_template.dart';
import 'email_templates/employee_document_template.dart';

/// Email service for sending emails via SMTP Service
class EmailService {
  final AppLogger logger = AppLogger('EmailService');
  final SmtpService _smtpService = SmtpService();

  /// Send email via SMTP Service
  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String htmlContent,
    List<String>? ccEmails,
    List<String>? attachments,
  }) async {
    try {
      // Validate inputs
      if (toEmail.isEmpty || !toEmail.contains('@')) {
        logger.error('Invalid email address: $toEmail');
        return false;
      }

      // Delegate to SmtpService
      return await _smtpService.sendEmail(
        toEmail: toEmail,
        subject: subject,
        htmlContent: htmlContent,
        ccEmails: ccEmails,
        attachments: attachments,
      );
    } catch (e, stackTrace) {
      logger.error('Error in EmailService: $e', e, stackTrace);
      return false;
    }
  }

  /*
  /// LEGACY: Send email via n8n webhook
  Future<bool> sendEmailN8n({
    required String toEmail,
    required String subject,
    required String htmlContent,
    List<String>? ccEmails,
    List<String>? attachments,
  }) async {
    try {
      // ... (Previous implementation commented out for reference)
      // Build payload
      final Map<String, dynamic> payload = {
        'to': toEmail,
        'subject': subject,
        'message': htmlContent,
      };
      
      // ... rest of n8n logic
       final response = await http.post(...)
       return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  */

  /// Send OTP verification email
  Future<bool> sendOTPEmail({
    required String toEmail,
    required String userName,
    required String otp,
    required String userType,
    String? subject,
  }) async {
    final finalSubject =
        subject ?? 'Your Verification Code - Webnox Sprintly Admin';
    final htmlContent = OTPEmailTemplate.generateOTPEmailTemplate(
      userName: userName,
      otp: otp,
      userType: userType,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: finalSubject,
      htmlContent: htmlContent,
    );
  }

  /// Send Password Reset OTP email
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String userName,
    required String otp,
  }) async {
    final subject = 'Password Reset Request - Webnox Sprintly Admin';
    final htmlContent =
        PasswordResetEmailTemplate.generatePasswordResetEmailTemplate(
          userName: userName,
          otp: otp,
        );

    logger.info('Sending password reset email to: $toEmail');
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Password Changed Confirmation email
  Future<bool> sendPasswordChangedEmail({
    required String toEmail,
    required String userName,
  }) async {
    final subject = 'Your Password Has Been Changed - Webnox Sprintly Admin';
    final htmlContent =
        PasswordResetEmailTemplate.generatePasswordChangedEmailTemplate(
          userName: userName,
        );

    logger.info('Sending password changed confirmation email to: $toEmail');
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Welcome email for new employee with OTP
  Future<bool> sendWelcomeEmail({
    required String toEmail,
    required String userName,
    required String employeeId,
    required String otp,
    String defaultPassword = '123456',
  }) async {
    final subject = 'Welcome to Webnox Sprintly - Your Account Details';
    final htmlContent = generateWelcomeEmailTemplate(
      userName: userName,
      employeeId: employeeId,
      otp: otp,
      defaultPassword: defaultPassword,
    );

    logger.info('Sending welcome email to: $toEmail');
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Generate Welcome email HTML template for new employees
  String generateWelcomeEmailTemplate({
    required String userName,
    required String employeeId,
    required String otp,
    String defaultPassword = '123456',
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Welcome to Webnox Sprintly</title>
</head>

<body style="margin:0; padding:0; background:#667eea; background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">

<div style="max-width:600px; margin:0 auto; padding:40px 20px;">

    <!-- Card -->
    <div style="background:#ffffff; border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.25);">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); padding:45px 30px; text-align:center;">
            <div style="font-size:42px; margin-bottom:12px;">🎉</div>
            <h1 style="color:#ffffff; margin:0; font-size:28px; font-weight:600;">Welcome to the Team!</h1>
            <p style="color:rgba(255,255,255,0.9); margin:12px 0 0; font-size:16px;">Webnox Sprintly Admin Dashboard</p>
        </div>

        <!-- Content -->
        <div style="padding:40px 32px;">

            <p style="font-size:18px; margin:0 0 20px; color:#333;">
                Hello <strong style="color:#667eea;">$userName</strong>,
            </p>

            <p style="font-size:16px; line-height:1.7; color:#555; margin:0 0 28px;">
                We're excited to have you on board! Your account has been created successfully.
                Below are your login credentials and verification code.
            </p>

            <!-- Account Box -->
            <div style="background:linear-gradient(135deg,#f5f7fa 0%,#e8ecf3 100%); border-radius:14px; padding:24px; margin:28px 0; border-left:4px solid #667eea;">
                <h3 style="margin:0 0 18px; font-size:16px; color:#333;">📋 Your Account Details</h3>
                <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Employee ID:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; text-align:right;">$employeeId</td>
                    </tr>
                    <tr>
                        <td style="color:#666; padding:10px 0; font-size:14px;">Default Password:</td>
                        <td style="color:#333; padding:10px 0; font-size:14px; font-weight:600; font-family:monospace; letter-spacing:1px; text-align:right;">$defaultPassword</td>
                    </tr>
                </table>
            </div>

            <!-- OTP Section -->
            <div style="text-align:center; margin:36px 0 10px;">
                <p style="font-size:14px; color:#555; margin-bottom:18px;">
                    Use this verification code to verify your email:
                </p>

                <!-- OTP BOXES (EMAIL SAFE) - CHANGED TO DIV STRUCTURE -->
                <div style="text-align: center;">
                    ${_generateOTPDigits(otp)}
                </div>

                <div style="background:linear-gradient(135deg,#fff3cd 0%,#ffeaa7 100%); border-radius:10px; padding:14px 22px; margin-top:24px; display:inline-block;">
                    <span style="color:#856404; font-size:13px;">⏰ This OTP is valid for <strong>15 minutes</strong> only</span>
                </div>
            </div>

            <!-- Security Notice -->
            <div style="background:linear-gradient(135deg,#fff5f5 0%,#ffe0e0 100%); border-radius:14px; padding:22px; margin:30px 0; border-left:4px solid #e74c3c;">
                <h4 style="color:#c0392b; margin:0 0 10px; font-size:14px;">⚠️ Important Security Notice</h4>
                <ul style="color:#666; font-size:13px; line-height:1.8; margin:0; padding-left:18px;">
                    <li>Please change your default password after your first login</li>
                    <li>Never share your login credentials with anyone</li>
                    <li>If you didn't register, please ignore this email</li>
                </ul>
            </div>

            <!-- Steps -->
            <h4 style="font-size:15px; margin-bottom:14px;">🚀 Getting Started</h4>

            <table width="100%" cellpadding="0" cellspacing="0" style="font-size:14px; color:#555;">
                <tr><td style="padding:8px 0;">① Login with your email and default password</td></tr>
                <tr><td style="padding:8px 0;">② Enter the OTP to verify your email</td></tr>
                <tr><td style="padding:8px 0;">③ Change your password and start exploring!</td></tr>
            </table>

        </div>

        <!-- Footer -->
        <div style="background:#f8f9fa; padding:26px 30px; text-align:center; border-top:1px solid #e9ecef;">
            <p style="font-size:12px; color:#999; margin:0 0 8px;">
                This email was sent by Webnox Sprintly Admin System.
            </p>
            <p style="font-size:12px; color:#999; margin:0;">
                © ${DateTime.now().year} Webnox Technologies Pvt Ltd. All rights reserved.
            </p>
        </div>

    </div>

    <div style="text-align:center; margin-top:22px; color:rgba(255,255,255,0.75); font-size:11px;">
        A Product by Mobile App Team
    </div>

</div>
</body>
</html>
    ''';
  }

  // ==========================================
  // Task Card Email Methods
  // ==========================================

  /// Send Task Created Email
  Future<bool> sendTaskCreatedEmail({
    required String toEmail,
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
  }) async {
    final subject = TaskCardEmailTemplate.generateCreatedSubject(
      taskName,
      projectName,
    );
    final htmlContent = TaskCardEmailTemplate.generateTaskCreatedEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: assignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Updated Email
  Future<bool> sendTaskUpdatedEmail({
    required String toEmail,
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
  }) async {
    final subject = TaskCardEmailTemplate.generateUpdatedSubject(
      taskName,
      projectName,
    );
    final htmlContent = TaskCardEmailTemplate.generateTaskUpdatedEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      updatedBy: updatedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      changesDescription: changesDescription,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Deleted Email
  Future<bool> sendTaskDeletedEmail({
    required String toEmail,
    required String employeeName,
    required String taskName,
    required String projectName,
    required String deletedBy,
    String? reason,
  }) async {
    final subject = TaskCardEmailTemplate.generateDeletedSubject(taskName);
    final htmlContent = TaskCardEmailTemplate.generateTaskDeletedEmail(
      employeeName: employeeName,
      taskName: taskName,
      projectName: projectName,
      deletedBy: deletedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Duplicated Email
  Future<bool> sendTaskDuplicatedEmail({
    required String toEmail,
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
  }) async {
    final subject = TaskCardEmailTemplate.generateDuplicatedSubject(
      taskName,
      projectName,
    );
    final htmlContent = TaskCardEmailTemplate.generateTaskDuplicatedEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      assignedBy: assignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      originalTaskName: originalTaskName,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Reassigned Email (To New Assignee)
  Future<bool> sendTaskReassignedToNewEmail({
    required String toEmail,
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
  }) async {
    final subject = TaskCardEmailTemplate.generateReassignedSubject(
      taskName,
      projectName,
    );
    final htmlContent = TaskCardEmailTemplate.generateTaskReassignedToNewEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      reassignedBy: reassignedBy,
      fromDate: fromDate,
      toDate: toDate,
      taskDuration: taskDuration,
      previousAssignee: previousAssignee,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task QA Approved Email
  Future<bool> sendTaskQaApprovedEmail({
    required String toEmail,
    required String employeeName,
    required String taskName,
    required String projectName,
    required String approvedBy,
    String? notes,
  }) async {
    final subject = TaskCardEmailTemplate.generateQaApprovedSubject(taskName);
    final htmlContent = TaskCardEmailTemplate.generateTaskQaApprovedEmail(
      employeeName: employeeName,
      taskName: taskName,
      projectName: projectName,
      approvedBy: approvedBy,
      notes: notes,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task QA Rejected Email
  Future<bool> sendTaskQaRejectedEmail({
    required String toEmail,
    required String employeeName,
    required String taskName,
    required String projectName,
    required String rejectedBy,
    required String notes,
  }) async {
    final subject = TaskCardEmailTemplate.generateQaRejectedSubject(taskName);
    final htmlContent = TaskCardEmailTemplate.generateTaskQaRejectedEmail(
      employeeName: employeeName,
      taskName: taskName,
      projectName: projectName,
      rejectedBy: rejectedBy,
      notes: notes,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Reassigned Email (To Old Assignee)
  Future<bool> sendTaskReassignedFromEmail({
    required String toEmail,
    required String employeeName,
    required String taskName,
    required String projectName,
    required String reassignedBy,
    required String newAssignee,
    String? reason,
  }) async {
    final subject = TaskCardEmailTemplate.generateReassignedSubject(
      taskName,
      projectName,
    );
    final htmlContent = TaskCardEmailTemplate.generateTaskReassignedFromEmail(
      employeeName: employeeName,
      taskName: taskName,
      projectName: projectName,
      reassignedBy: reassignedBy,
      newAssignee: newAssignee,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Task Card Request Email Methods
  // ==========================================

  /// Send Task Request Approved Email
  Future<bool> sendTaskRequestApprovedEmail({
    required String toEmail,
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
  }) async {
    final subject = TaskCardRequestApprovalTemplate.generateApprovalSubject(
      taskName,
    );
    final htmlContent = TaskCardRequestApprovalTemplate.generateApprovalEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      priorityLevel: priorityLevel,
      projectName: projectName,
      fromDate: fromDate,
      toDate: toDate,
      approvedBy: approvedBy,
      remarks: remarks,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Task Request Rejected Email
  Future<bool> sendTaskRequestRejectedEmail({
    required String toEmail,
    required String employeeName,
    required String taskName,
    required String taskDescription,
    required String taskType,
    required String projectName,
    required String fromDate,
    required String toDate,
    required String rejectedBy,
    String? rejectionReason,
  }) async {
    final subject = TaskCardRequestApprovalTemplate.generateRejectionSubject(
      taskName,
    );
    final htmlContent = TaskCardRequestApprovalTemplate.generateRejectionEmail(
      employeeName: employeeName,
      taskName: taskName,
      taskDescription: taskDescription,
      taskType: taskType,
      projectName: projectName,
      fromDate: fromDate,
      toDate: toDate,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Leave Request Email Methods
  // ==========================================

  /// Send Leave Approved Email
  Future<bool> sendLeaveApprovedEmail({
    required String toEmail,
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String approvedBy,
    String? remarks,
  }) async {
    final subject = LeaveRequestEmailTemplate.generateApprovalSubject(
      leaveType,
    );
    final htmlContent = LeaveRequestEmailTemplate.generateApprovalEmail(
      employeeName: employeeName,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      approvedBy: approvedBy,
      remarks: remarks,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Leave Rejected Email
  Future<bool> sendLeaveRejectedEmail({
    required String toEmail,
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String rejectedBy,
    String? reason,
  }) async {
    final subject = LeaveRequestEmailTemplate.generateRejectionSubject(
      leaveType,
    );
    final htmlContent = LeaveRequestEmailTemplate.generateRejectionEmail(
      employeeName: employeeName,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      rejectedBy: rejectedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Leave Requested Email (To HR/Admin)
  Future<bool> sendLeaveRequestedEmail({
    required String toEmail,
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    bool isPaidLeave = false,
    bool isHalfDay = false,
    String? halfDayType,
  }) async {
    final subject = LeaveRequestEmailTemplate.generateRequestSubject(
      employeeName,
      leaveType,
    );
    final htmlContent = LeaveRequestEmailTemplate.generateRequestEmail(
      employeeName: employeeName,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      reason: reason,
      isPaidLeave: isPaidLeave,
      isHalfDay: isHalfDay,
      halfDayType: halfDayType,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Permission Request Email Methods
  // ==========================================

  /// Send Permission Approved Email
  Future<bool> sendPermissionApprovedEmail({
    required String toEmail,
    required String employeeName,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
    required String approvedBy,
    String? remarks,
  }) async {
    final subject = PermissionRequestEmailTemplate.generateApprovalSubject(
      permissionDate,
    );
    final htmlContent = PermissionRequestEmailTemplate.generateApprovalEmail(
      employeeName: employeeName,
      permissionDate: permissionDate,
      fromTime: fromTime,
      toTime: toTime,
      totalHours: totalHours,
      reason: reason,
      approvedBy: approvedBy,
      remarks: remarks,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Permission Rejected Email
  Future<bool> sendPermissionRejectedEmail({
    required String toEmail,
    required String employeeName,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
    required String rejectedBy,
    String? rejectionReason,
  }) async {
    final subject = PermissionRequestEmailTemplate.generateRejectionSubject(
      permissionDate,
    );
    final htmlContent = PermissionRequestEmailTemplate.generateRejectionEmail(
      employeeName: employeeName,
      permissionDate: permissionDate,
      fromTime: fromTime,
      toTime: toTime,
      totalHours: totalHours,
      reason: reason,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Permission Requested Email (To HR/Admin)
  Future<bool> sendPermissionRequestedEmail({
    required String toEmail,
    required String employeeName,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
  }) async {
    final subject = PermissionRequestEmailTemplate.generateRequestSubject(
      employeeName,
      permissionDate,
    );
    final htmlContent = PermissionRequestEmailTemplate.generateRequestEmail(
      employeeName: employeeName,
      permissionDate: permissionDate,
      fromTime: fromTime,
      toTime: toTime,
      totalHours: totalHours,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // WFH Request Email Methods
  // ==========================================

  /// Send WFH Approved Email
  Future<bool> sendWFHApprovedEmail({
    required String toEmail,
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String approvedBy,
    String? remarks,
  }) async {
    final subject = WFHRequestEmailTemplate.generateApprovalSubject(
      '$fromDate to $toDate',
    );
    final htmlContent = WFHRequestEmailTemplate.generateApprovalEmail(
      employeeName: employeeName,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      reason: reason,
      approvedBy: approvedBy,
      remarks: remarks,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send WFH Rejected Email
  Future<bool> sendWFHRejectedEmail({
    required String toEmail,
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String rejectedBy,
    String? rejectionReason,
  }) async {
    final subject = WFHRequestEmailTemplate.generateRejectionSubject(
      '$fromDate to $toDate',
    );
    final htmlContent = WFHRequestEmailTemplate.generateRejectionEmail(
      employeeName: employeeName,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      reason: reason,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send WFH Requested Email (To HR/Admin)
  Future<bool> sendWFHRequestedEmail({
    required String toEmail,
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    String? employeeRole,
  }) async {
    final subject = WFHRequestEmailTemplate.generateRequestSubject(
      employeeName,
    );
    final htmlContent = WFHRequestEmailTemplate.generateRequestEmail(
      employeeName: employeeName,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      reason: reason,
      employeeRole: employeeRole,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Project Email Methods
  // ==========================================

  /// Send Project Created Email
  Future<bool> sendProjectCreatedEmail({
    required String toEmail,
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
  }) async {
    final subject = ProjectEmailTemplate.generateCreatedSubject(projectName);
    final htmlContent = ProjectEmailTemplate.generateProjectCreatedEmail(
      recipientName: recipientName,
      projectName: projectName,
      projectDescription: projectDescription,
      priorityLevel: priorityLevel,
      status: status,
      startDate: startDate,
      endDate: endDate,
      projectManager: projectManager,
      teamLead: teamLead,
      createdBy: createdBy,
      recipientRole: recipientRole,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Project Updated Email
  Future<bool> sendProjectUpdatedEmail({
    required String toEmail,
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
  }) async {
    final subject = ProjectEmailTemplate.generateUpdatedSubject(projectName);
    final htmlContent = ProjectEmailTemplate.generateProjectUpdatedEmail(
      recipientName: recipientName,
      projectName: projectName,
      projectDescription: projectDescription,
      priorityLevel: priorityLevel,
      status: status,
      startDate: startDate,
      endDate: endDate,
      projectManager: projectManager,
      teamLead: teamLead,
      updatedBy: updatedBy,
      changesDescription: changesDescription,
      recipientRole: recipientRole,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Project Deleted Email
  Future<bool> sendProjectDeletedEmail({
    required String toEmail,
    required String recipientName,
    required String projectName,
    required String deletedBy,
    String? reason,
  }) async {
    final subject = ProjectEmailTemplate.generateDeletedSubject(projectName);
    final htmlContent = ProjectEmailTemplate.generateProjectDeletedEmail(
      recipientName: recipientName,
      projectName: projectName,
      deletedBy: deletedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Project Discontinued Email
  Future<bool> sendProjectDiscontinuedEmail({
    required String toEmail,
    required String recipientName,
    required String projectName,
    required String discontinuedBy,
    String? reason,
  }) async {
    final subject = ProjectEmailTemplate.generateDiscontinuedSubject(
      projectName,
    );
    final htmlContent = ProjectEmailTemplate.generateProjectDiscontinuedEmail(
      recipientName: recipientName,
      projectName: projectName,
      discontinuedBy: discontinuedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Admin Email Methods
  // ==========================================

  /// Send Admin Welcome Email
  Future<bool> sendAdminWelcomeEmail({
    required String toEmail,
    required String adminName,
    required String role,
    required String defaultPassword,
    String? adminId,
  }) async {
    final subject = AdminEmailTemplate.generateWelcomeSubject();
    final htmlContent = AdminEmailTemplate.generateWelcomeEmail(
      adminName: adminName,
      email: toEmail,
      role: role,
      defaultPassword: defaultPassword,
      adminId: adminId,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Admin Deactivated Email
  Future<bool> sendAdminDeactivatedEmail({
    required String toEmail,
    required String adminName,
    required String role,
    required String deactivatedBy,
    String? reason,
  }) async {
    final subject = AdminEmailTemplate.generateDeactivatedSubject();
    final htmlContent = AdminEmailTemplate.generateDeactivatedEmail(
      adminName: adminName,
      role: role,
      deactivatedBy: deactivatedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Admin Activated Email
  Future<bool> sendAdminActivatedEmail({
    required String toEmail,
    required String adminName,
    required String role,
    required String activatedBy,
  }) async {
    final subject = AdminEmailTemplate.generateActivatedSubject();
    final htmlContent = AdminEmailTemplate.generateActivatedEmail(
      adminName: adminName,
      role: role,
      activatedBy: activatedBy,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Employee Email Methods
  // ==========================================

  /// Send Employee Welcome Email
  Future<bool> sendEmployeeWelcomeEmail({
    required String toEmail,
    required String employeeName,
    required String employeeId,
    required String designation,
    required String department,
    required String defaultPassword,
    String? reportingTo,
    String? joiningDate,
  }) async {
    final subject = EmployeeEmailTemplate.generateWelcomeSubject();
    final htmlContent = EmployeeEmailTemplate.generateWelcomeEmail(
      employeeName: employeeName,
      email: toEmail,
      employeeId: employeeId,
      designation: designation,
      department: department,
      defaultPassword: defaultPassword,
      reportingTo: reportingTo,
      joiningDate: joiningDate,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Employee Deactivated Email
  Future<bool> sendEmployeeDeactivatedEmail({
    required String toEmail,
    required String employeeName,
    required String employeeId,
    required String designation,
    required String deactivatedBy,
    String? reason,
  }) async {
    final subject = EmployeeEmailTemplate.generateDeactivatedSubject();
    final htmlContent = EmployeeEmailTemplate.generateDeactivatedEmail(
      employeeName: employeeName,
      employeeId: employeeId,
      designation: designation,
      deactivatedBy: deactivatedBy,
      reason: reason,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Employee Exit Email
  Future<bool> sendEmployeeExitEmail({
    required String toEmail,
    required String employeeName,
    required String employeeId,
    required String designation,
    required String department,
    required String exitDate,
    required String processedBy,
    String? exitType,
    String? remarks,
  }) async {
    final subject = EmployeeEmailTemplate.generateExitSubject(employeeName);
    final htmlContent = EmployeeEmailTemplate.generateExitEmail(
      employeeName: employeeName,
      employeeId: employeeId,
      designation: designation,
      department: department,
      exitDate: exitDate,
      processedBy: processedBy,
      exitType: exitType,
      remarks: remarks,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Announcement Email Methods
  // ==========================================

  /// Send Announcement Created Email
  Future<bool> sendAnnouncementCreatedEmail({
    required String toEmail,
    required String recipientName,
    required String announcementTitle,
    required String announcementContent,
    required String createdBy,
    required String createdDate,
    String? priority,
    String? expiryDate,
  }) async {
    final subject = AnnouncementEmailTemplate.generateCreatedSubject(
      announcementTitle,
    );
    final htmlContent =
        AnnouncementEmailTemplate.generateAnnouncementCreatedEmail(
          recipientName: recipientName,
          announcementTitle: announcementTitle,
          announcementContent: announcementContent,
          createdBy: createdBy,
          createdDate: createdDate,
          priority: priority,
          expiryDate: expiryDate,
        );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Announcement Updated Email
  Future<bool> sendAnnouncementUpdatedEmail({
    required String toEmail,
    required String recipientName,
    required String announcementTitle,
    required String announcementContent,
    required String updatedBy,
    required String updatedDate,
    String? priority,
    String? expiryDate,
  }) async {
    final subject = AnnouncementEmailTemplate.generateUpdatedSubject(
      announcementTitle,
    );
    final htmlContent =
        AnnouncementEmailTemplate.generateAnnouncementUpdatedEmail(
          recipientName: recipientName,
          announcementTitle: announcementTitle,
          announcementContent: announcementContent,
          updatedBy: updatedBy,
          updatedDate: updatedDate,
          priority: priority,
          expiryDate: expiryDate,
        );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Announcement Deleted Email
  Future<bool> sendAnnouncementDeletedEmail({
    required String toEmail,
    required String recipientName,
    required String announcementTitle,
    required String deletedBy,
  }) async {
    final subject = AnnouncementEmailTemplate.generateDeletedSubject(
      announcementTitle,
    );
    final htmlContent =
        AnnouncementEmailTemplate.generateAnnouncementDeletedEmail(
          recipientName: recipientName,
          announcementTitle: announcementTitle,
          deletedBy: deletedBy,
        );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // ==========================================
  // Company Holiday Email Methods
  // ==========================================

  Future<bool> sendCompanyHolidayCreatedEmail({
    required String toEmail,
    required String recipientName,
    required String holidayName,
    required String fromDate,
    required String toDate,
    required int totalDays,
    String? remarks,
    required String createdBy,
    bool isOptional = false,
  }) async {
    final subject = CompanyHolidayEmailTemplate.generateCreatedSubject(
      holidayName,
    );
    final html = CompanyHolidayEmailTemplate.generateCreatedEmail(
      recipientName: recipientName,
      holidayName: holidayName,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      remarks: remarks,
      createdBy: createdBy,
      isOptional: isOptional,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
    );
  }

  Future<bool> sendCompanyHolidayUpdatedEmail({
    required String toEmail,
    required String recipientName,
    required String holidayName,
    required String fromDate,
    required String toDate,
    required int totalDays,
    String? remarks,
    required String updatedBy,
    bool isOptional = false,
  }) async {
    final subject = CompanyHolidayEmailTemplate.generateUpdatedSubject(
      holidayName,
    );
    final html = CompanyHolidayEmailTemplate.generateUpdatedEmail(
      recipientName: recipientName,
      holidayName: holidayName,
      fromDate: fromDate,
      toDate: toDate,
      totalDays: totalDays,
      remarks: remarks,
      updatedBy: updatedBy,
      isOptional: isOptional,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
    );
  }

  Future<bool> sendCompanyHolidayDeletedEmail({
    required String toEmail,
    required String recipientName,
    required String holidayName,
    required String deletedBy,
    String? reason,
  }) async {
    final subject = CompanyHolidayEmailTemplate.generateDeletedSubject(
      holidayName,
    );
    final html = CompanyHolidayEmailTemplate.generateDeletedEmail(
      recipientName: recipientName,
      holidayName: holidayName,
      deletedBy: deletedBy,
      reason: reason,
    );
    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: html,
    );
  }

  // ==========================================
  // Celebration Email Methods
  // ==========================================

  /// Send Birthday Wishes Email
  Future<bool> sendBirthdayEmail({
    required String toEmail,
    required String employeeName,
    required String birthDate,
    String? designation,
    String? department,
  }) async {
    final subject = CelebrationEmailTemplate.generateBirthdaySubject(
      employeeName,
    );
    final htmlContent = CelebrationEmailTemplate.generateBirthdayEmail(
      employeeName: employeeName,
      birthDate: birthDate,
      designation: designation,
      department: department,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send Work Anniversary Email
  Future<bool> sendWorkAnniversaryEmail({
    required String toEmail,
    required String employeeName,
    required int yearsCompleted,
    required String joiningDate,
    String? designation,
    String? department,
  }) async {
    final subject = CelebrationEmailTemplate.generateAnniversarySubject(
      employeeName,
      yearsCompleted,
    );
    final htmlContent = CelebrationEmailTemplate.generateWorkAnniversaryEmail(
      employeeName: employeeName,
      yearsCompleted: yearsCompleted,
      joiningDate: joiningDate,
      designation: designation,
      department: department,
    );

    return await sendEmail(
      toEmail: toEmail,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  String _generateOTPDigits(String otp) {
    final buffer = StringBuffer();
    for (int i = 0; i < otp.length; i++) {
      buffer.write('''
        <div style="width: 50px; height: 60px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; display: inline-block; text-align: center; line-height: 60px; vertical-align: middle; margin: 0 4px;">
          <span style="color: #ffffff; font-size: 28px; font-weight: 700;">${otp[i]}</span>
        </div>
      ''');
    }
    return buffer.toString();
  }

  /// Send document request email to employee
  Future<bool> sendDocumentRequestEmail({
    required String toEmail,
    required String employeeName,
    required String adminName,
    required String documentList,
    required int documentCount,
  }) async {
    final htmlContent =
        EmployeeDocumentEmailTemplate.generateDocumentRequestEmail(
          employeeName: employeeName,
          adminName: adminName,
          documentList: documentList,
          documentCount: documentCount,
        );

    return await sendEmail(
      toEmail: toEmail,
      subject: '📋 Document Request - Webnox Sprintly',
      htmlContent: htmlContent,
    );
  }

  /// Send document submitted email to admin
  Future<bool> sendDocumentSubmittedEmail({
    required String toEmail,
    required String adminName,
    required String employeeName,
    required String documentName,
  }) async {
    final htmlContent =
        EmployeeDocumentEmailTemplate.generateDocumentSubmittedEmail(
          adminName: adminName,
          employeeName: employeeName,
          documentName: documentName,
        );

    return await sendEmail(
      toEmail: toEmail,
      subject: '✅ Document Submitted - $employeeName',
      htmlContent: htmlContent,
    );
  }

  /// Send document reviewed email to employee
  Future<bool> sendDocumentReviewedEmail({
    required String toEmail,
    required String employeeName,
    required String documentName,
    required String status,
    String? adminComments,
  }) async {
    final htmlContent =
        EmployeeDocumentEmailTemplate.generateDocumentReviewedEmail(
          employeeName: employeeName,
          documentName: documentName,
          status: status,
          adminComments: adminComments,
        );

    final statusLabel = status.toLowerCase() == 'approved'
        ? 'Approved'
        : 'Rejected';
    return await sendEmail(
      toEmail: toEmail,
      subject: 'Document $statusLabel - $documentName',
      htmlContent: htmlContent,
    );
  }
}
