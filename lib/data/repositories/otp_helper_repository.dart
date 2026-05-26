import 'dart:math';
import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// Repository for password reset and OTP operations
class OTPHelperRepository {
  final AppLogger logger = AppLogger('OTPHelperRepository');

  static const String _tableName = 'password_reset_helper';
  static const int otpValidityMinutes = 15;

  /// Generate a random 6-digit OTP
  String generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Create a new OTP record for email verification
  /// Also updates otp_generated_at in auth.users table
  Future<String> createOTPRecord({
    required String email,
    required String userType, // 'Employee' or 'Admin'
    String otpType = 'email_verification',
  }) async {
    try {
      return await _attemptCreateOTP(email, userType, otpType);
    } catch (e) {
      // Check for missing column error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('column') &&
          errorStr.contains('does not exist') &&
          (errorStr.contains('otp_type') || errorStr.contains('user_type'))) {
        logger.warning(
          'Missing columns detected in password_reset_helper. Attempting to fix schema...',
        );
        await _fixSchema();
        // Retry once
        return await _attemptCreateOTP(email, userType, otpType);
      }
      rethrow;
    }
  }

  Future<String> _attemptCreateOTP(
    String email,
    String userType,
    String otpType,
  ) async {
    final otp = generateOTP();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: otpValidityMinutes));

    // 1. Delete existing OTPs
    try {
      await DatabaseConnection.execute(
        '''
        DELETE FROM $_tableName WHERE email = @email
        ''',
        values: {'email': email},
      );
    } catch (e) {
      logger.warning('Failed to clean up old OTPs: $e');
      // Continue anyway
    }

    // 2. Insert new OTP record (Primary operation - must succeed)
    try {
      await DatabaseConnection.execute(
        '''
        INSERT INTO $_tableName (email, otp, otp_type, user_type, expires_at, is_used, created_at)
        VALUES (@email, @otp, @otpType, @userType, @expiresAt, FALSE, @createdAt)
        ''',
        values: {
          'email': email,
          'otp': otp,
          'otpType': otpType,
          'userType': userType,
          'createdAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        },
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('column') && errorStr.contains('does not exist')) {
        logger.error('Missing columns in $_tableName: $e');
        rethrow; // Trigger self-healing
      }
      logger.error('Error inserting OTP record: $e');
      throw AppException(
        code: 'OTP_CREATE_ERROR',
        message: 'Failed to create OTP record. Please try again.',
      );
    }

    // 3. Update auth.users (Secondary operation - can fail without breaking flow)
    try {
      await DatabaseConnection.execute(
        '''
        UPDATE auth.users 
        SET otp = @otp, otp_generated_at = @generatedAt
        WHERE email = @email
        ''',
        values: {
          'email': email,
          'otp': otp,
          'generatedAt': now.toIso8601String(),
        },
      );
    } catch (e) {
      // Log but do not fail the request if this update fails
      // The primary OTP verification uses password_reset_helper table anyway
      logger.warning('Failed to update auth.users with OTP (non-critical): $e');
    }

    logger.info(
      'OTP created for email: $email, OTP: $otp, Expires: $expiresAt',
    );
    return otp;
  }

  /// Fix missing columns in password_reset_helper table
  Future<void> _fixSchema() async {
    try {
      logger.info('Adding missing columns to $_tableName...');

      // Attempt to add otp_type column
      try {
        await DatabaseConnection.execute(
          'ALTER TABLE $_tableName ADD COLUMN otp_type VARCHAR(50) DEFAULT \'email_verification\'',
        );
      } catch (e) {
        // Ignore if already exists
        logger.info('otp_type column add result: $e');
      }

      // Attempt to add user_type column
      try {
        await DatabaseConnection.execute(
          'ALTER TABLE $_tableName ADD COLUMN user_type VARCHAR(20) DEFAULT \'Employee\'',
        );
      } catch (e) {
        // Ignore if already exists
        logger.info('user_type column add result: $e');
      }

      logger.info('Schema fix attempted completed.');
    } catch (e) {
      logger.error('Failed to fix schema: $e');
    }
  }

  /// Verify OTP for a given email
  /// Returns true if OTP is valid and not expired
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      // Get the latest OTP record for this email
      final result = await DatabaseConnection.queryOne(
        '''
        SELECT * FROM $_tableName 
        WHERE email = @email 
          AND otp = @otp 
          AND is_used = FALSE
        ORDER BY created_at DESC
        LIMIT 1
        ''',
        values: {'email': email, 'otp': otp},
      );

      if (result == null) {
        logger.warning(
          'OTP verification failed: No matching OTP found for email: $email',
        );
        return {
          'success': false,
          'reason': 'INVALID_OTP',
          'message': 'Invalid OTP. Please try again.',
        };
      }

      // Check if OTP has expired using expires_at column
      final expiresAt = DateTime.parse(result['expires_at'].toString());

      if (now.isAfter(expiresAt)) {
        // Mark as used since it expired
        await DatabaseConnection.execute(
          '''
          UPDATE $_tableName 
          SET is_used = TRUE 
          WHERE email = @email AND otp = @otp
          ''',
          values: {'email': email, 'otp': otp},
        );

        logger.warning(
          'OTP verification failed: OTP expired for email: $email',
        );
        return {
          'success': false,
          'reason': 'OTP_EXPIRED',
          'message': 'OTP has expired. Please request a new one.',
          'requiresResend': true,
        };
      }

      // Mark OTP as used
      await DatabaseConnection.execute(
        '''
        UPDATE $_tableName 
        SET is_used = TRUE
        WHERE email = @email AND otp = @otp
        ''',
        values: {'email': email, 'otp': otp},
      );

      logger.info('OTP verified successfully for email: $email');
      return {'success': true, 'message': 'OTP verified successfully.'};
    } catch (e, stackTrace) {
      logger.error('Error verifying OTP: $e', e, stackTrace);
      throw AppException(
        code: 'OTP_VERIFY_ERROR',
        message: 'Failed to verify OTP. Please try again.',
      );
    }
  }

  /// Check if email has a pending (valid) OTP
  Future<bool> hasPendingOTP(String email) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        SELECT 1 FROM $_tableName 
        WHERE email = @email 
          AND is_used = FALSE 
          AND expires_at > NOW()
        LIMIT 1
        ''',
        values: {'email': email},
      );
      return result != null;
    } catch (e) {
      logger.error('Error checking pending OTP: $e');
      return false;
    }
  }

  /// Get the latest OTP for an email (for resend scenarios)
  Future<Map<String, dynamic>?> getLatestOTP(String email) async {
    try {
      return await DatabaseConnection.queryOne(
        '''
        SELECT * FROM $_tableName 
        WHERE email = @email 
        ORDER BY created_at DESC
        LIMIT 1
        ''',
        values: {'email': email},
      );
    } catch (e) {
      logger.error('Error getting latest OTP: $e');
      return null;
    }
  }

  /// Invalidate all OTPs for an email
  Future<void> invalidateAllOTPs(String email) async {
    try {
      await DatabaseConnection.execute(
        '''
        UPDATE $_tableName 
        SET is_used = TRUE 
        WHERE email = @email AND is_used = FALSE
        ''',
        values: {'email': email},
      );
      logger.info('All OTPs invalidated for email: $email');
    } catch (e) {
      logger.error('Error invalidating OTPs: $e');
    }
  }
}
