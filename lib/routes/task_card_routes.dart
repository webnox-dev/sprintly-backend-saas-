import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/task_card_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// TaskCard routes handler with proper naming conventions
/// Provides ADMIN and EMPLOYEE endpoints for task card management
class TaskCardRoutes {
  final TaskCardService _service = TaskCardService();
  final AppLogger _logger = AppLogger('TaskCardRoutes');

  Router get router {
    final router = Router();

    // ==========================================
    // ADMIN ROUTES - /admin/task-cards
    // ==========================================

    // GET /admin/task-cards - getAllTaskCards
    router.get('/admin/task-cards', _getAllTaskCards);

    // POST /admin/task-cards - createNewTaskCard
    router.post('/admin/task-cards', _createNewTaskCard);

    // GET /admin/task-cards/delayed/count - getDelayedTaskCardsCount
    router.get('/admin/task-cards/delayed/count', _getDelayedTaskCardsCount);

    // GET /admin/task-cards/delayed - getDelayedTaskCards (list for dialog)
    router.get('/admin/task-cards/delayed', _getDelayedTaskCards);

    // GET /admin/task-cards/<taskId> - getTaskCardById
    router.get('/admin/task-cards/<taskId>', _getTaskCardById);

    // PUT /admin/task-cards/<taskId> - updateTaskCard
    router.put('/admin/task-cards/<taskId>', _updateTaskCard);

    // DELETE /admin/task-cards/<taskId> - deleteTaskCard
    router.delete('/admin/task-cards/<taskId>', _deleteTaskCard);

    // POST /admin/task-cards/<taskId>/duplicate - duplicateTaskCard
    router.post('/admin/task-cards/<taskId>/duplicate', _duplicateTaskCard);

    // PUT /admin/task-cards/<taskId>/reassign - reassignTaskCard
    router.put('/admin/task-cards/<taskId>/reassign', _reassignTaskCard);

    // PATCH /admin/task-cards/update-status - updateTaskStatusById
    router.patch('/admin/task-cards/update-status', _updateTaskStatusById);

    // GET /admin/task-cards/<taskId>/logs - getTaskCardLogs
    router.get('/admin/task-cards/<taskId>/logs', _getTaskCardLogs);

    // GET /admin/employees/<employeeId>/task-cards - getTaskCardsByEmployeeId
    router.get(
      '/admin/employees/<employeeId>/task-cards',
      _getTaskCardsByEmployeeId,
    );

    // ==========================================
    // EMPLOYEE ROUTES - /employee/task-cards
    // ==========================================

    // GET /employee/task-cards - getEmployeeTaskCards
    router.get('/employee/task-cards', _getEmployeeTaskCards);

    // PATCH /employee/task-cards/<taskId>/decision - updateEmployeeTaskDecision
    router.patch(
      '/employee/task-cards/<taskId>/decision',
      _updateEmployeeTaskDecision,
    );

    // PATCH /employee/task-cards/<taskId>/work-status - updateEmployeeWorkStatus
    router.patch(
      '/employee/task-cards/<taskId>/work-status',
      _updateEmployeeWorkStatus,
    );

    // PATCH /employee/task-cards/<taskId>/notes - addTaskNotes
    router.patch('/employee/task-cards/<taskId>/notes', _addTaskNotes);

    // PATCH /employee/task-cards/<taskId>/qa-approve - qaApproveTask
    router.patch('/employee/task-cards/<taskId>/qa-approve', _qaApproveTask);

    // PATCH /employee/task-cards/<taskId>/qa-disapprove - qaDisapproveTask
    router.patch(
      '/employee/task-cards/<taskId>/qa-disapprove',
      _qaDisapproveTask,
    );

    // PATCH /employee/task-cards/<taskId>/qa-start - qaStartTask
    router.patch('/employee/task-cards/<taskId>/qa-start', _qaStartTask);

    // PATCH /employee/task-cards/<taskId>/qa-complete - qaCompleteTask
    router.patch('/employee/task-cards/<taskId>/qa-complete', _qaCompleteTask);

    // PATCH /employee/task-cards/<taskId>/qa-redo - qaRedoTask
    router.patch('/employee/task-cards/<taskId>/qa-redo', _qaRedoTask);

    return router;
  }

  // ==========================================
  // ADMIN HANDLERS
  // ==========================================

