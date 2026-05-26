import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// Notification repository for in-app notifications
class NotificationRepository {
  final AppLogger logger = AppLogger('NotificationRepository');

  /// Create a notification for a user
  Future<Map<String, dynamic>?> createNotification({
    required String userId,
    required String userType,
    required String title,
    required String body,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    String? createdBy,
  }) async {
    try {
      final sql = '''
        INSERT INTO notifications (
          user_id, user_type, title, body, notification_type,
          related_entity_type, related_entity_id, data, created_by, created_at
        )
        VALUES (
          @user_id, @user_type, @title, @body, @notification_type,
          @related_entity_type, @related_entity_id, @data::jsonb, @created_by, CURRENT_TIMESTAMP
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.query(
        sql,
        values: {
          'user_id': userId,
          'user_type': userType,
          'title': title,
          'body': body,
          'notification_type': notificationType,
          'related_entity_type': relatedEntityType,
          'related_entity_id': relatedEntityId,
          'data': data != null ? _encodeJson(data) : '{}',
          'created_by': createdBy,
        },
      );

      if (result.isNotEmpty) {
        logger.info('Notification created for $userType: $userId');
        return _formatNotification(result.first);
      }
      return null;
    } catch (e, stackTrace) {
      logger.error('Error creating notification: $e', e, stackTrace);
      return null; // Don't throw - notifications are not critical
    }
  }

  /// Create notifications for multiple users
  Future<void> createNotificationsForUsers({
    required List<String> userIds,
    required String userType,
    required String title,
    required String body,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    String? createdBy,
  }) async {
    for (final userId in userIds) {
      await createNotification(
        userId: userId,
        userType: userType,
        title: title,
        body: body,
        notificationType: notificationType,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        data: data,
        createdBy: createdBy,
      );
    }
  }

  /// Create notification for all admins
  Future<void> createNotificationForAllAdmins({
    required String title,
    required String body,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    String? createdBy,
  }) async {
    try {
      // Get all active admin IDs
      final admins = await DatabaseConnection.query(
        'SELECT admin_id FROM admins WHERE status = 1',
      );

      for (final admin in admins) {
        await createNotification(
          userId: admin['admin_id'] as String,
          userType: 'Admin',
          title: title,
          body: body,
          notificationType: notificationType,
          relatedEntityType: relatedEntityType,
          relatedEntityId: relatedEntityId,
          data: data,
          createdBy: createdBy,
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        'Error creating notifications for all admins: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Create notification for all employees
  Future<void> createNotificationForAllEmployees({
    required String title,
    required String body,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    String? createdBy,
  }) async {
    try {
      // Get all active employee IDs
      final employees = await DatabaseConnection.query(
        'SELECT employee_id FROM employees WHERE status = 1',
      );

      for (final emp in employees) {
        await createNotification(
          userId: emp['employee_id'] as String,
          userType: 'Employee',
          title: title,
          body: body,
          notificationType: notificationType,
          relatedEntityType: relatedEntityType,
          relatedEntityId: relatedEntityId,
          data: data,
          createdBy: createdBy,
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        'Error creating notifications for all employees: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Create notification for all users (admins + employees)
  Future<void> createNotificationForAll({
    required String title,
    required String body,
    required String notificationType,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    String? createdBy,
  }) async {
    await createNotificationForAllAdmins(
      title: title,
      body: body,
      notificationType: notificationType,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      data: data,
      createdBy: createdBy,
    );
    await createNotificationForAllEmployees(
      title: title,
      body: body,
      notificationType: notificationType,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      data: data,
      createdBy: createdBy,
    );
  }

  /// Find notifications by userId and userType (simpler method for employee flow)
  /// This method is specifically added for employee dashboard compatibility
  Future<List<Map<String, dynamic>>> findByUserId(
    String userId,
    String userType,
  ) async {
    try {
      logger.info(
        'DEBUG: Fetching notifications for userId: $userId, userType: $userType',
      );

      final results = await DatabaseConnection.query(
        '''
        SELECT * FROM notifications 
        WHERE user_id = @userId AND user_type = @userType 
        ORDER BY created_at DESC
        ''',
        values: {'userId': userId, 'userType': userType},
      );

      logger.info('DEBUG: Found ${results.length} notifications');

      if (results.isNotEmpty) {
        final firstRow = results.first;
        logger.info('DEBUG: First row keys: ${firstRow.keys}');
        logger.info('DEBUG: First row values: $firstRow');
        firstRow.forEach((key, value) {
          logger.info(
            'DEBUG: Key: $key, Type: ${value.runtimeType}, Value: $value',
          );
        });
      }

      return results.map((row) {
        try {
          return _formatNotification(row);
        } catch (e) {
          logger.error('DEBUG: Error mapping row to Notification: $e');
          logger.error('DEBUG: Row data: $row');
          rethrow;
        }
      }).toList();
    } catch (e, stackTrace) {
      logger.error('DEBUG: Repository Error: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get notifications for a user with pagination
  Future<Map<String, dynamic>> getNotificationsForUser({
    required String userId,
    required String userType,
    int page = 1,
    int limit = 20,
    bool? isRead, // Changed from unreadOnly. null=all, true=read, false=unread
    String? notificationType,
  }) async {
    try {
      var whereClause = 'WHERE user_id = @user_id AND user_type = @user_type';
      final values = <String, dynamic>{
        'user_id': userId,
        'user_type': userType,
      };

      if (isRead != null) {
        whereClause += ' AND is_read = @is_read';
        values['is_read'] = isRead;
      }

      if (notificationType != null) {
        whereClause += ' AND notification_type = @notification_type';
        values['notification_type'] = notificationType;
      }

      // Get total count
      final countResult = await DatabaseConnection.query(
        'SELECT COUNT(*) as total FROM notifications $whereClause',
        values: values,
      );
      final total = countResult.isNotEmpty
          ? (countResult.first['total'] as int? ?? 0)
          : 0;

      // Get unread count
      final unreadResult = await DatabaseConnection.query(
        'SELECT COUNT(*) as unread FROM notifications WHERE user_id = @user_id AND user_type = @user_type AND is_read = false',
        values: {'user_id': userId, 'user_type': userType},
      );
      final unreadCount = unreadResult.isNotEmpty
          ? (unreadResult.first['unread'] as int? ?? 0)
          : 0;

      // Get paginated results
      final offset = (page - 1) * limit;
      final sql =
          '''
        SELECT * FROM notifications 
        $whereClause
        ORDER BY created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      values['limit'] = limit;
      values['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: values);

      return {
        'notifications': results.map(_formatNotification).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
          'hasMore': page * limit < total,
        },
        'unreadCount': unreadCount,
      };
    } catch (e, stackTrace) {
      logger.error('Error getting notifications: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to get notifications',
        details: {'error': e.toString()},
      );
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final result = await DatabaseConnection.execute(
        '''
        UPDATE notifications 
        SET is_read = true, read_at = CURRENT_TIMESTAMP
        WHERE notification_id = @id
        ''',
        values: {'id': notificationId},
      );
      return result > 0;
    } catch (e, stackTrace) {
      logger.error('Error marking notification as read: $e', e, stackTrace);
      return false;
    }
  }

