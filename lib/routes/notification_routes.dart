import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../core/utils/logger.dart';
import '../data/repositories/notification_repository.dart';
import '../services/celebration_scheduler_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_notification_service.dart';

/// Routes for in-app notifications management
class NotificationRoutes {
  final AppLogger _logger = AppLogger('NotificationRoutes');
  final NotificationRepository _notificationRepo = NotificationRepository();
  final AuthService _authService = AuthService();

  Router get router {
    final router = Router();

    // Get notifications for a specific user (by userId in path)
    router.get('/notifications/user/<userId>', getNotificationsForUser);

    // Get unread notification count for a specific user (by userId in path)
    router.get(
      '/notifications/user/<userId>/unread-count',
      getUnreadCountForUser,
    );

    // Get notifications for the current user
    router.get('/notifications', getNotifications);

    // Get unread notification count
    router.get('/notifications/unread-count', getUnreadCount);

    // Mark a notification as read
    router.post('/notifications/<notificationId>/read', markAsRead);

    // Mark all notifications as read
    router.post('/notifications/read-all', markAllAsRead);

    // Delete a notification
    router.delete('/notifications/<notificationId>', deleteNotification);

    // Delete all notifications
    router.delete('/notifications/all', deleteAllNotifications);

    // Trigger manual celebration check (admin only)
    router.post('/notifications/trigger-celebrations', triggerCelebrations);

    // Send direct ping (push notification only) to an employee
    router.post('/notifications/direct-ping', sendDirectPing);

    return router;
  }

