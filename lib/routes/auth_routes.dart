import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../data/repositories/otp_helper_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/fcm_token_repository.dart';
import '../data/repositories/session_repository.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Authentication routes handler
class AuthRoutes {
  final AuthService service = AuthService();
  final EmailService emailService = EmailService();
  final OTPHelperRepository otpRepository = OTPHelperRepository();
  final EmployeeRepository employeeRepository = EmployeeRepository();
  final AdminRepository adminRepository = AdminRepository();
  final UserRepository userRepository = UserRepository();
  final FcmTokenRepository fcmTokenRepository = FcmTokenRepository();
  final SessionRepository sessionRepository = SessionRepository();
  final AppLogger logger = AppLogger('AuthRoutes');

  Router get router {
    final router = Router();

    // POST /api/auth/login - Admin/Employee login
    router.post('/auth/login', handleLogin);

    // POST /api/auth/discover-workspaces - Discover organizations by email
    router.post('/auth/discover-workspaces', handleDiscoverWorkspaces);

    // POST /api/auth/employee-login - Employee login
    router.post('/auth/employee-login', handleEmployeeLogin);

    // POST /api/auth/verify-otp - Verify OTP and get token
    router.post('/auth/verify-otp', handleVerifyOTP);

    // POST /api/auth/resend-otp - Resend OTP
    router.post('/auth/resend-otp', handleResendOTP);

    // POST /api/auth/logout - Logout
    router.post('/auth/logout', handleLogout);

    // POST /api/auth/send-email - Send email (authenticated)
    router.post('/auth/send-email', handleSendEmail);

    // POST /api/auth/verify-email/employee - Verify employee email with OTP
    router.post('/auth/verify-email/employee', handleVerifyEmployeeEmail);

    // POST /api/auth/verify-email/admin - Verify admin email with OTP
    router.post('/auth/verify-email/admin', handleVerifyAdminEmail);

    // POST /api/auth/resend-verification-otp - Resend email verification OTP
    router.post('/auth/resend-verification-otp', handleResendVerificationOTP);

    // ======== FORGOT PASSWORD ENDPOINTS ========
    // POST /api/auth/forgot-password/request - Request password reset OTP
    router.post('/auth/forgot-password/request', handleForgotPasswordRequest);

    // POST /api/auth/forgot-password/verify - Verify password reset OTP
    router.post('/auth/forgot-password/verify', handleForgotPasswordVerify);

    // POST /api/auth/forgot-password/resend - Resend password reset OTP
    router.post('/auth/forgot-password/resend', handleForgotPasswordResend);

    // POST /api/auth/change-password - Change password
    router.post('/auth/change-password', handleChangePassword);

    // ======== FCM TOKEN ENDPOINTS ========
    // POST /api/auth/fcm-token - Update FCM token
    router.post('/auth/fcm-token', handleUpdateFcmToken);

    // GET /api/auth/sessions - Get active sessions
    router.get('/auth/sessions', handleGetSessions);

    // DELETE /api/auth/sessions/others - Revoke all other sessions
    router.delete('/auth/sessions/others', handleRevokeAllOtherSessions);

    // DELETE /api/auth/sessions/<id> - Revoke a specific session
    router.delete('/auth/sessions/<id>', handleRevokeSession);

    // POST /api/auth/sessions/revoke-with-credentials - Revoke a session using credentials
    router.post(
      '/auth/sessions/revoke-with-credentials',
      handleRevokeSessionWithCredentials,
    );

    // POST /api/auth/sessions/request-otp - Request OTP for session actions
    router.post('/auth/sessions/request-otp', handleRequestSessionOTP);

    // POST /api/auth/sessions/set-main - Set as main device
    router.post('/auth/sessions/set-main', handleSetMainDevice);

    // POST /api/auth/sessions/verify-main-logout - Verify OTP for main device logout
    router.post('/auth/sessions/verify-main-logout', handleVerifyMainLogout);

    // DELETE /api/auth/fcm-token - Remove FCM token (logout)
    router.delete('/auth/fcm-token', handleRemoveFcmToken);

    return router;
  }

