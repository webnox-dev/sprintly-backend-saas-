import '../../domain/models/permission.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// Permission repository for database operations
/// Matches exact database schema for permissions table
class PermissionRepository {
  final AppLogger _logger = AppLogger('PermissionRepository');

  /// Get all permission records with pagination and filters
  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 50,
    String? employeeId,
    String? status,
    String? fromDate,
    String? toDate,
    String? search,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final conditions = <String>[];
      final params = <String, dynamic>{};
      var paramIndex = 1;

      if (employeeId != null && employeeId.isNotEmpty) {
        conditions.add('p.employee_id = @empId$paramIndex');
        params['empId$paramIndex'] = employeeId;
        paramIndex++;
      }

      if (status != null && status.isNotEmpty) {
        int? statusCode = int.tryParse(status);
        if (statusCode == null) {
          switch (status.toLowerCase()) {
            case 'pending':
              statusCode = 0;
              break;
            case 'approved':
              statusCode = 1;
              break;
            case 'rejected':
              statusCode = 2;
              break;
          }
        }
        if (statusCode != null) {
          conditions.add('p.permission_status = @status$paramIndex');
          params['status$paramIndex'] = statusCode;
          paramIndex++;
        }
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        conditions.add('p.permission_date >= @fromDate$paramIndex::date');
        params['fromDate$paramIndex'] = fromDate;
        paramIndex++;
      }

      if (toDate != null && toDate.isNotEmpty) {
        conditions.add('p.permission_date <= @toDate$paramIndex::date');
        params['toDate$paramIndex'] = toDate;
        paramIndex++;
      }

      if (search != null && search.isNotEmpty) {
        conditions.add(
          '(e.employee_name ILIKE @search$paramIndex OR p.employee_id ILIKE @search$paramIndex OR e.employee_designation ILIKE @search$paramIndex)',
        );
        params['search$paramIndex'] = '%$search%';
        paramIndex++;
      }