  /// GET /admin/task-cards - Get all task cards with filters
  Future<Response> _getAllTaskCards(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final projectId = params['project_id'];
      final employeeId = params['employee_id'];
      final workflowStatus = params['workflow_status'];
      final priorityLevel = params['priority_level'];
      final search = params['search'];
      final sortBy = params['sort_by'];
      final ascending = params['order'] != 'desc';
      final excludeWorkflowStatus = params['exclude_status'];
      final workflowStatusIn = params['status_in']?.split(',');
      final isDevStarted = params['is_dev_started'] == 'true';
      final excludeTaskId = params['exclude_task_id'];

      final result = await _service.getAllTaskCards(
        page: page,
        limit: limit,
        projectId: projectId,
        employeeId: employeeId,
        workflowStatus: workflowStatus,
        priorityLevel: priorityLevel,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
        excludeWorkflowStatus: excludeWorkflowStatus,
        workflowStatusIn: workflowStatusIn,
        isDevStarted: isDevStarted,
        excludeTaskId: excludeTaskId,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
          'totalPages': result['totalPages'],
          'hasNext': result['page'] < result['totalPages'],
          'hasPrev': result['page'] > 1,
        },
      ).toShelfResponse();
    } on AppException catch (e) {
      return _handleException(e);
    } catch (e, stackTrace) {
      _logger.error('Error in getAllTaskCards: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /admin/task-cards - Create new task card
  Future<Response> _createNewTaskCard(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final createdBy =
          data['created_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';

      final taskCard = await _service.createNewTaskCard(data, createdBy);

      return ApiResponse.success(
        data: taskCard.toJson(),
        message: 'Task card created successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in createNewTaskCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// Trigger notification for task creation (runs async in background)

  /// GET /admin/task-cards/delayed/count - Get delayed task cards count
  Future<Response> _getDelayedTaskCardsCount(Request request) async {
    try {
      final count = await _service.getDelayedTaskCardsCount();
      return ApiResponse.success(data: {'count': count}).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getDelayedTaskCardsCount: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/task-cards/delayed - Get delayed task cards list (for dialog)
  Future<Response> _getDelayedTaskCards(Request request) async {
    try {
      final params = request.url.queryParameters;
      final includeOvertimeOnly = params['overtime_only'] == 'true';
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '10') ?? 10;
      final search = params['search'];
      final employeeId = params['employee_id'];
      final projectId = params['project_id'];

      DateTime? month;
      if (params['month'] != null) {
        try {
          // Expects YYYY-MM
          final parts = params['month']!.split('-');
          if (parts.length == 2) {
            month = DateTime(int.parse(parts[0]), int.parse(parts[1]));
          }
        } catch (_) {}
      }

      final result = await _service.getDelayedTaskCardsWithDetails(
        includeOvertimeOnly: includeOvertimeOnly,
        page: page,
        limit: limit,
        search: search,
        employeeId: employeeId,
        projectId: projectId,
        month: month,
      );

      return ApiResponse.success(
        data: result['data'],
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
        },
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getDelayedTaskCards: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/task-cards/<taskId> - Get task card by ID
  Future<Response> _getTaskCardById(Request request, String taskId) async {
    try {
      final taskCard = await _service.getTaskCardById(taskId);
      return ApiResponse.success(data: taskCard.toJson()).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Task card not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in getTaskCardById: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PUT /admin/task-cards/<taskId> - Update task card
  Future<Response> _updateTaskCard(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final updatedBy =
          data['updated_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';

      final taskCard = await _service.updateTaskCard(taskId, data, updatedBy);

      return ApiResponse.success(
        data: taskCard.toJson(),
        message: 'Task card updated successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateTaskCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// DELETE /admin/task-cards/<taskId> - Delete task card (soft)
  Future<Response> _deleteTaskCard(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = body.isNotEmpty
          ? jsonDecode(body) as Map<String, dynamic>
          : {};
      final deletedBy =
          data['deleted_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';

      await _service.deleteTaskCard(taskId, deletedBy);

      return ApiResponse.success(
        message: 'Task card deleted successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in deleteTaskCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// POST /admin/task-cards/<taskId>/duplicate - Duplicate task card
  Future<Response> _duplicateTaskCard(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      _logger.info('Duplicate task request body: $body');
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeIds = (data['employee_ids'] as List?)?.cast<String>() ?? [];
      final duplicatedBy =
          data['duplicated_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';
      final newAttachments = data['new_attachments'] as List<dynamic>?;
      _logger.info('New attachments count: ${newAttachments?.length}');

      final overrides = <String, dynamic>{};
      for (final key in [
        'task_name',
        'task_description',
        'task_duration',
        'task_type',
        'priority_level',
        'from_date',
        'to_date',
      ]) {
        if (data.containsKey(key)) {
          overrides[key] = data[key];
        }
      }

      final duplicatedTasks = await _service.duplicateTaskCard(
        taskId,
        employeeIds,
        duplicatedBy,
        newAttachments: newAttachments,
        overrides: overrides.isNotEmpty ? overrides : null,
      );

      return ApiResponse.success(
        data: duplicatedTasks.map((t) => t.toJson()).toList(),
        message:
            'Task card duplicated to ${duplicatedTasks.length} employee(s)',
      ).toShelfResponse(statusCode: 201);
    } on NotFoundException {
      return _notFound('Task card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in duplicateTaskCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PUT /admin/task-cards/<taskId>/reassign - Reassign task card
  Future<Response> _reassignTaskCard(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final newEmployeeId = data['new_employee_id']?.toString() ?? '';
      final reason = data['reason']?.toString() ?? '';
      final reassignedBy =
          data['reassigned_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';

      final taskCard = await _service.reassignTaskCard(
        taskId,
        newEmployeeId,
        reason,
        reassignedBy,
      );

      return ApiResponse.success(
        data: taskCard.toJson(),
        message: 'Task card reassigned successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in reassignTaskCard: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /admin/task-cards/update-status - Update task status by ID
  Future<Response> _updateTaskStatusById(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final taskId = data['task_id']?.toString() ?? '';
      final workflowStatus = data['workflow_status']?.toString() ?? '';
      final updatedBy =
          data['updated_by']?.toString() ??
          request.context['employeeId']?.toString() ??
          'admin';

      if (taskId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'task_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (workflowStatus.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'workflow_status is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taskCard = await _service.updateTaskCardStatusById(
        taskId,
        workflowStatus,
        updatedBy,
      );

      return ApiResponse.success(
        data: taskCard.toJson(),
        message: 'Task status updated successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateTaskStatusById: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/task-cards/<taskId>/logs - Get task card logs
  Future<Response> _getTaskCardLogs(Request request, String taskId) async {
    try {
      final logs = await _service.getTaskCardLogs(taskId);
      return ApiResponse.success(
        data: logs.map((log) => log.toJson()).toList(),
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in getTaskCardLogs: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// GET /admin/employees/<employeeId>/task-cards - Get employee's task cards
  Future<Response> _getTaskCardsByEmployeeId(
    Request request,
    String employeeId,
  ) async {
    try {
      final taskCards = await _service.getTaskCardsByEmployeeId(employeeId);
      return ApiResponse.success(
        data: taskCards.map((t) => t.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getTaskCardsByEmployeeId: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // EMPLOYEE HANDLERS
  // ==========================================

  /// GET /employee/task-cards - Get employee's assigned task cards
  Future<Response> _getEmployeeTaskCards(Request request) async {
    try {
      // Get employee ID from auth header or query param
      final employeeId =
          request.headers['x-employee-id'] ??
          request.url.queryParameters['employee_id'] ??
          '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taskCards = await _service.getEmployeeTaskCards(employeeId);
      return ApiResponse.success(
        data: taskCards.map((t) => t.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeeTaskCards: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/decision - Accept/Reject task
  Future<Response> _updateEmployeeTaskDecision(
    Request request,
    String taskId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final status = (data['status'] as num?)?.toInt() ?? 0;
      final reason = data['reason']?.toString();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taskCard = await _service.updateEmployeeTaskDecision(
        taskId,
        employeeId,
        status,
        reason,
      );

      final message = status == 1 ? 'Task accepted' : 'Task rejected';
      return ApiResponse.success(
        data: taskCard.toJson(),
        message: message,
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: 'UNAUTHORIZED',
        message: e.message,
      ).toShelfResponse(statusCode: 403);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateEmployeeTaskDecision: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/work-status - Start/Pause/Complete
  Future<Response> _updateEmployeeWorkStatus(
    Request request,
    String taskId,
  ) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final employeeTaskStatus =
          (data['employee_task_status'] as num?)?.toInt() ?? 0;

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _service.updateEmployeeWorkStatus(
        taskId,
        employeeId,
        employeeTaskStatus,
      );

      return ApiResponse.success(
        data: result,
        message: 'Work status updated',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } on UnauthorizedException catch (e) {
      return ApiResponse.error(
        code: 'UNAUTHORIZED',
        message: e.message,
      ).toShelfResponse(statusCode: 403);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in updateEmployeeWorkStatus: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/notes - Add notes and attachments
  Future<Response> _addTaskNotes(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final devNotes = data['dev_notes']?.toString();
      final qcNotes = data['qc_notes']?.toString();
      final attachments = data['attachments'] as List?;

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taskCard = await _service.addTaskNotes(
        taskId,
        employeeId,
        devNotes,
        qcNotes,
        attachments,
      );

      return ApiResponse.success(
        data: taskCard.toJson(),
        message: 'Notes added successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in addTaskNotes: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/qa-approve - qaApproveTask
  Future<Response> _qaApproveTask(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final notes = data['notes']?.toString();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await _service.qaApproveTask(
        taskId: taskId,
        userId: employeeId,
        notes: notes,
      );

      return ApiResponse.success(
        data: {'success': success},
        message: success
            ? 'Task approved successfully'
            : 'Task approval failed',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in qaApproveTask: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/qa-disapprove - qaDisapproveTask
  Future<Response> _qaDisapproveTask(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final notes = data['notes']?.toString() ?? '';

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (notes.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Notes are required for disapproval',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await _service.qaDisapproveTask(
        taskId: taskId,
        userId: employeeId,
        notes: notes,
      );

      return ApiResponse.success(
        data: {'success': success},
        message: success
            ? 'Task disapproved successfully'
            : 'Task disapproval failed',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in qaDisapproveTask: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/qa-start
  Future<Response> _qaStartTask(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final notes = data['notes']?.toString();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await _service.qaStartTask(
        taskId: taskId,
        userId: employeeId,
        notes: notes,
      );

      return ApiResponse.success(
        data: {'success': success},
        message: success ? 'Task started successfully' : 'Task start failed',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in qaStartTask: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/qa-complete
  Future<Response> _qaCompleteTask(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final notes = data['notes']?.toString();
      final attachments = (data['attachments'] as List?)
          ?.map((e) => e.toString())
          .toList();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await _service.qaCompleteTask(
        taskId: taskId,
        userId: employeeId,
        notes: notes,
        attachments: attachments,
      );

      return ApiResponse.success(
        data: {'success': success},
        message: success
            ? 'Task completed successfully'
            : 'Task completion failed',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in qaCompleteTask: $e', e, stackTrace);
      return _internalError();
    }
  }

  /// PATCH /employee/task-cards/<taskId>/qa-redo
  Future<Response> _qaRedoTask(Request request, String taskId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final employeeId =
          data['employee_id']?.toString() ??
          request.headers['x-employee-id'] ??
          '';
      final notes = data['notes']?.toString() ?? '';
      final attachments = (data['attachments'] as List?)
          ?.map((e) => e.toString())
          .toList();

      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required',
        ).toShelfResponse(statusCode: 400);
      }
      if (notes.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Notes are required for redo',
        ).toShelfResponse(statusCode: 400);
      }

      final success = await _service.qaRedoTask(
        taskId: taskId,
        userId: employeeId,
        notes: notes,
        attachments: attachments,
      );

      return ApiResponse.success(
        data: {'success': success},
        message: success
            ? 'Task sent for redo successfully'
            : 'Task redo submission failed',
      ).toShelfResponse();
    } on NotFoundException {
      return _notFound('Task card');
    } catch (e, stackTrace) {
      _logger.error('Error in qaRedoTask: $e', e, stackTrace);
      return _internalError();
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Response _handleException(AppException e) {
    int statusCode;
    switch (e.code) {
      case 'NOT_FOUND':
        statusCode = 404;
        break;
      case 'VALIDATION_ERROR':
        statusCode = 400;
        break;
      case 'UNAUTHORIZED':
        statusCode = 401;
        break;
      case 'CONFLICT':
        statusCode = 409;
        break;
      default:
        statusCode = 500;
    }
    return ApiResponse.error(
      code: e.code,
      message: e.message,
      details: e.details,
    ).toShelfResponse(statusCode: statusCode);
  }

  Response _notFound(String resource) {
    return ApiResponse.error(
      code: 'NOT_FOUND',
      message: '$resource not found',
    ).toShelfResponse(statusCode: 404);
  }

  Response _internalError() {
    return ApiResponse.error(
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    ).toShelfResponse(statusCode: 500);
  }
}