  /// Mark all notifications as read for a user
  Future<int> markAllAsRead(String userId, String userType) async {
    try {
      final result = await DatabaseConnection.execute(
        '''
        UPDATE notifications 
        SET is_read = true, read_at = CURRENT_TIMESTAMP
        WHERE user_id = @user_id AND user_type = @user_type AND is_read = false
        ''',
        values: {'user_id': userId, 'user_type': userType},
      );
      return result;
    } catch (e, stackTrace) {
      logger.error(
        'Error marking all notifications as read: $e',
        e,
        stackTrace,
      );
      return 0;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final result = await DatabaseConnection.execute(
        'DELETE FROM notifications WHERE notification_id = @id',
        values: {'id': notificationId},
      );
      return result > 0;
    } catch (e, stackTrace) {
      logger.error('Error deleting notification: $e', e, stackTrace);
      return false;
    }
  }

  /// Delete all notifications for a user
  Future<int> deleteAllForUser(String userId, String userType) async {
    try {
      final result = await DatabaseConnection.execute(
        'DELETE FROM notifications WHERE user_id = @user_id AND user_type = @user_type',
        values: {'user_id': userId, 'user_type': userType},
      );
      return result;
    } catch (e, stackTrace) {
      logger.error('Error deleting all notifications: $e', e, stackTrace);
      return 0;
    }
  }

