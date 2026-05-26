import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:path/path.dart' as p;
import '../core/utils/logger.dart';
import '../data/repositories/fcm_token_repository.dart';

/// Firebase Cloud Messaging Notification Service
/// Uses FCM HTTP v1 API with Service Account authentication
class FirebaseNotificationService {
  static final AppLogger _logger = AppLogger('FirebaseNotificationService');
  static final FcmTokenRepository _fcmTokenRepository = FcmTokenRepository();

  // Firebase project configuration - loaded from environment
  static String? _projectId;
  static String? _serviceAccountJson;
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // Notification icon and branding
  static const String _notificationIcon = 'ic_notification';
  static const String _appName = 'Webnox Sprintly';
  static const String _androidChannelId = 'webnox_sprintly_notifications';

  /// Initialize the Firebase notification service
  /// Resolves service account path from env, CWD, or package root so it works regardless of run directory.
  static Future<void> initialize() async {
    try {
      _projectId =
          Platform.environment['FIREBASE_PROJECT_ID'] ??
          _getEnvValue('FIREBASE_PROJECT_ID');

      final envPath =
          Platform.environment['FIREBASE_SERVICE_ACCOUNT_PATH'] ??
          _getEnvValue('FIREBASE_SERVICE_ACCOUNT_PATH');

      final candidates = <String>[];
      if (envPath != null && envPath.isNotEmpty) {
        candidates.add(p.normalize(envPath));
      }
      candidates.add('firebase-service-account.json');
      candidates.add(
        p.join(Directory.current.path, 'firebase-service-account.json'),
      );
      try {
        final scriptPath = Platform.script.toFilePath();
        if (scriptPath.isNotEmpty) {
          final binDir = p.dirname(scriptPath);
          final packageRoot = p.dirname(binDir);
          candidates.add(p.join(packageRoot, 'firebase-service-account.json'));
        }
      } catch (_) {}

      File? serviceAccountFile;
      String? usedPath;
      for (final path in candidates) {
        final file = File(path);
        if (await file.exists()) {
          serviceAccountFile = file;
          usedPath = path;
          break;
        }
      }

      if (serviceAccountFile != null && usedPath != null) {
        _serviceAccountJson = await serviceAccountFile.readAsString();
        final serviceAccount = jsonDecode(_serviceAccountJson!);
        _projectId ??= serviceAccount['project_id'];
        _logger.info(
          'Firebase service initialized with project: $_projectId (file: $usedPath)',
        );
      } else {
        _logger.warning(
          'Firebase service account file not found. Tried: $candidates',
        );
        _logger.warning(
          'Push notifications will be disabled. Please add firebase-service-account.json or set FIREBASE_SERVICE_ACCOUNT_PATH.',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Firebase service: $e', e, stackTrace);
    }
  }

  /// Get environment variable from .env file
  static String? _getEnvValue(String key) {
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          if (line.startsWith('$key=')) {
            return line.substring(key.length + 1);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get OAuth2 access token for FCM API
  static Future<String?> _getAccessToken() async {
    if (_serviceAccountJson == null) {
      _logger.warning('Service account not configured, skipping notification');
      return null;
    }

    // Return cached token if still valid
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(
        _tokenExpiry!.subtract(const Duration(minutes: 5)),
      )) {
        return _accessToken;
      }
    }

    try {
      final serviceAccount = jsonDecode(_serviceAccountJson!);
      final clientEmail = serviceAccount['client_email'];
      final privateKey = serviceAccount['private_key'];

      // Create JWT for service account using dart_jsonwebtoken
      final now = DateTime.now().toUtc();
      final expiry = now.add(const Duration(hours: 1));

      final key = RSAPrivateKey(privateKey);
      final jwtToken = JWT({
        'iss': clientEmail,
        'sub': clientEmail,
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
      });

      final jwt = jwtToken.sign(key, algorithm: JWTAlgorithm.RS256);

      // Exchange JWT for access token
      final bodyParams = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': jwt,
      };

      final bodyString = bodyParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: bodyString,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in'] ?? 3600),
        );
        return _accessToken;
      } else {
        _logger.error('Failed to get access token: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.error('Error getting access token: $e', e, stackTrace);
      return null;
    }
  }

  /// Send notification to a single FCM token
  static Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
    String? imageUrl,
  }) async {
    // Skip legacy API - use HTTP v1 API directly since legacy is disabled
    if (_projectId == null) {
      _logger.warning('Firebase project not configured, skipping notification');
      return false;
    }

    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        _logger.warning('No access token available, cannot send notification');
        return false;
      }

      final url =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final message = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
            if (imageUrl != null) 'image': imageUrl,
          },
          'data': {...?data, 'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
          'android': {
            'notification': {
              'channel_id': _androidChannelId,
              'icon': _notificationIcon,
              'color': '#6366F1',
            },
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
          'webpush': {
            'notification': {
              'icon': '/icons/Icon-192.png',
              'badge': '/icons/Icon-192.png',
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        _logger.info('Notification sent successfully to token');
        return true;
      } else {
        final responseBody = response.body;
        _logger.error('Failed to send notification: $responseBody');

        // Check for UNREGISTERED/INVALID token errors and remove invalid tokens
        try {
          final errorData = jsonDecode(responseBody);
          if (errorData['error'] != null) {
            final error = errorData['error'];
            final errorCode = error['details']?[0]?['errorCode'];
            final errorMessage =
                error['message']?.toString().toLowerCase() ?? '';

            // Check for various invalid token indicators
            final isInvalidToken =
                errorCode == 'UNREGISTERED' ||
                errorCode == 'INVALID_ARGUMENT' ||
                errorMessage.contains('notregistered') ||
                errorMessage.contains('invalid') ||
                errorMessage.contains('unregistered');

            if (isInvalidToken) {
              _logger.warning(
                'Token is unregistered/invalid (errorCode: $errorCode), removing from database',
              );
              try {
                await _fcmTokenRepository.removeToken(token);
                _logger.info(
                  'Successfully removed invalid token from database',
                );
              } catch (e) {
                _logger.error('Failed to remove invalid token: $e');
              }
            }
          }
        } catch (e) {
          // Ignore JSON parsing errors, but log them
          _logger.warning('Could not parse error response: $e');
        }

        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Error sending notification: $e', e, stackTrace);
      return false;
    }
  }

  /// Send notification to multiple tokens
  /// [targetLabel] Optional description for logs (e.g. "Employee:emp1", "All admins").
  static Future<void> sendToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
    String? imageUrl,
    String? targetLabel,
  }) async {
    final target = targetLabel != null ? ' | Target: $targetLabel' : '';

    if (tokens.isEmpty) {
      _logger.info('[PUSH] No tokens to send to, skipping$target');
      return;
    }

    // Remove duplicates
    final uniqueTokens = tokens.toSet().toList();
    _logger.info(
      '[PUSH] Sending to ${uniqueTokens.length} token(s)$target | Title: $title',
    );

    int successCount = 0;
    int invalidTokenCount = 0;

    for (final token in uniqueTokens) {
      try {
        final success = await sendToToken(
          token: token,
          title: title,
          body: body,
          data: data,
          imageUrl: imageUrl,
        );
        if (success) {
          successCount++;
        } else {
          invalidTokenCount++;
        }
      } catch (e) {
        _logger.warning('Failed to send notification to token: $e');
        invalidTokenCount++;
      }
    }

    if (successCount > 0) {
      _logger.info(
        '[PUSH] Delivered: $successCount/${uniqueTokens.length} token(s)$target',
      );
    }
    if (invalidTokenCount > 0) {
      _logger.warning(
        '[PUSH] Failed: $invalidTokenCount/${uniqueTokens.length} token(s) (invalid/unregistered)$target',
      );
    }
    if (successCount == 0 && uniqueTokens.isNotEmpty) {
      _logger.warning(
        '[PUSH] No notifications delivered (all tokens failed)$target',
      );
    }
  }

  // ============================================
  // HIGH-LEVEL NOTIFICATION METHODS
  // ============================================

  /// Notify a specific employee
  static Future<void> notifyEmployee({
    required String employeeId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'employee_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: Employee:$employeeId | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getTokensForUser(
      employeeId,
      'Employee',
    );
    if (tokens.isEmpty) {
      _logger.warning(
        '[PUSH] No FCM tokens for Employee:$employeeId - push not sent',
      );
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'employee_notification', ...?data},
      targetLabel: 'Employee:$employeeId',
    );
  }

  /// Notify a specific admin
  static Future<void> notifyAdmin({
    required String adminId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'admin_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: Admin:$adminId | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getTokensForUser(adminId, 'Admin');
    if (tokens.isEmpty) {
      _logger.warning(
        '[PUSH] No FCM tokens for Admin:$adminId - push not sent',
      );
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'admin_notification', ...?data},
      targetLabel: 'Admin:$adminId',
    );
  }

  /// Notify all admins
  static Future<void> notifyAllAdmins({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'all_admins_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: All admins | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getAllAdminTokens();
    if (tokens.isEmpty) {
      _logger.warning('[PUSH] No FCM tokens for any admin - push not sent');
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'all_admins_notification', ...?data},
      targetLabel: 'All admins (${tokens.length} token(s))',
    );
  }

  /// Notify all employees
  static Future<void> notifyAllEmployees({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'all_employees_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: All employees | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getAllEmployeeTokens();
    if (tokens.isEmpty) {
      _logger.warning('[PUSH] No FCM tokens for any employee - push not sent');
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'all_employees_notification', ...?data},
      targetLabel: 'All employees (${tokens.length} token(s))',
    );
  }

  /// Notify all users (admins + employees)
  static Future<void> notifyAll({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'broadcast_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: All users (admins + employees) | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getAllActiveTokens();
    if (tokens.isEmpty) {
      _logger.warning('[PUSH] No FCM tokens for any user - push not sent');
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'broadcast_notification', ...?data},
      targetLabel: 'All users (${tokens.length} token(s))',
    );
  }

  /// Notify specific employees by IDs
  static Future<void> notifyEmployees({
    required List<String> employeeIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'group_notification';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: Employees:${employeeIds.join(",")} | Title: $title',
    );
    final tokens = await _fcmTokenRepository.getTokensForEmployees(employeeIds);
    if (tokens.isEmpty) {
      _logger.warning(
        '[PUSH] No FCM tokens for employees ${employeeIds.join(",")} - push not sent',
      );
      return;
    }
    await sendToTokens(
      tokens: tokens,
      title: _appName,
      body: body,
      data: {'type': 'group_notification', ...?data},
      targetLabel:
          'Employees:${employeeIds.length} user(s), ${tokens.length} token(s)',
    );
  }

  // ============================================
  // PROJECT NOTIFICATIONS
  // ============================================

  /// Notify about project creation
  static Future<void> notifyProjectCreated({
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
  }) async {
    final body = 'New Project Created: $projectName';
    final data = {'type': 'project_created', 'project_name': projectName};

    // Notify all admins
    await notifyAllAdmins(title: 'New Project', body: body, data: data);

    // Notify team members
    final allMembers = <String>{
      ...teamMemberIds,
      if (projectManagerId != null) projectManagerId,
      if (teamLeaderId != null) teamLeaderId,
    }.toList();

    await notifyEmployees(
      employeeIds: allMembers,
      title: 'New Project Assignment',
      body: 'You have been assigned to project: $projectName',
      data: data,
    );
  }

  /// Notify about project update
  static Future<void> notifyProjectUpdated({
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
  }) async {
    final body = 'Project Updated: $projectName';
    final data = {'type': 'project_updated', 'project_name': projectName};

    await notifyAllAdmins(title: 'Project Updated', body: body, data: data);

    final allMembers = <String>{
      ...teamMemberIds,
      if (projectManagerId != null) projectManagerId,
      if (teamLeaderId != null) teamLeaderId,
    }.toList();

    await notifyEmployees(
      employeeIds: allMembers,
      title: 'Project Updated',
      body: body,
      data: data,
    );
  }

  /// Notify about project discontinuation
  static Future<void> notifyProjectDiscontinued({
    required String projectName,
    required List<String> teamMemberIds,
    String? projectManagerId,
    String? teamLeaderId,
  }) async {
    final body = 'Project Discontinued: $projectName';
    final data = {'type': 'project_discontinued', 'project_name': projectName};

    await notifyAllAdmins(
      title: 'Project Discontinued',
      body: body,
      data: data,
    );

    final allMembers = <String>{
      ...teamMemberIds,
      if (projectManagerId != null) projectManagerId,
      if (teamLeaderId != null) teamLeaderId,
    }.toList();

    await notifyEmployees(
      employeeIds: allMembers,
      title: 'Project Discontinued',
      body: body,
      data: data,
    );
  }

  // ============================================
  // TASK CARD NOTIFICATIONS
  // ============================================

  /// Notify about task card creation/assignment
  /// This is the simplified version for task card creation
  static Future<void> notifyTaskAssigned({
    required String employeeId,
    required String taskName,
    String? projectName,
    String? assignedBy,
  }) async {
    String body = '';
    if (assignedBy != null && projectName != null) {
      body = '$assignedBy assigned you a new task: $taskName for $projectName';
    } else if (assignedBy != null) {
      body = '$assignedBy assigned you a new task: $taskName';
    } else if (projectName != null) {
      body = 'New Task Assigned: $taskName for $projectName';
    } else {
      body = 'New Task Assigned: $taskName';
    }
    _logger.info(
      '[PUSH] Trigger: task_assigned | To: Employee:$employeeId | Task: $taskName',
    );
    final employeeTokens = await _fcmTokenRepository.getTokensForUser(
      employeeId,
      'Employee',
    );
    if (employeeTokens.isEmpty) {
      _logger.warning(
        '[PUSH] No FCM tokens for Employee:$employeeId - task_assigned not sent',
      );
      return;
    }
    await sendToTokens(
      tokens: employeeTokens,
      title: _appName,
      body: body,
      data: {'type': 'task_assigned', 'task_name': taskName},
      targetLabel: 'Employee:$employeeId',
    );
  }

  /// Notify all admins about task card creation
  /// Simplified version that gets all admin tokens and sends notification
  static Future<void> notifyAllAdminsForTaskCreation({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final triggerType = data?['type'] ?? 'task_created';
    _logger.info(
      '[PUSH] Trigger: $triggerType | To: All admins | Title: $title',
    );
    final adminTokens = await _fcmTokenRepository.getAllAdminTokens();
    if (adminTokens.isEmpty) {
      _logger.warning(
        '[PUSH] No FCM tokens for admins - $triggerType not sent',
      );
      return;
    }
    await sendToTokens(
      tokens: adminTokens,
      title: _appName,
      body: body,
      data: {'type': 'all_admins_notification', ...?data},
      targetLabel: 'All admins (${adminTokens.length} token(s))',
    );
  }

  /// Notify about task card update
  static Future<void> notifyTaskUpdated({
    required String employeeId,
    required String taskName,
    String? updatedBy,
  }) async {
    final body = updatedBy != null
        ? '$updatedBy updated your task: $taskName'
        : 'Your task has been updated: $taskName';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Updated',
      body: body,
      data: {'type': 'task_updated', 'task_name': taskName},
    );
  }

  /// Notify about task card deletion
  static Future<void> notifyTaskDeleted({
    required String employeeId,
    required String taskName,
  }) async {
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Deleted',
      body: 'Task Deleted: $taskName',
      data: {'type': 'task_deleted', 'task_name': taskName},
    );
  }

  /// Notify about task reassignment
  static Future<void> notifyTaskReassigned({
    required String newEmployeeId,
    required String? oldEmployeeId,
    required String taskName,
  }) async {
    // Notify new assignee
    await notifyEmployee(
      employeeId: newEmployeeId,
      title: 'Task Reassigned to You',
      body: 'You have been assigned: $taskName',
      data: {'type': 'task_reassigned', 'task_name': taskName},
    );

    // Notify old assignee
    if (oldEmployeeId != null && oldEmployeeId != newEmployeeId) {
      await notifyEmployee(
        employeeId: oldEmployeeId,
        title: 'Task Reassigned',
        body: 'Task has been reassigned: $taskName',
        data: {'type': 'task_reassigned_from', 'task_name': taskName},
      );
    }
  }

  /// Notify about task duplication
  static Future<void> notifyTaskDuplicated({
    required String employeeId,
    required String taskName,
  }) async {
    await notifyEmployee(
      employeeId: employeeId,
      title: 'New Task (Duplicated)',
      body: 'New duplicated task: $taskName',
      data: {'type': 'task_duplicated', 'task_name': taskName},
    );
  }

  /// Notify about task request approval
  static Future<void> notifyTaskRequestApproved({
    required String employeeId,
    required String taskName,
    String? approvedBy,
  }) async {
    final body = approvedBy != null
        ? '$approvedBy approved your task request: $taskName'
        : 'Your task request has been approved: $taskName';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Request Approved',
      body: body,
      data: {'type': 'task_request_approved', 'task_name': taskName},
    );
  }

  /// Notify about task request rejection
  static Future<void> notifyTaskRequestRejected({
    required String employeeId,
    required String taskName,
    String? reason,
    String? rejectedBy,
  }) async {
    String body = '';
    if (rejectedBy != null && reason != null && reason.isNotEmpty) {
      body =
          '$rejectedBy rejected your task request: $taskName. Reason: $reason';
    } else if (rejectedBy != null) {
      body = '$rejectedBy rejected your task request: $taskName';
    } else if (reason != null && reason.isNotEmpty) {
      body = 'Task request rejected: $taskName. Reason: $reason';
    } else {
      body = 'Your task request has been rejected: $taskName';
    }

    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Request Rejected',
      body: body,
      data: {'type': 'task_request_rejected', 'task_name': taskName},
    );
  }

  /// Notify employee when QA approves task
  static Future<void> notifyTaskQaApproved({
    required String employeeId,
    required String taskName,
    String? approvedBy,
  }) async {
    final body = approvedBy != null
        ? '$approvedBy approved your task "$taskName"'
        : 'Your task "$taskName" has been approved by QA.';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Approved',
      body: body,
      data: {'type': 'task_qa_approved', 'task_name': taskName},
    );
  }

  /// Notify employee when QA rejects task (sent for redo)
  static Future<void> notifyTaskQaRejected({
    required String employeeId,
    required String taskName,
    String? notes,
    String? rejectedBy,
  }) async {
    String body = '';
    if (rejectedBy != null && notes != null && notes.isNotEmpty) {
      body = '$rejectedBy sent "$taskName" for redo. Feedback: $notes';
    } else if (rejectedBy != null) {
      body = '$rejectedBy sent your task "$taskName" for redo.';
    } else if (notes != null && notes.isNotEmpty) {
      body = 'Task "$taskName" sent for redo. Feedback: $notes';
    } else {
      body = 'Your task "$taskName" has been sent for redo by QA.';
    }

    await notifyEmployee(
      employeeId: employeeId,
      title: 'Task Sent for Redo',
      body: body,
      data: {'type': 'task_qa_rejected', 'task_name': taskName},
    );
  }

  /// Notify admins about new task request from employee
  static Future<void> notifyTaskRequested({
    required String employeeName,
    required String taskName,
  }) async {
    await notifyAllAdmins(
      title: 'New Task Request',
      body: '$employeeName requested a task card: $taskName',
      data: {
        'type': 'task_requested',
        'employee_name': employeeName,
        'task_name': taskName,
      },
    );
  }

  /// Notify admins about task status update by employee
  static Future<void> notifyTaskStatusUpdated({
    required String employeeName,
    required String taskName,
    required String newStatus,
  }) async {
    await notifyAllAdmins(
      title: 'Task Status Updated',
      body: '$employeeName updated task: $taskName to $newStatus',
      data: {
        'type': 'task_status_updated',
        'task_name': taskName,
        'status': newStatus,
      },
    );
  }

  // ============================================
  // LEAVE/PERMISSION/WFH NOTIFICATIONS
  // ============================================

  /// Notify employee about leave request approval
  static Future<void> notifyLeaveApproved({
    required String employeeId,
    required String dates,
    String? approvedBy,
  }) async {
    final body = approvedBy != null
        ? '$approvedBy approved your leave request for $dates'
        : 'Your leave request has been approved for $dates';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Leave Approved',
      body: body,
      data: {'type': 'leave_approved'},
    );
  }

  /// Notify employee about leave request rejection
  static Future<void> notifyLeaveRejected({
    required String employeeId,
    required String dates,
    String? reason,
    String? rejectedBy,
  }) async {
    String body = '';
    if (rejectedBy != null && reason != null && reason.isNotEmpty) {
      body = '$rejectedBy rejected your leave for $dates. Reason: $reason';
    } else if (rejectedBy != null) {
      body = '$rejectedBy rejected your leave for $dates';
    } else if (reason != null && reason.isNotEmpty) {
      body = 'Leave request rejected for $dates. Reason: $reason';
    } else {
      body = 'Your leave request has been rejected for $dates';
    }

    await notifyEmployee(
      employeeId: employeeId,
      title: 'Leave Rejected',
      body: body,
      data: {'type': 'leave_rejected'},
    );
  }

  /// Notify employee about permission request approval
  static Future<void> notifyPermissionApproved({
    required String employeeId,
    required String date,
    String? approvedBy,
  }) async {
    final body = approvedBy != null
        ? '$approvedBy approved your permission request for $date'
        : 'Your permission request has been approved for $date';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'Permission Approved',
      body: body,
      data: {'type': 'permission_approved'},
    );
  }

  /// Notify employee about permission request rejection
  static Future<void> notifyPermissionRejected({
    required String employeeId,
    required String date,
    String? reason,
    String? rejectedBy,
  }) async {
    String body = '';
    if (rejectedBy != null && reason != null && reason.isNotEmpty) {
      body = '$rejectedBy rejected your permission for $date. Reason: $reason';
    } else if (rejectedBy != null) {
      body = '$rejectedBy rejected your permission for $date';
    } else if (reason != null && reason.isNotEmpty) {
      body = 'Permission request rejected for $date. Reason: $reason';
    } else {
      body = 'Your permission request has been rejected for $date';
    }

    await notifyEmployee(
      employeeId: employeeId,
      title: 'Permission Rejected',
      body: body,
      data: {'type': 'permission_rejected'},
    );
  }

  /// Notify employee about WFH request approval
  static Future<void> notifyWfhApproved({
    required String employeeId,
    required String dates,
    String? approvedBy,
  }) async {
    final body = approvedBy != null
        ? '$approvedBy approved your WFH request for $dates'
        : 'Your work from home request has been approved for $dates';
    await notifyEmployee(
      employeeId: employeeId,
      title: 'WFH Approved',
      body: body,
      data: {'type': 'wfh_approved'},
    );
  }

  /// Notify employee about WFH request rejection
  static Future<void> notifyWfhRejected({
    required String employeeId,
    required String dates,
    String? reason,
    String? rejectedBy,
  }) async {
    String body = '';
    if (rejectedBy != null && reason != null && reason.isNotEmpty) {
      body = '$rejectedBy rejected your WFH for $dates. Reason: $reason';
    } else if (rejectedBy != null) {
      body = '$rejectedBy rejected your WFH for $dates';
    } else if (reason != null && reason.isNotEmpty) {
      body = 'WFH request rejected for $dates. Reason: $reason';
    } else {
      body = 'Your work from home request has been rejected for $dates';
    }

    await notifyEmployee(
      employeeId: employeeId,
      title: 'WFH Rejected',
      body: body,
      data: {'type': 'wfh_rejected'},
    );
  }

  /// Notify admins about new leave request
  static Future<void> notifyLeaveRequested({
    required String employeeName,
    required String dates,
  }) async {
    _logger.info(
      '[PUSH] Trigger: leave_requested | From: $employeeName | Dates: $dates | To: All admins',
    );
    await notifyAllAdmins(
      title: 'New Leave Request',
      body: '$employeeName requested leave for $dates',
      data: {'type': 'leave_requested', 'employee_name': employeeName},
    );
  }

  /// Notify admins about new permission request
  static Future<void> notifyPermissionRequested({
    required String employeeName,
    required String date,
  }) async {
    _logger.info(
      '[PUSH] Trigger: permission_requested | From: $employeeName | Date: $date | To: All admins',
    );
    await notifyAllAdmins(
      title: 'New Permission Request',
      body: '$employeeName requested permission for $date',
      data: {'type': 'permission_requested', 'employee_name': employeeName},
    );
  }

  /// Notify admins about new WFH request
  static Future<void> notifyWfhRequested({
    required String employeeName,
    required String dates,
  }) async {
    _logger.info(
      '[PUSH] Trigger: wfh_requested | From: $employeeName | Dates: $dates | To: All admins',
    );
    await notifyAllAdmins(
      title: 'New WFH Request',
      body: '$employeeName requested work from home for $dates',
      data: {'type': 'wfh_requested', 'employee_name': employeeName},
    );
  }

  // ============================================
  // ANNOUNCEMENT NOTIFICATIONS
  // ============================================

  /// Notify all about new announcement
  static Future<void> notifyAnnouncementCreated({required String title}) async {
    await notifyAll(
      title: 'New Announcement',
      body: title,
      data: {'type': 'announcement_created'},
    );
  }

  /// Notify all about announcement update
  static Future<void> notifyAnnouncementUpdated({required String title}) async {
    await notifyAll(
      title: 'Announcement Updated',
      body: title,
      data: {'type': 'announcement_updated'},
    );
  }

  // ============================================
  // TODO NOTIFICATIONS
  // ============================================

  /// Notify admin about todo completion
  static Future<void> notifyTodoCompleted({
    required String adminId,
    required String todoTitle,
  }) async {
    await notifyAdmin(
      adminId: adminId,
      title: 'Todo Completed',
      body: 'Todo completed: $todoTitle',
      data: {'type': 'todo_completed', 'todo_title': todoTitle},
    );
  }

  /// Notify admin about overdue todo
  static Future<void> notifyTodoOverdue({
    required String adminId,
    required String todoTitle,
  }) async {
    await notifyAdmin(
      adminId: adminId,
      title: 'Todo Overdue',
      body: 'Todo is overdue: $todoTitle - Please review',
      data: {'type': 'todo_overdue', 'todo_title': todoTitle},
    );
  }

  // ============================================
  // EMPLOYEE/ADMIN NOTIFICATIONS
  // ============================================

  /// Notify all admins about new employee
  static Future<void> notifyEmployeeCreated({
    required String employeeName,
    required String employeeId,
  }) async {
    await notifyAllAdmins(
      title: 'New Employee',
      body: 'New employee joined: $employeeName ($employeeId)',
      data: {
        'type': 'employee_created',
        'employee_name': employeeName,
        'employee_id': employeeId,
      },
    );
  }

  /// Notify all admins about new admin
  static Future<void> notifyAdminCreated({
    required String adminName,
    required String adminId,
  }) async {
    await notifyAllAdmins(
      title: 'New Admin',
      body: 'New admin added: $adminName ($adminId)',
      data: {
        'type': 'admin_created',
        'admin_name': adminName,
        'admin_id': adminId,
      },
    );
  }
}
