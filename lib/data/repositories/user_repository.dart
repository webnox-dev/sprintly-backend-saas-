import 'dart:math';
import '../../domain/models/user.dart';
import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// User repository for authentication and OTP operations
/// Uses the auth.users table in PostgreSQL
class UserRepository {
  final AppLogger logger = AppLogger('UserRepository');

  /// Table name - using auth schema
  static const String _tableName = 'auth.users';

  /// Get user by email
  Future<User?> getByEmail(String email) async {
    try {
      final sql = 'SELECT * FROM $_tableName WHERE email = @email';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email},
      );
      return result != null ? User.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting user by email: $e', e, stackTrace);
      return null;
    }
  }

  /// Get user by employee ID
  Future<User?> getByEmployeeId(String employeeId) async {
    try {
      final sql = 'SELECT * FROM $_tableName WHERE employee_id = @employeeId';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'employeeId': employeeId},
      );
      return result != null ? User.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting user by employee ID: $e', e, stackTrace);
      return null;
    }
  }

  /// Create user with password
  Future<User?> createUser({
    required String employeeId,
    required String email,
    required String password,
    required String role, // 'Admin' or 'Employee'
    String? createdBy,
  }) async {
    try {
      final hashedPassword = User.hashPassword(password);

      final sql =
          '''
        INSERT INTO $_tableName (employee_id, email, encrypted_password, role, created_by, updated_by)
        VALUES (@employeeId, @email, @password, @role, @createdBy, @updatedBy)
        RETURNING *
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'employeeId': employeeId,
          'email': email,
          'password': hashedPassword,
          'role': role,
          'createdBy': createdBy ?? employeeId,
          'updatedBy': createdBy ?? employeeId,
        },
      );
      return result != null ? User.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error creating user: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to create user. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Generate and store OTP for a user
  Future<User?> generateOTP({required String email, String? updatedBy}) async {
    try {
      final otp = generateOTPCode();
      final now = DateTime.now().toUtc();

      final sql =
          '''
        UPDATE $_tableName 
        SET otp = @otp, 
            otp_generated_at = @otpGeneratedAt,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE email = @email
        RETURNING *
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'otp': otp,
          'otpGeneratedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'updatedBy': updatedBy ?? 'SYSTEM',
          'email': email,
        },
      );
      return result != null ? User.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error generating OTP: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to generate OTP. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Verify OTP and confirm email
  Future<User?> verifyOTP({required String email, required String otp}) async {
    try {
      final user = await getByEmail(email);
      if (user == null) {
        throw AppException(
          code: 'USER_NOT_FOUND',
          message: 'User not found with this email.',
        );
      }

      // Check if OTP matches
      if (user.otp != otp) {
        throw AppException(
          code: 'INVALID_OTP',
          message: 'Invalid OTP. Please try again.',
        );
      }

      // Check if OTP is expired (15 minutes)
      if (!user.isOtpValid()) {
        throw AppException(
          code: 'OTP_EXPIRED',
          message: 'OTP has expired. Please request a new one.',
        );
      }

      // Confirm email
      final now = DateTime.now().toUtc();
      final sql =
          '''
        UPDATE $_tableName 
        SET email_confirmed_at = @confirmedAt,
            otp = NULL,
            otp_generated_at = NULL,
            updated_at = @updatedAt
        WHERE email = @email
        RETURNING *
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'confirmedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'email': email,
        },
      );
      return result != null ? User.fromMap(result) : null;
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      logger.error('Error verifying OTP: $e', e, stackTrace);
      throw AppException(
        code: 'VERIFICATION_ERROR',
        message: 'Failed to verify OTP. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Update user password
  Future<bool> updatePassword({
    required String email,
    required String newPassword,
    String? updatedBy,
  }) async {
    try {
      final hashedPassword = User.hashPassword(newPassword);
      final now = DateTime.now().toUtc();

      final sql =
          '''
        UPDATE $_tableName 
        SET encrypted_password = @password,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE email = @email
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {
          'password': hashedPassword,
          'updatedAt': now.toIso8601String(),
          'updatedBy': updatedBy ?? 'SYSTEM',
          'email': email,
        },
      );
      return true;
    } catch (e, stackTrace) {
      logger.error('Error updating password: $e', e, stackTrace);
      return false;
    }
  }

  /// Generate random 4-digit OTP
  String generateOTPCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// Verify email by setting email_confirmed_at timestamp
  Future<bool> verifyEmail(String email) async {
    try {
      final now = DateTime.now().toUtc();
      final sql =
          '''
        UPDATE $_tableName 
        SET email_confirmed_at = @confirmedAt,
            updated_at = @updatedAt
        WHERE email = @email
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {
          'confirmedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'email': email,
        },
      );
      logger.info('Email verified for: $email');
      return true;
    } catch (e, stackTrace) {
      logger.error('Error verifying email: $e', e, stackTrace);
      return false;
    }
  }

  /// Ensure auth user exists (create if not, update if exists)
  Future<void> ensureAuthUserExists({
    required String email,
    required String employeeId,
    required String role,
    required String password,
    String? createdBy,
    String? organizationId,
  }) async {
    try {
      final hashedPassword = User.hashPassword(password);
      final now = DateTime.now().toUtc().toIso8601String();

      // PostgreSQL ON CONFLICT requires a unique constraint on email
      final sql = '''
        INSERT INTO auth.users (
          employee_id, email, encrypted_password, role, reference_id, 
          is_active, created_at, created_by, updated_at, updated_by,
          organization_id
        ) VALUES (
          @employeeId, @email, @password, @role, @referenceId, 
          1, @now, @createdBy, @now, @createdBy, @organizationId::uuid
        ) ON CONFLICT (email) DO UPDATE SET
          employee_id = @employeeId,
          reference_id = @employeeId,
          organization_id = EXCLUDED.organization_id,
          encrypted_password = EXCLUDED.encrypted_password,
          role = EXCLUDED.role,
          updated_at = @now,
          updated_by = @createdBy
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {
          'employeeId': employeeId,
          'email': email,
          'password': hashedPassword,
          'role': role,
          'referenceId': employeeId,
          'now': now,
          'createdBy': createdBy ?? 'SYSTEM',
          'organizationId': organizationId,
        },
        isGlobal: organizationId != null,
      );

      logger.info('Auth user ensured for email: $email, role: $role');
    } catch (e, stackTrace) {
      logger.error('Error ensuring auth user: $e', e, stackTrace);
      rethrow;
    }
  }
}
