import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:math';
import '../domain/models/user.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/otp_helper_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/organization_repository.dart';
import '../data/database/connection.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../config/app_config.dart';
import 'email_service.dart';

/// Authentication service
class AuthService {
  final AdminRepository adminRepository = AdminRepository();
  final EmployeeRepository employeeRepository = EmployeeRepository();
  final UserRepository userRepository = UserRepository();
  final OTPHelperRepository otpRepository = OTPHelperRepository();
  final SessionRepository sessionRepository = SessionRepository();
  final OrganizationRepository organizationRepository = OrganizationRepository();
  final EmailService emailService = EmailService();
  final AppLogger logger = AppLogger('AuthService');

  /// Login admin/employee
  Future<Map<String, dynamic>> login(
    String email,
    String password,
    String role, {
    String? organizationId,
    String? deviceName,
    String? platform,
    String? ipAddress,
    String? city,
    String? state,
    String? country,
    String? browser,
  }) async {
    logger.info('=== LOGIN ATTEMPT ===');
    logger.info('Email: $email');
    logger.info('Role: $role');
    logger.info('OrgId: $organizationId');

    try {
      // For Admin/Employee role, check membership FIRST
      String userName = 'User';
      String? employeeId;
      String? targetOrgId = organizationId;

      if (role == 'Admin') {
        logger.info('Checking admin membership...');
        final admin = organizationId != null 
            ? await adminRepository.getByEmailAndOrg(email, organizationId)
            : await adminRepository.getByEmail(email);

        if (admin == null) {
          logger.warning('LOGIN FAILED: Admin not found for email: $email and org: $organizationId');
          throw UnauthorizedException(
            message: 'Invalid email, password or organization',
          );
        }
        userName = admin.adminName;
        employeeId = admin.adminId;
        organizationId = admin.organizationId;
        targetOrgId = admin.organizationId;
      } else {
        logger.info('Checking employee membership...');
        final employee = organizationId != null
            ? await employeeRepository.getByEmailAndOrg(email, organizationId)
            : null; // In multi-tenant, we should ideally always have orgId for employees

        // If no orgId provided but it's a legacy flow, we might need a fallback, 
        // but for SaaS we should require org selection.
        
        if (employee == null && organizationId != null) {
           throw UnauthorizedException(message: 'Membership not found in this organization');
        }

        if (employee != null) {
          userName = employee.employeeName;
          employeeId = employee.employeeId;
          targetOrgId = employee.organizationId;
        }
      }

      // Check status if Admin
      // Note: For employees, we could also check status here if needed
      
      // Now get user from auth.users table and validate credentials
      logger.info('Checking user in auth.users table...');
      final user = await userRepository.getByEmail(email);

      if (user == null) {
        logger.warning(
          'LOGIN FAILED: User not found in auth.users table for email: $email',
        );
        logger.warning(
          'This means the user exists in admins/employees table but not in auth.users',
        );
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'User not found in auth.users table'},
        );
      }

      logger.info('User found in auth.users: EmployeeId=${user.employeeId}');

      // Verify password
      logger.info('Verifying password...');
      
