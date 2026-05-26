import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Repository for JWT-based session management
class SessionRepository {
  final AppLogger logger = AppLogger('SessionRepository');

  /// Create a new session on login
  Future<void> createSession({
    required String userId,
    required String userType,
    required String jwtToken,
    String? deviceName,
    String? platform,
    String? ipAddress,
    String? city,
    String? state,
    String? country,
    String? browser,
    bool isMainDevice = false,
  }) async {
    try {
      await DatabaseConnection.execute(
        '''
        INSERT INTO sessions (
          user_id, user_type, jwt_token, device_name, platform, 
          ip_address, city, state, country, browser, is_main_device,
          is_active, created_at, updated_at
        )
        VALUES (
          @user_id, @user_type, @jwt_token, @device_name, @platform,
          @ip_address, @city, @state, @country, @browser, @is_main_device,
          true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
        ''',
        values: {
          'user_id': userId,
          'user_type': userType,
          'jwt_token': jwtToken,
          'device_name': deviceName ?? 'Unknown',
          'platform': platform ?? 'Unknown',
          'ip_address': ipAddress,
          'city': city,
          'state': state,
          'country': country,
          'browser': browser,
          'is_main_device': isMainDevice,
        },
      );
      logger.info('Session created for $userType: $userId');
    } catch (e, stackTrace) {
      logger.error('Error creating session: $e', e, stackTrace);
    }
  }

  /// Get active session count for a user
  Future<int> getActiveSessionCount(String userId, String userType) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT COUNT(*) as count FROM sessions 
        WHERE user_id = @user_id AND user_type = @user_type AND is_active = true
        ''',
        values: {'user_id': userId, 'user_type': userType},
      );
      if (results.isEmpty) return 0;
      return int.tryParse(results.first['count'].toString()) ?? 0;
    } catch (e, stackTrace) {
      logger.error('Error getting session count: $e', e, stackTrace);
      return 0;
    }
  }

  /// Set a session as the main device for a user
  Future<void> setMainDevice(
    String sessionId,
    String userId,
    String userType,
  ) async {
    try {
      // First, reset all other main devices for this user
      await DatabaseConnection.execute(
        '''
        UPDATE sessions SET is_main_device = false 
        WHERE user_id = @user_id AND user_type = @user_type
        ''',
        values: {'user_id': userId, 'user_type': userType},
      );

      // Then set the specific session as main device
      await DatabaseConnection.execute(
        '''
        UPDATE sessions SET is_main_device = true 
        WHERE id = @id::uuid
        ''',
        values: {'id': sessionId},
      );
      logger.info('Main device updated to session: $sessionId');
    } catch (e, stackTrace) {
      logger.error('Error setting main device: $e', e, stackTrace);
    }
  }

  /// Check if a session is the main device
  Future<bool> isMainDevice(String sessionId) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT is_main_device FROM sessions WHERE id = @id::uuid
        ''',
        values: {'id': sessionId},
      );
      if (results.isEmpty) return false;
      return results.first['is_main_device'] == true;
    } catch (e, stackTrace) {
      logger.error('Error checking main device: $e', e, stackTrace);
      return false;
    }
  }

  /// Check if a JWT token is still active (not revoked)
  Future<bool> isTokenActive(String jwtToken) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT is_active FROM sessions 
        WHERE jwt_token = @jwt_token
        LIMIT 1
        ''',
        values: {'jwt_token': jwtToken},
      );

      if (results.isEmpty) {
        // Token not found in sessions table — reject it
        return false;
      }

      return results.first['is_active'] == true;
    } catch (e, stackTrace) {
      logger.error('Error checking token active status: $e', e, stackTrace);
      // Fail-open to avoid locking users out
      return true;
    }
  }

  /// Check if a JWT token belongs to the main device
  Future<bool> isTokenMainDevice(String jwtToken) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT is_main_device FROM sessions 
        WHERE jwt_token = @jwt_token
        LIMIT 1
        ''',
        values: {'jwt_token': jwtToken},
      );
      if (results.isEmpty) return false;
      return results.first['is_main_device'] == true;
    } catch (e, stackTrace) {
      logger.error(
        'Error checking token main device status: $e',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Get active sessions for a user
  Future<List<Map<String, dynamic>>> getActiveSessions(
    String userId,
    String userType,
  ) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT id, device_name, platform, ip_address, city, state, country, browser, is_main_device, jwt_token, created_at, updated_at
        FROM sessions
        WHERE user_id = @user_id AND user_type = @user_type AND is_active = true
        ORDER BY updated_at DESC
        ''',
        values: {'user_id': userId, 'user_type': userType},
      );

      return results.map((row) {
        final map = Map<String, dynamic>.from(row);
        if (map['created_at'] is DateTime) {
          map['created_at'] = (map['created_at'] as DateTime).toIso8601String();
        }
        if (map['updated_at'] is DateTime) {
          map['updated_at'] = (map['updated_at'] as DateTime).toIso8601String();
        }
        return map;
      }).toList();
    } catch (e, stackTrace) {
      logger.error('Error getting active sessions: $e', e, stackTrace);
      return [];
    }
  }

  /// Delete a specific session by its row ID
  Future<void> revokeSession(String sessionId) async {
    try {
      await DatabaseConnection.execute(
        '''
        DELETE FROM sessions 
        WHERE id = @id::uuid
        ''',
        values: {'id': sessionId},
      );
      logger.info('Session deleted: $sessionId');
    } catch (e, stackTrace) {
      logger.error('Error deleting session: $e', e, stackTrace);
    }
  }

  /// Delete a session by its JWT token string
  Future<void> deleteSessionByToken(String jwtToken) async {
    try {
      await DatabaseConnection.execute(
        '''
        DELETE FROM sessions 
        WHERE jwt_token = @jwt_token
        ''',
        values: {'jwt_token': jwtToken},
      );
      logger.info('Session deleted by token cleanup');
    } catch (e, stackTrace) {
      logger.error('Error deleting session by token: $e', e, stackTrace);
    }
  }

  /// Delete all sessions for a user except the current one
  Future<void> revokeAllSessionsExcept(
    String userId,
    String userType,
    String currentJwtToken,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        DELETE FROM sessions 
        WHERE user_id = @user_id 
        AND user_type = @user_type 
        AND jwt_token != @current_jwt
        ''',
        values: {
          'user_id': userId,
          'user_type': userType,
          'current_jwt': currentJwtToken,
        },
      );
      logger.info('All other sessions deleted for $userType: $userId');
    } catch (e, stackTrace) {
      logger.error('Error deleting all other sessions: $e', e, stackTrace);
    }
  }

  /// Get the user ID associated with a session
  Future<String?> getSessionUserId(String sessionId) async {
    try {
      final results = await DatabaseConnection.query(
        '''
        SELECT user_id FROM sessions WHERE id = @id::uuid
        ''',
        values: {'id': sessionId},
      );
      if (results.isEmpty) return null;
      return results.first['user_id']?.toString();
    } catch (e, stackTrace) {
      logger.error('Error getting session user ID: $e', e, stackTrace);
      return null;
    }
  }
}
