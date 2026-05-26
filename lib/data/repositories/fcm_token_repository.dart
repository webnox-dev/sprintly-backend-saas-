import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// FCM Token repository for Firebase Cloud Messaging
class FcmTokenRepository {
  final AppLogger logger = AppLogger('FcmTokenRepository');

  /// Save or update FCM token for a user
  /// If user already has a token entry, replaces it with the new token
  /// Each user has only ONE active token entry
  Future<void> saveToken({
    required String userId,
    required String userType,
    required String fcmToken,
    String? deviceType,
    String? deviceName,
    String? platform,
  }) async {
    try {
      // Step 1: Check if this Specific FCM Token already exists in the database
      // If it exists, it might belong to this user (update details)
      // or it might belong to another user (device changed owner? or same user re-login)
      final existingTokenCheck = await DatabaseConnection.query(
        'SELECT id FROM fcm_tokens WHERE fcm_token = @fcm_token',
        values: {'fcm_token': fcmToken},
      );

      if (existingTokenCheck.isNotEmpty) {
        // SCENARIO A: The FCM token is already known.
        // We must ensure it is assigned to the current user and is active.

        await DatabaseConnection.execute(
          '''
          UPDATE fcm_tokens 
          SET user_id = @user_id,
              user_type = @user_type,
              device_type = @device_type,
              device_name = @device_name,
              platform = @platform,
              is_active = true,
              updated_at = CURRENT_TIMESTAMP
          WHERE fcm_token = @fcm_token
          ''',
          values: {
            'user_id': userId,
            'user_type': userType,
            'fcm_token': fcmToken,
            'device_type': deviceType ?? 'unknown',
            'device_name': deviceName,
            'platform': platform ?? 'unknown',
          },
        );

        // Enforce "Single Token Per User" policy:
        // Delete any *other* token entries associated with this user
        // (Since we just confirmed the current device token is active)
        await DatabaseConnection.execute(
          '''
          DELETE FROM fcm_tokens 
          WHERE user_id = @user_id 
          AND user_type = @user_type 
          AND fcm_token != @fcm_token
          ''',
          values: {
            'user_id': userId,
            'user_type': userType,
            'fcm_token': fcmToken,
          },
        );
      } else {
        // SCENARIO B: This is a NEW FCM token (not found in DB).

        // Check if the user already has ANY entry in the table.
        // Use the most recently updated one to reuse the record.
        final existingUserEntry = await DatabaseConnection.query(
          '''
          SELECT id FROM fcm_tokens 
          WHERE user_id = @user_id AND user_type = @user_type 
          ORDER BY updated_at DESC LIMIT 1
          ''',
          values: {'user_id': userId, 'user_type': userType},
        );

        if (existingUserEntry.isNotEmpty) {
          // User exists! Reuse their existing record.
          // This solves the issue of "making new new entries".
          final existingId = existingUserEntry.first['id'];

          await DatabaseConnection.execute(
            '''
            UPDATE fcm_tokens 
            SET fcm_token = @fcm_token,
                device_type = @device_type,
                device_name = @device_name,
                platform = @platform,
                is_active = true,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = @id
            ''',
            values: {
              'id': existingId,
              'fcm_token': fcmToken,
              'device_type': deviceType ?? 'unknown',
              'device_name': deviceName,
              'platform': platform ?? 'unknown',
            },
          );

          // Clean up duplicates if any (though logic above should prevent them appearing)
          await DatabaseConnection.execute(
            '''
             DELETE FROM fcm_tokens 
             WHERE user_id = @user_id AND user_type = @user_type AND id != @id
             ''',
            values: {
              'user_id': userId,
              'user_type': userType,
              'id': existingId,
            },
          );
        } else {
          // User has NO entries. Create the first one.
          await DatabaseConnection.execute(
            '''
            INSERT INTO fcm_tokens (user_id, user_type, fcm_token, device_type, device_name, platform, is_active, created_at, updated_at)
            VALUES (@user_id, @user_type, @fcm_token, @device_type, @device_name, @platform, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ''',
            values: {
              'user_id': userId,
              'user_type': userType,
              'fcm_token': fcmToken,
              'device_type': deviceType ?? 'unknown',
              'device_name': deviceName,
              'platform': platform ?? 'unknown',
            },
          );
        }
      }

      logger.info('FCM token saved for $userType: $userId');

      // Also update the user's main profile table (redundant but requested/kept for compatibility)
      final userTable = userType == 'Admin' ? 'admins' : 'employees';
      final userIdColumn = userType == 'Admin' ? 'admin_id' : 'employee_id';

      final updateUserSql =
          '''
        UPDATE $userTable 
        SET fcm_token = @fcm_token, fcm_token_updated_at = CURRENT_TIMESTAMP
        WHERE $userIdColumn = @user_id
      ''';

      await DatabaseConnection.execute(
        updateUserSql,
        values: {'user_id': userId, 'fcm_token': fcmToken},
      );
    } catch (e, stackTrace) {
      logger.error('Error saving FCM token: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to save FCM token',
        details: {'error': e.toString()},
      );
    }
  }

