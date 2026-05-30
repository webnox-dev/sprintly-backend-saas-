import '../../domain/models/employee.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/otp_helper_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/logger.dart';
import '../../data/database/connection.dart';
import 'email_service.dart';
import 'unified_notification_service.dart';

import 'auth_service.dart';
import '../core/middleware/tenant_middleware.dart';

/// Employee service for business logic
class EmployeeService {
  final EmployeeRepository _repository = EmployeeRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final UserRepository _userRepository = UserRepository();
  final OTPHelperRepository _otpRepository = OTPHelperRepository();
  final OrganizationRepository _orgRepository = OrganizationRepository();
  final EmailService _emailService = EmailService();
  final AppLogger _logger = AppLogger('EmployeeService');


  /// Get all employees with filters
  Future<Map<String, dynamic>> getAllEmployees({
    int page = 1,
    int limit = 50,
    bool? status,
    String? role,
    String? designation,
    String? search,
    String? sortBy,
    bool ascending = true,
  }) async {
    return await _repository.getAll(
      page: page,
      limit: limit,
      status: status,
      role: role,
      designation: designation,
      search: search,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Get employee by ID
  Future<Employee> getEmployeeById(String employeeId) async {
    final employee = await _repository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }
    return employee;
  }

  /// Create employee
  Future<Employee> createEmployee(
    Map<String, dynamic> data, {
    String? imageUrl,
  }) async {
    // Validate required fields
    final errors = <String, List<String>>{};

    if (data['employee_id'] == null || data['employee_id'].toString().isEmpty) {
      errors['employee_id'] = ['Employee ID is required'];
    } else {
      // Validate employee ID format
      final empId = data['employee_id'].toString().toUpperCase();
      if (!Validators.isValidEmployeeId(empId)) {
        errors['employee_id'] = [
          'Invalid employee ID format. Must be 2 uppercase letters followed by digits',
        ];
      }
      data['employee_id'] = empId;
    }

    if (data['employee_name'] == null ||
        data['employee_name'].toString().isEmpty) {
      errors['employee_name'] = ['Employee name is required'];
    }

    if (data['employee_personal_email'] == null ||
        data['employee_personal_email'].toString().isEmpty) {
      errors['employee_personal_email'] = ['Personal email is required'];
    } else if (!Validators.isValidEmail(
      data['employee_personal_email'].toString(),
    )) {
      errors['employee_personal_email'] = ['Invalid email format'];
    }

    if (data['employee_phone_num'] == null ||
        data['employee_phone_num'].toString().isEmpty) {
      errors['employee_phone_num'] = ['Phone number is required'];
    } else if (!Validators.isValidPhone(
      data['employee_phone_num'].toString(),
    )) {
      errors['employee_phone_num'] = ['Invalid phone number format'];
    }

    if (data['employee_dob'] == null ||
        data['employee_dob'].toString().isEmpty) {
      errors['employee_dob'] = ['Date of birth is required'];
    } else if (!Validators.isValidDateFormat(data['employee_dob'].toString())) {
      errors['employee_dob'] = ['Invalid date format. Use DD-MM-YYYY'];
    }

    if (data['employee_doj'] == null ||
        data['employee_doj'].toString().isEmpty) {
      errors['employee_doj'] = ['Date of joining is required'];
    } else if (!Validators.isValidDateFormat(data['employee_doj'].toString())) {
      errors['employee_doj'] = ['Invalid date format. Use DD-MM-YYYY'];
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }

    final empId = data['employee_id'].toString();
    final email = data['employee_personal_email'].toString();
    final phone = data['employee_phone_num'].toString();

    // Get current organization context
    final orgId = getCurrentOrganizationId();
    
    // SaaS Plan Enforcements: check max_employees
    if (orgId != null && orgId.isNotEmpty) {
      final limits = await _orgRepository.getPlanLimits(orgId);
      if (limits != null) {
        final maxEmployees = limits['max_employees'] as int? ?? 10; // defaults to 10 if missing
        if (maxEmployees != -1) { // -1 means unlimited
          final activeCount = await _repository.countActiveByOrg(orgId);
          if (activeCount >= maxEmployees) {
            throw AppException(
              code: 'PLAN_LIMIT_EXCEEDED',
              message: 'You have reached the maximum number of employees ($maxEmployees) allowed on your current plan. Please upgrade to add more.',
            );
          }
        }
      }
    }

    // Check if employee ID already exists
    final exists = await _repository.existsById(empId);
    if (exists) {
      throw ConflictException(resource: 'Employee', field: 'employee_id');
    }

    // Check if phone number already exists
    final phoneExists = await _repository.existsByPhone(phone);
    if (phoneExists) {
      throw ConflictException(
        resource: 'Employee',
        field: 'employee_phone_num',
      );
    }

    // Check for existing admin with same ID, Email, or Phone
    _logger.info('Checking for existing admin to link...');
    final adminById = await _adminRepository.getById(empId);
    final adminByEmail = await _adminRepository.getByEmail(email);
    final adminByPhone = await _adminRepository.getByPhone(phone);

    final existingAdmin = adminById ?? adminByEmail ?? adminByPhone;

    if (existingAdmin != null) {
      _logger.info(
        'Existing admin found: ${existingAdmin.adminId}. Linking as synchronized employee.',
      );

      // Inherit admin ID and profile data
      data['employee_id'] = existingAdmin.adminId;
      data['employee_name'] = existingAdmin.adminName;
      data['employee_personal_email'] = existingAdmin.adminPersonalEmail;
      data['employee_phone_num'] = existingAdmin.adminPhoneNum;
      data['employee_img'] = existingAdmin.adminImg;
    }

    // Calculate age from DOB
    if (data['employee_age'] == null) {
      data['employee_age'] = _calculateAge(data['employee_dob'].toString());
    }

    // Set image URL if provided
    if (imageUrl != null && imageUrl.isNotEmpty) {
      data['employee_img'] = imageUrl;
    } else {
      data['employee_img'] ??= '';
    }

    // Set defaults
    data['employee_company_email'] ??= data['employee_personal_email'];
    data['status'] ??= true;
    data['employee_actual_salary'] ??= 0.0;
    data['employee_total_leave_days_in_year'] ??= 0.0;
    data['employee_pending_leave_count'] ??= 0.0;

    // Create employee object
    final employee = Employee(
      employeeId: data['employee_id'].toString(),
      employeeUUID: data['employee_uuid']?.toString(),
      employeeName: data['employee_name'].toString(),
      employeeRole: data['employee_role']?.toString() ?? '',
      employeeImg: data['employee_img']?.toString() ?? '',
      employeePhoneNum: data['employee_phone_num'].toString(),
      employeeGender: data['employee_gender']?.toString() ?? '',
      employeePersonalEmail: data['employee_personal_email'].toString(),
      employeeCompanyEmail: data['employee_company_email']?.toString() ?? '',
      employeeAddress: data['employee_address']?.toString(),
      employeeDesignation: data['employee_designation']?.toString(),
      employeeQualification: data['employee_qualification']?.toString(),
      employeeSpecialization: data['employee_specialization']?.toString(),
      employeeDOB: data['employee_dob'].toString(),
      employeeAge: (data['employee_age'] as num?)?.toInt() ?? 0,
      employeeDOJ: data['employee_doj'].toString(),
      employeeBloodGroup: data['employee_blood_group']?.toString() ?? '',
      employeeEmergencyContactNumber:
          data['employee_emergency_contact_number']?.toString() ?? '',
      employeeActualSalary:
          (data['employee_actual_salary'] as num?)?.toDouble() ?? 0.0,
      employeeTotalLeaveDaysInYear:
          (data['employee_total_leave_days_in_year'] as num?)?.toDouble() ??
          0.0,
      employeePendingLeaveCount:
          (data['employee_pending_leave_count'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as bool? ?? true,
      organizationId: orgId,
    );

    final createdEmployee = await _repository.create(employee);

    // Ensure auth user exists and is correctly linked
    final newPassword = AuthService.generateRandomPassword();
    await _userRepository.ensureAuthUserExists(
      email: createdEmployee.employeePersonalEmail,
      employeeId: createdEmployee.employeeId,
      role: 'Employee',
      createdBy: 'system',
      password: newPassword,
      organizationId: orgId,
    );

    // Trigger welcome email (OTP + Email) in background if it's a new user (not linked)
    if (existingAdmin == null) {
      _handleWelcomeEmailBackground(createdEmployee, newPassword);
    }

    // Trigger notifications for employee created (background - do not block response)
    UnifiedNotificationService.notifyEmployeeCreated(
      employeeId: createdEmployee.employeeId,
      employeeName: createdEmployee.employeeName,
      employeeEmail: createdEmployee.employeeCompanyEmail.isNotEmpty
          ? createdEmployee.employeeCompanyEmail
          : createdEmployee.employeePersonalEmail,
      createdBy: 'system',
    ).catchError((e, st) {
      _logger.warning('Failed to send employee created notifications: $e');
    });

    return createdEmployee;
  }

  /// Update employee
  Future<Employee> updateEmployee(
    String employeeId,
    Map<String, dynamic> updates, {
    String? imageUrl,
  }) async {
    // Check if employee exists
    final existing = await _repository.getById(employeeId);
    if (existing == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    // Validate email if provided
    if (updates.containsKey('employee_personal_email')) {
      if (!Validators.isValidEmail(
        updates['employee_personal_email'].toString(),
      )) {
        throw ValidationException({
          'employee_personal_email': ['Invalid email format'],
        });
      }
    }

    // Validate phone if provided
    if (updates.containsKey('employee_phone_num')) {
      if (!Validators.isValidPhone(updates['employee_phone_num'].toString())) {
        throw ValidationException({
          'employee_phone_num': ['Invalid phone number format'],
        });
      }
    }

    // Validate date formats if provided
    if (updates.containsKey('employee_dob')) {
      if (!Validators.isValidDateFormat(updates['employee_dob'].toString())) {
        throw ValidationException({
          'employee_dob': ['Invalid date format. Use DD-MM-YYYY'],
        });
      }
      // Recalculate age
      updates['employee_age'] = _calculateAge(
        updates['employee_dob'].toString(),
      );
    }

    if (updates.containsKey('employee_doj')) {
      if (!Validators.isValidDateFormat(updates['employee_doj'].toString())) {
        throw ValidationException({
          'employee_doj': ['Invalid date format. Use DD-MM-YYYY'],
        });
      }
    }

    // Set image URL if provided
    if (imageUrl != null) {
      updates['employee_img'] = imageUrl;
    }

    return await _repository.update(employeeId, updates);
  }

  /// Delete employee
  Future<bool> deleteEmployee(String employeeId) async {
    final employee = await _repository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    // Delete from auth.users first
    await _repository.deleteAuthUser(employee.employeePersonalEmail);

    // Then delete employee
    final result = await _repository.delete(employeeId);

    // Trigger notifications for employee deleted (background - do not block response)
    UnifiedNotificationService.notifyEmployeeDeleted(
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      employeeEmail: employee.employeeCompanyEmail.isNotEmpty
          ? employee.employeeCompanyEmail
          : employee.employeePersonalEmail,
      deletedBy: 'system',
    ).catchError((e, st) {
      _logger.warning('Failed to send employee deleted notifications: $e');
    });

    return result;
  }

  /// Update employee status
  Future<Employee> updateStatus(
    String employeeId,
    bool status,
    String changedBy,
  ) async {
    // Get employee details before update
    final existingEmployee = await _repository.getById(employeeId);
    if (existingEmployee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    // Use repository's updateStatus which syncs with auth.users
    await _repository.updateStatus(employeeId, status);

    // Fetch and return updated employee
    final employee = await _repository.getById(employeeId);
    if (employee == null) {
      throw NotFoundException(resource: 'Employee', id: employeeId);
    }

    // Trigger notifications for employee status changed (background - do not block response)
    UnifiedNotificationService.notifyEmployeeStatusChanged(
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      employeeEmail: employee.employeeCompanyEmail.isNotEmpty
          ? employee.employeeCompanyEmail
          : employee.employeePersonalEmail,
      isActive: status,
      changedBy: changedBy,
    ).catchError((e, st) {
      _logger.warning('Failed to send employee status notifications: $e');
    });

    return employee;
  }

  /// Exit employee
  Future<Employee> exitEmployee(
    String employeeId,
    String doe,
    String exitReason,
    String exitedBy,
  ) async {
    // Validate exit reason is mandatory
    if (exitReason.trim().isEmpty) {
      throw ValidationException({
        'exit_reason': ['Exit reason is required'],
      });
    }

    // Use repository's exitEmployee which sets status=0 and syncs with auth.users
    return await _repository.exitEmployee(
      employeeId: employeeId,
      exitDate: doe,
      exitReason: exitReason,
      exitedBy: exitedBy,
    );
  }

  /// Re-enter employee
  Future<Employee> reenterEmployee(String employeeId, String changedBy) async {
    return await _repository.update(employeeId, {
      'status': true,
      'employee_doe': null,
      'reason_of_exit': null,
      'exited_by': null,
      'exited_at': null,
      'changed_by': changedBy,
      'changed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Resend credentials to employee email
  Future<void> resendCredentials(String employeeId) async {
    final employee = await getEmployeeById(employeeId);
    final randomPassword = AuthService.generateRandomPassword();

    // Update password in auth.users
    final updated = await _userRepository.updatePassword(
      email: employee.employeePersonalEmail,
      newPassword: randomPassword,
      updatedBy: 'system',
    );

    if (!updated) {
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to update user password in database.',
      );
    }

    // Send the email
    final emailSent = await _emailService.sendWelcomeEmail(
      toEmail: employee.employeePersonalEmail,
      userName: employee.employeeName,
      employeeId: employee.employeeId,
      otp: '', // No OTP needed for resend, just the new password
      defaultPassword: randomPassword,
    );

    if (!emailSent) {
      throw AppException(
        code: 'EMAIL_ERROR',
        message: 'Failed to send credentials email. Please try again.',
      );
    }
  }

  /// Get QA Analyst employees
  Future<List<Employee>> getQCEmployees() async {
    return await _repository.getByRole('QA Analyst');
  }

  /// Get employees with birthdays in month
  Future<List<Employee>> getBirthdaysInMonth(int? month) async {
    final targetMonth = month ?? DateTime.now().month;
    return await _repository.getBirthdaysInMonth(targetMonth);
  }

  /// Get employees with anniversaries today
  Future<List<Employee>> getAnniversariesToday() async {
    return await _repository.getAnniversariesToday();
  }

  /// Get employee overview for today
  Future<Map<String, dynamic>> getOverviewToday() async {
    try {
      final allEmployees = await _repository.getAllActive();
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD

      // Get employees who actually punched in today
      final attendanceSql = '''
        SELECT DISTINCT employee_id 
        FROM employee_attendance 
        WHERE work_date = @today
      ''';
      final attendanceResults = await DatabaseConnection.query(
        attendanceSql,
        values: {'today': todayStr},
      );
      final presentIds = attendanceResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet()
          .intersection(allEmployees.map((e) => e.employeeId).toSet());

      final leaveSql = '''
        SELECT DISTINCT employee_id 
        FROM leave_zone 
        WHERE leave_from_date <= @today 
        AND leave_to_date >= @today 
        AND leave_status = 1
      ''';
      final leaveResults = await DatabaseConnection.query(
        leaveSql,
        values: {'today': todayStr},
      );
      final onLeaveIds = leaveResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      final permissionSql = '''
        SELECT DISTINCT employee_id 
        FROM permissions 
        WHERE permission_date = @today 
        AND permission_status = 1
      ''';
      final permissionResults = await DatabaseConnection.query(
        permissionSql,
        values: {'today': todayStr},
      );
      final onPermissionIds = permissionResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      final wfhSql = '''
        SELECT DISTINCT employee_id 
        FROM work_from_home_requests 
        WHERE start_date <= @today 
        AND end_date >= @today 
        AND wfh_status = 1
      ''';
      final wfhResults = await DatabaseConnection.query(
        wfhSql,
        values: {'today': todayStr},
      );
      final wfhIds = wfhResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      final allAway = presentIds
          .union(onLeaveIds)
          .union(wfhIds)
          .union(onPermissionIds);
      final absentCount = allEmployees.length - allAway.length;

      return {
        'totalEmployees': allEmployees.length,
        'presentToday': presentIds.length,
        'onLeaveToday': onLeaveIds.length,
        'onPermissionToday': onPermissionIds.length,
        'workFromHomeToday': wfhIds.length,
        'absentToday': absentCount > 0 ? absentCount : 0,
        'onLeaveEmployeeIds': onLeaveIds.toList(),
        'onPermissionEmployeeIds': onPermissionIds.toList(),
        'wfhEmployeeIds': wfhIds.toList(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting overview: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get present employees
  Future<List<Map<String, dynamic>>> getPresentEmployees([String? date]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getPresentEmployees(targetDate);
  }

  /// Get absent employees
  Future<List<Map<String, dynamic>>> getAbsentEmployees([String? date]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getAbsentEmployees(targetDate);
  }

  /// Get WFH employees
  Future<List<Map<String, dynamic>>> getWFHEmployees([String? date]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getWFHEmployees(targetDate);
  }

  /// Get employees on permission
  Future<List<Map<String, dynamic>>> getPermissionEmployees([
    String? date,
  ]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getPermissionEmployees(targetDate);
  }

  /// Get late employees
  Future<List<Map<String, dynamic>>> getLateEmployees([String? date]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getLateEmployees(targetDate);
  }

  /// Get "No Status Today" employees
  Future<List<Employee>> getNoStatusEmployees([String? date]) async {
    final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
    return await _repository.getNoStatusEmployees(targetDate);
  }

  /// Calculate age from DOB (DD-MM-YYYY format)
  int _calculateAge(String dob) {
    try {
      final parts = dob.split('-');
      if (parts.length != 3) return 0;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birthDate = DateTime(year, month, day);
      final today = DateTime.now();

      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      return age;
    } catch (e) {
      _logger.warning('Error calculating age: $e');
      return 0;
    }
  }

  /// Handle welcome email sending in background
  Future<void> _handleWelcomeEmailBackground(
    Employee createdEmployee,
    String password,
  ) async {
    try {
      final otp = await _otpRepository.createOTPRecord(
        email: createdEmployee.employeePersonalEmail,
        userType: 'Employee',
        otpType: 'email_verification',
      );
      _logger.info(
        'OTP generated for new employee: ${createdEmployee.employeeId}',
      );

      // Send welcome email with OTP
      final emailSent = await _emailService.sendWelcomeEmail(
        toEmail: createdEmployee.employeePersonalEmail,
        userName: createdEmployee.employeeName,
        employeeId: createdEmployee.employeeId,
        otp: otp,
        defaultPassword: password,
      );

      if (emailSent) {
        _logger.info(
          'Welcome email sent to: ${createdEmployee.employeePersonalEmail}',
        );
      } else {
        _logger.warning(
          'Failed to send welcome email to: ${createdEmployee.employeePersonalEmail}',
        );
      }
    } catch (e) {
      _logger.error('Error sending welcome email (background): $e');
    }
  }
}
