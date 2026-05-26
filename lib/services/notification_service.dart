import 'package:shelf/shelf.dart';
import 'package:webnox_sprintly_admin_backend/core/utils/response_helper.dart';
import 'package:webnox_sprintly_admin_backend/data/repositories/notification_repository.dart';

class NotificationService {
  final NotificationRepository _repository = NotificationRepository();

  Future<Response> getNotifications(Request request, String userId) async {
    try {
      final queryParams = request.url.queryParameters;
      final userType = queryParams['userType'] ?? 'Employee';
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '20') ?? 20;

      bool? isRead;
      if (queryParams.containsKey('is_read')) {
        final val = queryParams['is_read']?.toLowerCase();
        if (val == 'true') isRead = true;
        if (val == 'false') isRead = false;
      }

      final result = await _repository.getNotificationsForUser(
        userId: userId,
        userType: userType,
        page: page,
        limit: limit,
        isRead: isRead,
      );

      return ResponseHelper.ok(result);
    } catch (e) {
      print('DEBUG: NotificationService Error: $e');
      return ResponseHelper.internalServerError(
        'Failed to fetch notifications: $e',
      );
    }
  }

  Future<Response> markAsRead(Request request, String id) async {
    try {
      await _repository.markAsRead(id);
      return ResponseHelper.ok({'message': 'Notification marked as read'});
    } catch (e) {
      return ResponseHelper.internalServerError(
        'Failed to mark notification as read: $e',
      );
    }
  }

  Future<Response> markAllAsRead(Request request, String userId) async {
    try {
      final queryParams = request.url.queryParameters;
      final userType = queryParams['userType'] ?? 'Employee';

      await _repository.markAllAsRead(userId, userType);
      return ResponseHelper.ok({'message': 'All notifications marked as read'});
    } catch (e) {
      return ResponseHelper.internalServerError(
        'Failed to mark all as read: $e',
      );
    }
  }

  Future<Response> getUnreadCount(Request request, String userId) async {
    try {
      final queryParams = request.url.queryParameters;
      final userType = queryParams['userType'] ?? 'Employee';

      final count = await _repository.getUnreadCount(userId, userType);
      return ResponseHelper.ok({'count': count});
    } catch (e) {
      return ResponseHelper.internalServerError(
        'Failed to fetch unread count: $e',
      );
    }
  }
}