  /// Remove FCM token (on logout or token refresh)
  Future<void> removeToken(String fcmToken) async {
    try {
      final sql = '''
        UPDATE fcm_tokens 
        SET is_active = false, updated_at = CURRENT_TIMESTAMP
        WHERE fcm_token = @fcm_token
      ''';

      await DatabaseConnection.execute(sql, values: {'fcm_token': fcmToken});
      logger.info('FCM token deactivated');
    } catch (e, stackTrace) {
      logger.error('Error removing FCM token: $e', e, stackTrace);
      // Don't throw - token removal is not critical
    }
  }

  /// Remove all tokens for a user (on logout from all devices)
  Future<void> removeAllTokensForUser(String userId, String userType) async {
    try {
      final sql = '''
        UPDATE fcm_tokens 
        SET is_active = false, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = @user_id AND user_type = @user_type
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {'user_id': userId, 'user_type': userType},
      );

      // Also clear the user's table token
      final userTable = userType == 'Admin' ? 'admins' : 'employees';
      final userIdColumn = userType == 'Admin' ? 'admin_id' : 'employee_id';

      final updateUserSql =
          '''
        UPDATE $userTable 
        SET fcm_token = NULL, fcm_token_updated_at = NULL
        WHERE $userIdColumn = @user_id
      ''';

      await DatabaseConnection.execute(
        updateUserSql,
        values: {'user_id': userId},
      );

      logger.info('All FCM tokens removed for $userType: $userId');
    } catch (e, stackTrace) {
      logger.error('Error removing all FCM tokens: $e', e, stackTrace);
    }
  }

  /// Get FCM token for a specific user (Admin or Employee)
  /// Returns empty list if user doesn't exist or token is not active
  Future<List<String>> getTokensForUser(String userId, String userType) async {
    try {
      final sql = '''
        SELECT fcm_token 
        FROM fcm_tokens 
        WHERE user_id = @user_id 
        AND user_type = @user_type 
        AND is_active = true
        AND fcm_token IS NOT NULL
        AND fcm_token != ''
      ''';

      final results = await DatabaseConnection.query(
        sql,
        values: {'user_id': userId, 'user_type': userType},
      );

      final tokens = results.map((row) => row['fcm_token'] as String).toList();
      logger.info(
        'Retrieved ${tokens.length} FCM token(s) for $userType: $userId',
      );
      return tokens;
    } catch (e, stackTrace) {
      logger.error('Error getting FCM tokens for user: $e', e, stackTrace);
      return [];
    }
  }

  /// Get all active FCM tokens for all admins
  /// Returns only fcm_token column from fcm_tokens table where user_type = 'Admin' and is_active = true
  Future<List<String>> getAllAdminTokens() async {
    try {
      final sql = '''
        SELECT fcm_token 
        FROM fcm_tokens 
        WHERE user_type = 'Admin' 
        AND is_active = true
        AND fcm_token IS NOT NULL
        AND fcm_token != ''
      ''';

      final results = await DatabaseConnection.query(sql);
      final tokens = results.map((row) => row['fcm_token'] as String).toList();
      logger.info('Retrieved ${tokens.length} FCM token(s) for all admins');
      return tokens;
    } catch (e, stackTrace) {
      logger.error('Error getting all admin FCM tokens: $e', e, stackTrace);
      return [];
    }
  }

  /// Get all active FCM tokens for all employees
  /// Returns only fcm_token column from fcm_tokens table where user_type = 'Employee' and is_active = true
  Future<List<String>> getAllEmployeeTokens() async {
    try {
      final sql = '''
        SELECT fcm_token 
        FROM fcm_tokens 
        WHERE user_type = 'Employee' 
        AND is_active = true
        AND fcm_token IS NOT NULL
        AND fcm_token != ''
      ''';

      final results = await DatabaseConnection.query(sql);
      final tokens = results.map((row) => row['fcm_token'] as String).toList();
      logger.info('Retrieved ${tokens.length} FCM token(s) for all employees');
      return tokens;
    } catch (e, stackTrace) {
      logger.error('Error getting all employee FCM tokens: $e', e, stackTrace);
      return [];
    }
  }

  /// Get all active FCM tokens for both admins and employees
  Future<List<String>> getAllActiveTokens() async {
    try {
      final sql = '''
        SELECT DISTINCT fcm_token FROM fcm_tokens 
        WHERE is_active = true
        AND fcm_token IS NOT NULL
      ''';

      final results = await DatabaseConnection.query(sql);
      return results.map((row) => row['fcm_token'] as String).toList();
    } catch (e, stackTrace) {
      logger.error('Error getting all active FCM tokens: $e', e, stackTrace);
      return [];
    }
  }

  /// Get FCM tokens for specific employee IDs
  /// Only returns tokens for employees with status = 1 (active)
  Future<List<String>> getTokensForEmployees(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return [];

    try {
      // Build the IN clause with parameterized placeholders
      final placeholders = <String>[];
      final values = <String, dynamic>{};

      for (int i = 0; i < employeeIds.length; i++) {
        placeholders.add('@emp_$i');
        values['emp_$i'] = employeeIds[i];
      }

      final sql =
          '''
        SELECT DISTINCT ft.fcm_token 
        FROM fcm_tokens ft
        INNER JOIN employees e ON e.employee_id = ft.user_id
        WHERE ft.user_id IN (${placeholders.join(', ')})
        AND ft.user_type = 'Employee'
        AND ft.is_active = true
        AND e.status = 1
        AND ft.fcm_token IS NOT NULL
        AND ft.fcm_token != ''
      ''';

      final results = await DatabaseConnection.query(sql, values: values);
      final tokens = results.map((row) => row['fcm_token'] as String).toList();
      logger.info(
        'Retrieved ${tokens.length} FCM token(s) for ${employeeIds.length} employee(s)',
      );
      return tokens;
    } catch (e, stackTrace) {
      logger.error('Error getting FCM tokens for employees: $e', e, stackTrace);
      return [];
    }
  }

  /// Get FCM tokens for specific admin IDs
  /// Only returns tokens for admins with status = 1 (active)
  Future<List<String>> getTokensForAdmins(List<String> adminIds) async {
    if (adminIds.isEmpty) return [];

    try {
      final placeholders = <String>[];
      final values = <String, dynamic>{};

      for (int i = 0; i < adminIds.length; i++) {
        placeholders.add('@admin_$i');
        values['admin_$i'] = adminIds[i];
      }

      final sql =
          '''
        SELECT DISTINCT ft.fcm_token 
        FROM fcm_tokens ft
        INNER JOIN admins a ON a.admin_id = ft.user_id
        WHERE ft.user_id IN (${placeholders.join(', ')})
        AND ft.user_type = 'Admin'
        AND ft.is_active = true
        AND a.status = 1
        AND ft.fcm_token IS NOT NULL
        AND ft.fcm_token != ''
      ''';

      final results = await DatabaseConnection.query(sql, values: values);
      final tokens = results.map((row) => row['fcm_token'] as String).toList();
      logger.info(
        'Retrieved ${tokens.length} FCM token(s) for ${adminIds.length} admin(s)',
      );
      return tokens;
    } catch (e, stackTrace) {
      logger.error('Error getting FCM tokens for admins: $e', e, stackTrace);
      return [];
    }
  }

  /// Clean up old/expired tokens (for maintenance)
  Future<int> cleanupOldTokens({int daysOld = 90}) async {
    try {
      final sql =
          '''
        DELETE FROM fcm_tokens 
        WHERE is_active = false 
        AND updated_at < CURRENT_TIMESTAMP - INTERVAL '$daysOld days'
        RETURNING *
      ''';

      final results = await DatabaseConnection.query(sql);
      final count = results.length;

      if (count > 0) {
        logger.info('Cleaned up $count old FCM tokens');
      }

      return count;
    } catch (e, stackTrace) {
      logger.error('Error cleaning up old FCM tokens: $e', e, stackTrace);
      return 0;
    }
  }

  /// Get active sessions (devices) for a user
  Future<List<Map<String, dynamic>>> getActiveSessions(
    String userId,
    String userType,
  ) async {
    try {
      final sql = '''
        SELECT 
          id, 
          device_type, 
          device_name, 
          platform, 
          fcm_token, 
          updated_at 
        FROM fcm_tokens 
        WHERE user_id = @user_id 
        AND user_type = @user_type 
        AND is_active = true
        ORDER BY updated_at DESC
      ''';

      final results = await DatabaseConnection.query(
        sql,
        values: {'user_id': userId, 'user_type': userType},
      );

      return results.map((row) {
        final map = Map<String, dynamic>.from(row);
        if (map['updated_at'] is DateTime) {
          map['updated_at'] = (map['updated_at'] as DateTime).toIso8601String();
        }
        return map;
      }).toList();
    } catch (e, stackTrace) {
      logger.error('Error getting active sessions for user: $e', e, stackTrace);
      return [];
    }
  }
}
