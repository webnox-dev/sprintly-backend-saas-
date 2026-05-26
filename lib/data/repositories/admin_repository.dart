import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/models/admin.dart';
import 'package:postgres/postgres.dart';
import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// Admin repository for database operations
class AdminRepository {
  final AppLogger logger = AppLogger('AdminRepository');

  /// Get all admins
  Future<List<Admin>> getAll({
    String? search,
    bool? status,
    String? role,
    String? roleType,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      String sql = 'SELECT * FROM admins WHERE 1=1';
      Map<String, dynamic> values = {};

      if (search != null && search.isNotEmpty) {
        sql +=
            ' AND (admin_name ILIKE @search OR admin_personal_email ILIKE @search OR admin_id ILIKE @search)';
        values['search'] = '%$search%';
      }

      if (status != null) {
        sql += ' AND status = @status';
        values['status'] = status;
      }

      if (role != null && role.isNotEmpty && role != 'All') {
        sql += ' AND admin_role ILIKE @role';
        values['role'] = role;
      }

      if (roleType != null && roleType.isNotEmpty && roleType != 'All') {
        sql += ' AND role_type = @role_type';
        values['role_type'] = roleType;
      }

      String orderBy = 'created_at DESC';

      if (sortBy != null && sortBy.isNotEmpty) {
        final order = sortOrder?.toUpperCase() ?? 'ASC';
        switch (sortBy.toLowerCase()) {
          case 'name':
          case 'admin_name':
            orderBy = 'admin_name $order';
            break;
          case 'id':
          case 'admin_id':
            orderBy = 'admin_id $order';
            break;
          case 'role':
          case 'admin_role':
            orderBy = 'admin_role $order';
            break;
          case 'date':
          case 'created_at':
            orderBy = 'created_at $order';
            break;
        }
      }

      sql += ' ORDER BY $orderBy';

      final results = await DatabaseConnection.query(sql, values: values);
      return results.map((row) => Admin.fromMap(row)).toList();
    } catch (e, stackTrace) {
      logger.error('Error getting all admins: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to retrieve admins. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Get all memberships for an email (Multi-tenancy discovery)
  Future<List<Admin>> listByEmail(String email) async {
    try {
      final sql = 'SELECT * FROM admins WHERE admin_personal_email = @email OR admin_company_email = @email';
      final results = await DatabaseConnection.query(
        sql,
        values: {'email': email},
      );
      return results.map((row) => Admin.fromMap(row)).toList();
    } catch (e, stackTrace) {
      logger.error('Error listing admins by email: $e', e, stackTrace);
      return [];
    }
  }

  Future<Admin?> getByEmail(String email) async {
    try {
      final sql = 'SELECT * FROM admins WHERE admin_personal_email = @email';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email},
      );

      return result != null ? Admin.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting admin by email: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to retrieve admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Get admin by email and organization (Scoped login)
  Future<Admin?> getByEmailAndOrg(String email, String orgId) async {
    try {
      final sql = 'SELECT * FROM admins WHERE (admin_personal_email = @email OR admin_company_email = @email) AND organization_id = @orgId::uuid';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email, 'orgId': orgId},
      );
      return result != null ? Admin.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting admin by email and org: $e', e, stackTrace);
      return null;
    }
  }

  /// Get admin by ID
  Future<Admin?> getById(String adminId) async {
    try {
      final sql = 'SELECT * FROM admins WHERE admin_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': adminId},
      );

      return result != null ? Admin.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting admin by ID: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to retrieve admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Check if admin exists by ID
  Future<bool> existsById(String adminId) async {
    try {
      final sql = 'SELECT COUNT(*) as count FROM admins WHERE admin_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': adminId},
      );
      final count = result?['count'];
      if (count is num) {
        return count.toInt() > 0;
      }
      return false;
    } catch (e, stackTrace) {
      logger.error('Error checking admin existence: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Check if admin exists by phone
  Future<bool> existsByPhone(String phoneNumber) async {
    try {
      final sql =
          'SELECT COUNT(*) as count FROM admins WHERE admin_phone_num = @phone';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'phone': phoneNumber},
      );
      final count = result?['count'];
      if (count is num) {
        return count.toInt() > 0;
      }
      return false;
    } catch (e, stackTrace) {
      logger.error('Error checking admin phone existence: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get admin by phone number
  Future<Admin?> getByPhone(String phone) async {
    try {
      final sql = 'SELECT * FROM admins WHERE admin_phone_num = @phone';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'phone': phone},
      );

      return result != null ? Admin.fromMap(result) : null;
    } catch (e, stackTrace) {
      logger.error('Error getting admin by phone: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to retrieve admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  Future<Admin> create(Map<String, dynamic> data, {String? organizationId}) async {
    try {
      final sql = '''
        INSERT INTO admins (
          admin_id, admin_role, admin_img, admin_name, admin_phone_num,
          admin_gender, admin_personal_email, admin_company_email,
          admin_address, admin_designation, admin_qualification,
          admin_dob, admin_age, admin_doj, admin_blood_group,
          admin_emergency_contact_number, admin_actual_salary,
          admin_total_leave_days_in_year, admin_pending_leave_count,
          status, created_at, created_by, access_permissions, role_type,
          organization_id
        ) VALUES (
          @admin_id, @admin_role, @admin_img, @admin_name, @admin_phone_num,
          @admin_gender, @admin_personal_email, @admin_company_email,
          @admin_address, @admin_designation, @admin_qualification,
          @admin_dob, @admin_age, @admin_doj, @admin_blood_group,
          @admin_emergency_contact_number, @admin_actual_salary,
          @admin_total_leave_days_in_year, @admin_pending_leave_count,
          @status, @created_at, @created_by, @access_permissions, @role_type,
          @organization_id::uuid
        ) RETURNING *
      ''';

      final values = {
        'admin_id': data['admin_id'],
        'admin_role': data['admin_role'] ?? 'Admin',
        'admin_img': data['admin_img'] ?? '',
        'admin_name': data['admin_name'],
        'admin_phone_num': data['admin_phone_num'] ?? '',
        'admin_gender': data['admin_gender'] ?? '',
        'admin_personal_email': data['admin_personal_email'],
        'admin_company_email': data['admin_company_email'] ?? '',
        'admin_address': data['admin_address'],
        'admin_designation': data['admin_designation'],
        'admin_qualification': data['admin_qualification'],
        'admin_dob': data['admin_dob'],
        'admin_age': data['admin_age'],
        'admin_doj': data['admin_doj'],
        'admin_blood_group': data['admin_blood_group'] ?? '',
        'admin_emergency_contact_number':
            data['admin_emergency_contact_number'] ?? '',
        'admin_actual_salary': data['admin_actual_salary'] ?? 0.0,
        'admin_total_leave_days_in_year':
            data['admin_total_leave_days_in_year'] ?? 12.0,
        'admin_pending_leave_count': data['admin_pending_leave_count'] ?? 12.0,
        'status': data['status'] ?? 1,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': data['created_by'] ?? 'system',
        'access_permissions': data['access_permissions'] is List
            ? jsonEncode(data['access_permissions'])
            : data['access_permissions'],
        'role_type': data['role_type'] ?? 'Admin', // Default to Admin for admins
        'organization_id': organizationId ?? data['organization_id'],
      };

      final result = await DatabaseConnection.queryOne(
        sql, 
        values: values,
        isGlobal: organizationId != null || data['organization_id'] != null,
      );

      if (result == null) {
        throw AppException(
          code: 'INSERT_FAILED',
          message: 'Failed to create admin',
        );
      }

      return Admin.fromMap(result);
    } catch (e, stackTrace) {
      logger.error('Error creating admin: $e', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to create admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Update admin by ID
  Future<Admin> update(String adminId, Map<String, dynamic> data) async {
    try {
      if (data.isEmpty) {
        throw AppException(
          code: 'VALIDATION_ERROR',
          message: 'No fields to update',
        );
      }

      // Define valid fields that exist in the database
      final validFields = {
        'admin_id',
        'admin_role',
        'admin_img',
        'admin_cover_img',
        'admin_name',
        'admin_phone_num',
        'admin_gender',
        'admin_personal_email',
        'admin_company_email',
        'admin_address',
        'admin_designation',
        'admin_qualification',
        'admin_dob',
        'admin_age',
        'admin_doj',
        'admin_blood_group',
        'admin_emergency_contact_number',
        'admin_actual_salary',
        'admin_total_leave_days_in_year',
        'admin_pending_leave_count',
        'access_permissions',
        'role_type',
        'sidebar_config',
      };

      // Filter out invalid fields and build SET clause dynamically
      final filteredData = <String, dynamic>{};
      data.forEach((key, value) {
        if (validFields.contains(key)) {
          // Encode List values to JSON for JSONB columns
          if ((key == 'access_permissions' || key == 'sidebar_config') &&
              value is List) {
            filteredData[key] = jsonEncode(value);
          } else if (key == 'sidebar_config' && value is Map) {
            filteredData[key] = jsonEncode(value);
          } else {
            filteredData[key] = value;
          }
        } else if (key != 'updated_by') {
          logger.warning('Ignoring invalid field in admin update: $key');
        }
      });

      if (filteredData.isEmpty) {
        throw AppException(
          code: 'VALIDATION_ERROR',
          message: 'No valid fields to update',
        );
      }

      // Prepare sync for auth.users
      final authFieldsToUpdate = <String, dynamic>{};
      if (filteredData.containsKey('admin_personal_email')) {
        authFieldsToUpdate['email'] = filteredData['admin_personal_email'];
      } else if (filteredData.containsKey('admin_company_email')) {
        authFieldsToUpdate['email'] = filteredData['admin_company_email'];
      }

      if (filteredData.containsKey('admin_id')) {
        authFieldsToUpdate['employee_id'] = filteredData['admin_id'];
        authFieldsToUpdate['reference_id'] = filteredData['admin_id'];
      }
      if (filteredData.containsKey('role_type')) {
        authFieldsToUpdate['role'] =
            filteredData['role_type'].toString().toLowerCase();
      }

      // Use a transaction for both admins and auth.users updates
      final updatedAdmin = await DatabaseConnection.transaction((connection) async {
        // 1. Update admins table
        final setClauses = filteredData.keys
            .map((key) => '$key = @$key')
            .toList();
        setClauses.add('updated_at = @updated_at');
        setClauses.add('updated_by = @updated_by');

        final sql = '''
          UPDATE admins SET
            ${setClauses.join(', ')}
          WHERE admin_id = @old_admin_id
          RETURNING *
        ''';

        final result = await connection.execute(
          Sql.named(sql),
          parameters: {
            ...filteredData,
            'old_admin_id': adminId,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': data['updated_by'] ?? 'system',
          },
        );

        if (result.isEmpty) {
          throw AppException(
            code: 'UPDATE_FAILED',
            message: 'Admin with ID $adminId not found',
          );
        }

        // 2. Sync with auth.users if needed
        if (authFieldsToUpdate.isNotEmpty) {
          try {
            final authSetClauses = authFieldsToUpdate.keys
                .map((k) => '$k = @$k')
                .toList();
            final authValues = <String, dynamic>{'old_ref_id': adminId};
            authValues.addAll(authFieldsToUpdate);

            final authSql = '''
              UPDATE auth.users 
              SET ${authSetClauses.join(', ')}
              WHERE reference_id = @old_ref_id
            ''';
            
            await connection.execute(
              Sql.named(authSql),
              parameters: authValues,
            );
            logger.info('Synced update to auth.users for admin $adminId');
          } catch (e) {
            logger.warning('Failed to sync admin update to auth.users table: $e');
            // Fail transaction if critical sync (like admin_id change) fails
            if (filteredData.containsKey('admin_id')) {
              rethrow;
            }
          }
        }

        // Convert result to map
        final row = result.first;
        final Map<String, dynamic> rowMap = {};
        for (final column in result.schema.columns) {
          rowMap[column.columnName!] = row.toColumnMap()[column.columnName];
        }
        return rowMap;
      });

      return Admin.fromMap(updatedAdmin);
    } catch (e, stackTrace) {
      logger.error('Error updating admin: $e', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to update admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Delete admin by ID
  Future<void> delete(String adminId) async {
    try {
      final sql = 'DELETE FROM admins WHERE admin_id = @admin_id';
      await DatabaseConnection.execute(sql, values: {'admin_id': adminId});
    } catch (e, stackTrace) {
      logger.error('Error deleting admin: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to delete admin. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Update admin status (active/inactive)
  Future<void> updateStatus(String adminId, bool isActive) async {
    try {
      final sql = '''
        UPDATE admins SET 
          status = @status,
          changed_by = @changed_by,
          changed_at = @changed_at
        WHERE admin_id = @admin_id
      ''';

      final values = {
        'admin_id': adminId,
        'status': isActive ? 1 : 0,
        'changed_by': 'system',
        'changed_at': DateTime.now().toIso8601String(),
      };

      await DatabaseConnection.execute(sql, values: values);

      // Also update auth.users table
      final authSql = '''
        UPDATE auth.users SET 
          is_active = @is_active,
          updated_at = @changed_at,
          updated_by = @changed_by
        WHERE reference_id = @admin_id
      ''';

      final authValues = {
        'admin_id': adminId,
        'is_active': isActive ? 1 : 0,
        'changed_by': 'system',
        'changed_at': DateTime.now().toIso8601String(),
      };

      await DatabaseConnection.execute(authSql, values: authValues);
    } catch (e, stackTrace) {
      logger.error('Error updating admin status: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to update admin status. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Create auth user for admin
  Future<void> createAuthUser({
    required String email,
    required String name,
    required String role,
    required String referenceId,
    String defaultPassword = '123456',
  }) async {
    try {
      // Hash the default password using SHA256 (same as User.hashPassword)
      final passwordBytes = utf8.encode(defaultPassword);
      final passwordHash = sha256.convert(passwordBytes).toString();

      final sql = '''
        INSERT INTO auth.users (employee_id, email, encrypted_password, role, reference_id, is_active, created_at)
        VALUES (@employee_id, @email, @encrypted_password, @role, @reference_id, 1, @created_at)
        ON CONFLICT (email) DO UPDATE SET
          encrypted_password = COALESCE(auth.users.encrypted_password, @encrypted_password),
          role = @role,
          employee_id = @employee_id,
          reference_id = @reference_id,
          is_active = 1,
          updated_at = @created_at,
          updated_by = @created_by
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {
          'employee_id': referenceId,
          'email': email,
          'encrypted_password': passwordHash,
          'role': role,
          'reference_id': referenceId,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': 'System',
        },
      );

      logger.info(
        'Auth user created for admin: $referenceId with email: $email',
      );
    } catch (e, stackTrace) {
      logger.error('Error creating auth user: $e', e, stackTrace);
      // Don't throw - auth user creation is secondary
    }
  }

  /// Delete auth user
  Future<void> deleteAuthUser(String email) async {
    try {
      final sql = 'DELETE FROM auth.users WHERE email = @email';
      await DatabaseConnection.execute(sql, values: {'email': email});
    } catch (e, stackTrace) {
      logger.error('Error deleting auth user: $e', e, stackTrace);
      // Don't throw - auth user deletion is secondary
    }
  }

  /// Check if admin exists and is active
  Future<bool> isActive(String email) async {
    try {
      final sql = '''
        SELECT COUNT(*) as count 
        FROM admins 
        WHERE admin_personal_email = @email 
        AND status = true
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email},
      );
      final count = result?['count'];
      if (count is num) {
        return count.toInt() > 0;
      }
      return false;
    } catch (e, stackTrace) {
      logger.error('Error checking admin active status: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to check admin status. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }
}
