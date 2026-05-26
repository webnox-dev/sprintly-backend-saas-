import '../../domain/models/leave.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';
import 'dart:convert';

/// Leave repository for database operations
/// Matches the exact schema of leave_zone table
class LeaveRepository {
  final AppLogger _logger = AppLogger('LeaveRepository');

  /// Get all leave records with pagination and filters
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
        conditions.add('l.employee_id = @empId$paramIndex');
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
          conditions.add('l.leave_status = @status$paramIndex');
          params['status$paramIndex'] = statusCode;
          paramIndex++;
        }
      }

      // Overlapping date logic: (start <= toDate AND end >= fromDate)
      // This ensures we get all leaves that are active within the chosen range
      if (fromDate != null && fromDate.isNotEmpty) {
        conditions.add('l.leave_to_date >= @fromDate$paramIndex::date');
        params['fromDate$paramIndex'] = fromDate;
        paramIndex++;
      }

      if (toDate != null && toDate.isNotEmpty) {
        conditions.add('l.leave_from_date <= @toDate$paramIndex::date');
        params['toDate$paramIndex'] = toDate;
        paramIndex++;
      }

      if (search != null && search.isNotEmpty) {
        conditions.add(
          '(e.employee_name ILIKE @search$paramIndex OR l.employee_id ILIKE @search$paramIndex OR e.employee_designation ILIKE @search$paramIndex)',
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
        'leave_from_date',
        'leave_to_date',
        'leave_status',
      ];
      
      String defaultSortColumn = 'created_at';
      if (fromDate != null && fromDate.endsWith('-01-01') && toDate != null && toDate.endsWith('-12-31')) {
        defaultSortColumn = 'leave_from_date';
      }

      final sortColumn = validSortColumns.contains(sortBy)
          ? sortBy
          : defaultSortColumn;
      final sortDirection = ascending ? 'ASC' : 'DESC';

      // Get total count
      final countQuery =
          '''
        SELECT COUNT(*) as total 
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        $whereClause
      ''';
      final countResult = await DatabaseConnection.queryOne(
        countQuery,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Get paginated data
      final dataQuery =
          '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image,
               CASE 
                 WHEN l.approved_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', appr.admin_id,
                     'name', appr.admin_name,
                     'role', appr.admin_role,
                     'designation', appr.admin_designation,
                     'profile_img', appr.admin_img
                   )
                 WHEN l.rejected_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', rejr.admin_id,
                     'name', rejr.admin_name,
                     'role', rejr.admin_role,
                     'designation', rejr.admin_designation,
                     'profile_img', rejr.admin_img
                   )
               END as approver_details
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        LEFT JOIN admins appr ON l.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON l.rejected_by = rejr.admin_id
        $whereClause
        ORDER BY l.$sortColumn $sortDirection
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(dataQuery, values: params);
      final leaves = results
          .map((row) => Leave.fromJson(row).toJson())
          .toList();

      return {
        'data': leaves,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all leaves', e, stackTrace);
      rethrow;
    }
  }

  /// Get leave by ID
  Future<Leave?> getById(String leaveId) async {
    try {
      final sql = '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image,
               CASE 
                 WHEN l.approved_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', appr.admin_id,
                     'name', appr.admin_name,
                     'role', appr.admin_role,
                     'designation', appr.admin_designation,
                     'profile_img', appr.admin_img
                   )
                 WHEN l.rejected_by IS NOT NULL THEN 
                   jsonb_build_object(
                     'id', rejr.admin_id,
                     'name', rejr.admin_name,
                     'role', rejr.admin_role,
                     'designation', rejr.admin_designation,
                     'profile_img', rejr.admin_img
                   )
               END as approver_details
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        LEFT JOIN admins appr ON l.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON l.rejected_by = rejr.admin_id
        WHERE l.leave_id = @id
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': leaveId},
      );

      if (result == null) return null;
      return Leave.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error getting leave by ID', e, stackTrace);
      rethrow;
    }
  }

  /// Get leaves by employee ID
  Future<List<Leave>> getByEmployeeId(String employeeId) async {
    try {
      final sql = '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE l.employee_id = @empId 
        ORDER BY l.created_at DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'empId': employeeId},
      );

      return results.map((row) => Leave.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting leaves by employee ID', e, stackTrace);
      rethrow;
    }
  }

  /// Create leave request - matches exact leave_zone schema
  Future<Leave> create({
    required String employeeId,
    String? leaveFromDate,
    String? leaveToDate,
    String? leaveRemarks,
    bool isPaidLeave = false,
    String? leaveApprovalRejectionRemarks,
    int? leaveStatus,
    String? leaveType,
    List<dynamic>? selectedDates,
    num? totalLeaveDays,
    bool isHalfDay = false,
    String? halfDayType,
  }) async {
    try {
      // Convert selectedDates list to JSON string if provided
      String? selectedDatesJson;
      if (selectedDates != null && selectedDates.isNotEmpty) {
        selectedDatesJson = jsonEncode(selectedDates);
      }

      final sql = '''
        INSERT INTO leave_zone (
          employee_id, 
          leave_from_date, 
          leave_to_date, 
          leave_remarks,
          is_paid_leave, 
          leave_approval_rejection_remarks,
          leave_status,
          leave_type, 
          selected_dates, 
          total_leave_days,
          is_half_day, 
          half_day_type
        ) VALUES (
          @employee_id, 
          @leave_from_date::date, 
          @leave_to_date::date, 
          @leave_remarks,
          @is_paid_leave, 
          @leave_approval_rejection_remarks,
          @leave_status,
          @leave_type, 
          @selected_dates::jsonb, 
          @total_leave_days,
          @is_half_day, 
          @half_day_type
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'employee_id': employeeId,
          'leave_from_date': leaveFromDate,
          'leave_to_date': leaveToDate,
          'leave_remarks': leaveRemarks,
          'is_paid_leave': isPaidLeave,
          'leave_approval_rejection_remarks': leaveApprovalRejectionRemarks,
          'leave_status': leaveStatus ?? 0, // default pending
          'leave_type': leaveType,
          'selected_dates': selectedDatesJson,
          'total_leave_days': totalLeaveDays ?? 0,
          'is_half_day': isHalfDay,
          'half_day_type': halfDayType,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to create leave request');
      }

      _logger.info('Leave request created for employee: $employeeId');
      // Ideally fetch full details here, but minimal is mostly fine for create response.
      // User asked for "fetching". So LIST is priority.
      return Leave.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating leave request', e, stackTrace);
      rethrow;
    }
  }

  /// Update leave request
  Future<Leave?> update(String leaveId, Map<String, dynamic> updates) async {
    try {
      if (updates.isEmpty) {
        return await getById(leaveId);
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE leave_zone
        SET $setClause
        WHERE leave_id = @id
        RETURNING *
      ''';

      updates['id'] = leaveId;
      final result = await DatabaseConnection.queryOne(sql, values: updates);

      if (result == null) return null;
      return Leave.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating leave request', e, stackTrace);
      rethrow;
    }
  }

  /// Approve leave request - uses exact schema fields
  Future<Leave?> approve({
    required String leaveId,
    required String approvedBy,
    String? leaveApprovalRejectionRemarks,
  }) async {
    try {
      final sql = '''
        UPDATE leave_zone
        SET leave_status = 1,
            approved_by = @approved_by,
            approved_at = NOW(),
            updated_at = NOW(),
            leave_approval_rejection_remarks = @remarks
        WHERE leave_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'approved_by': approvedBy,
          'remarks': leaveApprovalRejectionRemarks,
          'id': leaveId,
        },
      );

      if (result == null) return null;
      _logger.info('Leave request approved: $leaveId by $approvedBy');
      return Leave.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error approving leave request', e, stackTrace);
      rethrow;
    }
  }

  /// Reject leave request - uses exact schema fields
  Future<Leave?> reject({
    required String leaveId,
    required String rejectedBy,
    String? leaveApprovalRejectionRemarks,
  }) async {
    try {
      final sql = '''
        UPDATE leave_zone
        SET leave_status = 2,
            rejected_by = @rejected_by,
            rejected_at = NOW(),
            updated_at = NOW(),
            leave_approval_rejection_remarks = @remarks
        WHERE leave_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'rejected_by': rejectedBy,
          'remarks': leaveApprovalRejectionRemarks,
          'id': leaveId,
        },
      );

      if (result == null) return null;
      _logger.info('Leave request rejected: $leaveId by $rejectedBy');
      return Leave.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error rejecting leave request', e, stackTrace);
      rethrow;
    }
  }

  /// Delete leave request
  Future<bool> delete(String leaveId) async {
    try {
      final sql = 'DELETE FROM leave_zone WHERE leave_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': leaveId},
      );

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting leave request', e, stackTrace);
      rethrow;
    }
  }

  /// Get leave statistics for an employee
  Future<Map<String, dynamic>> getEmployeeStatistics(String employeeId) async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_requests,
          COALESCE(SUM(CASE WHEN leave_status = 0 THEN 1 ELSE 0 END), 0) as pending_count,
          COALESCE(SUM(CASE WHEN leave_status = 1 THEN 1 ELSE 0 END), 0) as approved_count,
          COALESCE(SUM(CASE WHEN leave_status = 2 THEN 1 ELSE 0 END), 0) as rejected_count,
          COALESCE(SUM(CASE WHEN leave_status = 1 THEN total_leave_days ELSE 0 END), 0) as total_approved_days
        FROM leave_zone
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
          'total_approved_days': 0,
        };
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error('Error getting leave statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Get pending leave requests (for admin)
  Future<List<Leave>> getPendingRequests() async {
    try {
      final sql = '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation, 
               e.employee_img as employee_profile_image
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE l.leave_status = 0
        ORDER BY l.created_at ASC
      ''';
      final results = await DatabaseConnection.query(sql);

      return results.map((row) => Leave.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting pending leave requests', e, stackTrace);
      rethrow;
    }
  }

  /// Get active leaves for a list of users on a specific date
  Future<List<Leave>> getActiveLeavesForUsers(
    List<String> userIds,
    String date,
  ) async {
    if (userIds.isEmpty) return [];

    try {
      final conditions = <String>[];
      final values = <String, dynamic>{'date': date};

      // Create placeholders for the IN clause
      for (var i = 0; i < userIds.length; i++) {
        conditions.add('@id$i');
        values['id$i'] = userIds[i];
      }

      final placeholders = conditions.join(', ');

      final sql =
          '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE l.employee_id IN ($placeholders)
          AND l.leave_status = 1 -- Approved
          AND @date::DATE BETWEEN l.leave_from_date AND l.leave_to_date
      ''';

      final results = await DatabaseConnection.query(sql, values: values);
      return results.map((row) => Leave.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting active leaves for users', e, stackTrace);
      rethrow;
    }
  }

  /// Get all active leaves for a specific date
  Future<List<Leave>> getAllActiveLeaves(String date) async {
    try {
      final sql = '''
        SELECT l.*, 
               e.employee_name, 
               e.employee_role, 
               e.employee_designation
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE l.leave_status = 1 -- Approved
          AND @date::DATE BETWEEN l.leave_from_date AND l.leave_to_date
      ''';

      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date},
      );
      return results.map((row) => Leave.fromJson(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting all active leaves', e, stackTrace);
      rethrow;
    }
  }
}
