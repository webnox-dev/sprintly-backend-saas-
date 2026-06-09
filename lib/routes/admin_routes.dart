import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/email_service.dart';
import '../services/auth_service.dart';
import '../services/unified_notification_service.dart';
import '../core/utils/logger.dart';
import '../core/exceptions/app_exception.dart';
import '../core/rbac/rbac_constants.dart';
import '../core/middleware/tenant_middleware.dart';
import '../data/repositories/organization_repository.dart';

/// Admin routes for CRUD operations
class AdminRoutes {
  final Router _router = Router();
  final AdminRepository _adminRepository = AdminRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final UserRepository _userRepository = UserRepository();
  final OrganizationRepository _orgRepository = OrganizationRepository();
  final EmailService _emailService = EmailService();
  final AppLogger logger = AppLogger('AdminRoutes');

  Router get router {
    // GET /admins - Get all admins
    _router.get('/admins', _getAllAdmins);

    // POST /admins/get-by-id - Get admin by ID (POST method as requested)
    _router.post('/admins/get-by-id', _getAdminById);

    // POST /admins/getAdminDetailsById - Get detailed admin by ID
    _router.post('/admins/getAdminDetailsById', _getAdminDetailsById);

    // POST /admins - Add new admin
    _router.post('/admins', _addNewAdmin);

    // PUT /admins/updateAdminStatusById - Update admin status (active/inactive)
    // MUST be defined before /admins/<adminId> to avoid conflict
    _router.put('/admins/updateAdminStatusById', _updateAdminStatus);

    // PUT /admins/<adminId> - Update admin by ID
    _router.put('/admins/<adminId>', _updateAdminById);

    // DELETE /admins/<adminId> - Delete admin by ID
    _router.delete('/admins/<adminId>', _deleteAdminById);

    // POST /admins/<adminId>/resend-credentials - Resend credentials
    _router.post('/admins/<adminId>/resend-credentials', _resendAdminCredentials);

    // GET /admins/check-access - Check if admin has access to a specific permission
    _router.get('/admins/check-access', _checkAccess);

    return _router;
  }

