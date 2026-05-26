import 'dart:convert';
import '../../domain/models/wfh_request.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// WFH (Work From Home) repository for database operations
class WFHRepository {
  final AppLogger _logger = AppLogger('WFHRepository');

  /// Get all WFH requests with pagination and filters
  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 20,
    int? status,
    String? requesterType,
    String? requesterId,
    String? fromDate,
    String? toDate,
    String? search,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final whereConditions = <String>[];
      final params = <String, dynamic>{};
      var paramIndex = 1;

      if (status != null) {
        whereConditions.add('w.wfh_status = @status$paramIndex');
        params['status$paramIndex'] = status;
        paramIndex++;
      }

      // Note: requester_type column might not exist in older databases
      // Commenting out this filter until database schema is updated
      // if (requesterType != null && requesterType.isNotEmpty) {
      //   whereConditions.add('w.requester_type = @requesterType$paramIndex');
      //   params['requesterType$paramIndex'] = requesterType;
      //   paramIndex++;
      // }

      if (requesterId != null && requesterId.isNotEmpty) {
        whereConditions.add('w.employee_id = @requesterId$paramIndex');
        params['requesterId$paramIndex'] = requesterId;
        paramIndex++;
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        whereConditions.add('w.end_date >= @fromDate$paramIndex::DATE');
        params['fromDate$paramIndex'] = fromDate;
        paramIndex++;
      }

      if (toDate != null && toDate.isNotEmpty) {
        whereConditions.add('w.start_date <= @toDate$paramIndex::DATE');
        params['toDate$paramIndex'] = toDate;
        paramIndex++;
      }

      if (search != null && search.isNotEmpty) {
        whereConditions.add('(e.employee_name ILIKE @search$paramIndex OR a.admin_name ILIKE @search$paramIndex OR w.employee_id ILIKE @search$paramIndex OR e.employee_designation ILIKE @search$paramIndex OR w.reason ILIKE @search$paramIndex)');
        params['search$paramIndex'] = '%$search%';
        paramIndex++;
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      var orderBy = 'w.created_at DESC';
      if (sortBy != null && sortBy.isNotEmpty) {
        final direction = ascending ? 'ASC' : 'DESC';
        final validColumns = [
          'start_date',
          'end_date',
          'total_days',
          'wfh_status',
          'created_at',
        ];
        if (validColumns.contains(sortBy)) {
          orderBy = 'w.$sortBy $direction';
        }
      } else if (fromDate != null && fromDate.endsWith('-01-01') && toDate != null && toDate.endsWith('-12-31')) {
        final direction = ascending ? 'ASC' : 'DESC';
        orderBy = 'w.start_date $direction';
      }

      // Get total count
      final countQuery = '''
        SELECT COUNT(*) as total 
        FROM work_from_home_requests w 
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        LEFT JOIN admins a ON w.employee_id = a.admin_id
        $whereClause
      ''';
      final countResult = await DatabaseConnection.queryOne(
        countQuery,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Add pagination params
      params['limit'] = limit;
      params['offset'] = offset;

      // Get paginated data with requester details
      // Note: Using COALESCE to handle cases where employee might be an admin
      final query =
          '''
        SELECT 
          w.*,
          COALESCE(
            CASE WHEN e.employee_id IS NOT NULL THEN 
              jsonb_build_object(
                'id', e.employee_id,
                'name', e.employee_name,
                'email', e.employee_personal_email,
                'img', e.employee_img,
                'role', e.employee_role,
                'designation', e.employee_designation
              )
            END,
            CASE WHEN a.admin_id IS NOT NULL THEN 
              jsonb_build_object(
                'id', a.admin_id,
                'name', a.admin_name,
                'email', a.admin_personal_email,
                'img', a.admin_img,
                'role', a.admin_role,
                'designation', a.admin_designation
              )
            END
          ) as requester_details,
          CASE 
            WHEN w.approved_by IS NOT NULL THEN 
              jsonb_build_object(
                'id', appr.admin_id,
                'name', appr.admin_name,
                'role', appr.admin_role,
                'designation', appr.admin_designation,
                'profile_img', appr.admin_img
              )
            WHEN w.rejected_by IS NOT NULL THEN 
              jsonb_build_object(
                'id', rejr.admin_id,
                'name', rejr.admin_name,
                'role', rejr.admin_role,
                'designation', rejr.admin_designation,
                'profile_img', rejr.admin_img
              )
            ELSE NULL
          END as admin_details
        FROM work_from_home_requests w
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        LEFT JOIN admins a ON w.employee_id = a.admin_id
        LEFT JOIN admins appr ON w.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON w.rejected_by = rejr.admin_id
        $whereClause
        ORDER BY $orderBy
        LIMIT @limit OFFSET @offset
      ''';

      final results = await DatabaseConnection.query(query, values: params);
      final wfhRequests = results
          .map((row) => WFHRequest.fromMap(_processRow(row)))
          .toList();

      return {
        'data': wfhRequests.map((w) => w.toJson()).toList(),
        'pagination': {
          'total': total,
          'page': page,
          'limit': limit,
          'totalPages': (total / limit).ceil(),
          'hasMore': page * limit < total,
        },
      };
    } catch (e, stack) {
      _logger.error('Failed to get WFH requests', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch WFH requests: $e',
      );
    }
  }

