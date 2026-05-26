import '../core/utils/logger.dart';
import '../data/repositories/notification_repository.dart';
import '../data/database/connection.dart';
import 'firebase_notification_service.dart';
import 'email_service.dart';
import 'email_templates/admin_template.dart';
import 'email_templates/employee_template.dart';
import 'email_templates/celebration_template.dart';
import 'email_templates/task_card_request_template.dart';
import 'email_templates/calendar_meeting_template.dart';
import 'email_templates/chat_template.dart';
import 'email_templates/employee_document_template.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/employee_repository.dart';

/// Unified Notification Service
/// Coordinates Push Notifications, Emails, and Local (In-App) Notifications
class UnifiedNotificationService {
  static final AppLogger _logger = AppLogger('UnifiedNotificationService');
  static final NotificationRepository _notificationRepo =
      NotificationRepository();
  static final EmailService _emailService = EmailService();
  static final AdminRepository _adminRepo = AdminRepository();
  static final EmployeeRepository _employeeRepo = EmployeeRepository();

  // ============================================
  // 1. ADMIN NOTIFICATIONS
  // ============================================

  /// Notify when a new admin is created
  static Future<void> notifyAdminCreated({
    required String adminId,
    required String adminName,
    required String adminEmail,
    required String createdBy,
  }) async {
    _logger.info('Triggering notifications for admin created: $adminName');

    try {
      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'New Admin Added',
        body: 'New admin $adminName ($adminId) has been added to the system',
        data: {'type': 'admin_created', 'admin_id': adminId},
      );

      // Create local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Admin Added',
        body: 'New admin $adminName ($adminId) has been added to the system',
        notificationType: 'admin_created',
        relatedEntityType: 'admin',
        relatedEntityId: adminId,
        data: {'admin_name': adminName, 'admin_id': adminId},
        createdBy: createdBy,
      );