  /// GET /admins/check-access - Check permission
  Future<Response> _checkAccess(Request request) async {
    try {
      final adminId = request.url.queryParameters['admin_id'];
      final permission = request.url.queryParameters['permission'];

      if (adminId == null || adminId.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Query parameter "admin_id" is required',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      if (permission == null || permission.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Query parameter "permission" is required',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Fetch admin
      final admin = await _adminRepository.getById(adminId);
      if (admin == null) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'Admin not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // Resolve permissions
      // Use roleType if available, fallback to role (designation)
      final effectiveRole =
          admin.roleType ?? admin.adminRole; // admin.adminRole is designation

      // Check access
      final hasAccess = RbacHelper.hasPermission(
        permission,
        effectiveRole,
        admin.accessPermissions,
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Access check completed',
          'data': {
            'admin_id': adminId,
            'permission': permission,
            'has_access': hasAccess,
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error checking access: $e', e, stackTrace);
      return _errorResponse('Failed to check access', e);
    }
  }

  /// GET /admins - Get all admins (supports ?search=query)
  Future<Response> _getAllAdmins(Request request) async {
    try {
      // Extract query params
      final search = request.url.queryParameters['search'];
      final statusParam = request.url.queryParameters['status'];
      final role = request.url.queryParameters['role'];
      final roleType = request.url.queryParameters['roleType'];
      final sortBy = request.url.queryParameters['sortBy'];
      final sortOrder = request.url.queryParameters['sortOrder'];

      bool? status;
      if (statusParam != null) {
        if (statusParam.toLowerCase() == 'active') status = true;
        if (statusParam.toLowerCase() == 'inactive') status = false;
      }

      logger.info(
        'Fetching users... Search: $search, Status: $status, Role: $role, RoleType: $roleType, Sort: $sortBy ($sortOrder)',
      );

      final admins = await _adminRepository.getAll(
        search: search,
        status: status,
        role: role,
        roleType: roleType,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Admins fetched successfully',
          'data': admins.map((a) => a.toJson()).toList(),
          'count': admins.length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error fetching admins: $e', e, stackTrace);
      return _errorResponse('Failed to fetch admins', e);
    }
  }

  /// POST /admins/get-by-id - Get admin by ID
  Future<Response> _getAdminById(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final adminId = data['adminId']?.toString();

      if (adminId == null || adminId.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Admin ID is required in the payload',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      logger.info('Fetching admin by ID: $adminId');

      final admin = await _adminRepository.getById(adminId);

      if (admin == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'No admin found with ID: $adminId',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Fetch plan features
      Map<String, dynamic>? planFeatures;
      if (admin.organizationId != null) {
        final org = await _orgRepository.getById(admin.organizationId!);
        if (org != null && org['plan_features'] != null) {
          try {
            planFeatures = jsonDecode(org['plan_features'] as String) as Map<String, dynamic>;
          } catch (_) {}
        }
      }

      final responseData = admin.toJson();
      if (planFeatures != null) {
        responseData['plan_features'] = planFeatures;
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Admin fetched successfully',
          'data': responseData,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error fetching admin by ID: $e', e, stackTrace);
      return _errorResponse('Failed to fetch admin', e);
    }
  }

  /// POST /admins/getAdminDetailsById - Get detailed admin by ID
  Future<Response> _getAdminDetailsById(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final adminId = data['adminId']?.toString();

      if (adminId == null || adminId.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Admin ID is required in the payload',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      logger.info('Fetching detailed admin by ID: $adminId');

      final admin = await _adminRepository.getById(adminId);

      if (admin == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'No admin found with ID: $adminId',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Fetch plan features
      Map<String, dynamic>? planFeatures;
      if (admin.organizationId != null) {
        final org = await _orgRepository.getById(admin.organizationId!);
        if (org != null && org['plan_features'] != null) {
          try {
            planFeatures = jsonDecode(org['plan_features'] as String) as Map<String, dynamic>;
          } catch (_) {}
        }
      }

      final responseData = admin.toJson();
      if (planFeatures != null) {
        responseData['plan_features'] = planFeatures;
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Admin details fetched successfully',
          'data': responseData,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error fetching admin details by ID: $e', e, stackTrace);
      return _errorResponse('Failed to fetch admin details', e);
    }
  }

  /// POST /admins - Add new admin
  Future<Response> _addNewAdmin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      logger.info('=== ADD NEW ADMIN ATTEMPT ===');
      logger.info('Admin Name: ${data['admin_name']}');
      logger.info('Admin Email: ${data['admin_personal_email']}');

      // Validate ONLY truly required fields
      final requiredFields = ['admin_id', 'admin_name', 'admin_personal_email'];

      for (final field in requiredFields) {
        if (data[field] == null || data[field].toString().trim().isEmpty) {
          return Response(
            400,
            body: jsonEncode({
              'success': false,
              'message': 'Field "$field" is required',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      }

      final email = data['admin_personal_email'].toString().trim();
      final adminId = data['admin_id'].toString().trim();
      final phone = data['admin_phone_num']?.toString().trim();

      // Get current organization context
      final orgId = getCurrentOrganizationId();
      
      // SaaS Plan Enforcements: check max_admins
      if (orgId != null && orgId.isNotEmpty) {
        final limits = await _orgRepository.getPlanLimits(orgId);
        if (limits != null) {
          final maxAdmins = limits['max_admins'] as int? ?? 2; // defaults to 2 if missing
          if (maxAdmins != -1) { // -1 means unlimited
            final activeCount = await _adminRepository.countActiveAdminsByOrg(orgId);
            if (activeCount >= maxAdmins) {
              return Response(
                403,
                body: jsonEncode({
                  'success': false,
                  'message': 'You have reached the maximum number of admins ($maxAdmins) allowed on your current plan. Please upgrade to add more.',
                  'error': {
                    'code': 'PLAN_LIMIT_EXCEEDED',
                    'message': 'Admin limit reached'
                  }
                }),
                headers: {'content-type': 'application/json'},
              );
            }
          }
        }
      }

      // Check if admin with same admin_id exists
      final existingById = await _adminRepository.getById(adminId);
      if (existingById != null) {
        return Response(
          409,
          body: jsonEncode({
            'success': false,
            'message':
                'Admin ID "$adminId" already exists. Please use a different Admin ID.',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Check if admin with same email exists
      final existingByEmail = await _adminRepository.getByEmail(email);
      if (existingByEmail != null) {
        return Response(
          409,
          body: jsonEncode({
            'success': false,
            'message':
                'Email "$email" is already registered with another admin.',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Check for existing employee with same ID, Email, or Phone
      logger.info('Checking for existing employee to link...');
      final empById = await _employeeRepository.getById(adminId);
      final empByEmail = await _employeeRepository.getByEmail(email);
      final empByPhone = (phone != null && phone.isNotEmpty)
          ? await _employeeRepository.getByPhone(phone)
          : null;

      final existingEmployee = empById ?? empByEmail ?? empByPhone;

      if (existingEmployee != null) {
        logger.info(
          'Existing employee found: ${existingEmployee.employeeId}. Linking as synchronized admin.',
        );

        // Inherit employee ID and profile data
        // Explicitly use employee_id as admin_id
        data['admin_id'] = existingEmployee.employeeId;
        data['admin_name'] = existingEmployee.employeeName;
        data['admin_personal_email'] = existingEmployee.employeePersonalEmail;
        data['admin_phone_num'] = existingEmployee.employeePhoneNum;
        data['admin_img'] = existingEmployee.employeeImg;

        // Create the admin record
        final newAdmin = await _adminRepository.create(data);

        // Ensure auth.users record exists and is correctly linked
        await _userRepository.ensureAuthUserExists(
          email: existingEmployee.employeePersonalEmail,
          employeeId: existingEmployee.employeeId,
          role: 'admin',
          createdBy: data['created_by']?.toString() ?? 'system',
          password: AuthService.generateRandomPassword(),
        );

        logger.info(
          'Synchronized Admin created successfully for employee: ${newAdmin.adminId}',
        );

        return Response(
          201,
          body: jsonEncode({
            'success': true,
            'message':
                'Existing employee found. Profiles linked successfully. Use your existing credentials to login as Admin.',
            'data': newAdmin.toJson(),
            'isLinked': true,
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Standard Admin creation flow (No matching employee found)
      final randomPassword = AuthService.generateRandomPassword();

      // Create admin
      final newAdmin = await _adminRepository.create(data);

      // Create brand new auth user
      await _userRepository.ensureAuthUserExists(
        email: email,
        employeeId: newAdmin.adminId,
        role: 'admin',
        createdBy: data['created_by']?.toString() ?? 'system',
        password: randomPassword,
      );

      // Send welcome email in background
      _sendWelcomeEmailBackground(data, randomPassword);

      logger.info('Standard Admin created successfully: ${newAdmin.adminId}');

      // Trigger notifications
      UnifiedNotificationService.notifyAdminCreated(
        adminId: newAdmin.adminId,
        adminName: newAdmin.adminName,
        adminEmail: newAdmin.adminPersonalEmail,
        createdBy: data['created_by']?.toString() ?? 'system',
      ).catchError((e, st) {
        logger.warning('Failed to send admin created notifications: $e');
      });

      return Response(
        201,
        body: jsonEncode({
          'success': true,
          'message': 'Admin created successfully. Welcome email sent.',
          'data': newAdmin.toJson(),
          'isLinked': false,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error adding new admin: $e', e, stackTrace);
      return _errorResponse('Failed to create admin', e);
    }
  }

  /// PUT /admins/<adminId> - Update admin by ID
  Future<Response> _updateAdminById(Request request, String adminId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      logger.info('Updating admin: $adminId');

      // Check if admin exists
      final existingAdmin = await _adminRepository.getById(adminId);
      if (existingAdmin == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'No admin found with ID: $adminId',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Update admin
      final updatedAdmin = await _adminRepository.update(adminId, data);

      logger.info('Admin updated successfully: $adminId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Admin updated successfully',
          'data': updatedAdmin.toJson(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error updating admin: $e', e, stackTrace);
      return _errorResponse('Failed to update admin', e);
    }
  }

  /// DELETE /admins/<adminId> - Delete admin by ID
  Future<Response> _deleteAdminById(Request request, String adminId) async {
    try {
      logger.info('Deleting admin: $adminId');

      // Check if admin exists
      final existingAdmin = await _adminRepository.getById(adminId);
      if (existingAdmin == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'No admin found with ID: $adminId',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Delete admin
      await _adminRepository.delete(adminId);

      // Also remove from auth users
      await _adminRepository.deleteAuthUser(existingAdmin.adminPersonalEmail);

      logger.info('Admin deleted successfully: $adminId');

      // Trigger notifications for admin deleted (background - do not block response)
      UnifiedNotificationService.notifyAdminDeleted(
        adminId: existingAdmin.adminId,
        adminName: existingAdmin.adminName,
        deletedBy: 'system', // Could be extracted from auth context
      ).catchError((e, st) {
        logger.warning('Failed to send admin deleted notifications: $e');
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Admin deleted successfully'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error deleting admin: $e', e, stackTrace);
      return _errorResponse('Failed to delete admin', e);
    }
  }

  /// PUT /admins/updateAdminStatusById - Update admin status
  Future<Response> _updateAdminStatus(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final adminId = data['admin_id'] as String?;
      final isActive = data['is_active'] as bool?;

      if (adminId == null || adminId.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Field "admin_id" (string) is required',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      if (isActive == null) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Field "is_active" (boolean) is required',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      logger.info('Updating admin status: $adminId -> isActive: $isActive');

      // Check if admin exists
      final existingAdmin = await _adminRepository.getById(adminId);
      if (existingAdmin == null) {
        return Response(
          404,
          body: jsonEncode({
            'success': false,
            'message': 'No admin found with ID: $adminId',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // Update status
      await _adminRepository.updateStatus(adminId, isActive);

      final changedBy = data['changed_by']?.toString() ?? 'system';
      // Trigger notifications in background - do not block response
      UnifiedNotificationService.notifyAdminStatusChanged(
        adminId: existingAdmin.adminId,
        adminName: existingAdmin.adminName,
        adminEmail: existingAdmin.adminPersonalEmail,
        adminRole: existingAdmin.adminRole,
        isActive: isActive,
        changedBy: changedBy,
      ).catchError((e, st) {
        logger.warning('Failed to send admin status change notifications: $e');
      });

      logger.info('Admin status updated successfully: $adminId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': isActive
              ? 'Admin activated successfully'
              : 'Admin deactivated successfully',
          'data': {'admin_id': adminId, 'is_active': isActive},
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error updating admin status: $e', e, stackTrace);
      return _errorResponse('Failed to update admin status', e);
    }
  }

  /// Generate welcome email HTML
  String _generateWelcomeEmail({
    required String name,
    required String email,
    required String role,
    required String password,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Welcome to Webnox Sprintly Admin</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { background: linear-gradient(135deg, #4F46E5, #7C3AED); padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; color: #222; }
        p { font-size: 15px; line-height: 1.7; margin: 0 0 16px 0; color: #4a4e57; }
        .info-box { margin: 20px 0; background: #e7f3ff; border-left: 4px solid #4F46E5; padding: 18px; border-radius: 10px; font-size: 14px; color: #004085; line-height: 1.6; }
        .signature { margin-top: 20px; font-size: 14px; color: #4a4e57; font-weight: 500; }
        .footer { margin-top: 40px; text-align: center; padding: 24px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; }
        .footer p { margin: 5px 0; font-size: 13px; color: #7a7e87; }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="header">
            <h1>Welcome to Webnox Sprintly Admin!</h1>
        </div>
        <div class="content">
            <div class="greeting">
                Hello <strong>$name</strong>,
            </div>
            <p>
                Welcome aboard! You have been added as an <strong>$role</strong> on the Webnox Sprintly Admin platform.
            </p>
            <div class="info-box">
                <strong>Your Login Credentials:</strong><br>
                Email: <strong>$email</strong><br>
                Password: <strong>$password</strong><br><br>
                <span style="color: #dc3545; font-weight: 500;">⚠️ Please change your password after your first login for security.</span>
            </div>
            <p>
                You can now access the admin dashboard to manage employees, projects, and more.
            </p>
            <div class="signature">
                Best regards,<br>
                <strong>Webnox Sprintly Admin Team</strong><br>
                Webnox Technologies Pvt Ltd
            </div>
        </div>
        <div class="footer">
            <p>This is an automated message. Please do not reply.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  /// Send welcome email in background
  Future<void> _sendWelcomeEmailBackground(Map<String, dynamic> data, String password) async {
    try {
      logger.info(
        'Sending welcome email (background) to: ${data['admin_personal_email']}',
      );
      final emailSent = await _emailService.sendEmail(
        toEmail: data['admin_personal_email'],
        subject: 'Welcome to Webnox Sprintly Admin',
        htmlContent: _generateWelcomeEmail(
          name: data['admin_name'],
          email: data['admin_personal_email'],
          role: data['admin_role'] ?? 'Admin',
          password: password,
        ),
      );
      if (emailSent) {
        logger.info(
          'Welcome email sent successfully to: ${data['admin_personal_email']}',
        );
      } else {
        logger.warning(
          'Failed to send welcome email to: ${data['admin_personal_email']} - Email service returned false',
        );
      }
    } catch (emailError, emailStack) {
      logger.error(
        'Error sending welcome email: $emailError',
        emailError,
        emailStack,
      );
    }
  }

  /// POST /admins/:adminId/resend-credentials
  Future<Response> _resendAdminCredentials(Request request, String adminId) async {
    try {
      final admin = await _adminRepository.getById(adminId);
      if (admin == null) {
        return Response(
          404,
          body: jsonEncode({'success': false, 'message': 'Admin not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final randomPassword = AuthService.generateRandomPassword();

      // Update password in auth.users
      final updated = await _userRepository.updatePassword(
        email: admin.adminPersonalEmail,
        newPassword: randomPassword,
        updatedBy: 'system',
      );

      if (!updated) {
        throw AppException(
          code: 'DATABASE_ERROR',
          message: 'Failed to update admin password in database.',
        );
      }

      // Send the email
      // We use the same background helper but await it for the API response
      final emailSent = await _emailService.sendEmail(
        toEmail: admin.adminPersonalEmail,
        subject: 'New Login Credentials - Webnox Sprintly Admin',
        htmlContent: _generateWelcomeEmail(
          name: admin.adminName,
          email: admin.adminPersonalEmail,
          role: admin.adminRole,
          password: randomPassword,
        ),
      );

      if (!emailSent) {
        throw AppException(
          code: 'EMAIL_ERROR',
          message: 'Failed to send credentials email.',
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Credentials resent successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.error('Error resending admin credentials: $e', e, stackTrace);
      return _errorResponse('Failed to resend credentials', e);
    }
  }

  /// Error response helper
  Response _errorResponse(String message, dynamic error) {
    int statusCode = 500;
    String? errorCode;
    Map<String, dynamic>? details;

    if (error is AppException) {
      statusCode = (error is NotFoundException)
          ? 404
          : (error is UnauthorizedException)
          ? 401
          : (error is ForbiddenException)
          ? 403
          : (error is ConflictException)
          ? 409
          : 400;
      errorCode = error.code;
      details = error.details;
    }

    return Response(
      statusCode,
      body: jsonEncode({
        'success': false,
        'message': message,
        'error': {
          'code': errorCode ?? 'SERVER_ERROR',
          'message': error.toString().replaceFirst('Exception: ', ''),
          if (details != null) 'details': details,
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  }
}