  /// Get WFH request by ID
  Future<WFHRequest?> getById(String wfhId) async {
    try {
      final query = '''
        SELECT 
          w.*,
          COALESCE(
            CASE WHEN e.employee_id IS NOT NULL THEN 
              jsonb_build_object(
                'id', e.employee_id,
                'name', e.employee_name,
                'email', e.employee_personal_email,
                'img', e.employee_img,
                'role', e.employee_role,
                'designation', e.employee_designation
              )
            END,
            CASE WHEN a.admin_id IS NOT NULL THEN 
              jsonb_build_object(
                'id', a.admin_id,
                'name', a.admin_name,
                'email', a.admin_personal_email,
                'img', a.admin_img,
                'role', a.admin_role,
                'designation', a.admin_designation
              )
            END
          ) as requester_details,
          CASE 
            WHEN w.approved_by IS NOT NULL THEN 
              jsonb_build_object(
                'id', appr.admin_id,
                'name', appr.admin_name,
                'role', appr.admin_role,
                'designation', appr.admin_designation,
                'profile_img', appr.admin_img
              )
            WHEN w.rejected_by IS NOT NULL THEN 
              jsonb_build_object(
                'id', rejr.admin_id,
                'name', rejr.admin_name,
                'role', rejr.admin_role,
                'designation', rejr.admin_designation,
                'profile_img', rejr.admin_img
              )
            ELSE NULL
          END as admin_details
        FROM work_from_home_requests w
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        LEFT JOIN admins a ON w.employee_id = a.admin_id
        LEFT JOIN admins appr ON w.approved_by = appr.admin_id
        LEFT JOIN admins rejr ON w.rejected_by = rejr.admin_id
        WHERE w.wfh_id = @id
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'id': wfhId},
      );
      if (result == null) return null;

      return WFHRequest.fromMap(_processRow(result));
    } catch (e, stack) {
      _logger.error('Failed to get WFH request by ID', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch WFH request: $e',
      );
    }
  }

  /// Create WFH request
  Future<WFHRequest> create(WFHRequest wfh) async {
    try {
      final insertMap = wfh.toInsertMap();
      final columns = insertMap.keys.toList();
      final placeholders = columns.map((k) => '@$k').join(', ');

      final query =
          '''
        INSERT INTO work_from_home_requests (${columns.join(', ')})
        VALUES ($placeholders)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: insertMap,
      );
      if (result == null) {
        throw AppException(
          code: 'CREATE_FAILED',
          message: 'Failed to create WFH request',
        );
      }

      return WFHRequest.fromMap(result);
    } catch (e, stack) {
      _logger.error('Failed to create WFH request', e, stack);
      if (e is AppException) rethrow;
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to create WFH request: $e',
      );
    }
  }

  /// Update WFH request
  Future<WFHRequest?> update(String wfhId, Map<String, dynamic> updates) async {
    try {
      if (updates.isEmpty) {
        return await getById(wfhId);
      }

      updates['updated_at'] = DateTime.now().toIso8601String();

      final setClauses = updates.keys.map((k) => '$k = @$k').join(', ');
      updates['id'] = wfhId;

      final query =
          '''
        UPDATE work_from_home_requests
        SET $setClauses
        WHERE wfh_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(query, values: updates);
      if (result == null) return null;

      return WFHRequest.fromMap(result);
    } catch (e, stack) {
      _logger.error('Failed to update WFH request', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to update WFH request: $e',
      );
    }
  }

  /// Delete WFH request
  Future<bool> delete(String wfhId) async {
    try {
      final query = 'DELETE FROM work_from_home_requests WHERE wfh_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        query,
        values: {'id': wfhId},
      );
      return affectedRows > 0;
    } catch (e, stack) {
      _logger.error('Failed to delete WFH request', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to delete WFH request: $e',
      );
    }
  }

  /// Approve WFH request
  Future<WFHRequest?> approve({
    required String wfhId,
    required String approvedBy,
    String? remarks,
  }) async {
    try {
      final query = '''
        UPDATE work_from_home_requests
        SET 
          wfh_status = 1,
          approved_by = @approvedBy,
          approved_at = CURRENT_TIMESTAMP,
          approval_rejection_remarks = @remarks,
          rejected_by = NULL,
          rejected_at = NULL,
          updated_at = CURRENT_TIMESTAMP
        WHERE wfh_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'id': wfhId, 'approvedBy': approvedBy, 'remarks': remarks},
      );
      if (result == null) return null;

      return WFHRequest.fromMap(result);
    } catch (e, stack) {
      _logger.error('Failed to approve WFH request', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to approve WFH request: $e',
      );
    }
  }

  /// Reject WFH request
  Future<WFHRequest?> reject({
    required String wfhId,
    required String rejectedBy,
    String? remarks,
  }) async {
    try {
      final query = '''
        UPDATE work_from_home_requests
        SET 
          wfh_status = 2,
          rejected_by = @rejectedBy,
          rejected_at = CURRENT_TIMESTAMP,
          approval_rejection_remarks = @remarks,
          approved_by = NULL,
          approved_at = NULL,
          updated_at = CURRENT_TIMESTAMP
        WHERE wfh_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        query,
        values: {'id': wfhId, 'rejectedBy': rejectedBy, 'remarks': remarks},
      );
      if (result == null) return null;

      return WFHRequest.fromMap(result);
    } catch (e, stack) {
      _logger.error('Failed to reject WFH request', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to reject WFH request: $e',
      );
    }
  }

  /// Get WFH requests for a specific employee
  Future<List<WFHRequest>> getByEmployeeId(String employeeId) async {
    try {
      final query = '''
        SELECT w.*
        FROM work_from_home_requests w
        WHERE w.employee_id = @employeeId
        ORDER BY w.created_at DESC
      ''';

      final results = await DatabaseConnection.query(
        query,
        values: {'employeeId': employeeId},
      );
      return results.map((row) => WFHRequest.fromMap(row)).toList();
    } catch (e, stack) {
      _logger.error('Failed to get WFH by requester', e, stack);
      throw AppException(
        code: 'DB_ERROR',
        message: 'Failed to fetch WFH by requester: $e',
      );
    }
  }

  /// Check if WFH request exists
  Future<bool> exists(String wfhId) async {
    try {
      final query =
          'SELECT 1 FROM work_from_home_requests WHERE wfh_id = @id LIMIT 1';
      final result = await DatabaseConnection.queryOne(
        query,
        values: {'id': wfhId},
      );
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Process row to handle JSONB fields
  Map<String, dynamic> _processRow(Map<String, dynamic> row) {
    final processed = Map<String, dynamic>.from(row);

    // Parse JSONB fields
    for (final key in [
      'requester_details',
      'approver_details',
      'rejecter_details',
    ]) {
      if (processed[key] is String) {
        try {
          processed[key] = jsonDecode(processed[key]);
        } catch (_) {}
      }
    }

    return processed;
  }
}