      final whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(' AND ')}'
          : '';

      // Validate sort column
      const validSortColumns = [
        'created_at',
        'permission_date',
        'permission_status',
      ];
      
      String defaultSortColumn = 'created_at';
      if (fromDate != null && fromDate.endsWith('-01-01') && toDate != null && toDate.endsWith('-12-31')) {
        defaultSortColumn = 'permission_date';
      }

      final sortColumn = validSortColumns.contains(sortBy)
          ? sortBy
          : defaultSortColumn;
      final sortDirection = ascending ? 'ASC' : 'DESC';

      // Get total count
      final countQuery =
          '''
        SELECT COUNT(*) as total 
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        $whereClause
      ''';
      final countResult = await DatabaseConnection.queryOne(
        countQuery,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Get paginated data with requester details
      final dataQuery =
          '''
        SELECT p.permission_id, 
               p.employee_id, 
               p.requester_type, 
               p.permission_date, 
               p.permission_from_time::text, 
               p.permission_to_time::text, 
               p.permission_status, 
               p.permission_remarks, 
               p.permission_approval_rejection_remarks, 
               p.approved_by, 
               p.rejected_by, 
               p.approved_at, 
               p.rejected_at, 
               p.created_by, 
               p.created_at, 
               p.updated_by, 
               p.updated_at,
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image,
               CASE WHEN e.employee_id IS NOT NULL THEN 
                 jsonb_build_object(
                   'id', e.employee_id,
                   'name', e.employee_name,
                   'email', e.employee_personal_email,
                   'img', e.employee_img,
                   'role', e.employee_role,
                   'designation', e.employee_designation
                 )
               END as requester_details,
               CASE 
                 WHEN p.approved_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', appr.admin_id,
                     'name', appr.admin_name,
                     'role', appr.admin_role,
                     'designation', appr.admin_designation,
                     'profile_img', appr.admin_img
                   )
                 WHEN p.rejected_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', rejr.admin_id,
                     'name', rejr.admin_name,
                     'role', rejr.admin_role,
                     'designation', rejr.admin_designation,
                     'profile_img', rejr.admin_img
                   )
               END as approver_details
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        LEFT JOIN admins appr ON p.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON p.rejected_by = rejr.admin_id
        $whereClause
        ORDER BY p.$sortColumn $sortDirection
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(dataQuery, values: params);
      final permissions = results
          .map((row) => Permission.fromJson(row).toJson())
          .toList();

      return {
        'data': permissions,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all permissions', e, stackTrace);
      rethrow;
    }
  }

  /// Get permission by ID
  Future<Permission?> getById(String permissionId) async {
    try {
      final sql = '''
        SELECT p.permission_id, 
               p.employee_id, 
               p.requester_type, 
               p.permission_date, 
               p.permission_from_time::text, 
               p.permission_to_time::text, 
               p.permission_status, 
               p.permission_remarks, 
               p.permission_approval_rejection_remarks, 
               p.approved_by, 
               p.rejected_by, 
               p.approved_at, 
               p.rejected_at, 
               p.created_by, 
               p.created_at, 
               p.updated_by, 
               p.updated_at,
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image,
               CASE WHEN e.employee_id IS NOT NULL THEN 
                 jsonb_build_object(
                   'id', e.employee_id,
                   'name', e.employee_name,
                   'email', e.employee_personal_email,
                   'img', e.employee_img,
                   'role', e.employee_role,
                   'designation', e.employee_designation
                 )
               END as requester_details,
               CASE 
                 WHEN p.approved_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', appr.admin_id,
                     'name', appr.admin_name,
                     'role', appr.admin_role,
                     'designation', appr.admin_designation,
                     'profile_img', appr.admin_img
                   )
                 WHEN p.rejected_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', rejr.admin_id,
                     'name', rejr.admin_name,
                     'role', rejr.admin_role,
                     'designation', rejr.admin_designation,
                     'profile_img', rejr.admin_img
                   )
               END as approver_details
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        LEFT JOIN admins appr ON p.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON p.rejected_by = rejr.admin_id
        WHERE p.permission_id = @id
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': permissionId},
      );

      if (result == null) return null;
      return Permission.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting permission by ID', e, stackTrace);
      rethrow;
    }
  }

  /// Get permissions by employee ID
  Future<List<Permission>> getByEmployeeId(String employeeId) async {
    try {
      final sql = '''
        SELECT p.permission_id, 
               p.employee_id, 
               p.requester_type, 
               p.permission_date, 
               p.permission_from_time::text, 
               p.permission_to_time::text, 
               p.permission_status, 
               p.permission_remarks, 
               p.permission_approval_rejection_remarks, 
               p.approved_by, 
               p.rejected_by, 
               p.approved_at, 
               p.rejected_at, 
               p.created_by, 
               p.created_at, 
               p.updated_by, 
               p.updated_at,
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.employee_id = @empId 
        ORDER BY p.created_at DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'empId': employeeId},
      );

      return results.map((row) => Permission.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting permissions by employee ID', e, stackTrace);
      rethrow;
    }
  }

  /// Create permission request - matches exact schema
  Future<Permission> create({
    required String employeeId,
    required String permissionDate,
    required String permissionFromTime,
    required String permissionToTime,
    String requesterType = 'Employee',
    int permissionStatus = 0,
    String? permissionRemarks,
    String? createdBy,
  }) async {
    try {
      final sql = '''
        INSERT INTO permissions (
          employee_id, 
          requester_type,
          permission_date, 
          permission_from_time, 
          permission_to_time, 
          permission_status,
          permission_remarks,
          created_by
        ) VALUES (
          @employee_id, 
          @requester_type,
          @permission_date::date, 
          @permission_from_time::time, 
          @permission_to_time::time, 
          @permission_status,
          @permission_remarks,
          @created_by
        )
        RETURNING permission_id, employee_id, requester_type, permission_date, 
                  permission_from_time::text, permission_to_time::text, 
                  permission_status, permission_remarks, permission_approval_rejection_remarks, 
                  approved_by, rejected_by, approved_at, rejected_at, 
                  created_by, created_at, updated_by, updated_at
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'employee_id': employeeId,
          'requester_type': requesterType,
          'permission_date': permissionDate,
          'permission_from_time': permissionFromTime,
          'permission_to_time': permissionToTime,
          'permission_status': permissionStatus,
          'permission_remarks': permissionRemarks,
          'created_by': createdBy ?? employeeId,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to create permission request');
      }

      _logger.info('Permission request created for employee: $employeeId');
      return Permission.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating permission request', e, stackTrace);
      rethrow;
    }
  }

  /// Update permission request
  Future<Permission?> update(
    String permissionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (updates.isEmpty) {
        return await getById(permissionId);
      }

      updates['updated_at'] = 'NOW()';
      final setClause = updates.keys
          .map((k) {
            if (k == 'updated_at') return '$k = NOW()';
            return '$k = @$k';
          })
          .join(', ');

      final sql =
          '''
        UPDATE permissions
        SET $setClause
        WHERE permission_id = @id
        RETURNING permission_id, employee_id, requester_type, permission_date, 
                  permission_from_time::text, permission_to_time::text, 
                  permission_status, permission_remarks, permission_approval_rejection_remarks, 
                  approved_by, rejected_by, approved_at, rejected_at, 
                  created_by, created_at, updated_by, updated_at
      ''';

      updates.remove('updated_at');
      updates['id'] = permissionId;
      final result = await DatabaseConnection.queryOne(sql, values: updates);

      if (result == null) return null;
      return Permission.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating permission request', e, stackTrace);
      rethrow;
    }
  }

  /// Approve permission request - uses exact schema fields
  Future<Permission?> approve({
    required String permissionId,
    required String approvedBy,
    String? permissionApprovalRejectionRemarks,
  }) async {
    try {
      final sql = '''
        UPDATE permissions
        SET permission_status = 1,
            approved_by = @approved_by,
            approved_at = NOW(),
            permission_approval_rejection_remarks = @remarks,
            updated_at = NOW()
        WHERE permission_id = @id
        RETURNING permission_id, employee_id, requester_type, permission_date, 
                  permission_from_time::text, permission_to_time::text, 
                  permission_status, permission_remarks, permission_approval_rejection_remarks, 
                  approved_by, rejected_by, approved_at, rejected_at, 
                  created_by, created_at, updated_by, updated_at
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'approved_by': approvedBy,
          'remarks': permissionApprovalRejectionRemarks,
          'id': permissionId,
        },
      );

      if (result == null) return null;
      _logger.info('Permission request approved: $permissionId by $approvedBy');
      return Permission.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error approving permission request', e, stackTrace);
      rethrow;
    }
  }

  /// Reject permission request - uses exact schema fields
  Future<Permission?> reject({
    required String permissionId,
    required String rejectedBy,
    String? permissionApprovalRejectionRemarks,
  }) async {
    try {
      final sql = '''
        UPDATE permissions
        SET permission_status = 2,
            rejected_by = @rejected_by,
            rejected_at = NOW(),
            permission_approval_rejection_remarks = @remarks,
            updated_at = NOW()
        WHERE permission_id = @id
        RETURNING permission_id, employee_id, requester_type, permission_date, 
                  permission_from_time::text, permission_to_time::text, 
                  permission_status, permission_remarks, permission_approval_rejection_remarks, 
                  approved_by, rejected_by, approved_at, rejected_at, 
                  created_by, created_at, updated_by, updated_at
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'rejected_by': rejectedBy,
          'remarks': permissionApprovalRejectionRemarks,
          'id': permissionId,
        },
      );

      if (result == null) return null;
      _logger.info('Permission request rejected: $permissionId by $rejectedBy');
      return Permission.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error rejecting permission request', e, stackTrace);
      rethrow;
    }
  }

  /// Delete permission request
  Future<bool> delete(String permissionId) async {
    try {
      final sql = 'DELETE FROM permissions WHERE permission_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': permissionId},
      );

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting permission request', e, stackTrace);
      rethrow;
    }
  }

  /// Get permission statistics for an employee
  Future<Map<String, dynamic>> getEmployeeStatistics(String employeeId) async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_requests,
          COALESCE(SUM(CASE WHEN permission_status = 0 THEN 1 ELSE 0 END), 0) as pending_count,
          COALESCE(SUM(CASE WHEN permission_status = 1 THEN 1 ELSE 0 END), 0) as approved_count,
          COALESCE(SUM(CASE WHEN permission_status = 2 THEN 1 ELSE 0 END), 0) as rejected_count
        FROM permissions
        WHERE employee_id = @empId
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'empId': employeeId},
      );

      if (result == null) {
        return {
          'total_requests': 0,
          'pending_count': 0,
          'approved_count': 0,
          'rejected_count': 0,
        };
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error getting permission statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Get pending permission requests (for admin)
  Future<List<Permission>> getPendingRequests() async {
    try {
      final sql = '''
        SELECT p.permission_id, 
               p.employee_id, 
               p.requester_type, 
               p.permission_date, 
               p.permission_from_time::text, 
               p.permission_to_time::text, 
               p.permission_status, 
               p.permission_remarks, 
               p.permission_approval_rejection_remarks, 
               p.approved_by, 
               p.rejected_by, 
               p.approved_at, 
               p.rejected_at, 
               p.created_by, 
               p.created_at, 
               p.updated_by, 
               p.updated_at,
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.permission_status = 0
        ORDER BY p.created_at ASC
      ''';
      final results = await DatabaseConnection.query(sql);

      return results.map((row) => Permission.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting pending permission requests', e, stackTrace);
      rethrow;
    }
  }
}