      // Send email to all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendEmail(
            toEmail: email,
            subject: 'New Admin Added - Webnox Sprintly',
            htmlContent: AdminEmailTemplate.generateNewAdminNotificationEmail(
              recipientName: admin['admin_name'] as String? ?? 'Admin',
              newAdminName: adminName,
              newAdminId: adminId,
              newAdminEmail: adminEmail,
            ),
          );
        }
      }

      _logger.info('Admin created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending admin created notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when an admin is deleted
  static Future<void> notifyAdminDeleted({
    required String adminId,
    required String adminName,
    required String deletedBy,
  }) async {
    _logger.info('Triggering notifications for admin deleted: $adminName');

    try {
      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Admin Removed',
        body: 'Admin $adminName ($adminId) has been removed from the system',
        data: {'type': 'admin_deleted', 'admin_id': adminId},
      );

      // Create local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Admin Removed',
        body: 'Admin $adminName ($adminId) has been removed from the system',
        notificationType: 'admin_deleted',
        relatedEntityType: 'admin',
        relatedEntityId: adminId,
        data: {'admin_name': adminName, 'admin_id': adminId},
        createdBy: deletedBy,
      );

      // Send email to all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendEmail(
            toEmail: email,
            subject: 'Admin Removed - Webnox Sprintly',
            htmlContent:
                AdminEmailTemplate.generateAdminRemovedNotificationEmail(
                  recipientName: admin['admin_name'] as String? ?? 'Admin',
                  removedAdminName: adminName,
                  removedAdminId: adminId,
                ),
          );
        }
      }

      _logger.info('Admin deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending admin deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when an admin status changes (activated/deactivated)
  static Future<void> notifyAdminStatusChanged({
    required String adminId,
    required String adminName,
    required String adminEmail,
    required String adminRole,
    required bool isActive,
    required String changedBy,
  }) async {
    final statusText = isActive ? 'activated' : 'deactivated';
    _logger.info('Triggering notifications for admin $statusText: $adminName');

    try {
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Admin Status Changed',
        body: 'Admin $adminName ($adminId) has been $statusText',
        data: {
          'type': 'admin_status_changed',
          'admin_id': adminId,
          'status': statusText,
        },
      );

      await FirebaseNotificationService.notifyAdmin(
        adminId: adminId,
        title: 'Account Status Updated',
        body: 'Your account has been $statusText',
        data: {'type': 'admin_status_changed', 'status': statusText},
      );

      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Admin Status Changed',
        body: 'Admin $adminName ($adminId) has been $statusText',
        notificationType: 'admin_status_changed',
        relatedEntityType: 'admin',
        relatedEntityId: adminId,
        data: {
          'admin_name': adminName,
          'admin_id': adminId,
          'status': statusText,
        },
        createdBy: changedBy,
      );

      await _notificationRepo.createNotification(
        userId: adminId,
        userType: 'Admin',
        title: 'Account Status Updated',
        body: 'Your account has been $statusText',
        notificationType: 'admin_status_changed',
        relatedEntityType: 'admin',
        relatedEntityId: adminId,
        data: {'status': statusText},
        createdBy: changedBy,
      );

      if (adminEmail.isNotEmpty) {
        if (isActive) {
          await _emailService.sendAdminActivatedEmail(
            toEmail: adminEmail,
            adminName: adminName,
            role: adminRole,
            activatedBy: changedBy,
          );
        } else {
          await _emailService.sendAdminDeactivatedEmail(
            toEmail: adminEmail,
            adminName: adminName,
            role: adminRole,
            deactivatedBy: changedBy,
          );
        }
      }

      _logger.info('Admin status changed notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending admin status changed notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 2. EMPLOYEE NOTIFICATIONS
  // ============================================

  /// Notify when an employee is created
  static Future<void> notifyEmployeeCreated({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String createdBy,
  }) async {
    _logger.info(
      'Triggering notifications for employee created: $employeeName',
    );

    try {
      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'New Employee Added',
        body: 'New employee $employeeName ($employeeId) has joined the team',
        data: {'type': 'employee_created', 'employee_id': employeeId},
      );

      // Create local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Employee Added',
        body: 'New employee $employeeName ($employeeId) has joined the team',
        notificationType: 'employee_created',
        relatedEntityType: 'employee',
        relatedEntityId: employeeId,
        data: {'employee_name': employeeName, 'employee_id': employeeId},
        createdBy: createdBy,
      );

      // Send email to all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendEmail(
            toEmail: email,
            subject: 'New Employee Joined - Webnox Sprintly',
            htmlContent:
                EmployeeEmailTemplate.generateNewEmployeeNotificationEmail(
                  recipientName: admin['admin_name'] as String? ?? 'Admin',
                  employeeName: employeeName,
                  employeeId: employeeId,
                  employeeEmail: employeeEmail,
                ),
          );
        }
      }

      _logger.info('Employee created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending employee created notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when an employee status changes (active/deactivated)
  static Future<void> notifyEmployeeStatusChanged({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required bool isActive,
    required String changedBy,
  }) async {
    final statusText = isActive ? 'activated' : 'deactivated';
    _logger.info(
      'Triggering notifications for employee $statusText: $employeeName',
    );

    try {
      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Employee Status Changed',
        body: 'Employee $employeeName ($employeeId) has been $statusText',
        data: {
          'type': 'employee_status_changed',
          'employee_id': employeeId,
          'status': statusText,
        },
      );

      // Push notification to the employee
      await FirebaseNotificationService.notifyEmployee(
        employeeId: employeeId,
        title: 'Account Status Updated',
        body: 'Your account has been $statusText',
        data: {'type': 'employee_status_changed', 'status': statusText},
      );

      // Create local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Employee Status Changed',
        body: 'Employee $employeeName ($employeeId) has been $statusText',
        notificationType: 'employee_status_changed',
        relatedEntityType: 'employee',
        relatedEntityId: employeeId,
        data: {
          'employee_name': employeeName,
          'employee_id': employeeId,
          'status': statusText,
        },
        createdBy: changedBy,
      );

      // Create local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Account Status Updated',
        body: 'Your account has been $statusText',
        notificationType: 'employee_status_changed',
        relatedEntityType: 'employee',
        relatedEntityId: employeeId,
        data: {'status': statusText},
        createdBy: changedBy,
      );

      // Send email to the employee
      if (employeeEmail.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: employeeEmail,
          subject: 'Account Status Updated - Webnox Sprintly',
          htmlContent: EmployeeEmailTemplate.generateStatusChangeEmail(
            employeeName: employeeName,
            isActive: isActive,
          ),
        );
      }

      _logger.info('Employee status changed notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending employee status notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when an employee is deleted
  static Future<void> notifyEmployeeDeleted({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String deletedBy,
  }) async {
    _logger.info(
      'Triggering notifications for employee deleted: $employeeName',
    );

    try {
      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Employee Removed',
        body:
            'Employee $employeeName ($employeeId) has been removed from the system',
        data: {'type': 'employee_deleted', 'employee_id': employeeId},
      );

      // Create local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Employee Removed',
        body:
            'Employee $employeeName ($employeeId) has been removed from the system',
        notificationType: 'employee_deleted',
        relatedEntityType: 'employee',
        relatedEntityId: employeeId,
        data: {'employee_name': employeeName, 'employee_id': employeeId},
        createdBy: deletedBy,
      );

      // Send email to the employee
      if (employeeEmail.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: employeeEmail,
          subject: 'Account Removed - Webnox Sprintly',
          htmlContent: EmployeeEmailTemplate.generateAccountRemovedEmail(
            employeeName: employeeName,
          ),
        );
      }

      _logger.info('Employee deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending employee deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 3. PROJECT NOTIFICATIONS
  // ============================================

  /// Notify when a project is created
  static Future<void> notifyProjectCreated({
    required String projectId,
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
    required String createdBy,
  }) async {
    _logger.info('Triggering notifications for project created: $projectName');

    try {
      final allMembers = <String>{
        ...teamMemberIds,
        if (projectManagerId != null) projectManagerId,
        if (teamLeaderId != null) teamLeaderId,
      }.toList();

      // Push notifications
      await FirebaseNotificationService.notifyProjectCreated(
        projectName: projectName,
        teamMemberIds: teamMemberIds,
        projectManagerId: projectManagerId,
        teamLeaderId: teamLeaderId,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Project Created',
        body: 'Project "$projectName" has been created',
        notificationType: 'project_created',
        relatedEntityType: 'project',
        relatedEntityId: projectId,
        data: {'project_name': projectName, 'project_id': projectId},
        createdBy: createdBy,
      );

      // Local notifications for team members
      for (final memberId in allMembers) {
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: 'Employee',
          title: 'New Project Assignment',
          body: 'You have been assigned to project "$projectName"',
          notificationType: 'project_created',
          relatedEntityType: 'project',
          relatedEntityId: projectId,
          data: {'project_name': projectName, 'project_id': projectId},
          createdBy: createdBy,
        );
      }

      _logger.info('Project created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending project created notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a project is updated
  static Future<void> notifyProjectUpdated({
    required String projectId,
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
    required String updatedBy,
  }) async {
    _logger.info('Triggering notifications for project updated: $projectName');

    try {
      final allMembers = <String>{
        ...teamMemberIds,
        if (projectManagerId != null) projectManagerId,
        if (teamLeaderId != null) teamLeaderId,
      }.toList();

      // Push notifications
      await FirebaseNotificationService.notifyProjectUpdated(
        projectName: projectName,
        teamMemberIds: teamMemberIds,
        projectManagerId: projectManagerId,
        teamLeaderId: teamLeaderId,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Project Updated',
        body: 'Project "$projectName" has been updated',
        notificationType: 'project_updated',
        relatedEntityType: 'project',
        relatedEntityId: projectId,
        data: {'project_name': projectName, 'project_id': projectId},
        createdBy: updatedBy,
      );

      // Local notifications for team members
      for (final memberId in allMembers) {
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: 'Employee',
          title: 'Project Updated',
          body: 'Project "$projectName" has been updated',
          notificationType: 'project_updated',
          relatedEntityType: 'project',
          relatedEntityId: projectId,
          data: {'project_name': projectName, 'project_id': projectId},
          createdBy: updatedBy,
        );
      }

      _logger.info('Project updated notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending project updated notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a project is deleted/discontinued
  static Future<void> notifyProjectDeleted({
    required String projectId,
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
    required String deletedBy,
    String? reason,
  }) async {
    _logger.info('Triggering notifications for project deleted: $projectName');

    try {
      final allMembers = <String>{
        ...teamMemberIds,
        if (projectManagerId != null) projectManagerId,
        if (teamLeaderId != null) teamLeaderId,
      }.toList();

      // Push notifications
      await FirebaseNotificationService.notifyProjectDiscontinued(
        projectName: projectName,
        teamMemberIds: teamMemberIds,
        projectManagerId: projectManagerId,
        teamLeaderId: teamLeaderId,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Project Discontinued',
        body: 'Project "$projectName" has been discontinued',
        notificationType: 'project_deleted',
        relatedEntityType: 'project',
        relatedEntityId: projectId,
        data: {
          'project_name': projectName,
          'project_id': projectId,
          'reason': reason ?? '',
        },
        createdBy: deletedBy,
      );

      // Local notifications for team members
      for (final memberId in allMembers) {
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: 'Employee',
          title: 'Project Discontinued',
          body: 'Project "$projectName" has been discontinued',
          notificationType: 'project_deleted',
          relatedEntityType: 'project',
          relatedEntityId: projectId,
          data: {
            'project_name': projectName,
            'project_id': projectId,
            'reason': reason ?? '',
          },
          createdBy: deletedBy,
        );
      }

      _logger.info('Project deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending project deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 4. TASK CARD NOTIFICATIONS
  // ============================================

  /// Notify when a task is created
  static Future<void> notifyTaskCreated({
    required String taskId,
    required String taskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String assignedById,
    String? assignedByName,
  }) async {
    _logger.info('Triggering notifications for task created: $taskName');

    final adminName =
        assignedByName ??
        (await _adminRepo.getById(assignedById))?.adminName ??
        assignedById;

    try {
      // Push notification to employee (single employee - gets token by employee_id)
      await FirebaseNotificationService.notifyTaskAssigned(
        employeeId: employeeId,
        taskName: taskName,
        projectName: projectName,
        assignedBy: adminName,
      );

      // Push notification to all admins (gets all admin tokens where user_type = 'Admin' and is_active = true)
      await FirebaseNotificationService.notifyAllAdminsForTaskCreation(
        title: 'New Task Created',
        body: 'Task "$taskName" assigned to $employeeName',
        data: {'type': 'task_created', 'task_id': taskId},
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'New Task Assigned',
        body:
            'You have been assigned a new task: "$taskName" for project "$projectName"',
        notificationType: 'task_created',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'project_name': projectName},
        createdBy: assignedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Task Created',
        body: 'Task "$taskName" assigned to $employeeName',
        notificationType: 'task_created',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {
          'task_name': taskName,
          'employee_name': employeeName,
          'project_name': projectName,
        },
        createdBy: assignedById,
      );

      // Send email to the employee
      if (employeeEmail.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: employeeEmail,
          subject: 'New Task Assigned - Webnox Sprintly',
          htmlContent: EmployeeEmailTemplate.generateTaskAssignedEmail(
            employeeName: employeeName,
            taskName: taskName,
            projectName: projectName,
            assignedBy: adminName,
          ),
        );
      }

      _logger.info('Task created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task created notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is updated
  static Future<void> notifyTaskUpdated({
    required String taskId,
    required String taskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String updatedById,
    String? updatedByName,
    String? employeeEmail,
    String? taskDescription,
    String? taskType,
    String? priorityLevel,
    String? fromDate,
    String? toDate,
    String? taskDuration,
  }) async {
    _logger.info('Triggering notifications for task updated: $taskName');

    final adminName =
        updatedByName ??
        (await _adminRepo.getById(updatedById))?.adminName ??
        updatedById;

    try {
      // Push notification to employee
      await FirebaseNotificationService.notifyTaskUpdated(
        employeeId: employeeId,
        taskName: taskName,
        updatedBy: adminName,
      );

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Task Updated',
        body: 'Task "$taskName" has been updated',
        data: {'type': 'task_updated', 'task_id': taskId},
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task Updated',
        body: 'Task "$taskName" has been updated',
        notificationType: 'task_updated',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'project_name': projectName},
        createdBy: updatedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task Updated',
        body: 'Task "$taskName" assigned to $employeeName has been updated',
        notificationType: 'task_updated',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'employee_name': employeeName},
        createdBy: updatedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendTaskUpdatedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName,
          taskName: taskName,
          taskDescription: taskDescription ?? 'No description',
          taskType: taskType ?? 'Task',
          priorityLevel: priorityLevel ?? 'Medium',
          projectName: projectName,
          updatedBy: adminName,
          fromDate: fromDate ?? 'N/A',
          toDate: toDate ?? 'N/A',
          taskDuration: taskDuration ?? 'N/A',
        );
      }

      _logger.info('Task updated notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task updated notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is duplicated
  static Future<void> notifyTaskDuplicated({
    required String taskId,
    required String taskName,
    required String originalTaskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String duplicatedById,
    String? duplicatedByName,
    String? employeeEmail,
    String? taskDescription,
    String? taskType,
    String? priorityLevel,
    String? fromDate,
    String? toDate,
    String? taskDuration,
  }) async {
    _logger.info('Triggering notifications for task duplicated: $taskName');

    final adminName =
        duplicatedByName ??
        (await _adminRepo.getById(duplicatedById))?.adminName ??
        duplicatedById;

    try {
      // Push notification to employee
      await FirebaseNotificationService.notifyTaskDuplicated(
        employeeId: employeeId,
        taskName: taskName,
      );

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Task Duplicated',
        body: 'Task "$originalTaskName" has been duplicated as "$taskName"',
        data: {'type': 'task_duplicated', 'task_id': taskId},
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'New Task (Duplicated)',
        body: 'You have been assigned a duplicated task: "$taskName"',
        notificationType: 'task_duplicated',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'original_task_name': originalTaskName},
        createdBy: duplicatedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task Duplicated',
        body:
            'Task "$originalTaskName" duplicated as "$taskName" for $employeeName',
        notificationType: 'task_duplicated',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'employee_name': employeeName},
        createdBy: duplicatedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendTaskDuplicatedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName,
          taskName: taskName,
          taskDescription: taskDescription ?? 'No description',
          taskType: taskType ?? 'Task',
          priorityLevel: priorityLevel ?? 'Medium',
          projectName: projectName,
          assignedBy: adminName,
          fromDate: fromDate ?? 'N/A',
          toDate: toDate ?? 'N/A',
          taskDuration: taskDuration ?? 'N/A',
          originalTaskName: originalTaskName,
        );
      }

      _logger.info('Task duplicated notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task duplicated notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is reassigned
  static Future<void> notifyTaskReassigned({
    required String taskId,
    required String taskName,
    required String projectName,
    required String newEmployeeId,
    required String newEmployeeName,
    String? oldEmployeeId,
    String? oldEmployeeName,
    required String reassignedById,
    String? reassignedByName,
    String? reason,
    // Email params
    String? newEmployeeEmail,
    String? oldEmployeeEmail,
    String? taskDescription,
    String? taskType,
    String? priorityLevel,
    String? fromDate,
    String? toDate,
    String? taskDuration,
  }) async {
    _logger.info('Triggering notifications for task reassigned: $taskName');

    final adminName =
        reassignedByName ??
        (await _adminRepo.getById(reassignedById))?.adminName ??
        reassignedById;

    try {
      // Push notifications
      await FirebaseNotificationService.notifyTaskReassigned(
        newEmployeeId: newEmployeeId,
        oldEmployeeId: oldEmployeeId,
        taskName: taskName,
      );

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Task Reassigned',
        body: 'Task "$taskName" reassigned to $newEmployeeName',
        data: {'type': 'task_reassigned', 'task_id': taskId},
      );

      // Local notification for new employee
      await _notificationRepo.createNotification(
        userId: newEmployeeId,
        userType: 'Employee',
        title: 'Task Reassigned to You',
        body: 'You have been assigned task: "$taskName"',
        notificationType: 'task_reassigned',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'project_name': projectName},
        createdBy: reassignedById,
      );

      // Local notification for old employee
      if (oldEmployeeId != null && oldEmployeeId != newEmployeeId) {
        await _notificationRepo.createNotification(
          userId: oldEmployeeId,
          userType: 'Employee',
          title: 'Task Reassigned',
          body: 'Task "$taskName" has been reassigned to $newEmployeeName',
          notificationType: 'task_reassigned_from',
          relatedEntityType: 'task',
          relatedEntityId: taskId,
          data: {'task_name': taskName, 'new_assignee': newEmployeeName},
          createdBy: reassignedById,
        );
      }

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task Reassigned',
        body:
            'Task "$taskName" reassigned from ${oldEmployeeName ?? 'N/A'} to $newEmployeeName by $adminName',
        notificationType: 'task_reassigned',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {
          'task_name': taskName,
          'new_employee': newEmployeeName,
          'old_employee': oldEmployeeName ?? '',
          'reassigned_by_name': adminName,
        },
        createdBy: reassignedById,
      );

      // Email to new employee
      if (newEmployeeEmail != null && newEmployeeEmail.isNotEmpty) {
        await _emailService.sendTaskReassignedToNewEmail(
          toEmail: newEmployeeEmail,
          employeeName: newEmployeeName,
          taskName: taskName,
          taskDescription: taskDescription ?? 'No description',
          taskType: taskType ?? 'Task',
          priorityLevel: priorityLevel ?? 'Medium',
          projectName: projectName,
          reassignedBy: adminName,
          fromDate: fromDate ?? 'N/A',
          toDate: toDate ?? 'N/A',
          taskDuration: taskDuration ?? 'N/A',
          previousAssignee: oldEmployeeName ?? 'Previous assignee',
        );
      }

      // Email to old employee
      if (oldEmployeeEmail != null && oldEmployeeEmail.isNotEmpty) {
        await _emailService.sendTaskReassignedFromEmail(
          toEmail: oldEmployeeEmail,
          employeeName: oldEmployeeName ?? 'Employee',
          taskName: taskName,
          projectName: projectName,
          reassignedBy: adminName,
          newAssignee: newEmployeeName,
          reason: reason,
        );
      }

      _logger.info('Task reassigned notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task reassigned notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is deleted
  static Future<void> notifyTaskDeleted({
    required String taskId,
    required String taskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String deletedById,
    String? deletedByName,
    String? reason,
    String? employeeEmail,
  }) async {
    _logger.info('Triggering notifications for task deleted: $taskName');

    final adminName =
        deletedByName ??
        (await _adminRepo.getById(deletedById))?.adminName ??
        deletedById;

    try {
      // Push notification to employee
      await FirebaseNotificationService.notifyTaskDeleted(
        employeeId: employeeId,
        taskName: taskName,
      );

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: 'Task Deleted',
        body: 'Task "$taskName" has been deleted',
        data: {'type': 'task_deleted', 'task_id': taskId},
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task Deleted',
        body: 'Task "$taskName" has been deleted',
        notificationType: 'task_deleted',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'reason': reason ?? ''},
        createdBy: deletedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task Deleted',
        body: 'Task "$taskName" for $employeeName has been deleted',
        notificationType: 'task_deleted',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {
          'task_name': taskName,
          'employee_name': employeeName,
          'deleted_by_name': adminName,
        },
        createdBy: deletedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendTaskDeletedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName,
          taskName: taskName,
          projectName: projectName,
          deletedBy: adminName,
        );
      }

      _logger.info('Task deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 5. TASK REQUEST NOTIFICATIONS
  // ============================================

  /// Notify when a task request is created
  static Future<void> notifyTaskRequestCreated({
    required String requestId,
    required String taskName,
    required String employeeId,
    required String employeeName,
    String? employeeEmail,
    String? projectName,
    String? taskDescription,
    String? taskType,
    String? priorityLevel,
    String? fromDate,
    String? toDate,
    String? taskDuration,
  }) async {
    _logger.info(
      'Triggering notifications for task request created: $taskName',
    );

    try {
      // 1. Push notification to all admins
      await FirebaseNotificationService.notifyTaskRequested(
        employeeName: employeeName,
        taskName: taskName,
      );

      // 2. Fetch all admins for email
      final admins = await _adminRepo.getAll(status: true);
      final adminEmails = <String>{};
      for (final admin in admins) {
        if (admin.adminCompanyEmail.isNotEmpty) {
          adminEmails.add(admin.adminCompanyEmail);
        } else if (admin.adminPersonalEmail.isNotEmpty) {
          adminEmails.add(admin.adminPersonalEmail);
        }
      }

      // 3. Email to admin(s) and employee
      final htmlContent = TaskCardRequestEmailTemplate.generateEmailContent(
        employeeName: employeeName,
        taskName: taskName,
        taskDescription: taskDescription ?? 'No description',
        taskType: taskType ?? 'Task',
        priorityLevel: priorityLevel ?? 'Medium',
        projectName: projectName ?? 'Unknown Project',
        assignedBy: employeeName,
        fromDate: fromDate ?? 'N/A',
        toDate: toDate ?? 'N/A',
        taskDuration: taskDuration ?? 'N/A',
      );

      final subject = TaskCardRequestEmailTemplate.generateEmailSubject(
        taskName: taskName,
        projectName: projectName ?? 'Unknown Project',
      );

      if (adminEmails.isNotEmpty ||
          (employeeEmail != null && employeeEmail.isNotEmpty)) {
        String toEmail;
        List<String> ccEmails = adminEmails.toList();

        if (employeeEmail != null && employeeEmail.isNotEmpty) {
          toEmail = employeeEmail;
        } else {
          toEmail = ccEmails.removeAt(0);
        }

        await _emailService.sendEmail(
          toEmail: toEmail,
          subject: subject,
          htmlContent: htmlContent,
          ccEmails: ccEmails,
        );
      }

      _logger.info('Task request creation notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task request creation notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task request is approved
  static Future<void> notifyTaskRequestApproved({
    required String requestId,
    required String taskName,
    required String employeeId,
    required String approvedById,
    String? approvedByName,
    String? remarks,
    String? employeeEmail,
    String? employeeName,
    String? projectName,
    String? taskDescription,
    String? taskType,
    String? priorityLevel,
    String? fromDate,
    String? toDate,
  }) async {
    _logger.info(
      'Triggering notifications for task request approved: $taskName',
    );

    final adminName =
        approvedByName ??
        (await _adminRepo.getById(approvedById))?.adminName ??
        approvedById;

    try {
      // Push notification to employee
      await FirebaseNotificationService.notifyTaskRequestApproved(
        employeeId: employeeId,
        taskName: taskName,
        approvedBy: adminName,
      );

      // Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task Request Approved',
        body: 'Your task request "$taskName" has been approved',
        notificationType: 'task_request_approved',
        relatedEntityType: 'task_request',
        relatedEntityId: requestId,
        data: {'task_name': taskName, 'remarks': remarks ?? ''},
        createdBy: approvedById,
      );

      // Simple email to employee
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendTaskRequestApprovedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          taskName: taskName,
          taskDescription: taskDescription ?? 'No description',
          taskType: taskType ?? 'Task',
          priorityLevel: priorityLevel ?? 'Medium',
          projectName: projectName ?? 'Unknown Project',
          approvedBy: adminName,
          remarks: remarks ?? 'Approved',
          fromDate: fromDate ?? 'N/A',
          toDate: toDate ?? 'N/A',
        );
      }

      _logger.info('Task request approved notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task request approved notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task request is rejected
  static Future<void> notifyTaskRequestRejected({
    required String requestId,
    required String taskName,
    required String employeeId,
    required String rejectedById,
    String? rejectedByName,
    String? reason,
    String? employeeEmail,
    String? employeeName,
    String? projectName,
    String? taskDescription,
    String? taskType,
    String? fromDate,
    String? toDate,
  }) async {
    _logger.info(
      'Triggering notifications for task request rejected: $taskName',
    );

    final adminName =
        rejectedByName ??
        (await _adminRepo.getById(rejectedById))?.adminName ??
        rejectedById;

    try {
      // Push notification to employee
      await FirebaseNotificationService.notifyTaskRequestRejected(
        employeeId: employeeId,
        taskName: taskName,
        reason: reason,
        rejectedBy: adminName,
      );

      // Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task Request Rejected',
        body: 'Your task request "$taskName" has been rejected',
        notificationType: 'task_request_rejected',
        relatedEntityType: 'task_request',
        relatedEntityId: requestId,
        data: {'task_name': taskName, 'reason': reason ?? ''},
        createdBy: rejectedById,
      );

      // Email to employee
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendTaskRequestRejectedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          taskName: taskName,
          taskDescription: taskDescription ?? 'No description',
          taskType: taskType ?? 'Task',
          projectName: projectName ?? 'Unknown Project',
          fromDate: fromDate ?? 'N/A',
          toDate: toDate ?? 'N/A',
          rejectedBy: adminName,
          rejectionReason: reason ?? 'Not specified',
        );
      }

      _logger.info('Task request rejected notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task request rejected notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is QA Approved
  static Future<void> notifyTaskQaApproved({
    required String taskId,
    required String taskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String approvedById,
    String? approvedByName,
    String? notes,
  }) async {
    _logger.info('Triggering notifications for task QA approved: $taskName');

    final adminName =
        approvedByName ??
        (await _adminRepo.getById(approvedById))?.adminName ??
        approvedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyTaskQaApproved(
        employeeId: employeeId,
        taskName: taskName,
        approvedBy: adminName,
      );

      // Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task QA Approved',
        body: 'Your task "$taskName" has been approved by QA',
        notificationType: 'task_qa_approved',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'notes': notes ?? ''},
        createdBy: approvedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task QA Approved',
        body: 'Task "$taskName" (Dev: $employeeName) approved by QA',
        notificationType: 'task_qa_approved',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {
          'task_name': taskName,
          'employee_name': employeeName,
          'notes': notes ?? '',
          'approved_by_name': adminName,
        },
        createdBy: approvedById,
      );

      // Email
      if (employeeEmail.isNotEmpty) {
        await _emailService.sendTaskQaApprovedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName,
          taskName: taskName,
          projectName: projectName,
          approvedBy: adminName,
          notes: notes,
        );
      }

      _logger.info('Task QA approved notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task QA approved notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a task is QA Rejected
  static Future<void> notifyTaskQaRejected({
    required String taskId,
    required String taskName,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    required String rejectedById,
    String? rejectedByName,
    required String notes,
  }) async {
    _logger.info('Triggering notifications for task QA rejected: $taskName');

    final adminName =
        rejectedByName ??
        (await _adminRepo.getById(rejectedById))?.adminName ??
        rejectedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyTaskQaRejected(
        employeeId: employeeId,
        taskName: taskName,
        notes: notes,
        rejectedBy: adminName,
      );

      // Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Task QA Rejected',
        body: 'Your task "$taskName" has been rejected by QA',
        notificationType: 'task_qa_rejected',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {'task_name': taskName, 'notes': notes},
        createdBy: rejectedById,
      );

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Task QA Rejected',
        body: 'Task "$taskName" (Dev: $employeeName) rejected by QA',
        notificationType: 'task_qa_rejected',
        relatedEntityType: 'task',
        relatedEntityId: taskId,
        data: {
          'task_name': taskName,
          'employee_name': employeeName,
          'notes': notes,
          'rejected_by_name': adminName,
        },
        createdBy: rejectedById,
      );

      // Email
      if (employeeEmail.isNotEmpty) {
        await _emailService.sendTaskQaRejectedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName,
          taskName: taskName,
          projectName: projectName,
          notes: notes,
          rejectedBy: adminName,
        );
      }

      _logger.info('Task QA rejected notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending task QA rejected notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 6. LEAVE/WFH/PERMISSION NOTIFICATIONS
  // ============================================

  /// Notify when a leave request is approved
  static Future<void> notifyLeaveApproved({
    required String leaveId,
    required String employeeId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String approvedById,
    String? approvedByName,
    String? remarks,
    String? employeeEmail,
    String? employeeName,
  }) async {
    _logger.info('Triggering notifications for leave approved');

    final adminName =
        approvedByName ??
        (await _adminRepo.getById(approvedById))?.adminName ??
        approvedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyLeaveApproved(
        employeeId: employeeId,
        dates: '$fromDate to $toDate',
        approvedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Leave Request Approved',
        body: 'Your leave request for $fromDate to $toDate has been approved',
        notificationType: 'leave_approved',
        relatedEntityType: 'leave',
        relatedEntityId: leaveId,
        data: {'from_date': fromDate, 'to_date': toDate},
        createdBy: approvedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendLeaveApprovedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          leaveType: leaveType,
          fromDate: fromDate,
          toDate: toDate,
          totalDays: totalDays,
          approvedBy: adminName,
          remarks: remarks ?? 'Approved',
        );
      }

      _logger.info('Leave approved notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending leave approved notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a leave request is rejected
  static Future<void> notifyLeaveRejected({
    required String leaveId,
    required String employeeId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String rejectedById,
    String? rejectedByName,
    String? reason,
    String? employeeEmail,
    String? employeeName,
  }) async {
    _logger.info('Triggering notifications for leave rejected');

    final adminName =
        rejectedByName ??
        (await _adminRepo.getById(rejectedById))?.adminName ??
        rejectedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyLeaveRejected(
        employeeId: employeeId,
        dates: '$fromDate to $toDate',
        reason: reason,
        rejectedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Leave Request Rejected',
        body:
            'Your leave request for $fromDate to $toDate has been rejected${reason != null ? ": $reason" : ""}',
        notificationType: 'leave_rejected',
        relatedEntityType: 'leave',
        relatedEntityId: leaveId,
        data: {
          'from_date': fromDate,
          'to_date': toDate,
          'reason': reason ?? '',
        },
        createdBy: rejectedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendLeaveRejectedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          leaveType: leaveType,
          fromDate: fromDate,
          toDate: toDate,
          totalDays: totalDays,
          rejectedBy: adminName,
          reason: reason ?? 'Not specified',
        );
      }

      _logger.info('Leave rejected notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending leave rejected notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a leave request is submitted (Sent to HR/Admin)
  static Future<void> notifyLeaveRequested({
    required String leaveId,
    required String employeeId,
    required String employeeName,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    bool isHalfDay = false,
    String? halfDayType,
    bool isPaidLeave = false,
  }) async {
    _logger.info('Triggering notifications for leave requested: $employeeName');

    try {
      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Leave Request',
        body:
            '$employeeName has requested $leaveType from $fromDate to $toDate',
        notificationType: 'leave_requested',
        relatedEntityType: 'leave',
        relatedEntityId: leaveId,
        data: {
          'employee_name': employeeName,
          'leave_type': leaveType,
          'total_days': totalDays,
        },
        createdBy: employeeId,
      );

      // Email all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendLeaveRequestedEmail(
            toEmail: email,
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
        }
      }

      _logger.info('Leave requested notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending leave requested notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a WFH request is approved
  static Future<void> notifyWFHApproved({
    required String wfhId,
    required String employeeId,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String approvedById,
    String? approvedByName,
    String? remarks,
    String? employeeEmail,
    String? employeeName,
  }) async {
    _logger.info('Triggering notifications for WFH approved');

    final adminName =
        approvedByName ??
        (await _adminRepo.getById(approvedById))?.adminName ??
        approvedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyWfhApproved(
        employeeId: employeeId,
        dates: '$fromDate to $toDate',
        approvedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'WFH Request Approved',
        body:
            'Your work from home request for $fromDate to $toDate has been approved',
        notificationType: 'wfh_approved',
        relatedEntityType: 'wfh',
        relatedEntityId: wfhId,
        data: {'from_date': fromDate, 'to_date': toDate},
        createdBy: approvedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendWFHApprovedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          fromDate: fromDate,
          toDate: toDate,
          totalDays: totalDays,
          reason: reason,
          approvedBy: adminName,
          remarks: remarks ?? 'Approved',
        );
      }

      _logger.info('WFH approved notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending WFH approved notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a WFH request is rejected
  static Future<void> notifyWFHRejected({
    required String wfhId,
    required String employeeId,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    required String rejectedById,
    String? rejectedByName,
    String? employeeEmail,
    String? employeeName,
  }) async {
    _logger.info('Triggering notifications for WFH rejected');

    final adminName =
        rejectedByName ??
        (await _adminRepo.getById(rejectedById))?.adminName ??
        rejectedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyWfhRejected(
        employeeId: employeeId,
        dates: '$fromDate to $toDate',
        reason: reason,
        rejectedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'WFH Request Rejected',
        body:
            'Your work from home request for $fromDate to $toDate has been rejected: $reason',
        notificationType: 'wfh_rejected',
        relatedEntityType: 'wfh',
        relatedEntityId: wfhId,
        data: {
          'from_date': fromDate,
          'to_date': toDate,
          'rejection_reason': reason,
        },
        createdBy: rejectedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendWFHRejectedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          fromDate: fromDate,
          toDate: toDate,
          totalDays: totalDays,
          reason: reason,
          rejectedBy: adminName,
          rejectionReason: reason,
        );
      }

      _logger.info('WFH rejected notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending WFH rejected notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a WFH request is submitted (Sent to HR/Admin)
  static Future<void> notifyWFHRequested({
    required String wfhId,
    required String employeeId,
    required String employeeName,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
    String? employeeRole,
  }) async {
    _logger.info('Triggering notifications for WFH requested: $employeeName');

    try {
      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New WFH Request',
        body: '$employeeName has requested WFH from $fromDate to $toDate',
        notificationType: 'wfh_requested',
        relatedEntityType: 'wfh',
        relatedEntityId: wfhId,
        data: {'employee_name': employeeName, 'total_days': totalDays},
        createdBy: employeeId,
      );

      // Email all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendWFHRequestedEmail(
            toEmail: email,
            employeeName: employeeName,
            fromDate: fromDate,
            toDate: toDate,
            totalDays: totalDays,
            reason: reason,
            employeeRole: employeeRole,
          );
        }
      }

      _logger.info('WFH requested notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending WFH requested notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a permission request is approved
  static Future<void> notifyPermissionApproved({
    required String permissionId,
    required String employeeId,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
    required String approvedById,
    String? approvedByName,
    String? remarks,
    String? employeeEmail,
    String? employeeName,
  }) async {
    _logger.info('Triggering notifications for permission approved');

    final adminName =
        approvedByName ??
        (await _adminRepo.getById(approvedById))?.adminName ??
        approvedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyPermissionApproved(
        employeeId: employeeId,
        date: permissionDate,
        approvedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Permission Request Approved',
        body:
            'Your permission request for $permissionDate ($fromTime - $toTime) has been approved',
        notificationType: 'permission_approved',
        relatedEntityType: 'permission',
        relatedEntityId: permissionId,
        data: {
          'date': permissionDate,
          'from_time': fromTime,
          'to_time': toTime,
        },
        createdBy: approvedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendPermissionApprovedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          permissionDate: permissionDate,
          fromTime: fromTime,
          toTime: toTime,
          totalHours: totalHours,
          reason: reason,
          approvedBy: adminName,
          remarks: remarks ?? 'Approved',
        );
      }

      _logger.info('Permission approved notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending permission approved notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a permission request is rejected
  static Future<void> notifyPermissionRejected({
    required String permissionId,
    required String employeeId,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
    required String rejectedById,
    String? rejectedByName,
    String? employeeEmail,
    String? employeeName,
    String? rejectionReason,
  }) async {
    _logger.info('Triggering notifications for permission rejected');

    final adminName =
        rejectedByName ??
        (await _adminRepo.getById(rejectedById))?.adminName ??
        rejectedById;

    try {
      // Push notification
      await FirebaseNotificationService.notifyPermissionRejected(
        employeeId: employeeId,
        date: permissionDate,
        reason: rejectionReason,
        rejectedBy: adminName,
      );

      // Local notification for the employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Permission Request Rejected',
        body:
            'Your permission request for $permissionDate ($fromTime - $toTime) has been rejected${rejectionReason != null ? ": $rejectionReason" : ""}',
        notificationType: 'permission_rejected',
        relatedEntityType: 'permission',
        relatedEntityId: permissionId,
        data: {
          'date': permissionDate,
          'rejection_reason': rejectionReason ?? '',
        },
        createdBy: rejectedById,
      );

      // Email
      if (employeeEmail != null && employeeEmail.isNotEmpty) {
        await _emailService.sendPermissionRejectedEmail(
          toEmail: employeeEmail,
          employeeName: employeeName ?? 'Employee',
          permissionDate: permissionDate,
          fromTime: fromTime,
          toTime: toTime,
          totalHours: totalHours,
          reason: reason,
          rejectedBy: adminName,
          rejectionReason: rejectionReason ?? 'Not specified',
        );
      }

      _logger.info('Permission rejected notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending permission rejected notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Notify when a permission request is submitted (Sent to HR/Admin)
  static Future<void> notifyPermissionRequested({
    required String permissionId,
    required String employeeId,
    required String employeeName,
    required String permissionDate,
    required String fromTime,
    required String toTime,
    required String totalHours,
    required String reason,
  }) async {
    _logger.info(
      'Triggering notifications for permission requested: $employeeName',
    );

    try {
      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Permission Request',
        body: '$employeeName has requested permission on $permissionDate',
        notificationType: 'permission_requested',
        relatedEntityType: 'permission',
        relatedEntityId: permissionId,
        data: {
          'employee_name': employeeName,
          'date': permissionDate,
          'hours': totalHours,
        },
        createdBy: employeeId,
      );

      // Email all admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendPermissionRequestedEmail(
            toEmail: email,
            employeeName: employeeName,
            permissionDate: permissionDate,
            fromTime: fromTime,
            toTime: toTime,
            totalHours: totalHours,
            reason: reason,
          );
        }
      }

      _logger.info('Permission requested notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending permission requested notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 7. ANNOUNCEMENT NOTIFICATIONS
  // ============================================

  /// Notify when an announcement is created
  static Future<void> notifyAnnouncementCreated({
    required String announcementId,
    required String title,
    required String content,
    required String createdBy,
  }) async {
    _logger.info('Triggering notifications for announcement: $title');

    try {
      // Push notification to all
      await FirebaseNotificationService.notifyAnnouncementCreated(title: title);

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'New Announcement',
        body: title,
        notificationType: 'announcement_created',
        relatedEntityType: 'announcement',
        relatedEntityId: announcementId,
        data: {'announcement_title': title},
        createdBy: createdBy,
      );

      // Local notifications for all employees
      await _notificationRepo.createNotificationForAllEmployees(
        title: 'New Announcement',
        body: title,
        notificationType: 'announcement_created',
        relatedEntityType: 'announcement',
        relatedEntityId: announcementId,
        data: {'announcement_title': title},
        createdBy: createdBy,
      );

      // Send email to all admins and employees
      final allAdmins = await _getAllActiveAdmins();
      final createdDate = DateTime.now().toIso8601String().split('T')[0];
      for (final a in allAdmins) {
        final e = _getAdminEmail(a);
        if (e != null && e.isNotEmpty) {
          await _emailService.sendAnnouncementCreatedEmail(
            toEmail: e,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            announcementTitle: title,
            announcementContent: content,
            createdBy: createdBy,
            createdDate: createdDate,
          );
        }
      }

      // Get all active employees for email
      final allEmployees = await DatabaseConnection.query(
        'SELECT employee_id, employee_name, employee_personal_email, employee_company_email FROM employees WHERE status = 1',
      );
      for (final employee in allEmployees) {
        final email = _getEmployeeEmail(employee);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendAnnouncementCreatedEmail(
            toEmail: email,
            recipientName: employee['employee_name'] as String? ?? 'Employee',
            announcementTitle: title,
            announcementContent: content,
            createdBy: createdBy,
            createdDate: createdDate,
          );
        }
      }

      _logger.info('Announcement notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending announcement notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> notifyAnnouncementUpdated({
    required String announcementId,
    required String title,
    required String content,
    required String updatedBy,
  }) async {
    _logger.info('Triggering notifications for announcement updated: $title');
    try {
      await FirebaseNotificationService.notifyAnnouncementUpdated(title: title);
      await _notificationRepo.createNotificationForAll(
        title: 'Announcement Updated',
        body: title,
        notificationType: 'announcement_updated',
        relatedEntityType: 'announcement',
        relatedEntityId: announcementId,
        data: {'announcement_title': title},
        createdBy: updatedBy,
      );
      final updatedDate = DateTime.now().toIso8601String().split('T')[0];
      final allAdmins = await _getAllActiveAdmins();
      for (final a in allAdmins) {
        final e = _getAdminEmail(a);
        if (e != null && e.isNotEmpty) {
          await _emailService.sendAnnouncementUpdatedEmail(
            toEmail: e,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            announcementTitle: title,
            announcementContent: content,
            updatedBy: updatedBy,
            updatedDate: updatedDate,
          );
        }
      }
      final allEmployees = await _getAllActiveEmployees();
      for (final emp in allEmployees) {
        final email = _getEmployeeEmail(emp);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendAnnouncementUpdatedEmail(
            toEmail: email,
            recipientName: emp['employee_name'] as String? ?? 'Employee',
            announcementTitle: title,
            announcementContent: content,
            updatedBy: updatedBy,
            updatedDate: updatedDate,
          );
        }
      }
      _logger.info('Announcement updated notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending announcement updated notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> notifyAnnouncementDeleted({
    required String announcementId,
    required String title,
    required String deletedBy,
  }) async {
    _logger.info('Triggering notifications for announcement deleted: $title');
    try {
      await FirebaseNotificationService.notifyAll(
        title: 'Announcement Removed',
        body: 'Announcement "$title" has been removed.',
        data: {
          'type': 'announcement_deleted',
          'announcement_id': announcementId,
          'announcement_title': title,
        },
      );
      await _notificationRepo.createNotificationForAll(
        title: 'Announcement Removed',
        body: 'Announcement "$title" has been removed.',
        notificationType: 'announcement_deleted',
        relatedEntityType: 'announcement',
        relatedEntityId: announcementId,
        data: {'announcement_title': title},
        createdBy: deletedBy,
      );
      final allAdmins = await _getAllActiveAdmins();
      for (final a in allAdmins) {
        final e = _getAdminEmail(a);
        if (e != null && e.isNotEmpty) {
          await _emailService.sendAnnouncementDeletedEmail(
            toEmail: e,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            announcementTitle: title,
            deletedBy: deletedBy,
          );
        }
      }
      final allEmployees = await _getAllActiveEmployees();
      for (final emp in allEmployees) {
        final email = _getEmployeeEmail(emp);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendAnnouncementDeletedEmail(
            toEmail: email,
            recipientName: emp['employee_name'] as String? ?? 'Employee',
            announcementTitle: title,
            deletedBy: deletedBy,
          );
        }
      }
      _logger.info('Announcement deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending announcement deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 8. CHAT MESSAGE NOTIFICATIONS
  // ============================================

  /// Notify when a new chat message is received
  static Future<void> notifyChatMessage({
    required String senderId,
    required String senderName,
    required String senderType,
    required String recipientId,
    required String recipientType,
    required String message,
    String? groupId,
    String? groupName,
    List<String>? groupMemberIds,
  }) async {
    try {
      if (groupId != null && groupMemberIds != null) {
        // Group message - notify all members except sender
        _logger.info(
          'Triggering notifications for group message in: $groupName',
        );

        for (final memberId in groupMemberIds) {
          if (memberId == senderId) continue; // Don't notify sender

          // Determine member type
          final isAdmin = await _isAdmin(memberId);
          final memberType = isAdmin ? 'Admin' : 'Employee';

          // Push notification
          if (isAdmin) {
            await FirebaseNotificationService.notifyAdmin(
              adminId: memberId,
              title: groupName ?? 'Group Message',
              body: '$senderName: $message',
              data: {'type': 'chat_message', 'group_id': groupId},
            );
          } else {
            await FirebaseNotificationService.notifyEmployee(
              employeeId: memberId,
              title: groupName ?? 'Group Message',
              body: '$senderName: $message',
              data: {'type': 'chat_message', 'group_id': groupId},
            );
          }

          // Local notification (no email for chat)
          await _notificationRepo.createNotification(
            userId: memberId,
            userType: memberType,
            title: groupName ?? 'Group Message',
            body: '$senderName: $message',
            notificationType: 'chat_message',
            relatedEntityType: 'chat_group',
            relatedEntityId: groupId,
            data: {'sender_name': senderName, 'group_name': groupName ?? ''},
            createdBy: senderId,
          );
        }
      } else {
        // Direct message
        _logger.info(
          'Triggering notifications for direct message to: $recipientId',
        );

        // Push notification
        if (recipientType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: recipientId,
            title: 'New Message from $senderName',
            body: message,
            data: {'type': 'chat_message', 'sender_id': senderId},
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: recipientId,
            title: 'New Message from $senderName',
            body: message,
            data: {'type': 'chat_message', 'sender_id': senderId},
          );
        }

        // Local notification (no email for chat)
        await _notificationRepo.createNotification(
          userId: recipientId,
          userType: recipientType,
          title: 'New Message from $senderName',
          body: message,
          notificationType: 'chat_message',
          relatedEntityType: 'chat',
          relatedEntityId: senderId,
          data: {'sender_name': senderName, 'sender_id': senderId},
          createdBy: senderId,
        );
      }

      _logger.info('Chat message notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending chat notifications: $e', e, stackTrace);
    }
  }

  // ============================================
  // 9. BIRTHDAY & ANNIVERSARY NOTIFICATIONS
  // ============================================

  /// Notify about birthday celebration
  static Future<void> notifyBirthday({
    required String personId,
    required String personName,
    required String personEmail,
    required String personType,
  }) async {
    _logger.info('Triggering birthday notifications for: $personName');

    try {
      final title = '🎂 Happy Birthday!';
      final bodyForAll =
          "Today is $personName's birthday! Wish them a wonderful day! 🎉";
      final bodyForPerson =
          'Happy Birthday, $personName! 🎂🎉 Wishing you a wonderful year ahead!';

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: title,
        body: bodyForAll,
        data: {
          'type': 'birthday',
          'person_id': personId,
          'person_type': personType,
        },
      );

      // Push notification to the birthday person
      if (personType == 'Admin') {
        await FirebaseNotificationService.notifyAdmin(
          adminId: personId,
          title: title,
          body: bodyForPerson,
          data: {'type': 'birthday'},
        );
      } else {
        await FirebaseNotificationService.notifyEmployee(
          employeeId: personId,
          title: title,
          body: bodyForPerson,
          data: {'type': 'birthday'},
        );
      }

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: title,
        body: bodyForAll,
        notificationType: 'birthday',
        relatedEntityType: personType.toLowerCase(),
        relatedEntityId: personId,
        data: {'person_name': personName, 'person_type': personType},
        createdBy: 'system',
      );

      // Local notification for the birthday person
      await _notificationRepo.createNotification(
        userId: personId,
        userType: personType,
        title: title,
        body: bodyForPerson,
        notificationType: 'birthday',
        relatedEntityType: personType.toLowerCase(),
        relatedEntityId: personId,
        data: {},
        createdBy: 'system',
      );

      // Send birthday email: To = person, CC = all admins
      final allAdmins = await _getAllActiveAdmins();
      final ccEmails = <String>[];
      for (final admin in allAdmins) {
        if (admin['admin_id'] == personId) continue; // Skip self
        final email = admin['admin_personal_email'] as String?;
        if (email != null && email.isNotEmpty) ccEmails.add(email);
      }
      await _emailService.sendEmail(
        toEmail: personEmail,
        subject: '🎂 Happy Birthday from Webnox Sprintly!',
        htmlContent: CelebrationEmailTemplate.generateBirthdayEmail(
          recipientName: personName,
          isSelf: true,
        ),
        ccEmails: ccEmails.isNotEmpty ? ccEmails : null,
      );

      _logger.info('Birthday notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending birthday notifications: $e', e, stackTrace);
    }
  }

  /// Notify about work anniversary celebration
  static Future<void> notifyWorkAnniversary({
    required String personId,
    required String personName,
    required String personEmail,
    required String personType,
    required int yearsCompleted,
  }) async {
    _logger.info(
      'Triggering work anniversary notifications for: $personName ($yearsCompleted years)',
    );

    try {
      final title = '🎉 Work Anniversary!';
      final bodyForAll =
          "$personName is celebrating $yearsCompleted year${yearsCompleted > 1 ? 's' : ''} at Webnox! 🎊";
      final bodyForPerson =
          'Congratulations on your $yearsCompleted year${yearsCompleted > 1 ? 's' : ''} work anniversary! 🎉';

      // Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: title,
        body: bodyForAll,
        data: {
          'type': 'work_anniversary',
          'person_id': personId,
          'years': yearsCompleted.toString(),
        },
      );

      // Push notification to the anniversary person
      if (personType == 'Admin') {
        await FirebaseNotificationService.notifyAdmin(
          adminId: personId,
          title: title,
          body: bodyForPerson,
          data: {
            'type': 'work_anniversary',
            'years': yearsCompleted.toString(),
          },
        );
      } else {
        await FirebaseNotificationService.notifyEmployee(
          employeeId: personId,
          title: title,
          body: bodyForPerson,
          data: {
            'type': 'work_anniversary',
            'years': yearsCompleted.toString(),
          },
        );
      }

      // Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: title,
        body: bodyForAll,
        notificationType: 'work_anniversary',
        relatedEntityType: personType.toLowerCase(),
        relatedEntityId: personId,
        data: {'person_name': personName, 'years_completed': yearsCompleted},
        createdBy: 'system',
      );

      // Local notification for the anniversary person
      await _notificationRepo.createNotification(
        userId: personId,
        userType: personType,
        title: title,
        body: bodyForPerson,
        notificationType: 'work_anniversary',
        relatedEntityType: personType.toLowerCase(),
        relatedEntityId: personId,
        data: {'years_completed': yearsCompleted},
        createdBy: 'system',
      );

      // Send anniversary email: To = person, CC = all admins
      final allAdmins = await _getAllActiveAdmins();
      final ccEmails = <String>[];
      for (final admin in allAdmins) {
        if (admin['admin_id'] == personId) continue; // Skip self
        final email = admin['admin_personal_email'] as String?;
        if (email != null && email.isNotEmpty) ccEmails.add(email);
      }
      await _emailService.sendEmail(
        toEmail: personEmail,
        subject: '🎉 Congratulations on Your Work Anniversary!',
        htmlContent: CelebrationEmailTemplate.generateWorkAnniversaryEmail(
          recipientName: personName,
          yearsCompleted: yearsCompleted,
          isSelf: true,
        ),
        ccEmails: ccEmails.isNotEmpty ? ccEmails : null,
      );

      _logger.info('Work anniversary notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending work anniversary notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // 10. COMPANY HOLIDAY NOTIFICATIONS
  // ============================================

  static String _fmtDate(DateTime? d) {
    if (d == null) return 'N/A';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<void> notifyCompanyHolidayCreated({
    required String holidayId,
    required String holidayName,
    required DateTime fromDate,
    DateTime? toDate,
    required int totalDays,
    String? remarks,
    required String createdBy,
    bool isOptional = false,
  }) async {
    _logger.info(
      'Triggering notifications for company holiday created: $holidayName',
    );
    try {
      final fromStr = _fmtDate(fromDate);
      final toStr = toDate != null ? _fmtDate(toDate) : fromStr;
      final body =
          'Company holiday added: $holidayName ($fromStr${totalDays > 1 ? ' – $toStr' : ''})';
      await FirebaseNotificationService.notifyAll(
        title: 'Company Holiday Added',
        body: body,
        data: {
          'type': 'company_holiday_created',
          'holiday_id': holidayId,
          'holiday_name': holidayName,
        },
      );
      await _notificationRepo.createNotificationForAll(
        title: 'Company Holiday Added',
        body: body,
        notificationType: 'company_holiday_created',
        relatedEntityType: 'company_holiday',
        relatedEntityId: holidayId,
        data: {'holiday_name': holidayName},
        createdBy: createdBy,
      );
      final allAdmins = await _getAllActiveAdmins();
      final allEmployees = await _getAllActiveEmployees();
      for (final a in allAdmins) {
        final email = _getAdminEmail(a);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayCreatedEmail(
            toEmail: email,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            holidayName: holidayName,
            fromDate: fromStr,
            toDate: toStr,
            totalDays: totalDays,
            remarks: remarks,
            createdBy: createdBy,
            isOptional: isOptional,
          );
        }
      }
      for (final emp in allEmployees) {
        final email = _getEmployeeEmail(emp);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayCreatedEmail(
            toEmail: email,
            recipientName: emp['employee_name'] as String? ?? 'Employee',
            holidayName: holidayName,
            fromDate: fromStr,
            toDate: toStr,
            totalDays: totalDays,
            remarks: remarks,
            createdBy: createdBy,
            isOptional: isOptional,
          );
        }
      }
      _logger.info('Company holiday created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending company holiday created notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> notifyCompanyHolidayUpdated({
    required String holidayId,
    required String holidayName,
    required DateTime fromDate,
    DateTime? toDate,
    required int totalDays,
    String? remarks,
    required String updatedBy,
    bool isOptional = false,
  }) async {
    _logger.info(
      'Triggering notifications for company holiday updated: $holidayName',
    );
    try {
      final fromStr = _fmtDate(fromDate);
      final toStr = toDate != null ? _fmtDate(toDate) : fromStr;
      final body = 'Company holiday updated: $holidayName';
      await FirebaseNotificationService.notifyAll(
        title: 'Company Holiday Updated',
        body: body,
        data: {
          'type': 'company_holiday_updated',
          'holiday_id': holidayId,
          'holiday_name': holidayName,
        },
      );
      await _notificationRepo.createNotificationForAll(
        title: 'Company Holiday Updated',
        body: body,
        notificationType: 'company_holiday_updated',
        relatedEntityType: 'company_holiday',
        relatedEntityId: holidayId,
        data: {'holiday_name': holidayName},
        createdBy: updatedBy,
      );
      final allAdmins = await _getAllActiveAdmins();
      final allEmployees = await _getAllActiveEmployees();
      for (final a in allAdmins) {
        final email = _getAdminEmail(a);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayUpdatedEmail(
            toEmail: email,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            holidayName: holidayName,
            fromDate: fromStr,
            toDate: toStr,
            totalDays: totalDays,
            remarks: remarks,
            updatedBy: updatedBy,
            isOptional: isOptional,
          );
        }
      }
      for (final emp in allEmployees) {
        final email = _getEmployeeEmail(emp);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayUpdatedEmail(
            toEmail: email,
            recipientName: emp['employee_name'] as String? ?? 'Employee',
            holidayName: holidayName,
            fromDate: fromStr,
            toDate: toStr,
            totalDays: totalDays,
            remarks: remarks,
            updatedBy: updatedBy,
            isOptional: isOptional,
          );
        }
      }
      _logger.info('Company holiday updated notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending company holiday updated notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> notifyCompanyHolidayDeleted({
    required String holidayId,
    required String holidayName,
    required String deletedBy,
    String? reason,
  }) async {
    _logger.info(
      'Triggering notifications for company holiday deleted: $holidayName',
    );
    try {
      final body = 'Company holiday removed: $holidayName';
      await FirebaseNotificationService.notifyAll(
        title: 'Company Holiday Removed',
        body: body,
        data: {
          'type': 'company_holiday_deleted',
          'holiday_id': holidayId,
          'holiday_name': holidayName,
        },
      );
      await _notificationRepo.createNotificationForAll(
        title: 'Company Holiday Removed',
        body: body,
        notificationType: 'company_holiday_deleted',
        relatedEntityType: 'company_holiday',
        relatedEntityId: holidayId,
        data: {'holiday_name': holidayName},
        createdBy: deletedBy,
      );
      final allAdmins = await _getAllActiveAdmins();
      final allEmployees = await _getAllActiveEmployees();
      for (final a in allAdmins) {
        final email = _getAdminEmail(a);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayDeletedEmail(
            toEmail: email,
            recipientName: a['admin_name'] as String? ?? 'Admin',
            holidayName: holidayName,
            deletedBy: deletedBy,
            reason: reason,
          );
        }
      }
      for (final emp in allEmployees) {
        final email = _getEmployeeEmail(emp);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendCompanyHolidayDeletedEmail(
            toEmail: email,
            recipientName: emp['employee_name'] as String? ?? 'Employee',
            holidayName: holidayName,
            deletedBy: deletedBy,
            reason: reason,
          );
        }
      }
      _logger.info('Company holiday deleted notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Error sending company holiday deleted notifications: $e',
        e,
        stackTrace,
      );
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get all active admins
  static Future<List<Map<String, dynamic>>> _getAllActiveAdmins() async {
    try {
      return await DatabaseConnection.query(
        'SELECT admin_id, admin_name, admin_personal_email, admin_company_email FROM admins WHERE status = 1',
      );
    } catch (e) {
      _logger.error('Error getting active admins: $e');
      return [];
    }
  }

  static String? _getAdminEmail(Map<String, dynamic> admin) {
    final companyEmail = admin['admin_company_email']?.toString();
    if (companyEmail != null && companyEmail.isNotEmpty) return companyEmail;
    final personalEmail = admin['admin_personal_email']?.toString();
    if (personalEmail != null && personalEmail.isNotEmpty) return personalEmail;
    return null;
  }

  static String? _getEmployeeEmail(Map<String, dynamic> employee) {
    final companyEmail = employee['employee_company_email']?.toString();
    if (companyEmail != null && companyEmail.isNotEmpty) return companyEmail;
    final personalEmail = employee['employee_personal_email']?.toString();
    if (personalEmail != null && personalEmail.isNotEmpty) return personalEmail;
    return null;
  }

  /// Get all active employees
  static Future<List<Map<String, dynamic>>> _getAllActiveEmployees() async {
    try {
      return await DatabaseConnection.query(
        'SELECT employee_id, employee_name, employee_personal_email, employee_company_email FROM employees WHERE status = 1',
      );
    } catch (e) {
      _logger.error('Error getting active employees: $e');
      return [];
    }
  }

  /// Check if a user is an admin
  static Future<bool> _isAdmin(String userId) async {
    try {
      final result = await DatabaseConnection.query(
        'SELECT 1 FROM admins WHERE admin_id = @id LIMIT 1',
        values: {'id': userId},
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // CALENDAR MEETING NOTIFICATIONS
  // ============================================

  /// Notify a participant when a meeting is scheduled
  static Future<void> notifyMeetingScheduled({
    required String meetingId,
    required String meetingName,
    required String meetingDescription,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    String? gmeetLink,
    required String participantId,
    required String participantName,
    required String participantEmail,
    required String participantType,
  }) async {
    _logger.info(
      'Sending meeting invitation to $participantId for "$meetingName"',
    );

    try {
      // 1. Push Notification (send based on participant type)
      if (participantType == 'Admin') {
        await FirebaseNotificationService.notifyAdmin(
          adminId: participantId,
          title: '📅 New Meeting: $meetingName',
          body:
              'Scheduled by $hostName on $meetingDate at $startTime. Venue: $venue',
          data: {'type': 'meeting_invitation', 'meeting_id': meetingId},
        );
      } else {
        await FirebaseNotificationService.notifyEmployee(
          employeeId: participantId,
          title: '📅 New Meeting: $meetingName',
          body:
              'Scheduled by $hostName on $meetingDate at $startTime. Venue: $venue',
          data: {'type': 'meeting_invitation', 'meeting_id': meetingId},
        );
      }

      // 2. Email Notification
      if (participantEmail.isNotEmpty && participantEmail.contains('@')) {
        final subject = CalendarMeetingEmailTemplate.generateInvitationSubject(
          meetingName,
        );
        final htmlContent =
            CalendarMeetingEmailTemplate.generateMeetingInvitationEmail(
              participantName: participantName,
              meetingName: meetingName,
              meetingDescription: meetingDescription,
              hostName: hostName,
              venue: venue,
              meetingDate: meetingDate,
              startTime: startTime,
              endTime: endTime,
              gmeetLink: gmeetLink,
            );
        await _emailService.sendEmail(
          toEmail: participantEmail,
          subject: subject,
          htmlContent: htmlContent,
        );
      }

      // 3. In-App Notification
      await _notificationRepo.createNotification(
        userId: participantId,
        userType: participantType,
        title: 'New Meeting: $meetingName',
        body:
            'Scheduled by $hostName on $meetingDate at $startTime. Venue: $venue',
        notificationType: 'meeting_invitation',
        relatedEntityType: 'meeting',
        relatedEntityId: meetingId,
        data: {
          'meeting_id': meetingId,
          'host_name': hostName,
          'venue': venue,
          'meeting_date': meetingDate,
          'start_time': startTime,
          'end_time': endTime,
        },
      );
    } catch (e, st) {
      _logger.error(
        'Error sending meeting invitation to $participantId: $e',
        e,
        st,
      );
    }
  }

  /// Notify host when a participant responds to a meeting
  static Future<void> notifyMeetingResponse({
    required String meetingId,
    required String meetingName,
    required String responderId,
    required String response, // 'accepted' or 'declined'
    required String hostId,
  }) async {
    _logger.info(
      'Notifying host $hostId about $response response from $responderId',
    );

    try {
      // Get responder name
      String responderName = responderId;
      try {
        final empResult = await DatabaseConnection.query(
          'SELECT employee_name FROM employees WHERE employee_id = @id',
          values: {'id': responderId},
        );
        if (empResult.isNotEmpty) {
          responderName = empResult.first['employee_name'] as String;
        } else {
          final adminResult = await DatabaseConnection.query(
            'SELECT admin_name FROM admins WHERE admin_id = @id',
            values: {'id': responderId},
          );
          if (adminResult.isNotEmpty) {
            responderName = adminResult.first['admin_name'] as String;
          }
        }
      } catch (_) {}

      final statusEmoji = response == 'accepted' ? '✅' : '❌';
      final statusText = response == 'accepted' ? 'accepted' : 'declined';

      // Push notification to host (hosts are always admins)
      await FirebaseNotificationService.notifyAdmin(
        adminId: hostId,
        title: '$statusEmoji Meeting Response: $meetingName',
        body: '$responderName has $statusText the meeting invitation.',
        data: {
          'type': 'meeting_response',
          'meeting_id': meetingId,
          'response': response,
        },
      );

      // In-App notification to host
      final isHostAdmin = await _isAdmin(hostId);
      await _notificationRepo.createNotification(
        userId: hostId,
        userType: isHostAdmin ? 'Admin' : 'Employee',
        title: '$statusEmoji Meeting Response: $meetingName',
        body: '$responderName has $statusText the meeting invitation.',
        notificationType: 'meeting_response',
        relatedEntityType: 'meeting',
        relatedEntityId: meetingId,
        data: {
          'meeting_id': meetingId,
          'responder_id': responderId,
          'responder_name': responderName,
          'response': response,
        },
      );
    } catch (e, st) {
      _logger.error('Error sending meeting response notification: $e', e, st);
    }
  }

  /// Send meeting reminder to specific participants
  static Future<void> notifyMeetingReminder({
    required String meetingId,
    required String meetingName,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    required String reminderMinutes,
    String? gmeetLink,
    required List<Map<String, dynamic>> participants,
    required List<String> declinedMembers,
  }) async {
    _logger.info(
      'Sending $reminderMinutes min reminder for "$meetingName" to ${participants.length} members',
    );

    for (final member in participants) {
      final memberId = member['user_id'] as String?;
      final memberName = member['user_name'] as String? ?? '';
      final memberEmail = member['user_email'] as String? ?? '';
      final memberType = member['user_type'] as String? ?? 'Employee';

      if (memberId == null || memberId.isEmpty) continue;

      // Skip declined members
      if (declinedMembers.contains(memberId)) continue;

      try {
        // 1. Push Notification (send based on member type)
        if (memberType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: memberId,
            title: '⏰ Meeting in $reminderMinutes min: $meetingName',
            body: 'Your meeting at $venue starts at $startTime. Get ready!',
            data: {
              'type': 'meeting_reminder',
              'meeting_id': meetingId,
              'reminder_minutes': reminderMinutes,
            },
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: memberId,
            title: '⏰ Meeting in $reminderMinutes min: $meetingName',
            body: 'Your meeting at $venue starts at $startTime. Get ready!',
            data: {
              'type': 'meeting_reminder',
              'meeting_id': meetingId,
              'reminder_minutes': reminderMinutes,
            },
          );
        }

        // 2. Email Notification
        if (memberEmail.isNotEmpty && memberEmail.contains('@')) {
          final subject = CalendarMeetingEmailTemplate.generateReminderSubject(
            meetingName,
            reminderMinutes,
          );
          final htmlContent =
              CalendarMeetingEmailTemplate.generateMeetingReminderEmail(
                participantName: memberName,
                meetingName: meetingName,
                hostName: hostName,
                venue: venue,
                meetingDate: meetingDate,
                startTime: startTime,
                endTime: endTime,
                reminderMinutes: reminderMinutes,
                gmeetLink: gmeetLink,
              );
          await _emailService.sendEmail(
            toEmail: memberEmail,
            subject: subject,
            htmlContent: htmlContent,
          );
        }

        // 3. In-App Notification
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: memberType,
          title: '⏰ Meeting in $reminderMinutes min: $meetingName',
          body: 'Your meeting at $venue starts at $startTime. Get ready!',
          notificationType: 'meeting_reminder',
          relatedEntityType: 'meeting',
          relatedEntityId: meetingId,
          data: {'meeting_id': meetingId, 'reminder_minutes': reminderMinutes},
        );
      } catch (e) {
        _logger.warning('Failed to send reminder to $memberId: $e');
      }
    }
  }

  /// Notify participants when a meeting is postponed
  static Future<void> notifyMeetingPostponed({
    required String meetingId,
    required String meetingName,
    required String hostName,
    required String oldDate,
    required String oldStartTime,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    required String reason,
    required List<Map<String, dynamic>> participants,
  }) async {
    _logger.info(
      'Notifying ${participants.length} members about postponement of "$meetingName"',
    );

    for (final member in participants) {
      final memberId = member['user_id'] as String?;
      final memberName = member['user_name'] as String? ?? '';
      final memberEmail = member['user_email'] as String? ?? '';
      final memberType = member['user_type'] as String? ?? 'Employee';

      if (memberId == null || memberId.isEmpty) continue;

      try {
        // 1. Push Notification
        if (memberType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: memberId,
            title: '📅 Meeting Postponed: $meetingName',
            body: 'Rescheduled to $newDate at $newStartTime. Reason: $reason',
            data: {
              'type': 'meeting_postponed',
              'meeting_id': meetingId,
              'new_date': newDate,
              'new_time': newStartTime,
            },
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: memberId,
            title: '📅 Meeting Postponed: $meetingName',
            body: 'Rescheduled to $newDate at $newStartTime. Reason: $reason',
            data: {
              'type': 'meeting_postponed',
              'meeting_id': meetingId,
              'new_date': newDate,
              'new_time': newStartTime,
            },
          );
        }

        // 2. Email Notification
        if (memberEmail.isNotEmpty && memberEmail.contains('@')) {
          final subject = CalendarMeetingEmailTemplate.generatePostponedSubject(
            meetingName,
          );
          final htmlContent =
              CalendarMeetingEmailTemplate.generateMeetingPostponedEmail(
                participantName: memberName,
                meetingName: meetingName,
                hostName: hostName,
                oldDate: oldDate,
                oldStartTime: oldStartTime,
                newDate: newDate,
                newStartTime: newStartTime,
                newEndTime: newEndTime,
                reason: reason,
              );

          await _emailService.sendEmail(
            toEmail: memberEmail,
            subject: subject,
            htmlContent: htmlContent,
          );
        }

        // 3. In-App Notification
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: memberType,
          title: 'Meeting Postponed: $meetingName',
          body: 'Rescheduled to $newDate at $newStartTime. Reason: $reason',
          notificationType: 'meeting_postponed',
          relatedEntityType: 'meeting',
          relatedEntityId: meetingId,
          data: {
            'meeting_id': meetingId,
            'new_date': newDate,
            'new_start_time': newStartTime,
            'new_end_time': newEndTime,
            'reason': reason,
          },
        );
      } catch (e) {
        _logger.warning('Failed to notify $memberId about postponement: $e');
      }
    }
  }

  /// Notify participants when a meeting is cancelled
  static Future<void> notifyMeetingCancelled({
    required String meetingId,
    required String meetingName,
    required String hostName,
    required String meetingDate,
    required String startTime,
    required List<Map<String, dynamic>> participants,
  }) async {
    _logger.info(
      'Notifying ${participants.length} members about cancellation of "$meetingName"',
    );

    for (final member in participants) {
      final memberId = member['user_id'] as String?;
      final memberName = member['user_name'] as String? ?? '';
      final memberEmail = member['user_email'] as String? ?? '';
      final memberType = member['user_type'] as String? ?? 'Employee';

      if (memberId == null || memberId.isEmpty) continue;

      try {
        // 1. Push Notification
        if (memberType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: memberId,
            title: '🚫 Meeting Cancelled: $meetingName',
            body: 'The meeting scheduled for $meetingDate has been cancelled.',
            data: {'type': 'meeting_cancelled', 'meeting_id': meetingId},
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: memberId,
            title: '🚫 Meeting Cancelled: $meetingName',
            body: 'The meeting scheduled for $meetingDate has been cancelled.',
            data: {'type': 'meeting_cancelled', 'meeting_id': meetingId},
          );
        }

        // 2. Email Notification
        if (memberEmail.isNotEmpty && memberEmail.contains('@')) {
          final subject = CalendarMeetingEmailTemplate.generateCancelledSubject(
            meetingName,
          );
          final htmlContent =
              CalendarMeetingEmailTemplate.generateMeetingCancelledEmail(
                participantName: memberName,
                meetingName: meetingName,
                hostName: hostName,
                meetingDate: meetingDate,
                startTime: startTime,
              );

          await _emailService.sendEmail(
            toEmail: memberEmail,
            subject: subject,
            htmlContent: htmlContent,
          );
        }

        // 3. In-App Notification
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: memberType,
          title: 'Meeting Cancelled: $meetingName',
          body: 'The meeting scheduled for $meetingDate has been cancelled.',
          notificationType: 'meeting_cancelled',
          relatedEntityType: 'meeting',
          relatedEntityId: meetingId,
          data: {
            'meeting_id': meetingId,
            'meeting_name': meetingName,
            'meeting_date': meetingDate,
          },
        );
      } catch (e) {
        _logger.warning('Failed to notify $memberId about cancellation: $e');
      }
    }
  }

  /// Notify participants when a meeting is updated
  static Future<void> notifyMeetingUpdated({
    required String meetingId,
    required String meetingName,
    required String hostName,
    required String venue,
    required String meetingDate,
    required String startTime,
    required String endTime,
    String? gmeetLink,
    required List<Map<String, dynamic>> participants,
  }) async {
    _logger.info(
      'Notifying ${participants.length} members about update of "$meetingName"',
    );

    for (final member in participants) {
      final memberId = member['user_id'] as String?;
      final memberName = member['user_name'] as String? ?? '';
      final memberEmail = member['user_email'] as String? ?? '';
      final memberType = member['user_type'] as String? ?? 'Employee';

      if (memberId == null || memberId.isEmpty) continue;

      try {
        // 1. Push Notification
        if (memberType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: memberId,
            title: '📝 Meeting Updated: $meetingName',
            body: 'Details have been updated. Check the new schedule.',
            data: {'type': 'meeting_updated', 'meeting_id': meetingId},
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: memberId,
            title: '📝 Meeting Updated: $meetingName',
            body: 'Details have been updated. Check the new schedule.',
            data: {'type': 'meeting_updated', 'meeting_id': meetingId},
          );
        }

        // 2. Email Notification
        if (memberEmail.isNotEmpty && memberEmail.contains('@')) {
          final subject = CalendarMeetingEmailTemplate.generateUpdatedSubject(
            meetingName,
          );
          final htmlContent =
              CalendarMeetingEmailTemplate.generateMeetingUpdatedEmail(
                participantName: memberName,
                meetingName: meetingName,
                hostName: hostName,
                venue: venue,
                meetingDate: meetingDate,
                startTime: startTime,
                endTime: endTime,
                gmeetLink: gmeetLink,
              );

          await _emailService.sendEmail(
            toEmail: memberEmail,
            subject: subject,
            htmlContent: htmlContent,
          );
        }

        // 3. In-App Notification
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: memberType,
          title: 'Meeting Updated: $meetingName',
          body: 'Details have been updated. Check the new schedule.',
          notificationType: 'meeting_updated',
          relatedEntityType: 'meeting',
          relatedEntityId: meetingId,
          data: {
            'meeting_id': meetingId,
            'meeting_name': meetingName,
            'meeting_date': meetingDate,
            'start_time': startTime,
            'end_time': endTime,
            'venue': venue,
          },
        );
      } catch (e) {
      }
    }
  }

  // ============================================
  // 11. CHAT GROUP NOTIFICATIONS
  // ============================================

  /// Notify when a new chat group is created
  static Future<void> notifyGroupCreated({
    required String conversationId,
    required String groupName,
    required String creatorName,
    String? description,
    required List<Map<String, dynamic>> participants,
  }) async {
    _logger.info('Triggering notifications for group created: $groupName');

    try {
      for (final member in participants) {
        final memberId = member['userId']?.toString() ?? member['user_id']?.toString() ?? '';
        final memberType = member['userType']?.toString() ?? member['user_type']?.toString() ?? 'Employee';

        if (memberId.isEmpty) continue;

        // 1. Push notification
        if (memberType == 'Admin') {
          await FirebaseNotificationService.notifyAdmin(
            adminId: memberId,
            title: '💬 New Group Invitation',
            body: '$creatorName added you to group "$groupName"',
            data: {'type': 'group_created', 'conversation_id': conversationId},
          );
        } else {
          await FirebaseNotificationService.notifyEmployee(
            employeeId: memberId,
            title: '💬 New Group Invitation',
            body: '$creatorName added you to group "$groupName"',
            data: {'type': 'group_created', 'conversation_id': conversationId},
          );
        }

        // 2. Local notification
        await _notificationRepo.createNotification(
          userId: memberId,
          userType: memberType,
          title: 'New Group Invitation',
          body: 'You have been added to group "$groupName" by $creatorName',
          notificationType: 'group_created',
          relatedEntityType: 'chat_group',
          relatedEntityId: conversationId,
          data: {'group_name': groupName, 'creator_name': creatorName},
          createdBy: creatorName,
        );

        // 3. Email notification (Optional, based on user type)
        String? memberEmail;
        String? memberName;
        
        if (memberType == 'Admin') {
           final admin = await _adminRepo.getById(memberId);
           memberEmail = admin?.adminCompanyEmail ?? admin?.adminPersonalEmail;
           memberName = admin?.adminName;
        } else {
           final emp = await _employeeRepo.getById(memberId);
           memberEmail = emp?.employeeCompanyEmail ?? emp?.employeePersonalEmail;
           memberName = emp?.employeeName;
        }

        if (memberEmail != null && memberEmail.isNotEmpty) {
           await _emailService.sendEmail(
             toEmail: memberEmail,
             subject: '💬 New TeamSync Group: $groupName',
             htmlContent: ChatEmailTemplate.generateGroupCreatedEmail(
               recipientName: memberName ?? 'User',
               groupName: groupName,
               createdBy: creatorName,
               description: description,
             ),
           );
        }
      }

      _logger.info('Group created notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending group created notifications: $e', e, stackTrace);
    }
  }

  /// Notify when a member is removed from a group
  static Future<void> notifyMemberRemoved({
    required String conversationId,
    required String groupName,
    required String removerName,
    required String removedUserId,
    required String removedUserType,
  }) async {
    _logger.info('Triggering notification for member removed: $removedUserId from $groupName');

    try {
      // 1. Push notification
      if (removedUserType == 'Admin') {
        await FirebaseNotificationService.notifyAdmin(
          adminId: removedUserId,
          title: '🚪 Removed from Group',
          body: 'You have been removed from "$groupName" by $removerName',
          data: {'type': 'member_removed', 'conversation_id': conversationId},
        );
      } else {
        await FirebaseNotificationService.notifyEmployee(
          employeeId: removedUserId,
          title: '🚪 Removed from Group',
          body: 'You have been removed from "$groupName" by $removerName',
          data: {'type': 'member_removed', 'conversation_id': conversationId},
        );
      }

      // 2. Local notification
      await _notificationRepo.createNotification(
        userId: removedUserId,
        userType: removedUserType,
        title: 'Removed from Group',
        body: 'You have been removed from group "$groupName" by $removerName',
        notificationType: 'member_removed',
        relatedEntityType: 'chat_group',
        relatedEntityId: conversationId,
        data: {'group_name': groupName, 'remover_name': removerName},
        createdBy: removerName,
      );

      _logger.info('Member removed notification sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending member removed notification: $e', e, stackTrace);
    }
  }

  // ============================================
  // 12. EMPLOYEE DOCUMENT NOTIFICATIONS
  // ============================================

  /// Notify when documents are requested from an employee
  static Future<void> notifyDocumentRequested({
    required String employeeId,
    required String employeeName,
    required String adminName,
    required String documentList,
    required int documentCount,
  }) async {
    _logger.info('Triggering notifications for document request to: $employeeName');

    try {
      // 1. Push notification to employee
      await FirebaseNotificationService.notifyEmployee(
        employeeId: employeeId,
        title: '📋 Document Request',
        body: '$adminName has requested $documentCount document(s) for verification.',
        data: {'type': 'document_requested'},
      );

      // 2. Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Document Request',
        body: '$adminName has requested: $documentList',
        notificationType: 'document_requested',
        relatedEntityType: 'employee_document',
        relatedEntityId: employeeId,
        data: {
          'admin_name': adminName,
          'document_list': documentList,
          'count': documentCount,
        },
        createdBy: adminName,
      );

      // 3. Email to employee
      final emp = await _employeeRepo.getById(employeeId);
      final email = emp?.employeeCompanyEmail ?? emp?.employeePersonalEmail;
      if (email != null && email.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: email,
          subject: '📋 Document Request - Webnox Sprintly',
          htmlContent: EmployeeDocumentEmailTemplate.generateDocumentRequestEmail(
            employeeName: employeeName,
            adminName: adminName,
            documentList: documentList.replaceAll(', ', '<br>• '),
            documentCount: documentCount,
          ),
        );
      }

      _logger.info('Document request notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending document request notifications: $e', e, stackTrace);
    }
  }

  /// Notify when an employee submits a document
  static Future<void> notifyDocumentSubmitted({
    required String employeeId,
    required String employeeName,
    required String documentName,
  }) async {
    _logger.info('Triggering notifications for document submission from: $employeeName');

    try {
      // 1. Push notification to all admins
      await FirebaseNotificationService.notifyAllAdmins(
        title: '✅ Document Submitted',
        body: '$employeeName submitted "$documentName" for review.',
        data: {'type': 'document_submitted', 'employee_id': employeeId},
      );

      // 2. Local notifications for all admins
      await _notificationRepo.createNotificationForAllAdmins(
        title: 'Document Submitted',
        body: '$employeeName submitted "$documentName"',
        notificationType: 'document_submitted',
        relatedEntityType: 'employee_document',
        relatedEntityId: employeeId,
        data: {'employee_name': employeeName, 'document_name': documentName},
        createdBy: employeeId,
      );

      // 3. Email to all active admins
      final allAdmins = await _getAllActiveAdmins();
      for (final admin in allAdmins) {
        final email = _getAdminEmail(admin);
        if (email != null && email.isNotEmpty) {
          await _emailService.sendEmail(
            toEmail: email,
            subject: '✅ Document Submitted review required - Webnox Sprintly',
            htmlContent: EmployeeDocumentEmailTemplate.generateDocumentSubmittedEmail(
              adminName: admin['admin_name'] as String? ?? 'Admin',
              employeeName: employeeName,
              documentName: documentName,
            ),
          );
        }
      }

      _logger.info('Document submission notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending document submission notifications: $e', e, stackTrace);
    }
  }

  /// Notify when a document review is completed (approved/rejected)
  static Future<void> notifyDocumentReviewed({
    required String employeeId,
    required String employeeName,
    required String documentName,
    required String status,
    String? adminComments,
  }) async {
    final statusLabel = status.toLowerCase() == 'approved' ? 'Approved' : 'Rejected';
    final emoji = status.toLowerCase() == 'approved' ? '✅' : '❌';
    _logger.info('Triggering notifications for document $statusLabel: $documentName');

    try {
      // 1. Push notification to employee
      await FirebaseNotificationService.notifyEmployee(
        employeeId: employeeId,
        title: '$emoji Document $statusLabel',
        body: 'Your document "$documentName" has been $status.',
        data: {'type': 'document_reviewed', 'status': status},
      );

      // 2. Local notification for employee
      await _notificationRepo.createNotification(
        userId: employeeId,
        userType: 'Employee',
        title: 'Document Reviewed',
        body: 'Your document "$documentName" has been $statusLabel',
        notificationType: 'document_reviewed',
        relatedEntityType: 'employee_document',
        relatedEntityId: employeeId,
        data: {
          'document_name': documentName,
          'status': status,
          'comments': adminComments ?? '',
        },
        createdBy: 'Admin',
      );

      // 3. Email to employee
      final emp = await _employeeRepo.getById(employeeId);
      final email = emp?.employeeCompanyEmail ?? emp?.employeePersonalEmail;
      if (email != null && email.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: email,
          subject: '$emoji Document Verification Update - Webnox Sprintly',
          htmlContent: EmployeeDocumentEmailTemplate.generateDocumentReviewedEmail(
            employeeName: employeeName,
            documentName: documentName,
            status: status,
            adminComments: adminComments,
          ),
        );
      }

      _logger.info('Document review notifications sent successfully');
    } catch (e, stackTrace) {
      _logger.error('Error sending document review notifications: $e', e, stackTrace);
    }
  }
}
