import 'dart:convert';
import '../../domain/models/task_card_request.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// TaskCardRequest repository for handling task card request flow
class TaskCardRequestRepository {
  final AppLogger _logger = AppLogger('TaskCardRequestRepository');

  // ==========================================
  // ADMIN - TASK CARD REQUEST OPERATIONS
  // ==========================================

  /// Get all pending task card requests (Admin)
  /// GET /admin/task-card-requests
  Future<Map<String, dynamic>> getAllTaskCardRequests({
    int page = 1,
    int limit = 50,
    String? status,
    String? employeeId,
    String? projectId,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var whereConditions = <String>[];
      final params = <String, dynamic>{};

      if (status != null && status.isNotEmpty) {
        whereConditions.add('tcr.request_status = @status');
        params['status'] = status;
      }

      if (employeeId != null && employeeId.isNotEmpty) {
        whereConditions.add('tcr.employee_id = @employeeId');
        params['employeeId'] = employeeId;
      }

      if (projectId != null && projectId.isNotEmpty) {
        whereConditions.add('tcr.project_id = @projectId');
        params['projectId'] = projectId;
      }

      if (search != null && search.isNotEmpty) {
        whereConditions.add(
          '(tcr.task_name ILIKE @search OR p.project_name ILIKE @search OR e.employee_name ILIKE @search)',
        );
        params['search'] = '%$search%';
      }

      if (fromDate != null) {
        whereConditions.add('tcr.requested_on >= @fromDate');
        params['fromDate'] = fromDate.toIso8601String();
      }

      if (toDate != null) {
        whereConditions.add('tcr.requested_on <= @toDate');
        params['toDate'] = toDate.toIso8601String();
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      // Count query
      // Count query
      final countSql =
          '''
        SELECT COUNT(*) as total 
        FROM task_card_requests tcr 
        LEFT JOIN employees e ON tcr.employee_id = e.employee_id
        LEFT JOIN projects p ON tcr.project_id = p.project_id
        $whereClause
      ''';
      _logger.info('Executing count query: $countSql with params: $params');

      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;
      _logger.info('Total count: $total');

      // Data query with JOINs to employees and projects tables
      final sql =
          '''
        SELECT 
          tcr.request_id,
          tcr.task_id,
          tcr.employee_id,
          tcr.project_id,
          tcr.task_name,
          tcr.task_description,
          tcr.task_duration,
          tcr.task_type,
          tcr.priority_level,
          tcr.workflow_status,
          tcr.from_date,
          tcr.to_date,
          tcr.task_attachments,
          tcr.requested_by,
          tcr.requested_on,
          tcr.approved_rejected_by,
          tcr.approved_rejected_at,
          tcr.approved_rejected_reason,
          tcr.request_status,
          tcr.created_at,
          tcr.updated_at,
          -- Build employee_details JSON using employees table
          CASE 
            WHEN e.employee_id IS NOT NULL THEN
              jsonb_build_object(
                'employee_id', e.employee_id,
                'name', e.employee_name,
                'role', e.employee_role,
                'designation', e.employee_designation,
                'email', COALESCE(e.employee_company_email, e.employee_personal_email),
                'profile_img', e.employee_img
              )
            ELSE NULL
          END as employee_details,
          -- Build project_details JSON using projects table
          CASE 
            WHEN p.project_id IS NOT NULL THEN
              jsonb_build_object(
                'project_id', p.project_id,
                'project_name', p.project_name,
                'project_status', p.project_status,
                'handled_by_bde_ids', p.project_followed_by_bde_employee_ids,
                'project_manager_details', CASE 
                  WHEN COALESCE(pm_admin.admin_id, pm_emp.employee_id) IS NOT NULL THEN jsonb_build_object(
                    'id', COALESCE(pm_admin.admin_id, pm_emp.employee_id),
                    'name', COALESCE(pm_admin.admin_name, pm_emp.employee_name),
                    'role', COALESCE(pm_admin.admin_role, pm_emp.employee_role),
                    'designation', COALESCE(pm_admin.admin_designation, pm_emp.employee_designation),
                    'profile_image', COALESCE(pm_admin.admin_img, pm_emp.employee_img)
                  )
                  ELSE NULL
                END,
                'team_leader_details', CASE 
                  WHEN tl.employee_id IS NOT NULL THEN jsonb_build_object(
                    'id', tl.employee_id,
                    'name', tl.employee_name,
                    'role', tl.employee_role,
                    'designation', tl.employee_designation,
                    'profile_image', tl.employee_img
                  )
                  ELSE NULL
                END
              )
            ELSE NULL
          END as project_details,
          -- Build approver_details JSON using employees table (aliased as approver)
          CASE 
            WHEN approver.employee_id IS NOT NULL THEN
              jsonb_build_object(
                'employee_id', approver.employee_id,
                'name', approver.employee_name,
                'role', approver.employee_role,
                'designation', approver.employee_designation,
                'email', COALESCE(approver.employee_company_email, approver.employee_personal_email),
                'profile_img', approver.employee_img
              )
            ELSE NULL
          END as approver_details
        FROM task_card_requests tcr
        LEFT JOIN employees e ON tcr.employee_id = e.employee_id
        LEFT JOIN projects p ON tcr.project_id = p.project_id
        LEFT JOIN admins pm_admin ON p.project_manager_id = pm_admin.admin_id
        LEFT JOIN employees pm_emp ON p.project_manager_id = pm_emp.employee_id AND pm_admin.admin_id IS NULL
        LEFT JOIN employees tl ON p.project_team_leader_id = tl.employee_id
        LEFT JOIN employees approver ON tcr.approved_rejected_by = approver.employee_id
        $whereClause 
        ORDER BY tcr.requested_on DESC 
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      _logger.info('Executing data query with employee and project JOINs');
      final results = await DatabaseConnection.query(sql, values: params);
      _logger.info('Query returned ${results.length} rows');

      // Debug: Log the project_id and project_details for debugging
      if (results.isNotEmpty) {
        final firstRow = results.first;
        _logger.info('First row project_id: ${firstRow['project_id']}');
        _logger.info(
          'First row project_details: ${firstRow['project_details']}',
        );
      }

      final requests = <Map<String, dynamic>>[];
      for (final row in results) {
        var rowMap = Map<String, dynamic>.from(row);

        // Enrich project_details with Handled By (BDEs) info
        if (rowMap['project_details'] != null) {
          try {
            final projDetails = Map<String, dynamic>.from(
              rowMap['project_details'] is String
                  ? jsonDecode(rowMap['project_details'])
                  : rowMap['project_details'],
            );

            if (projDetails['handled_by_bde_ids'] != null) {
              final bdeIds = projDetails['handled_by_bde_ids'];
              if (bdeIds is List && bdeIds.isNotEmpty) {
                final List<String> ids = bdeIds
                    .map((e) => e.toString())
                    .toList();
                final bdeDetails = await _getEmployeeDetailsList(ids);
                projDetails['handled_by'] = bdeDetails;
                rowMap['project_details'] = projDetails;
              }
            }
          } catch (e) {
            _logger.error('Error enriching project details: $e');
            // Continue without enrichment if fails
          }
        }
        requests.add(TaskCardRequest.fromMap(rowMap).toJson());
      }

      _logger.info('Mapped ${requests.length} task card requests');

      return {
        'data': requests,
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': total > 0 ? (total / limit).ceil() : 0,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting task card requests: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task card request by ID
  Future<TaskCardRequest?> getTaskCardRequestById(String requestId) async {
    try {
      final sql = '''
        SELECT 
          tcr.*,
          CASE 
            WHEN e.employee_id IS NOT NULL THEN
              jsonb_build_object(
                'employee_id', e.employee_id,
                'name', e.employee_name,
                'role', e.employee_role,
                'designation', e.employee_designation,
                'email', COALESCE(e.employee_company_email, e.employee_personal_email),
                'profile_img', e.employee_img
              )
            ELSE NULL
          END as employee_details,
          CASE 
            WHEN p.project_id IS NOT NULL THEN
              jsonb_build_object(
                'project_id', p.project_id,
                'project_name', p.project_name,
                'project_status', p.project_status,
                'handled_by_bde_ids', p.project_followed_by_bde_employee_ids,
                'project_manager_details', CASE 
                  WHEN COALESCE(pm_admin.admin_id, pm_emp.employee_id) IS NOT NULL THEN jsonb_build_object(
                    'id', COALESCE(pm_admin.admin_id, pm_emp.employee_id),
                    'name', COALESCE(pm_admin.admin_name, pm_emp.employee_name),
                    'role', COALESCE(pm_admin.admin_role, pm_emp.employee_role),
                    'designation', COALESCE(pm_admin.admin_designation, pm_emp.employee_designation),
                    'profile_image', COALESCE(pm_admin.admin_img, pm_emp.employee_img)
                  )
                  ELSE NULL
                END,
                'team_leader_details', CASE 
                  WHEN tl.employee_id IS NOT NULL THEN jsonb_build_object(
                    'id', tl.employee_id,
                    'name', tl.employee_name,
                    'role', tl.employee_role,
                    'designation', tl.employee_designation,
                    'profile_image', tl.employee_img
                  )
                  ELSE NULL
                END
              )
            ELSE NULL
          END as project_details,
          CASE 
            WHEN approver.employee_id IS NOT NULL THEN
              jsonb_build_object(
                'employee_id', approver.employee_id,
                'name', approver.employee_name,
                'role', approver.employee_role,
                'designation', approver.employee_designation,
                'email', COALESCE(approver.employee_company_email, approver.employee_personal_email),
                'profile_img', approver.employee_img
              )
            ELSE NULL
          END as approver_details
        FROM task_card_requests tcr
        LEFT JOIN employees e ON tcr.employee_id = e.employee_id
        LEFT JOIN projects p ON tcr.project_id = p.project_id
        LEFT JOIN admins pm_admin ON p.project_manager_id = pm_admin.admin_id
        LEFT JOIN employees pm_emp ON p.project_manager_id = pm_emp.employee_id AND pm_admin.admin_id IS NULL
        LEFT JOIN employees tl ON p.project_team_leader_id = tl.employee_id
        LEFT JOIN employees approver ON tcr.approved_rejected_by = approver.employee_id
        WHERE tcr.request_id = @id
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': requestId},
      );
      if (result == null) return null;

      var rowMap = Map<String, dynamic>.from(result);

      // Enrich project_details with Handled By (BDEs) info
      if (rowMap['project_details'] != null) {
        try {
          final projDetails = Map<String, dynamic>.from(
            rowMap['project_details'] is String
                ? jsonDecode(rowMap['project_details'])
                : rowMap['project_details'],
          );

          if (projDetails['handled_by_bde_ids'] != null) {
            final bdeIds = projDetails['handled_by_bde_ids'];
            if (bdeIds is List && bdeIds.isNotEmpty) {
              final List<String> ids = bdeIds.map((e) => e.toString()).toList();
              final bdeDetails = await _getEmployeeDetailsList(ids);
              projDetails['handled_by'] = bdeDetails;
              rowMap['project_details'] = projDetails;
            }
          }
        } catch (e) {
          _logger.error('Error enriching project details in getById: $e');
        }
      }

      return TaskCardRequest.fromMap(rowMap);
    } catch (e, stackTrace) {
      _logger.error('Error getting task card request by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Approve task card request (Admin)
  /// POST /admin/task-card-requests/{requestId}/approve
  Future<TaskCardRequest> approveTaskCardRequest(
    String requestId,
    String approvedBy,
    String? remarks,
  ) async {
    try {
      final existing = await getTaskCardRequestById(requestId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }

      if (existing.requestStatus != 'pending') {
        throw ValidationException({
          'request_status': ['Request has already been processed'],
        });
      }

      final sql = '''
        UPDATE task_card_requests 
        SET request_status = 'approved',
            approved_rejected_by = @approvedBy,
            approved_rejected_at = @approvedAt,
            approved_rejected_reason = @remarks
        WHERE request_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': requestId,
          'approvedBy': approvedBy,
          'approvedAt': DateTime.now().toIso8601String(),
          'remarks': remarks ?? 'Approved',
        },
      );

      if (result == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }

      // Fetch the full request with employee details for task card creation
      final fullRequest = await getTaskCardRequestById(requestId);

      // Create the actual task card from the request
      if (fullRequest != null) {
        await _createTaskCardFromRequest(fullRequest, approvedBy);
      }

      // Return the updated request with employee details
      return fullRequest ?? TaskCardRequest.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error approving task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Reject task card request (Admin)
  /// POST /admin/task-card-requests/{requestId}/reject
  Future<TaskCardRequest> rejectTaskCardRequest(
    String requestId,
    String rejectedBy,
    String reason,
  ) async {
    try {
      final existing = await getTaskCardRequestById(requestId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }

      if (existing.requestStatus != 'pending') {
        throw ValidationException({
          'request_status': ['Request has already been processed'],
        });
      }

      final sql = '''
        UPDATE task_card_requests 
        SET request_status = 'rejected',
            approved_rejected_by = @rejectedBy,
            approved_rejected_at = @rejectedAt,
            approved_rejected_reason = @reason
        WHERE request_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': requestId,
          'rejectedBy': rejectedBy,
          'rejectedAt': DateTime.now().toIso8601String(),
          'reason': reason,
        },
      );

      if (result == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }

      return TaskCardRequest.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error rejecting task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TASK CARD REQUEST OPERATIONS
  // ==========================================

  /// Create new task card request (Employee)
  /// POST /employee/task-card-requests
  Future<TaskCardRequest> createTaskCardRequest(
    Map<String, dynamic> data,
    String employeeId,
  ) async {
    try {
      _validateTaskCardRequestData(data);

      final insertData = <String, dynamic>{
        'employee_id': employeeId,
        'project_id': data['project_id'],
        'task_name': data['task_name'],
        'task_description': data['task_description'],
        'task_duration': data['task_duration'],
        'task_type': data['task_type'] ?? 'Task',
        'priority_level': data['priority_level'] ?? 'Medium',
        'workflow_status': 'TODO',
        'from_date': data['from_date'],
        'to_date': data['to_date'],
        'task_attachments': data['task_attachments'] != null
            ? jsonEncode(data['task_attachments'])
            : '[]',
        'requested_by': employeeId,
        'request_status': 'pending',
      };

      final columns = insertData.keys.join(', ');
      final placeholders = insertData.keys.map((k) => '@$k').join(', ');

      final sql =
          '''
        INSERT INTO task_card_requests ($columns)
        VALUES ($placeholders)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: insertData);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create task card request');
      }

      return TaskCardRequest.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee's task card requests
  /// GET /employee/task-card-requests
  Future<List<TaskCardRequest>> getEmployeeTaskCardRequests(
    String employeeId,
  ) async {
    try {
      final sql = '''
        SELECT * FROM task_card_requests 
        WHERE employee_id = @employeeId
        ORDER BY requested_on DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'employeeId': employeeId},
      );
      return results.map((row) => TaskCardRequest.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee task card requests: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Cancel task card request (Employee - only pending requests)
  /// DELETE /employee/task-card-requests/{requestId}
  Future<bool> cancelTaskCardRequest(
    String requestId,
    String employeeId,
  ) async {
    try {
      final existing = await getTaskCardRequestById(requestId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }

      if (existing.employeeId != employeeId) {
        throw UnauthorizedException(
          message: 'Not authorized to cancel this request',
        );
      }

      if (existing.requestStatus != 'pending') {
        throw ValidationException({
          'request_status': ['Can only cancel pending requests'],
        });
      }

      final sql = 'DELETE FROM task_card_requests WHERE request_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': requestId},
      );

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error cancelling task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  void _validateTaskCardRequestData(Map<String, dynamic> data) {
    final errors = <String, List<String>>{};

    if (data['task_name'] == null || (data['task_name'] as String).isEmpty) {
      errors['task_name'] = ['Task name is required'];
    }
    if (data['from_date'] == null) {
      errors['from_date'] = ['From date is required'];
    }
    if (data['to_date'] == null) {
      errors['to_date'] = ['To date is required'];
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  Future<void> _createTaskCardFromRequest(
    TaskCardRequest request,
    String createdBy,
  ) async {
    try {
      // Build insert data - only include columns that exist in the task_cards table
      final insertData = <String, dynamic>{
        'task_name': request.taskName,
        'task_description': request.taskDescription,
        'task_duration': request.taskDuration,
        'task_type': request.taskType ?? 'Task',
        'priority_level': request.priorityLevel ?? 'Medium',
        'project_id': request.projectId,
        'employee_id': request.employeeId,
        'workflow_status': 'TODO',
        'assigned_at': DateTime.now().toIso8601String(),
        'from_date': request.fromDate?.toIso8601String().split('T')[0],
        'to_date': request.toDate?.toIso8601String().split('T')[0],
        'task_attachments': request.taskAttachments != null
            ? jsonEncode(request.taskAttachments)
            : '[]',
        'is_deleted': false,
        'created_by': createdBy,
        'updated_at': null,
      };

      final columns = insertData.keys.join(', ');
      final placeholders = insertData.keys.map((k) => '@$k').join(', ');

      final sql =
          '''
        INSERT INTO task_cards ($columns)
        VALUES ($placeholders)
        RETURNING task_id
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: insertData);

      if (result != null) {
        // Update the request with the created task_id
        final updateSql = '''
          UPDATE task_card_requests 
          SET task_id = @taskId
          WHERE request_id = @requestId
        ''';
        await DatabaseConnection.execute(
          updateSql,
          values: {'taskId': result['task_id'], 'requestId': request.requestId},
        );

        // Create log entry for the new task
        final logSql = '''
          INSERT INTO task_card_logs (task_id, action_name, action_description, actioned_by)
          VALUES (@taskId, 'Task Created', 'Task created from approved request', @createdBy)
        ''';
        await DatabaseConnection.execute(
          logSql,
          values: {'taskId': result['task_id'], 'createdBy': createdBy},
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error creating task card from request: $e', e, stackTrace);
      // Don't rethrow - approval should succeed even if task creation fails
      // The request is marked as approved, task can be created manually
    }
  }

  Future<List<Map<String, dynamic>>> _getEmployeeDetailsList(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    for (final id in ids) {
      final emp = await DatabaseConnection.queryOne(
        'SELECT employee_id, employee_name, employee_role, employee_designation, employee_img FROM employees WHERE employee_id = @id',
        values: {'id': id},
      );
      if (emp != null) {
        result.add({
          'id': emp['employee_id']
              ?.toString(), // key 'id' to match generic 'details' structure
          'name': emp['employee_name']?.toString(),
          'role': emp['employee_role']?.toString(),
          'designation': emp['employee_designation']?.toString(),
          'profile_image': emp['employee_img']
              ?.toString(), // key 'profile_image' to match
        });
      }
    }
    return result;
  }
}