      if (!user.verifyPassword(password)) {
        logger.warning('LOGIN FAILED: Invalid password for email: $email');
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'Password verification failed'},
        );
      }
      logger.info('Password verified successfully');

      // Check if account is active in auth.users table
      if (!user.isActive) {
        logger.warning(
          'LOGIN FAILED: User account is inactive in auth.users. Email: $email',
        );
        throw UnauthorizedException(
          message: 'Your account is inactive. Please contact support.',
          details: {'reason': 'Account is inactive in auth.users'},
        );
      }

      // Check if email is confirmed
      if (!user.isEmailConfirmed) {
        logger.info('Email not verified for: $email. Sending OTP...');
        final otp = await otpRepository.createOTPRecord(
          email: email,
          userType: role,
          otpType: 'email_verification',
        );
        // Send OTP email in background - do not block login response
        emailService
            .sendOTPEmail(
              toEmail: email,
              userName: userName,
              otp: otp,
              userType: role,
            )
            .catchError((e, st) {
              logger.warning('Failed to send OTP email: $e');
              return false;
            });
        logger.info('OTP send triggered for: $email');

        return {
          'success': false,
          'code': 'EMAIL_NOT_VERIFIED',
          'message': 'Please verify your email. OTP has been sent to $email',
          'data': {'email': email, 'role': role, 'employeeId': user.employeeId},
        };
      }

      // Check session limit (5 max)
      final sessionCount = await sessionRepository.getActiveSessionCount(
        user.employeeId,
        role,
      );

      if (sessionCount >= 5) {
        logger.warning('LOGIN FAILED: Session limit exceeded for $email');
        final activeSessions = await sessionRepository.getActiveSessions(
          user.employeeId,
          role,
        );
        return {
          'success': false,
          'code': 'SESSION_LIMIT_EXCEEDED',
          'message':
              'Maximum 5 active sessions allowed. Please logout from another device.',
          'data': {
            'active_sessions': activeSessions,
            'max_sessions': 5,
            'current_count': sessionCount,
          },
        };
      }

      // Generate token
      final token = generateToken(employeeId ?? user.employeeId, email, role, orgId: targetOrgId);

      // Store JWT in sessions table for session management
      // If this is the first session, make it the main device
      await sessionRepository.createSession(
        userId: employeeId ?? user.employeeId,
        userType: role,
        jwtToken: token,
        deviceName: deviceName,
        platform: platform,
        ipAddress: ipAddress,
        city: city,
        state: state,
        country: country,
        browser: browser,
        isMainDevice: sessionCount == 0,
      );

      logger.info('LOGIN SUCCESS: $email logged in successfully');
      logger.info('=== LOGIN COMPLETE ===');
      
      // Fetch plan features to include in frontend state
      Map<String, dynamic>? planFeatures;
      if (targetOrgId != null) {
        final org = await organizationRepository.getById(targetOrgId);
        if (org != null && org['plan_features'] != null) {
          try {
            planFeatures = jsonDecode(org['plan_features'] as String) as Map<String, dynamic>;
          } catch (e) {
            logger.warning('Failed to parse plan_features for org $targetOrgId: $e');
          }
        }
      }

      return {
        'success': true,
        'message': 'Login successful',
        'data': {
          'token': token,
          'employeeId': employeeId ?? user.employeeId,
          'organizationId': targetOrgId,
          'email': email,
          'role': role,
          'name': userName,
          'plan_features': planFeatures,
          'expiresIn': AppConfig.jwtExpirationHours * 3600,
        },
      };
    } on AppException catch (e) {
      logger.error('LOGIN FAILED: ${e.message}');
      if (e.details != null) {
        logger.error('Details: ${e.details}');
      }
      rethrow;
    } catch (e, stackTrace) {
      logger.error('LOGIN ERROR (Unexpected): $e', e, stackTrace);
      throw UnauthorizedException(
        message: 'Login failed. Please check your credentials.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Employee Login
  Future<Map<String, dynamic>> employeeLogin(
    String email,
    String password, {
    String? organizationId,
    String? deviceName,
    String? platform,
    String? ipAddress,
    String? city,
    String? state,
    String? country,
    String? browser,
  }) async {
    logger.info('=== EMPLOYEE LOGIN ATTEMPT ===');
    logger.info('Email: $email');

    try {
      // Check employee status FIRST before validating credentials
      logger.info('Checking employee in employees table...');
      final employee = organizationId != null 
          ? await employeeRepository.getByEmailAndOrg(email, organizationId)
          : await employeeRepository.getByEmail(email);

      if (employee == null) {
        logger.warning(
          'EMPLOYEE LOGIN FAILED: Employee not found in employees table for email: $email and org: $organizationId',
        );
        throw UnauthorizedException(
          message: 'Invalid email, password or organization',
          details: {'reason': 'Employee not found in database'},
        );
      }

      logger.info(
        'Employee found: ${employee.employeeId} - ${employee.employeeName}',
      );

      if (employee.status != true) {
        logger.warning(
          'EMPLOYEE LOGIN FAILED: Employee account is inactive. EmployeeId: ${employee.employeeId}',
        );
        throw UnauthorizedException(
          message: 'Your account is inactive. Please contact support.',
          details: {
            'reason': 'Account status is inactive',
            'employeeId': employee.employeeId,
          },
        );
      }
      logger.info('Employee status is active');

      // Now get user from auth.users table and validate credentials
      logger.info('Checking user in auth.users table...');
      final user = await userRepository.getByEmail(email);

      if (user == null) {
        logger.warning(
          'EMPLOYEE LOGIN FAILED: User not found in auth.users table for email: $email',
        );
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'User not found in auth.users table'},
        );
      }

      // Verify password
      logger.info('Verifying password...');

      if (!user.verifyPassword(password)) {
        logger.warning(
          'EMPLOYEE LOGIN FAILED: Invalid password for email: $email',
        );
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'Password verification failed'},
        );
      }

      // Check if account is active in auth.users table
      if (!user.isActive) {
        logger.warning(
          'EMPLOYEE LOGIN FAILED: User account is inactive in auth.users. Email: $email',
        );
        throw UnauthorizedException(
          message: 'Your account is inactive. Please contact support.',
          details: {'reason': 'Account is inactive in auth.users'},
        );
      }

      // Check if email is confirmed
      if (!user.isEmailConfirmed) {
        logger.info('Email not verified for: $email. Sending OTP...');
        final otp = await otpRepository.createOTPRecord(
          email: email,
          userType: 'Employee',
          otpType: 'email_verification',
        );
        emailService
            .sendOTPEmail(
              toEmail: email,
              userName: employee.employeeName,
              otp: otp,
              userType: 'Employee',
            )
            .catchError((e, st) {
              logger.warning('Failed to send OTP email: $e');
              return false;
            });

        return {
          'success': false,
          'code': 'EMAIL_NOT_VERIFIED',
          'message': 'Please verify your email. OTP has been sent to $email',
          'data': {
            'email': email,
            'role': 'Employee',
            'employeeId': user.employeeId,
          },
        };
      }

      // Check session limit (5 max)
      final sessionCount = await sessionRepository.getActiveSessionCount(
        user.employeeId,
        'Employee',
      );

      if (sessionCount >= 5) {
        logger.warning('LOGIN FAILED: Session limit exceeded for $email');
        final activeSessions = await sessionRepository.getActiveSessions(
          user.employeeId,
          'Employee',
        );
        return {
          'success': false,
          'code': 'SESSION_LIMIT_EXCEEDED',
          'message':
              'Maximum 5 active sessions allowed. Please logout from another device.',
          'data': {
            'active_sessions': activeSessions,
            'max_sessions': 5,
            'current_count': sessionCount,
          },
        };
      }

      // Generate token
      final token = generateToken(user.employeeId, email, 'Employee');

      // Store JWT in sessions table for session management
      await sessionRepository.createSession(
        userId: user.employeeId,
        userType: 'Employee',
        jwtToken: token,
        deviceName: deviceName,
        platform: platform,
        ipAddress: ipAddress,
        city: city,
        state: state,
        country: country,
        browser: browser,
        isMainDevice: sessionCount == 0,
      );

      // Fetch plan features to include in frontend state
      Map<String, dynamic>? planFeatures;
      if (employee.organizationId != null) {
        final org = await organizationRepository.getById(employee.organizationId!);
        if (org != null && org['plan_features'] != null) {
          try {
            planFeatures = jsonDecode(org['plan_features'] as String) as Map<String, dynamic>;
          } catch (e) {
            logger.warning('Failed to parse plan_features for org ${employee.organizationId}: $e');
          }
        }
      }

      return {
        'success': true,
        'message': 'Login successful',
        'data': {
          'token': token,
          'employeeId': user.employeeId,
          'email': email,
          'role': 'Employee',
          'plan_features': planFeatures,
          'expiresIn': AppConfig.jwtExpirationHours * 3600,
        },
      };
    } on AppException catch (e) {
      logger.error('EMPLOYEE LOGIN FAILED: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      logger.error('EMPLOYEE LOGIN ERROR (Unexpected): $e', e, stackTrace);
      throw UnauthorizedException(
        message: 'Login failed. Please check your credentials.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Verify OTP
  Future<Map<String, dynamic>> verifyOTP(
    String email,
    String otp,
    String role, {
    String? deviceName,
    String? platform,
  }) async {
    try {
      // Verify OTP using OTPHelperRepository
      final result = await otpRepository.verifyOTP(email: email, otp: otp);

      if (result['success'] != true) {
        if (result['requiresResend'] == true) {
          throw AppException(
            code: 'OTP_EXPIRED',
            message: 'OTP has expired. Please request a new one.',
          );
        }
        throw AppException(
          code: 'INVALID_OTP',
          message: 'Invalid OTP. Please try again.',
        );
      }

      // Confirm email in auth.users table
      await userRepository.verifyEmail(email);

      // Get user to generate token
      final user = await userRepository.getByEmail(email);
      if (user == null) {
        throw AppException(
          code: 'USER_NOT_FOUND',
          message: 'User not found after verification',
        );
      }

      // Generate token
      final token = generateToken(user.employeeId, email, role);

      // Store JWT in sessions table for session management
      await sessionRepository.createSession(
        userId: user.employeeId,
        userType: role,
        jwtToken: token,
        deviceName: deviceName,
        platform: platform,
      );

      return {
        'success': true,
        'message': 'Email verified successfully',
        'data': {
          'token': token,
          'employeeId': user.employeeId,
          'email': email,
          'role': role,
          'expiresIn': AppConfig.jwtExpirationHours * 3600,
        },
      };
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      logger.error('OTP verification error: $e', e, stackTrace);
      throw AppException(
        code: 'VERIFICATION_ERROR',
        message: 'Failed to verify OTP. Please try again.',
      );
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOTP(
    String email,
    String role, {
    String? employeeId,
  }) async {
    try {
      String userName = 'User';

      if (role == 'Admin') {
        final admin = await adminRepository.getByEmail(email);
        if (admin == null) {
          throw AppException(
            code: 'USER_NOT_FOUND',
            message: 'Admin not found',
          );
        }
        userName = admin.adminName;
      } else {
        final employee = await employeeRepository.getByEmail(email);
        if (employee == null) {
          throw AppException(
            code: 'USER_NOT_FOUND',
            message: 'Employee not found',
          );
        }
        userName = employee.employeeName;
      }

      final otp = await otpRepository.createOTPRecord(
        email: email,
        userType: role,
        otpType: 'email_verification',
      );

      if (role == 'Employee' && employeeId != null) {
        emailService
            .sendWelcomeEmail(
              toEmail: email,
              userName: userName,
              employeeId: employeeId,
              otp: otp,
            )
            .catchError((e, st) {
              logger.warning('Failed to resend welcome/OTP email: $e');
              return false;
            });
      } else {
        emailService
            .sendOTPEmail(
              toEmail: email,
              userName: userName,
              otp: otp,
              userType: role,
            )
            .catchError((e, st) {
              logger.warning('Failed to resend OTP email: $e');
              return false;
            });
      }

      return {'success': true, 'message': 'OTP resent successfully to $email'};
    } catch (e, stackTrace) {
      logger.error('Error resending OTP: $e', e, stackTrace);
      throw AppException(
        code: 'RESEND_FAILED',
        message: 'Failed to resend OTP',
        details: {'error': e.toString()},
      );
    }
  }

  /// Send OTP for session actions (set main, logout main)
  Future<void> sendSessionOTP({
    required String email,
    required String userName,
    required String userType,
    required String action,
  }) async {
    try {
      final otp = await otpRepository.createOTPRecord(
        email: email,
        userType: userType,
        otpType: 'session_verification',
      );

      String subject = (action == 'set_main')
          ? 'Verification Code to Set Main Device'
          : (action == 'logout_main')
          ? 'Verification Code to Logout from Main Device'
          : 'Verification Code';

      emailService
          .sendOTPEmail(
            toEmail: email,
            userName: userName,
            otp: otp,
            userType: userType,
            subject: subject,
          )
          .catchError((e, st) {
            logger.error('Failed to send session OTP email: $e', e, st);
            return false;
          });
      logger.info('Session OTP triggered for $email for action $action');
    } catch (e, stackTrace) {
      logger.error('Error sending session OTP: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Verify session OTP
  Future<bool> verifySessionOTP(String email, String otp) async {
    try {
      final result = await otpRepository.verifyOTP(email: email, otp: otp);
      return result['success'] == true;
    } catch (e, stackTrace) {
      logger.error('Error verifying session OTP: $e', e, stackTrace);
      return false;
    }
  }

  /// Verify JWT token
  Future<User?> verifyToken(String token) async {
    try {
      final jwt = JWT.verify(token, SecretKey(AppConfig.jwtSecret));

      final email = jwt.payload['email'] as String?;
      if (email == null) {
        return null;
      }

      // Check if this token has been revoked in the database
      final isActive = await sessionRepository.isTokenActive(token);
      if (!isActive) {
        logger.warning(
          'Token has been revoked or session not found for email: $email',
        );
        return null;
      }

      final organizationId = jwt.payload['organizationId'] as String?;
      final user = await userRepository.getByEmail(email);
      if (user == null || !user.isEmailConfirmed) {
        return null;
      }

      return user.copyWith(organizationId: organizationId);
    } catch (e) {
      logger.warning(
        'Token verification failed: $e. Proactively deleting session...',
      );
      // Proactively delete the session record if token is invalid/expired
      await sessionRepository.deleteSessionByToken(token);
      return null;
    }
  }

  /// Logout
  Future<void> logout(String? token) async {
    if (token != null) {
      await sessionRepository.deleteSessionByToken(token);
    }
    logger.info('User logged out and session deleted');
  }

  /// Revoke a session using raw credentials (useful when blocked by session limit during login)
  Future<void> revokeSessionWithCredentials({
    required String email,
    required String password,
    required String role,
    required String sessionId,
  }) async {
    try {
      // 1. Verify user exists
      final user = await userRepository.getByEmail(email);
      if (user == null) {
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'User not found'},
        );
      }

      // 2. Verify password
      if (!user.verifyPassword(password)) {
        throw UnauthorizedException(
          message: 'Invalid email or password',
          details: {'reason': 'Password verification failed'},
        );
      }

      // 3. Verify that the session belongs to this user
      final sessionOwnerId = await sessionRepository.getSessionUserId(
        sessionId,
      );
      if (sessionOwnerId != user.employeeId) {
        throw UnauthorizedException(
          message: 'Unauthorized',
          details: {'reason': 'Session does not belong to this user'},
        );
      }

      // 4. Revoke the session
      await sessionRepository.revokeSession(sessionId);
      logger.info(
        'Session $sessionId revoked by credentials for ${user.employeeId}',
      );
    } catch (e) {
      logger.error('Error in revokeSessionWithCredentials: $e');
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword(String email, String newPassword) async {
    try {
      final success = await userRepository.updatePassword(
        email: email,
        newPassword: newPassword,
      );

      if (!success) {
        throw AppException(
          code: 'UPDATE_FAILED',
          message: 'Failed to update password',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      logger.error('Error changing password: $e');
      throw AppException(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error while changing password',
        details: {'error': e.toString()},
      );
    }
  }

  /// Generate JWT token with employee_id and organization_id
  String generateToken(String employeeId, String email, String role, {String? orgId}) {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(hours: AppConfig.jwtExpirationHours));

    final jwt = JWT({
      'employeeId': employeeId,
      'organizationId': orgId,
      'email': email,
      'role': role,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    });

    return jwt.sign(SecretKey(AppConfig.jwtSecret));
  }

  /// Discover all workspaces (organizations) associated with an email
  Future<List<Map<String, dynamic>>> discoverWorkspaces(String email) async {
    try {
      logger.info('Discovering workspaces for email: $email');
      
      final List<Map<String, dynamic>> memberships = [];

      // 1. Check Admin memberships
      final adminMemberships = await adminRepository.listByEmail(email);
      for (final admin in adminMemberships) {
        if (admin.organizationId != null) {
          memberships.add({
            'organization_id': admin.organizationId,
            'role': 'Admin',
            'member_id': admin.adminId,
            'name': admin.adminName,
            'status': admin.status,
          });
        }
      }

      // 2. Check Employee memberships
      final employeeMemberships = await employeeRepository.listByEmail(email);
      for (final emp in employeeMemberships) {
        if (emp.organizationId != null) {
          // Avoid duplicates if user is both admin and employee in same org
          final exists = memberships.any((m) => m['organization_id'] == emp.organizationId);
          if (!exists) {
            memberships.add({
              'organization_id': emp.organizationId,
              'role': 'Employee',
              'member_id': emp.employeeId,
              'name': emp.employeeName,
              'status': emp.status,
            });
          }
        }
      }

      if (memberships.isEmpty) {
        return [];
      }

      // 3. Fetch Organization details for each membership
      final List<Map<String, dynamic>> result = [];
      for (final membership in memberships) {
        final org = await organizationRepository.getById(membership['organization_id']);
        if (org != null) {
          result.add({
            ...membership,
            'organization_name': org['name'],
            'organization_logo': org['logo_url'],
            'organization_slug': org['slug'],
          });
        }
      }

      return result;
    } catch (e, stackTrace) {
      logger.error('Error discovering workspaces: $e', e, stackTrace);
      return [];
    }
  }

  /// Generate a secure random password
  static String generateRandomPassword({int length = 12}) {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final random = Random.secure();
    return List.generate(
      length,
      (index) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Register a new organization and create its initial Super Admin
  Future<Map<String, dynamic>> registerOrganization({
    required String organizationName,
    required String adminName,
    required String adminEmail,
    required String adminPhone,
    required String password,
    String? industry,
    String? country,
  }) async {
    logger.info('Registering new organization: $organizationName');

    // 1. Check if organization name/slug already exists
    final slug = organizationName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final existingOrg = await organizationRepository.getBySlug(slug);
    if (existingOrg != null) {
      throw AppException(
        code: 'CONFLICT',
        message: 'An organization with this name already exists',
      );
    }

    // 2. We allow existing users to register new organizations. 
    // The ensureAuthUserExists call below handles linking or creating the auth record.

    return await DatabaseConnection.transaction((session) async {
      // 3. Create Organization
      final orgData = {
        'name': organizationName,
        'display_name': organizationName,
        'industry': industry,
        'country': country,
        'contact_email': adminEmail,
        'contact_phone': adminPhone,
        'status': 'trial', // Default to trial for self-registration
        'created_by': 'self_registration',
      };
      
      final org = await organizationRepository.create(orgData);
      final orgId = org['id'] as String;

      // 4. Create Admin record (Super Admin of the new org)
      // Generate a unique Admin ID to avoid global constraint conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final adminId = 'ADM${timestamp.substring(timestamp.length - 6)}'; 
      final adminData = {
        'admin_id': adminId,
        'admin_name': adminName,
        'admin_personal_email': adminEmail,
        'admin_phone_num': adminPhone,
        'admin_role': 'Super Admin',
        'role_type': 'Super Admin',
        'status': 1,
        'organization_id': orgId,
      };
      
      final admin = await adminRepository.create(adminData, organizationId: orgId);

      // 5. Create Auth User record
      await userRepository.ensureAuthUserExists(
        email: adminEmail,
        employeeId: adminId,
        role: 'admin',
        password: password,
        createdBy: 'self_registration',
        organizationId: orgId,
      );

      logger.info('Organization $organizationName registered successfully with ID: $orgId');

      return {
        'success': true,
        'message': 'Organization registered successfully',
        'data': {
          'organization': org,
          'admin': admin.toJson(),
        }
      };
    });
  }
}