  /// POST /api/auth/login
  Future<Response> handleLogin(Request request) async {
    try {
      final body = await request.readAsString();
      logger.info('Login request received: $body');

      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final password = data['password']?.toString();
      final role = data['role']?.toString() ?? 'Admin';
      final deviceName = data['device_name']?.toString();
      final platform = data['platform']?.toString();
      final ipAddress = data['ip_address']?.toString();
      final city = data['city']?.toString();
      final state = data['state']?.toString();
      final country = data['country']?.toString();
      final browser = data['browser']?.toString();

      logger.info(
        'Parsed login request - Email: $email, Role: $role, Password length: ${password?.length ?? 0}',
      );

      if (email == null || email.isEmpty) {
        logger.warning('Login validation failed: Email is required');
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (password == null || password.isEmpty) {
        logger.warning('Login validation failed: Password is required');
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Password is required',
        ).toShelfResponse(statusCode: 400);
      }

      final organizationId = data['organization_id']?.toString();

      final result = await service.login(
        email,
        password,
        role,
        organizationId: organizationId,
        deviceName: deviceName,
        platform: platform,
        ipAddress: ipAddress,
        city: city,
        state: state,
        country: country,
        browser: browser,
      );

      // Check if email verification is required
      if (result['success'] == false &&
          result['code'] == 'EMAIL_NOT_VERIFIED') {
        return ApiResponse.success(
          data: result,
          message: result['message'],
        ).toShelfResponse();
      }

      // Check if session limit exceeded (Return 403 Forbidden)
      if (result['success'] == false &&
          result['code'] == 'SESSION_LIMIT_EXCEEDED') {
        return ApiResponse.error(
          code: result['code'],
          message: result['message'],
          details: result['data'],
        ).toShelfResponse(statusCode: 403);
      }

      return ApiResponse.success(
        data: result['data'],
        message: result['message'] ?? 'Login successful',
      ).toShelfResponse();
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 401);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleLogin: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/discover
  Future<Response> handleDiscoverWorkspaces(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      final results = await service.discoverWorkspaces(email);

      return ApiResponse.success(
        data: results,
        message: results.isEmpty 
            ? 'No organizations found for this email' 
            : 'Found ${results.length} organizations',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleDiscoverWorkspaces: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/employee-login
  Future<Response> handleEmployeeLogin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final password = data['password']?.toString();
      final deviceName = data['device_name']?.toString();
      final platform = data['platform']?.toString();
      final ipAddress = data['ip_address']?.toString();
      final city = data['city']?.toString();
      final state = data['state']?.toString();
      final country = data['country']?.toString();
      final browser = data['browser']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (password == null || password.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Password is required',
        ).toShelfResponse(statusCode: 400);
      }

      final organizationId = data['organization_id']?.toString();

      final result = await service.employeeLogin(
        email,
        password,
        organizationId: organizationId,
        deviceName: deviceName,
        platform: platform,
        ipAddress: ipAddress,
        city: city,
        state: state,
        country: country,
        browser: browser,
      );

      // Check if email verification is required
      if (result['success'] == false &&
          result['code'] == 'EMAIL_NOT_VERIFIED') {
        print(
          'BACKEND DEBUG: handleEmployeeLogin - EMAIL_NOT_VERIFIED triggered',
        );
        return ApiResponse.success(
          data: result,
          message: result['message'],
        ).toShelfResponse();
      }

      // Check if session limit exceeded (Return 403 Forbidden)
      if (result['success'] == false &&
          result['code'] == 'SESSION_LIMIT_EXCEEDED') {
        print(
          'BACKEND DEBUG: handleEmployeeLogin - SESSION_LIMIT_EXCEEDED triggered',
        );
        return ApiResponse.error(
          code: result['code'],
          message: result['message'],
          details: result['data'],
        ).toShelfResponse(statusCode: 403);
      }

      return ApiResponse.success(
        data: result['data'],
        message: result['message'],
      ).toShelfResponse();
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 401);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleEmployeeLogin: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/verify-otp
  Future<Response> handleVerifyOTP(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final otp = data['otp']?.toString();
      final role = data['role']?.toString() ?? 'Admin';
      final deviceName = data['device_name']?.toString();
      final platform = data['platform']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (otp == null || otp.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Valid OTP is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await service.verifyOTP(
        email,
        otp,
        role,
        deviceName: deviceName,
        platform: platform,
      );

      return ApiResponse.success(
        data: result['data'],
        message: result['message'],
      ).toShelfResponse();
    } on AppException catch (e) {
      int statusCode = 400;
      if (e.code == 'INVALID_OTP' || e.code == 'OTP_EXPIRED') {
        statusCode = 401;
      }
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: statusCode);
    } catch (e, stackTrace) {
      logger.error('Error in handleVerifyOTP: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/resend-otp
  Future<Response> handleResendOTP(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final role = data['role']?.toString() ?? 'Admin';
      final employeeId = data['employeeId']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await service.resendOTP(
        email,
        role,
        employeeId: employeeId,
      );

      return ApiResponse.success(
        data: result,
        message: result['message'],
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleResendOTP: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/logout
  Future<Response> handleLogout(Request request) async {
    try {
      // Get token from Authorization header
      String? token;
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      }

      if (token == null) {
        return ApiResponse.success(
          message: 'Logout successful',
        ).toShelfResponse();
      }

      // Check if this is the main device
      final isMain = await sessionRepository.isTokenMainDevice(token);
      if (isMain) {
        return ApiResponse.error(
          code: 'MAIN_DEVICE_LOGOUT_REQUIRES_OTP',
          message: 'OTP verification required to logout from the main device',
        ).toShelfResponse(statusCode: 403);
      }

      await service.logout(token);

      return ApiResponse.success(
        message: 'Logout successful',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleLogout: $e', e, stackTrace);
      return ApiResponse.success(
        message: 'Logout successful',
      ).toShelfResponse();
    }
  }

  /// POST /api/auth/send-email - Send email (requires Bearer auth)
  Future<Response> handleSendEmail(Request request) async {
    try {
      // Check for Bearer token
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final toEmail = data['to']?.toString();
      final subject = data['subject']?.toString();
      final message = data['body']?.toString();
      final ccEmails = data['cc'] != null
          ? (data['cc'] as List).map((e) => e.toString()).toList()
          : null;
      final attachments = data['attachments'] != null
          ? (data['attachments'] as List).map((e) => e.toString()).toList()
          : null;

      if (toEmail == null || toEmail.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Recipient email (to) is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (subject == null || subject.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email subject is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (message == null || message.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email body is required',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await emailService.sendEmail(
        toEmail: toEmail,
        subject: subject,
        htmlContent: message,
        ccEmails: ccEmails,
        attachments: attachments,
      );

      if (success) {
        return ApiResponse.success(
          message: 'Email sent successfully',
          data: {'to': toEmail, 'subject': subject},
        ).toShelfResponse();
      } else {
        return ApiResponse.error(
          code: 'EMAIL_FAILED',
          message: 'Failed to send email',
        ).toShelfResponse(statusCode: 500);
      }
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleSendEmail: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/verify-email/employee - Verify employee email with OTP
  Future<Response> handleVerifyEmployeeEmail(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final otp = data['otp']?.toString();
      final deviceName = data['device_name']?.toString();
      final platform = data['platform']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (otp == null || otp.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'OTP is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info('Verifying employee email: $email with OTP: $otp');

      // Use AuthService.verifyOTP which updates email_verified and returns token
      final result = await service.verifyOTP(
        email,
        otp,
        'Employee',
        deviceName: deviceName,
        platform: platform,
      );

      logger.info('Employee email verified successfully: $email');
      return ApiResponse.success(
        message: 'Email verified successfully',
        data: result['data'],
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleVerifyEmployeeEmail: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/verify-email/admin - Verify admin email with OTP
  Future<Response> handleVerifyAdminEmail(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final otp = data['otp']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (otp == null || otp.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'OTP is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info('Verifying admin email: $email with OTP: $otp');

      // Verify OTP using OTPHelperRepository
      final result = await otpRepository.verifyOTP(email: email, otp: otp);

      if (result['success'] == true) {
        // Update the email_confirmed_at in auth.users table
        await userRepository.verifyEmail(email);

        logger.info('Admin email verified successfully: $email');
        return ApiResponse.success(
          message: 'Email verified successfully',
          data: {'email': email, 'verified': true},
        ).toShelfResponse();
      } else if (result['requiresResend'] == true) {
        // OTP expired - generate new OTP and send email
        logger.info('OTP expired for admin: $email. Generating new OTP...');

        // Get admin details
        final admin = await adminRepository.getByEmail(email);
        if (admin != null) {
          final newOtp = await otpRepository.createOTPRecord(
            email: email,
            userType: 'Admin',
            otpType: 'email_verification',
          );

          emailService
              .sendOTPEmail(
                toEmail: email,
                userName: admin.adminName,
                otp: newOtp,
                userType: 'admin',
              )
              .catchError((e, st) {
                logger.warning('Failed to send OTP email (OTP expired): $e');
                return false;
              });

          return ApiResponse.error(
            code: 'OTP_EXPIRED',
            message: 'OTP has expired. A new OTP has been sent to your email.',
            details: {'newOtpSent': true},
          ).toShelfResponse(statusCode: 400);
        }

        return ApiResponse.error(
          code: result['reason'] ?? 'OTP_EXPIRED',
          message: result['message'] ?? 'OTP has expired',
        ).toShelfResponse(statusCode: 400);
      } else {
        return ApiResponse.error(
          code: result['reason'] ?? 'INVALID_OTP',
          message: result['message'] ?? 'Invalid OTP',
        ).toShelfResponse(statusCode: 400);
      }
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleVerifyAdminEmail: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/resend-verification-otp - Resend email verification OTP
  Future<Response> handleResendVerificationOTP(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final userType = data['userType']?.toString() ?? 'Employee';

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info('Resending verification OTP to: $email (Type: $userType)');

      String? userName;
      String? employeeId;

      if (userType == 'Employee') {
        final employee = await employeeRepository.getByEmail(email);
        if (employee == null) {
          return ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Employee not found',
          ).toShelfResponse(statusCode: 404);
        }
        userName = employee.employeeName;
        employeeId = employee.employeeId;
      } else {
        final admin = await adminRepository.getByEmail(email);
        if (admin == null) {
          return ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Admin not found',
          ).toShelfResponse(statusCode: 404);
        }
        userName = admin.adminName;
        employeeId = admin.adminId;
      }

      // Generate new OTP
      final newOtp = await otpRepository.createOTPRecord(
        email: email,
        userType: userType,
        otpType: 'email_verification',
      );

      // Send email in background - do not block response
      if (userType == 'Employee') {
        emailService
            .sendWelcomeEmail(
              toEmail: email,
              userName: userName,
              employeeId: employeeId,
              otp: newOtp,
            )
            .catchError((e, st) {
              logger.warning('Failed to send verification OTP email: $e');
              return false;
            });
      } else {
        emailService
            .sendOTPEmail(
              toEmail: email,
              userName: userName,
              otp: newOtp,
              userType: userType.toLowerCase(),
            )
            .catchError((e, st) {
              logger.warning('Failed to send verification OTP email: $e');
              return false;
            });
      }

      logger.info('Verification OTP send triggered for: $email');
      return ApiResponse.success(
        message: 'Verification OTP sent successfully',
        data: {'email': email},
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleResendVerificationOTP: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ======== FORGOT PASSWORD HANDLERS ========

  /// POST /api/auth/forgot-password/request
  /// Payload: { email, phone_number, user_type }
  /// Verifies email and phone match, generates OTP, sends email
  Future<Response> handleForgotPasswordRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final userType = data['user_type']?.toString() ?? 'Admin';

      final phoneNumber = data['phone_number']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info(
        'Forgot password request for email: $email, userType: $userType',
      );

      String? userName;

      if (userType == 'Employee') {
        // Check if employee exists
        final employee = await employeeRepository.getByEmail(email);
        if (employee == null) {
          return ApiResponse.error(
            code: 'USER_NOT_FOUND',
            message: 'No employee account found with this email.',
          ).toShelfResponse(statusCode: 404);
        }

        if (phoneNumber == null || phoneNumber.isEmpty) {
          return ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Phone number is required',
          ).toShelfResponse(statusCode: 400);
        }

        // Verify phone number matches (Robust check)
        // Normalize: remove non-digits
        final storedPhone = employee.employeePhoneNum.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final inputPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

        // Check if stored phone ends with input phone or vice versa
        // This handles cases like +919876543210 vs 9876543210
        if (!storedPhone.endsWith(inputPhone) &&
            !inputPhone.endsWith(storedPhone)) {
          logger.warning(
            'Phone mismatch for employee: $email. Stored: ${employee.employeePhoneNum}, Input: $phoneNumber',
          );
          return ApiResponse.error(
            code: 'PHONE_MISMATCH',
            message: 'Phone number does not match our records.',
          ).toShelfResponse(statusCode: 400);
        }

        // Check if employee account is active
        if (employee.status != true) {
          return ApiResponse.error(
            code: 'ACCOUNT_INACTIVE',
            message: 'Your account is inactive. Please contact support.',
          ).toShelfResponse(statusCode: 403);
        }

        userName = employee.employeeName;
      } else {
        // Admin flow - Requires Phone Number Verification

        if (phoneNumber == null || phoneNumber.isEmpty) {
          return ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Phone number is required for Admin',
          ).toShelfResponse(statusCode: 400);
        }

        final admin = await adminRepository.getByEmail(email);
        if (admin == null) {
          return ApiResponse.error(
            code: 'ADMIN_NOT_FOUND',
            message: 'No admin account found with this email.',
          ).toShelfResponse(statusCode: 404);
        }

        // Verify phone number matches for Admin (Robust check)
        // Normalize: remove non-digits
        // Handle potential null in admin.adminPhoneNum just in case
        final storedPhone = admin.adminPhoneNum.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final inputPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

        // Check if stored phone ends with input phone (handles +91 vs no +91) or vice versa
        if (!storedPhone.endsWith(inputPhone) &&
            !inputPhone.endsWith(storedPhone)) {
          logger.warning(
            'Phone mismatch for admin: $email. Stored: ${admin.adminPhoneNum}, Input: $phoneNumber',
          );
          return ApiResponse.error(
            code: 'PHONE_MISMATCH',
            message: 'Phone number does not match our records.',
          ).toShelfResponse(statusCode: 400);
        }

        // Check if admin account is active
        if (admin.status != true) {
          return ApiResponse.error(
            code: 'ACCOUNT_INACTIVE',
            message: 'Your account is inactive. Please contact support.',
          ).toShelfResponse(statusCode: 403);
        }

        userName = admin.adminName;
      }

      final otp = await otpRepository.createOTPRecord(
        email: email,
        userType: userType,
        otpType: 'password_reset',
      );

      emailService
          .sendPasswordResetEmail(toEmail: email, userName: userName, otp: otp)
          .catchError((e, st) {
            logger.warning('Failed to send password reset OTP email: $e');
            return false;
          });

      logger.info('Password reset OTP send triggered for: $email');
      return ApiResponse.success(
        message: 'OTP has been sent to your email',
        data: {'email': email, 'userType': userType},
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleForgotPasswordRequest: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/forgot-password/verify
  /// Payload: { email, otp }
  /// Verifies OTP and checks 15-minute expiration
  /// POST /api/auth/forgot-password/verify
  /// Payload: { email, otp }
  /// Verifies OTP and checks 15-minute expiration
  Future<Response> handleForgotPasswordVerify(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final otp = data['otp']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (otp == null || otp.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'OTP is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info('Verifying password reset OTP for email: $email');

      // Verify OTP (15 min validity is handled in OTPHelperRepository)
      final result = await otpRepository.verifyOTP(email: email, otp: otp);

      if (result['success'] == true) {
        return ApiResponse.success(
          message: 'OTP verified successfully',
          data: {'email': email, 'verified': true},
        ).toShelfResponse();
      } else {
        return ApiResponse.error(
          code: result['reason'] ?? 'INVALID_OTP',
          message: result['message'] ?? 'Invalid OTP',
        ).toShelfResponse(statusCode: 400);
      }
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleForgotPasswordVerify: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/forgot-password/resend
  /// Payload: { email }
  /// Resends a new OTP
  /// POST /api/auth/forgot-password/resend
  /// Payload: { email }
  /// Resends a new OTP
  Future<Response> handleForgotPasswordResend(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      logger.info('Resending password reset OTP for: $email');

      // Determine user type and get name (try Employee first, then Admin)
      String? userName;
      String userType = 'Employee';

      final employee = await employeeRepository.getByEmail(email);
      if (employee != null) {
        userName = employee.employeeName;
        userType = 'Employee';
      } else {
        final admin = await adminRepository.getByEmail(email);
        if (admin != null) {
          userName = admin.adminName;
          userType = 'Admin';
        } else {
          return ApiResponse.error(
            code: 'USER_NOT_FOUND',
            message: 'User not found',
          ).toShelfResponse(statusCode: 404);
        }
      }

      final otp = await otpRepository.createOTPRecord(
        email: email,
        userType: userType,
        otpType: 'password_reset',
      );

      emailService
          .sendPasswordResetEmail(toEmail: email, userName: userName, otp: otp)
          .catchError((e, st) {
            logger.warning('Failed to send password reset OTP email: $e');
            return false;
          });

      logger.info('Password reset OTP resend triggered for: $email');
      return ApiResponse.success(
        message: 'New OTP has been sent to your email',
        data: {'email': email},
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleForgotPasswordResend: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/change-password
  /// Payload: { email, new_password }
  /// Optional: Authorization header with Bearer token (for settings screen)
  /// POST /api/auth/change-password
  /// Payload: { email, new_password, from_settings }
  /// If from_settings=true, requires Authorization header
  Future<Response> handleChangePassword(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final newPassword = data['new_password']?.toString();
      final isFromSettings = data['from_settings'] == true;

      if (email == null || email.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (newPassword == null || newPassword.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'New password is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (newPassword.length < 6) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Password must be at least 6 characters',
        ).toShelfResponse(statusCode: 400);
      }

      // Authentication check for settings flow
      if (isFromSettings) {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return ApiResponse.error(
            code: 'UNAUTHORIZED',
            message: 'Authorization token is required',
          ).toShelfResponse(statusCode: 401);
        }

        final token = authHeader.substring(7);
        final user = await service.verifyToken(token);
        if (user == null) {
          return ApiResponse.error(
            code: 'TOKEN_EXPIRED',
            message: 'Session expired. Please login again.',
          ).toShelfResponse(statusCode: 401);
        }

        // Verify the token belongs to the same user requesting password change
        if (user.email != email) {
          return ApiResponse.error(
            code: 'UNAUTHORIZED',
            message: 'You can only change your own password',
          ).toShelfResponse(statusCode: 403);
        }
      }

      logger.info(
        'Changing password for: $email (From Settings: $isFromSettings)',
      );

      // Note: We use the service which updates auth.users table directly
      // This works for both Admin and Employee as they share the auth.users table
      await service.changePassword(email, newPassword);

      if (!isFromSettings) {
        String userName = 'User';
        final employee = await employeeRepository.getByEmail(email);
        if (employee != null) {
          userName = employee.employeeName;
        } else {
          final admin = await adminRepository.getByEmail(email);
          if (admin != null) {
            userName = admin.adminName;
          }
        }
        final nameForEmail = userName;
        emailService
            .sendPasswordChangedEmail(toEmail: email, userName: nameForEmail)
            .catchError((e, st) {
              logger.warning('Failed to send password changed email: $e');
              return false;
            });
      }

      logger.info('Password changed successfully for: $email');
      return ApiResponse.success(
        message: 'Password changed successfully',
        data: {'email': email},
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleChangePassword: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ======== FCM TOKEN HANDLERS ========

  /// POST /api/auth/fcm-token
  /// Payload: { user_id, user_type, fcm_token, device_type?, device_name?, platform? }
  /// Saves or updates FCM token for push notifications
  Future<Response> handleUpdateFcmToken(Request request) async {
    try {
      // Check for Bearer token
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final userId = data['user_id']?.toString();
      final userType = data['user_type']?.toString();
      final fcmToken = data['fcm_token']?.toString();
      final deviceType = data['device_type']?.toString();
      final deviceName = data['device_name']?.toString();
      final platform = data['platform']?.toString();

      if (userId == null || userId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'User ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (userType == null || (userType != 'Admin' && userType != 'Employee')) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'User type must be Admin or Employee',
        ).toShelfResponse(statusCode: 400);
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'FCM token is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Save FCM token
      await fcmTokenRepository.saveToken(
        userId: userId,
        userType: userType,
        fcmToken: fcmToken,
        deviceType: deviceType,
        deviceName: deviceName,
        platform: platform,
      );

      logger.info('FCM token saved for $userType: $userId');
      return ApiResponse.success(
        message: 'FCM token saved successfully',
        data: {'user_id': userId, 'user_type': userType},
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleUpdateFcmToken: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/auth/fcm-token
  /// Payload: { fcm_token } or { user_id, user_type } for removing all tokens
  /// Removes FCM token on logout
  Future<Response> handleRemoveFcmToken(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final fcmToken = data['fcm_token']?.toString();
      final userId = data['user_id']?.toString();
      final userType = data['user_type']?.toString();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Remove specific token
        await fcmTokenRepository.removeToken(fcmToken);
        logger.info('FCM token removed');
        return ApiResponse.success(
          message: 'FCM token removed successfully',
        ).toShelfResponse();
      } else if (userId != null && userType != null) {
        // Remove all tokens for user
        await fcmTokenRepository.removeAllTokensForUser(userId, userType);
        logger.info('All FCM tokens removed for $userType: $userId');
        return ApiResponse.success(
          message: 'All FCM tokens removed successfully',
        ).toShelfResponse();
      } else {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message:
              'Either fcm_token or both user_id and user_type are required',
        ).toShelfResponse(statusCode: 400);
      }
    } catch (e, stackTrace) {
      logger.error('Error in handleRemoveFcmToken: $e', e, stackTrace);
      // Always return success for logout - token removal is not critical
      return ApiResponse.success(message: 'Logout processed').toShelfResponse();
    }
  }

  /// GET /api/auth/sessions
  /// Returns list of active sessions for the authenticated user
  Future<Response> handleGetSessions(Request request) async {
    try {
      // Check for Bearer token
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final sessions = await sessionRepository.getActiveSessions(
        user.employeeId,
        user.role,
      );

      return ApiResponse.success(
        message: 'Active sessions retrieved successfully',
        data: sessions,
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleGetSessions: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve sessions',
        details: {'error': e.toString()},
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/auth/sessions/<id>
  /// Revoke a specific session by its row ID
  Future<Response> handleRevokeSession(Request request, String id) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      // Check if session is main device
      final isMain = await sessionRepository.isMainDevice(id);
      if (isMain) {
        return ApiResponse.error(
          code: 'MAIN_DEVICE_LOGOUT_REQUIRES_OTP',
          message: 'OTP verification required to logout from the main device',
        ).toShelfResponse(statusCode: 403);
      }

      await sessionRepository.revokeSession(id);
      logger.info('Session $id revoked by user ${user.employeeId}');

      return ApiResponse.success(
        message: 'Session revoked successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleRevokeSession: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to revoke session',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/sessions/revoke-with-credentials
  /// Revoke a specific session by its row ID, providing credentials
  Future<Response> handleRevokeSessionWithCredentials(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email']?.toString();
      final password = data['password']?.toString();
      final role = data['role']?.toString() ?? 'Employee';
      final sessionId = data['session_id']?.toString();

      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty ||
          sessionId == null ||
          sessionId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Email, password, and session_id are required',
        ).toShelfResponse(statusCode: 400);
      }

      await service.revokeSessionWithCredentials(
        email: email,
        password: password,
        role: role,
        sessionId: sessionId,
      );

      return ApiResponse.success(
        message: 'Session revoked successfully',
      ).toShelfResponse();
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 401);
    } catch (e, stackTrace) {
      logger.error(
        'Error in handleRevokeSessionWithCredentials: $e',
        e,
        stackTrace,
      );
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to revoke session',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/auth/sessions/others
  /// Revoke all sessions except the current one
  Future<Response> handleRevokeAllOtherSessions(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      // Check if any of the other sessions is the main device
      final sessions = await sessionRepository.getActiveSessions(
        user.employeeId,
        user.role,
      );
      final otherIsMain = sessions.any(
        (s) => s['is_main_device'] == true && s['jwt_token'] != token,
      );

      if (otherIsMain) {
        return ApiResponse.error(
          code: 'MAIN_DEVICE_LOGOUT_REQUIRES_OTP',
          message:
              'OTP verification required to revoke the main device session',
        ).toShelfResponse(statusCode: 403);
      }

      await sessionRepository.revokeAllSessionsExcept(
        user.employeeId,
        user.role,
        token,
      );
      logger.info('All other sessions revoked for user ${user.employeeId}');

      return ApiResponse.success(
        message: 'All other sessions revoked successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleRevokeAllOtherSessions: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to revoke sessions',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/sessions/request-otp
  Future<Response> handleRequestSessionOTP(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final action = data['action']?.toString() ?? 'verify';

      // Get user name for email
      String userName = 'User';
      if (user.role == 'Admin') {
        final admin = await service.adminRepository.getByEmail(user.email);
        userName = admin?.adminName ?? 'Admin';
      } else {
        final employee = await service.employeeRepository.getByEmail(
          user.email,
        );
        userName = employee?.employeeName ?? 'Employee';
      }

      await service.sendSessionOTP(
        email: user.email,
        userName: userName,
        userType: user.role,
        action: action,
      );

      return ApiResponse.success(
        message: 'OTP sent to your registered email',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleRequestSessionOTP: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to send OTP',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/sessions/set-main
  Future<Response> handleSetMainDevice(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sessionId = data['session_id']?.toString();
      final otp = data['otp']?.toString();

      if (sessionId == null || otp == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'session_id and otp are required',
        ).toShelfResponse(statusCode: 400);
      }

      final isVaild = await service.verifySessionOTP(user.email, otp);
      if (!isVaild) {
        return ApiResponse.error(
          code: 'INVALID_OTP',
          message: 'Invalid or expired OTP',
        ).toShelfResponse(statusCode: 400);
      }

      await sessionRepository.setMainDevice(
        sessionId,
        user.employeeId,
        user.role,
      );

      return ApiResponse.success(
        message: 'Main device updated successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleSetMainDevice: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to set main device',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/auth/sessions/verify-main-logout
  Future<Response> handleVerifyMainLogout(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await service.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final otp = data['otp']?.toString();

      if (otp == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'otp is required',
        ).toShelfResponse(statusCode: 400);
      }

      final isVaild = await service.verifySessionOTP(user.email, otp);
      if (!isVaild) {
        return ApiResponse.error(
          code: 'INVALID_OTP',
          message: 'Invalid or expired OTP',
        ).toShelfResponse(statusCode: 400);
      }

      // Logout current session
      await service.logout(token);

      return ApiResponse.success(
        message: 'Logged out successfully from main device',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      logger.error('Error in handleVerifyMainLogout: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to logout',
      ).toShelfResponse(statusCode: 500);
    }
  }

}