  /// Get notifications for a specific user (by userId in path)
  Future<Response> getNotificationsForUser(
    Request request,
    String userId,
  ) async {
    try {
      // Authenticate using manual token verification
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get userType from query parameters (default to 'Employee')
      final queryParams = request.url.queryParameters;
      final userType = queryParams['userType'] ?? 'Employee';

      // Authorization check: employees can only view their own notifications,
      // admins can view any user's notifications
      final authenticatedUserId = user['userId']!;
      final authenticatedUserType = user['userType']!;
      if (authenticatedUserType != 'Admin' && authenticatedUserId != userId) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'You can only view your own notifications',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get query parameters
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
      bool? isRead;
      if (queryParams.containsKey('is_read')) {
        isRead = queryParams['is_read'] == 'true';
      } else if (queryParams['unread_only'] == 'true') {
        isRead = false;
      }

      final notificationType = queryParams['type'];

      // For employee-specific route, use simpler method for better compatibility
      // This route is specifically for employee dashboard
      Map<String, dynamic> result;

      try {
        // Use simpler findByUserId method for employee flow
        final notifications = await _notificationRepo.findByUserId(
          userId,
          userType,
        );
        final unreadCount = await _notificationRepo.getUnreadCount(
          userId,
          userType,
        );

        // Apply filters if needed
        List<Map<String, dynamic>> filteredNotifications = notifications;

        if (isRead != null) {
          filteredNotifications = filteredNotifications
              .where((n) => (n['is_read'] as bool? ?? false) == isRead)
              .toList();
        }

        if (notificationType != null) {
          filteredNotifications = filteredNotifications
              .where((n) => n['notification_type'] == notificationType)
              .toList();
        }

        // Apply pagination
        final total = filteredNotifications.length;
        final offset = (page - 1) * limit;
        final paginatedNotifications = filteredNotifications
            .skip(offset)
            .take(limit)
            .toList();

        result = {
          'notifications': paginatedNotifications,
          'pagination': {
            'page': page,
            'limit': limit,
            'total': total,
            'totalPages': (total / limit).ceil(),
            'hasMore': page * limit < total,
          },
          'unreadCount': unreadCount,
        };
      } catch (e) {
        _logger.warning(
          'Simple findByUserId failed, falling back to paginated method: $e',
        );
        // Fall back to paginated method
        result = await _notificationRepo.getNotificationsForUser(
          userId: userId,
          userType: userType,
          page: page,
          limit: limit,
          isRead: isRead,
          notificationType: notificationType,
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting notifications for user: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to get notifications',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Get unread notification count for a specific user (by userId in path)
  Future<Response> getUnreadCountForUser(Request request, String userId) async {
    try {
      // Authenticate using manual token verification
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Get userType from query parameters (default to 'Employee')
      final queryParams = request.url.queryParameters;
      final userType = queryParams['userType'] ?? 'Employee';

      // Authorization check: employees can only view their own notifications,
      // admins can view any user's notifications
      final authenticatedUserId = user['userId']!;
      final authenticatedUserType = user['userType']!;
      if (authenticatedUserType != 'Admin' && authenticatedUserId != userId) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'You can only view your own notification count',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final count = await _notificationRepo.getUnreadCount(userId, userType);

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'unread_count': count},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting unread count for user: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to get unread count',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Get notifications for the current user
  Future<Response> getNotifications(Request request) async {
    try {
      // Authenticate using manual token verification (same as chat routes)
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = user['userId']!;
      final userType = user['userType']!;

      // Get query parameters
      final queryParams = request.url.queryParameters;
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;
      bool? isRead;
      if (queryParams.containsKey('is_read')) {
        isRead = queryParams['is_read'] == 'true';
      } else if (queryParams['unread_only'] == 'true') {
        isRead = false;
      }

      final notificationType = queryParams['type'];

      final result = await _notificationRepo.getNotificationsForUser(
        userId: userId,
        userType: userType,
        page: page,
        limit: limit,
        isRead: isRead,
        notificationType: notificationType,
      );

      return Response.ok(
        jsonEncode({'success': true, 'data': result}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting notifications: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to get notifications',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Get unread notification count
  Future<Response> getUnreadCount(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = user['userId']!;
      final userType = user['userType']!;

      final count = await _notificationRepo.getUnreadCount(userId, userType);

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'unread_count': count},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting unread count: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to get unread count',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Mark a notification as read
  Future<Response> markAsRead(Request request, String notificationId) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final success = await _notificationRepo.markAsRead(notificationId);

      if (success) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'message': 'Notification marked as read',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'Notification not found',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error marking notification as read: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to mark notification as read',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Mark all notifications as read
  Future<Response> markAllAsRead(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = user['userId']!;
      final userType = user['userType']!;

      final count = await _notificationRepo.markAllAsRead(userId, userType);

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'All notifications marked as read',
          'data': {'updated_count': count},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error marking all notifications as read: $e',
        e,
        stackTrace,
      );
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to mark all notifications as read',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Delete a notification
  Future<Response> deleteNotification(
    Request request,
    String notificationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final success = await _notificationRepo.deleteNotification(
        notificationId,
      );

      if (success) {
        return Response.ok(
          jsonEncode({'success': true, 'message': 'Notification deleted'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'Notification not found',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error deleting notification: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete notification',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Delete all notifications for the current user
  Future<Response> deleteAllNotifications(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userId = user['userId']!;
      final userType = user['userType']!;

      final count = await _notificationRepo.deleteAllForUser(userId, userType);

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'All notifications deleted',
          'data': {'deleted_count': count},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting all notifications: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to delete all notifications',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Trigger manual celebration check (admin only)
  Future<Response> triggerCelebrations(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userType = user['userType']!;

      if (userType != 'Admin') {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Admin access required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await CelebrationSchedulerService.runManualCheck();

      return Response.ok(
        jsonEncode({
          'success': result['success'],
          'message': result['message'],
          'data': result,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error triggering celebrations: $e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to trigger celebrations',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Authenticate request and return user info (same approach as chat routes)
  Future<Map<String, String>?> _authenticateRequest(Request request) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7);
    final user = await _authService.verifyToken(token);
    if (user == null) {
      return null;
    }

    return {'userId': user.employeeId, 'userType': user.role};
  }

  /// Send a direct ping (push notification only) to an employee
  Future<Response> sendDirectPing(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Authentication required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userType = user['userType']!;

      if (userType != 'Admin') {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'message': 'Admin access required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final employeeId = data['employeeId']?.toString();
      final title = data['title']?.toString();
      final message = data['message']?.toString();

      if (employeeId == null ||
          title == null ||
          message == null ||
          employeeId.isEmpty ||
          title.isEmpty ||
          message.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'employeeId, title, and message are required',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Sends push notification alone, without DB entry
      await FirebaseNotificationService.notifyEmployee(
        employeeId: employeeId,
        title: title,
        body: message,
        data: {'type': 'direct_ping'},
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Direct ping sent successfully to employee \$employeeId',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Error sending direct ping: \$e', e, stackTrace);
      return Response(
        500,
        body: jsonEncode({
          'success': false,
          'message': 'Failed to send direct ping',
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