  /// Clear old notifications (maintenance)
  Future<int> clearOldNotifications({int daysOld = 30}) async {
    try {
      final result = await DatabaseConnection.execute('''
        DELETE FROM notifications 
        WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '$daysOld days'
        AND is_read = true
        ''');
      if (result > 0) {
        logger.info('Cleared $result old notifications');
      }
      return result;
    } catch (e, stackTrace) {
      logger.error('Error clearing old notifications: $e', e, stackTrace);
      return 0;
    }
  }

  /// Get unread count for a user
  Future<int> getUnreadCount(String userId, String userType) async {
    try {
      final result = await DatabaseConnection.query(
        'SELECT COUNT(*) as count FROM notifications WHERE user_id = @user_id AND user_type = @user_type AND is_read = false',
        values: {'user_id': userId, 'user_type': userType},
      );
      return result.isNotEmpty ? (result.first['count'] as int? ?? 0) : 0;
    } catch (e, stackTrace) {
      logger.error('Error getting unread count: $e', e, stackTrace);
      return 0;
    }
  }

  /// Format notification for response
  Map<String, dynamic> _formatNotification(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);

    // Handle data field (JSONB) - parse if it's a string
    if (map['data'] != null) {
      if (map['data'] is String) {
        try {
          // Try to parse JSON string
          final dataStr = map['data'] as String;
          if (dataStr.trim().isNotEmpty && dataStr.trim() != '{}') {
            // If it's a JSON string, we need to parse it
            // But DatabaseConnection should already handle this
            // If it's still a string, try manual parsing
            if (dataStr.startsWith('{') || dataStr.startsWith('[')) {
              // Already handled by DatabaseConnection, but keep as is
            }
          } else {
            map['data'] = null;
          }
        } catch (e) {
          logger.warning('Error parsing notification data field: $e');
          map['data'] = null;
        }
      }
      // If it's already a Map, keep it as is
    }

    // Convert timestamps to ISO strings
    if (map['created_at'] != null) {
      if (map['created_at'] is DateTime) {
        map['created_at'] = (map['created_at'] as DateTime).toIso8601String();
      } else if (map['created_at'] is String) {
        // Already a string, keep it
      } else {
        try {
          map['created_at'] = DateTime.parse(map['created_at'].toString())
              .toIso8601String();
        } catch (e) {
          logger.warning('Error parsing created_at: $e');
        }
      }
    }

    if (map['read_at'] != null) {
      if (map['read_at'] is DateTime) {
        map['read_at'] = (map['read_at'] as DateTime).toIso8601String();
      } else if (map['read_at'] is String) {
        // Already a string, keep it
      } else {
        try {
          map['read_at'] =
              DateTime.parse(map['read_at'].toString()).toIso8601String();
        } catch (e) {
          logger.warning('Error parsing read_at: $e');
          map['read_at'] = null;
        }
      }
    }

    // Ensure boolean fields are properly typed
    if (map['is_read'] != null) {
      if (map['is_read'] is bool) {
        // Already boolean
      } else {
        map['is_read'] = map['is_read'] == true ||
            map['is_read'] == 1 ||
            map['is_read'] == 'true';
      }
    } else {
      map['is_read'] = false;
    }

    return map;
  }

  /// Encode JSON data
  String _encodeJson(Map<String, dynamic> data) {
    try {
      return data.entries
          .map((e) => '"${e.key}": ${_encodeValue(e.value)}')
          .join(', ')
          .let((s) => '{$s}');
    } catch (e) {
      return '{}';
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is num || value is bool) return value.toString();
    if (value is List) return '[${value.map(_encodeValue).join(', ')}]';
    if (value is Map) return _encodeJson(Map<String, dynamic>.from(value));
    return '"${value.toString()}"';
  }
}

/// Extension for let pattern
extension LetExtension<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
