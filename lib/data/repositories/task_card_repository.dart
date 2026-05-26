import 'dart:convert';
import 'package:excel/excel.dart';
import '../../domain/models/task_card.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';
import 'helpers/task_card_query_builder.dart';
import 'helpers/task_duration_helper.dart';
import 'time_tracking_repository.dart';

/// TaskCard repository for database operations
/// Handles all Task Card CRUD operations with proper business logic
class TaskCardRepository {
  final AppLogger _logger = AppLogger('TaskCardRepository');
  final TimeTrackingRepository _timeTrackingRepository =
      TimeTrackingRepository();

  // ==========================================
  // ADMIN - TASK CARD OPERATIONS
  // ==========================================

  /// Get all task cards with pagination and filters (Admin)
  /// GET /admin/task-cards
  /// Supports different views: kanban, table, calendar
  Future<Map<String, dynamic>> getAllTaskCards({
    int page = 1,
    int limit = 50,
    String? projectId,
    String? employeeId,
    String? workflowStatus,
    String? priorityLevel,
    String? search,
    String? sortBy,
    bool ascending = false,
    String? view, // 'kanban', 'table', 'calendar'
    DateTime? date, // for calendar view
    String? employeeName, // filter by employee name
    String? projectName, // filter by project name
    String? excludeWorkflowStatus,
    List<String>? workflowStatusIn,
    bool isDevStarted = false,
    String? excludeTaskId,
  }) async {
    try {
      final offset = (page - 1) * limit;

      // Build WHERE clause and params
      final whereData = TaskCardQueryBuilder.buildWhereClause(
        projectId: projectId,
        employeeId: employeeId,
        workflowStatus: workflowStatus,
        priorityLevel: priorityLevel,
        search: search,
        employeeName: employeeName,
        projectName: projectName,
        excludeWorkflowStatus: excludeWorkflowStatus,
        workflowStatusIn: workflowStatusIn,
        isDevStarted: isDevStarted,
        excludeTaskId: excludeTaskId,
      );

      final whereClause = whereData['whereClause'] as String;
      final params = whereData['params'] as Map<String, dynamic>;

      // Build ORDER BY clause
      final orderBy = TaskCardQueryBuilder.buildOrderBy(
        sortBy: sortBy,
        ascending: ascending,
      );

      // Count query
      final countSql = TaskCardQueryBuilder.getCountQuery(whereClause);
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Data query
      final sql = TaskCardQueryBuilder.getAllTaskCardsQuery(
        whereClause: whereClause,
        orderBy: orderBy,
      );
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: params);
      final taskCards = results.map((row) => TaskCard.fromMap(row)).toList();

      // Handle different views
      if (view == 'kanban') {
        return _groupTasksForKanban(taskCards, total);
      } else if (view == 'calendar' && date != null) {
        return _filterTasksForCalendar(taskCards, date, total);
      }

      // Default table view
      return {
        'data': taskCards.map((tc) => tc.toJson()).toList(),
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': total > 0 ? (total / limit).ceil() : 0,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Group tasks by workflow status for kanban view
  Map<String, dynamic> _groupTasksForKanban(List<TaskCard> tasks, int total) {
    return {
      'view': 'kanban',
      'total': total,
      'data': {
        'todo': tasks
            .where((t) => t.workflowStatus == 'TODO')
            .map((t) => t.toJson())
            .toList(),
        'in_progress': tasks
            .where((t) => t.workflowStatus == 'In Progress')
            .map((t) => t.toJson())
            .toList(),
        'dev_completed': tasks
            .where((t) => t.workflowStatus == 'Dev Completed')
            .map((t) => t.toJson())
            .toList(),
        'in_qc': tasks
            .where((t) => t.workflowStatus == 'In QC')
            .map((t) => t.toJson())
            .toList(),
        'work_done': tasks
            .where((t) => t.workflowStatus == 'Work Done')
            .map((t) => t.toJson())
            .toList(),
        'redo': tasks
            .where((t) => t.workflowStatus == 'Redo')
            .map((t) => t.toJson())
            .toList(),
      },
      'counts': {
        'todo': tasks.where((t) => t.workflowStatus == 'TODO').length,
        'in_progress': tasks
            .where((t) => t.workflowStatus == 'In Progress')
            .length,
        'dev_completed': tasks
            .where((t) => t.workflowStatus == 'Dev Completed')
            .length,
        'in_qc': tasks.where((t) => t.workflowStatus == 'In QC').length,
        'work_done': tasks.where((t) => t.workflowStatus == 'Work Done').length,
        'redo': tasks.where((t) => t.workflowStatus == 'Redo').length,
      },
    };
  }

  /// Filter tasks for calendar view
  Map<String, dynamic> _filterTasksForCalendar(
    List<TaskCard> tasks,
    DateTime date,
    int total,
  ) {
    final filteredTasks = tasks.where((task) {
      if (task.fromDate == null || task.toDate == null) return false;
      final taskStart = task.fromDate!;
      final taskEnd = task.toDate!;
      return (taskStart.isBefore(date) || taskStart.isAtSameMomentAs(date)) &&
          (taskEnd.isAfter(date) || taskEnd.isAtSameMomentAs(date));
    }).toList();

    return {
      'view': 'calendar',
      'date': date.toIso8601String().split('T')[0],
      'total': filteredTasks.length,
      'data': filteredTasks.map((t) => t.toJson()).toList(),
    };
  }

  /// Get task card by ID (Admin)
  /// GET /admin/task-cards/{taskId}
  Future<TaskCard?> getTaskCardById(String taskId) async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCardByIdQuery();
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': taskId},
      );
      return result != null ? TaskCard.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting task card by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create new task card (Admin)
  /// POST /admin/task-cards
  Future<TaskCard> createNewTaskCard(
    Map<String, dynamic> data,
    String createdBy,
  ) async {
    try {
      // Validate required fields
      _validateTaskCardData(data);

      // Validate employee belongs to project
      if (data['project_id'] != null && data['employee_id'] != null) {
        await _validateEmployeeBelongsToProject(
          data['employee_id'] as String,
          data['project_id'] as String,
        );
      }

      // Date Validation
      if (data['from_date'] != null) {
        final fromDate = DateTime.parse(data['from_date']);
        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);
        if (fromDate.isBefore(startOfToday)) {
          throw ValidationException({
            'from_date': ['Start date cannot be in the past'],
          });
        }

        if (data['to_date'] != null) {
          final toDate = DateTime.parse(data['to_date']);
          if (toDate.isBefore(fromDate)) {
            throw ValidationException({
              'to_date': ['End date cannot be before start date'],
            });
          }
        }
      }

      // Prepare data (employee_details and project_details removed - fetched via JOINs)
      final insertData = <String, dynamic>{
        'task_name': data['task_name'],
        'task_description': data['task_description'],
        'task_duration': data['task_duration'],
        'task_type': data['task_type'] ?? 'Task',
        'priority_level': data['priority_level'] ?? 'Medium',
        'project_id': data['project_id'],
        'employee_id': data['employee_id'],
        'workflow_status': data['workflow_status'] ?? 'TODO',
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'from_date': data['from_date'],
        'to_date': data['to_date'],
        'task_attachments': data['task_attachments'] != null
            ? jsonEncode(data['task_attachments'])
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
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: insertData);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create task card');
      }

      final taskCard = TaskCard.fromMap(result);

      // Create log entry
      await _createTaskLog(
        taskCard.taskId,
        'Task Created',
        'Task card "${taskCard.taskName}" was created',
        createdBy,
      );

      // Save attachments
      if (data['task_attachments'] is List) {
        await _saveTaskAttachments(
          taskCard.taskId,
          data['task_attachments'],
          createdBy,
        );
      }

      return taskCard;
    } catch (e, stackTrace) {
      _logger.error('Error creating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update task card (Admin)
  /// PUT /admin/task-cards/{taskId}
  Future<TaskCard> updateTaskCard(
    String taskId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      // Get existing task card for comparison
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      if (updates.isEmpty) {
        throw ValidationException({
          'updates': ['No fields to update'],
        });
      }

      // Cannot change projectId after creation
      if (updates.containsKey('project_id') &&
          updates['project_id'] != existing.projectId) {
        throw ValidationException({
          'project_id': ['Cannot change project after task creation'],
        });
      }

      // Date Validation for Update
      if (updates.containsKey('from_date') || updates.containsKey('to_date')) {
        DateTime? fromDate;
        if (updates.containsKey('from_date')) {
          if (updates['from_date'] != null) {
            fromDate = DateTime.parse(updates['from_date']);
            final today = DateTime.now();
            final startOfToday = DateTime(today.year, today.month, today.day);
            if (fromDate.isBefore(startOfToday)) {
              throw ValidationException({
                'from_date': ['Start date cannot be in the past'],
              });
            }
          }
        } else {
          fromDate = existing.fromDate;
        }

        DateTime? toDate;
        if (updates.containsKey('to_date')) {
          if (updates['to_date'] != null) {
            toDate = DateTime.parse(updates['to_date']);
          }
        } else {
          toDate = existing.toDate;
        }

        if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
          throw ValidationException({
            'to_date': ['End date cannot be before start date'],
          });
        }
      }

      // Prepare update data
      final updateData = <String, dynamic>{};

      // Handle allowed fields
      final allowedFields = [
        'task_name',
        'task_description',
        'task_duration',
        'task_type',
        'priority_level',
        'workflow_status',
        'from_date',
        'to_date',
        'status_reason',
        'dev_notes',
        'qc_notes',
      ];

      for (final field in allowedFields) {
        if (updates.containsKey(field)) {
          updateData[field] = updates[field];
        }
      }

      // Handle JSON fields
      if (updates.containsKey('task_attachments')) {
        updateData['task_attachments'] = jsonEncode(
          updates['task_attachments'],
        );
      }
      if (updates.containsKey('dev_completed_attachments')) {
        updateData['dev_completed_attachments'] = jsonEncode(
          updates['dev_completed_attachments'],
        );
      }
      if (updates.containsKey('qc_completed_attachments')) {
        updateData['qc_completed_attachments'] = jsonEncode(
          updates['qc_completed_attachments'],
        );
      }

      updateData['updated_by'] = updatedBy;
      updateData['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final setClause = updateData.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE task_cards 
        SET $setClause
        WHERE task_id = @id AND is_deleted = FALSE
        RETURNING *
      ''';

      updateData['id'] = taskId;
      final result = await DatabaseConnection.queryOne(sql, values: updateData);

      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final updatedTask = TaskCard.fromMap(result);

      // Sync task_attachments table if updated
      if (updates.containsKey('task_attachments') &&
          updates['task_attachments'] is List) {
        await DatabaseConnection.queryOne(
          'DELETE FROM task_attachments WHERE task_id = @id',
          values: {'id': taskId},
        );

        await _saveTaskAttachments(
          taskId,
          updates['task_attachments'],
          updatedBy,
        );
      }

      // Create log entry
      await _createTaskLog(
        taskId,
        'Task Updated',
        'Task card was updated',
        updatedBy,
        oldValue: existing.toJson(),
        newValue: updatedTask.toJson(),
      );

      return updatedTask;
    } catch (e, stackTrace) {
      _logger.error('Error updating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Soft delete task card (Admin)
  /// DELETE /admin/task-cards/{taskId}
  Future<bool> deleteTaskCard(String taskId, String deletedBy) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final sql = '''
        UPDATE task_cards 
        SET is_deleted = TRUE, updated_by = @deletedBy
        WHERE task_id = @id
      ''';

      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': taskId, 'deletedBy': deletedBy},
      );

      if (affectedRows > 0) {
        await _createTaskLog(
          taskId,
          'Task Deleted',
          'Task card "${existing.taskName}" was soft deleted',
          deletedBy,
        );
      }

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Duplicate task card to multiple employees (Admin)
  /// POST /admin/task-cards/{taskId}/duplicate
  Future<List<TaskCard>> duplicateTaskCard(
    String taskId,
    List<String> employeeIds,
    String duplicatedBy, {
    List<dynamic>? newAttachments,
    Map<String, dynamic>? overrides,
  }) async {
    try {
      final original = await getTaskCardById(taskId);
      if (original == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Validate all employees belong to the same project
      for (final empId in employeeIds) {
        if (original.projectId != null) {
          await _validateEmployeeBelongsToProject(empId, original.projectId!);
        }
      }

      // Date Validation for Duplication
      DateTime? fromDate;
      if (overrides != null && overrides.containsKey('from_date')) {
        if (overrides['from_date'] != null) {
          fromDate = DateTime.parse(overrides['from_date']);
          final today = DateTime.now();
          final startOfToday = DateTime(today.year, today.month, today.day);
          if (fromDate.isBefore(startOfToday)) {
            throw ValidationException({
              'from_date': ['Start date cannot be in the past'],
            });
          }
        }
      } else {
        fromDate = original.fromDate;
      }

      DateTime? toDate;
      if (overrides != null && overrides.containsKey('to_date')) {
        if (overrides['to_date'] != null) {
          toDate = DateTime.parse(overrides['to_date']);
        }
      } else {
        toDate = original.toDate;
      }

      if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
        throw ValidationException({
          'to_date': ['End date cannot be before start date'],
        });
      }

      final duplicatedTasks = <TaskCard>[];

      // Prepare attachments
      final combinedAttachments = <dynamic>[];
      if (original.taskAttachments != null) {
        combinedAttachments.addAll(original.taskAttachments!);
      }
      if (newAttachments != null) {
        combinedAttachments.addAll(newAttachments);
      }
      _logger.info(
        'Combined attachments for duplication: ${combinedAttachments.length}',
      );

      for (final empId in employeeIds) {
        // Removed empDetails fetch - will be fetched via JOINs

        final insertData = <String, dynamic>{
          'task_name': overrides?['task_name'] ?? original.taskName,
          'task_description':
              overrides?['task_description'] ?? original.taskDescription,
          'task_duration': overrides?['task_duration'] ?? original.taskDuration,
          'task_type': overrides?['task_type'] ?? original.taskType,
          'priority_level':
              overrides?['priority_level'] ?? original.priorityLevel,
          'project_id': original.projectId,
          'employee_id': empId,
          'workflow_status': 'TODO',
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
          'from_date':
              overrides?['from_date'] ??
              original.fromDate?.toIso8601String().split('T')[0],
          'to_date':
              overrides?['to_date'] ??
              original.toDate?.toIso8601String().split('T')[0],
          'task_attachments': jsonEncode(combinedAttachments),
          'is_deleted': false,
          'created_by': duplicatedBy,
          'updated_at': null,
        };

        final columns = insertData.keys.join(', ');
        final placeholders = insertData.keys.map((k) => '@$k').join(', ');

        final sql =
            '''
          INSERT INTO task_cards ($columns)
          VALUES ($placeholders)
          RETURNING *
        ''';

        final result = await DatabaseConnection.queryOne(
          sql,
          values: insertData,
        );
        if (result != null) {
          final newTask = TaskCard.fromMap(result);
          duplicatedTasks.add(newTask);

          await _createTaskLog(
            newTask.taskId,
            'Task Duplicated',
            'Task duplicated from ${original.taskId}',
            duplicatedBy,
          );

          // Save attachments
          if (combinedAttachments.isNotEmpty) {
            await _saveTaskAttachments(
              newTask.taskId,
              combinedAttachments,
              duplicatedBy,
            );
          }
        }
      }

      return duplicatedTasks;
    } catch (e, stackTrace) {
      _logger.error('Error duplicating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Reassign task card to another employee (Admin)
  /// PUT /admin/task-cards/{taskId}/reassign
  Future<TaskCard> reassignTaskCard(
    String taskId,
    String newEmployeeId,
    String reason,
    String reassignedBy,
  ) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Validate new employee belongs to the same project
      if (existing.projectId != null) {
        await _validateEmployeeBelongsToProject(
          newEmployeeId,
          existing.projectId!,
        );
      }

      // Removed empDetails fetch - will be fetched via JOINs

      final sql = '''
        UPDATE task_cards 
        SET employee_id = @newEmployeeId,
            is_task_reassigned = TRUE,
            reassigned_by = @reassignedBy,
            reassigned_on = @reassignedOn,
            reassigned_reason = @reason,
            updated_by = @reassignedBy,
            updated_at = @reassignedOn
        WHERE task_id = @id AND is_deleted = FALSE
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': taskId,
          'newEmployeeId': newEmployeeId,
          'reassignedBy': reassignedBy,
          'reassignedOn': DateTime.now().toUtc().toIso8601String(),
          'reason': reason,
        },
      );

      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final updatedTask = TaskCard.fromMap(result);

      await _createTaskLog(
        taskId,
        'Task Reassigned',
        'Task reassigned from ${existing.employeeId} to $newEmployeeId. Reason: $reason',
        reassignedBy,
        oldValue: {'employee_id': existing.employeeId},
        newValue: {'employee_id': newEmployeeId},
      );

      return updatedTask;
    } catch (e, stackTrace) {
      _logger.error('Error reassigning task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update task card status only (Admin)
  /// PATCH /admin/task-cards/{taskId}/status
  /// If moving backward in workflow, clears the relevant tracking fields
  Future<TaskCard> updateTaskCardStatusById(
    String taskId,
    String workflowStatus,
    String updatedBy,
  ) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Define workflow order for regression detection
      const workflowOrder = {
        'TODO': 0,
        'In Progress': 1,
        'Dev Completed': 2,
        'In QC': 3,
        'Work Done': 4,
        'Redo': 1, // Redo is like going back to In Progress
      };

      final oldOrder = workflowOrder[existing.workflowStatus] ?? 0;
      final newOrder = workflowOrder[workflowStatus] ?? 0;
      final isRegression = newOrder < oldOrder;

      // Build dynamic SQL based on regression
      String additionalUpdates = '';
      final values = <String, dynamic>{
        'id': taskId,
        'workflowStatus': workflowStatus,
        'updatedBy': updatedBy,
      };

      if (isRegression) {
        // Clear fields based on regression level
        if (newOrder < 2) {
          // Going back to TODO or In Progress - clear dev tracking
          additionalUpdates = '''
            dev_started_at = NULL,
            dev_completed_at = NULL,
            total_dev_hours = 0.00,
            dev_notes = NULL,
            dev_completed_attachments = '[]'::jsonb,
          ''';
        }
        if (newOrder < 3) {
          // Going back before In QC - clear QC tracking
          additionalUpdates += '''
            qc_started_at = NULL,
            qc_completed_at = NULL,
            qc_total_hours = 0.00,
            qc_notes = NULL,
            qc_completed_attachments = '[]'::jsonb,
          ''';
        }
      }

      final sql =
          '''
        UPDATE task_cards 
        SET workflow_status = @workflowStatus,
            $additionalUpdates
            updated_by = @updatedBy,
            updated_at = CURRENT_TIMESTAMP
        WHERE task_id = @id AND is_deleted = FALSE
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: values);

      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Create log with regression info
      final description = isRegression
          ? 'Workflow status moved backward from ${existing.workflowStatus} to $workflowStatus (tracking data cleared)'
          : 'Workflow status changed from ${existing.workflowStatus} to $workflowStatus';

      await _createTaskLog(
        taskId,
        isRegression ? 'Status Regressed' : 'Status Updated',
        description,
        updatedBy,
        oldValue: {'workflow_status': existing.workflowStatus},
        newValue: {
          'workflow_status': workflowStatus,
          'is_regression': isRegression,
        },
      );

      return TaskCard.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating task status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task cards by employee ID (Admin)
  /// GET /admin/employees/{employeeId}/task-cards
  Future<List<TaskCard>> getTaskCardsByEmployeeId(String employeeId) async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCardsByEmployeeIdQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'employeeId': employeeId},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting task cards by employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task card logs (Admin)
  /// GET /admin/task-cards/{taskId}/logs
  Future<List<TaskCardLog>> getTaskCardLogs(String taskId) async {
    try {
      final sql = '''
        SELECT * FROM task_card_logs 
        WHERE task_id = @taskId
        ORDER BY actioned_datetime DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'taskId': taskId},
      );
      return results.map((row) => TaskCardLog.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting task card logs: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TASK CARD OPERATIONS
  // ==========================================

  /// Get employee's assigned task cards
  /// GET /employee/task-cards
  Future<List<TaskCard>> getEmployeeTaskCards(String employeeId) async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCardsByEmployeeIdQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'employeeId': employeeId},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting employee task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Employee accepts or rejects a task
  /// PATCH /employee/task-cards/{taskId}/decision
  Future<TaskCard> updateEmployeeTaskDecision(
    String taskId,
    String employeeId,
    int status, // 1 = accepted, 2 = rejected
    String? reason,
  ) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Verify employee owns this task
      if (existing.employeeId != employeeId) {
        throw UnauthorizedException(
          message: 'Task not assigned to this employee',
        );
      }

      final newStatus = status == 1 ? 'In Progress' : 'TODO';
      final statusReason = status == 2 ? reason : null;

      final sql = '''
        UPDATE task_cards 
        SET workflow_status = @workflowStatus,
            status_reason = @statusReason,
            updated_by = @employeeId
        WHERE task_id = @id AND is_deleted = FALSE
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'id': taskId,
          'workflowStatus': newStatus,
          'statusReason': statusReason,
          'employeeId': employeeId,
        },
      );

      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final actionName = status == 1
          ? 'Employee Accepted'
          : 'Employee Rejected';
      await _createTaskLog(
        taskId,
        actionName,
        status == 1
            ? 'Task accepted by employee'
            : 'Task rejected by employee. Reason: $reason',
        employeeId,
      );

      return TaskCard.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating employee task decision: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Employee starts/pauses/completes task (clock-in/out)
  /// PATCH /employee/task-cards/{taskId}/work-status
  Future<Map<String, dynamic>> updateEmployeeWorkStatus(
    String taskId,
    String employeeId,
    int employeeTaskStatus, // 3=started, 4=paused, 5=completed
  ) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      // Verify employee owns this task
      if (existing.employeeId != employeeId) {
        throw UnauthorizedException(
          message: 'Task not assigned to this employee',
        );
      }

      final now = DateTime.now();
      Map<String, dynamic>? trackingUpdate;
      String logAction;
      String logDescription;

      switch (employeeTaskStatus) {
        case 3: // Started (clock-in)
          trackingUpdate = {
            'dev_started_at': now.toIso8601String(),
            'workflow_status': 'In Progress',
          };
          logAction = 'Clock-In';
          logDescription = 'Employee started working on task';
          break;
        case 4: // Paused
          logAction = 'Work Paused';
          logDescription = 'Employee paused work on task';
          break;
        case 5: // Completed (clock-out)
          final devHours = existing.devStartedAt != null
              ? now.difference(existing.devStartedAt!).inMinutes / 60.0
              : 0.0;
          trackingUpdate = {
            'dev_completed_at': now.toIso8601String(),
            'total_dev_hours': (existing.totalDevHours ?? 0) + devHours,
            'workflow_status': 'Dev Completed',
          };
          logAction = 'Clock-Out';
          logDescription =
              'Employee completed work on task. Hours: ${devHours.toStringAsFixed(2)}';
          break;
        default:
          throw ValidationException({
            'status': ['Invalid employee task status'],
          });
      }

      if (trackingUpdate != null) {
        trackingUpdate['updated_by'] = employeeId;
        final setClause = trackingUpdate.keys.map((k) => '$k = @$k').join(', ');
        final sql =
            '''
          UPDATE task_cards 
          SET $setClause
          WHERE task_id = @id AND is_deleted = FALSE
          RETURNING *
        ''';
        trackingUpdate['id'] = taskId;
        await DatabaseConnection.queryOne(sql, values: trackingUpdate);
      }

      await _createTaskLog(taskId, logAction, logDescription, employeeId);

      // Update Time Tracking via TimeTrackingRepository
      if (employeeTaskStatus == 3) {
        // Started/Clock-in
        await _timeTrackingRepository.clockIn(
          employeeId: employeeId,
          taskId: taskId,
          taskName: existing.taskName,
        );
      } else if (employeeTaskStatus == 5) {
        // Completed/Clock-out
        await _timeTrackingRepository.clockOut(
          employeeId: employeeId,
          taskId: taskId,
        );
      } else if (employeeTaskStatus == 4) {
        // Pause - clock out current session
        await _timeTrackingRepository.clockOut(
          employeeId: employeeId,
          taskId: taskId,
        );
      }

      final updated = await getTaskCardById(taskId);
      return {
        'task': updated?.toJson(),
        'action': logAction,
        'timestamp': now.toIso8601String(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error updating work status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add dev/qc notes and attachments
  /// PATCH /employee/task-cards/{taskId}/notes
  Future<TaskCard> addTaskNotes(
    String taskId,
    String employeeId,
    String? devNotes,
    String? qcNotes,
    List<dynamic>? attachments,
  ) async {
    try {
      final existing = await getTaskCardById(taskId);
      if (existing == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final updates = <String, dynamic>{};

      if (devNotes != null) {
        updates['dev_notes'] = devNotes;
      }
      if (qcNotes != null) {
        updates['qc_notes'] = qcNotes;
      }
      if (attachments != null) {
        // Merge with existing attachments
        final existingAttachments = existing.devCompletedAttachments ?? [];
        final mergedAttachments = [...existingAttachments, ...attachments];
        updates['dev_completed_attachments'] = jsonEncode(mergedAttachments);
      }

      if (updates.isEmpty) {
        return existing;
      }

      updates['updated_by'] = employeeId;
      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE task_cards 
        SET $setClause
        WHERE task_id = @id AND is_deleted = FALSE
        RETURNING *
      ''';
      updates['id'] = taskId;

      final result = await DatabaseConnection.queryOne(sql, values: updates);
      if (result == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      final updatedTask = TaskCard.fromMap(result);

      // Log the notes update
      await _createTaskLog(
        taskId,
        'Notes Updated',
        'Task notes/attachments updated',
        employeeId,
        oldValue: {
          'dev_notes': existing.devNotes,
          'qc_notes': existing.qcNotes,
          'attachments_count': existing.devCompletedAttachments?.length ?? 0,
        },
        newValue: {
          'dev_notes': devNotes ?? existing.devNotes,
          'qc_notes': qcNotes ?? existing.qcNotes,
          'attachments_count': attachments?.length ?? 0,
        },
      );

      return updatedTask;
    } catch (e, stackTrace) {
      _logger.error('Error adding task notes: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Future<void> _createTaskLog(
    String taskId,
    String actionName,
    String description,
    String actionedBy, {
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    try {
      final sql = '''
        INSERT INTO task_card_logs (
          task_id, action_name, action_description, 
          actioned_by, actioned_datetime, old_value, new_value
        )
        VALUES (
          @taskId, @actionName, @description, 
          @actionedBy, NOW(), @oldValue::jsonb, @newValue::jsonb
        )
      ''';
      await DatabaseConnection.execute(
        sql,
        values: {
          'taskId': taskId,
          'actionName': actionName,
          'description': description,
          'actionedBy': actionedBy,
          'oldValue': oldValue != null ? jsonEncode(oldValue) : null,
          'newValue': newValue != null ? jsonEncode(newValue) : null,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error creating task log: $e', e, stackTrace);
    }
  }

  void _validateTaskCardData(Map<String, dynamic> data) {
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

    // Validate date range
    if (data['from_date'] != null && data['to_date'] != null) {
      final fromDate = DateTime.tryParse(data['from_date'].toString());
      final toDate = DateTime.tryParse(data['to_date'].toString());
      if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
        errors['from_date'] = ['From date must be before or equal to To date'];
      }
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  /// Validates that an employee exists in the database
  Future<void> _validateEmployeeExists(String employeeId) async {
    try {
      final sql = '''
        SELECT 1 FROM employees
        WHERE employee_id = @employeeId AND status = 1
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'employeeId': employeeId},
      );

      if (result == null) {
        throw ValidationException({
          'employee_id': ['Employee not found'],
        });
      }
    } catch (e) {
      if (e is ValidationException) rethrow;
      _logger.warning('Error validating employee exists: $e');
    }
  }

  Future<void> _validateEmployeeBelongsToProject(
    String employeeId,
    String projectId,
  ) async {
    // First, validate that the employee exists in the employees table
    await _validateEmployeeExists(employeeId);

    try {
      final sql = '''
        SELECT 1 FROM projects 
        WHERE project_id = @projectId 
        AND (
          project_manager_id = @employeeId 
          OR project_team_leader_id = @employeeId
          OR project_team_member_ids::jsonb ? @employeeId
        )
      ''';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'projectId': projectId, 'employeeId': employeeId},
      );

      if (result == null) {
        throw ValidationException({
          'employee_id': ['Employee does not belong to the selected project'],
        });
      }
    } catch (e) {
      if (e is ValidationException) rethrow;
      // If query fails (e.g., projects table doesn't exist), skip validation
      _logger.warning('Skipping project-employee validation: $e');
    }
  }

  // ==========================================
  // SEARCH & FILTER METHODS
  // ==========================================

  /// Search task cards across task name, employee name, project name
  Future<List<TaskCard>> searchTaskCards(String query, {int limit = 50}) async {
    try {
      final sql = TaskCardQueryBuilder.searchTaskCardsQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'query': '%$query%', 'limit': limit},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error searching task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task cards for a specific date (calendar view)
  Future<List<TaskCard>> getTaskCardsByDate(DateTime date) async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCardsByDateQuery();
      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date.toIso8601String().split('T')[0]},
      );
      return results.map((row) => TaskCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting tasks by date: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task count by status (for kanban headers)
  Future<Map<String, int>> getTaskCountByStatus() async {
    try {
      final sql = TaskCardQueryBuilder.getTaskCountByStatusQuery();
      final results = await DatabaseConnection.query(sql);

      final counts = <String, int>{};
      for (final row in results) {
        counts[row['workflow_status'] as String] = (row['count'] as num)
            .toInt();
      }
      return counts;
    } catch (e, stackTrace) {
      _logger.error('Error getting task count by status: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> qaApproveTask({
    required String taskId,
    required String userId,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final result = await DatabaseConnection.query(
        '''
        UPDATE task_cards
        SET workflow_status = 'Work Done',
            qc_started_at = @qcStartedAt,
            qc_completed_at = @qcCompletedAt,
            qc_notes = @notes,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE task_id = @taskId
        RETURNING task_id
        ''',
        values: {
          'taskId': taskId,
          'qcStartedAt': now.toIso8601String(),
          'qcCompletedAt': now.toIso8601String(),
          'notes': notes ?? '',
          'updatedAt': now.toIso8601String(),
          'updatedBy': userId,
        },
      );

      if (result.isNotEmpty) {
        await _createTaskLog(
          taskId,
          'QA_APPROVE',
          'QA Approved task. Notes: $notes',
          userId,
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error in qaApproveTask: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> qaDisapproveTask({
    required String taskId,
    required String userId,
    required String notes,
  }) async {
    try {
      final now = DateTime.now();
      final result = await DatabaseConnection.query(
        '''
        UPDATE task_cards
        SET workflow_status = 'Redo',
            qc_started_at = @qcStartedAt,
            qc_notes = @notes,
            status_reason = @statusReason,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE task_id = @taskId
        RETURNING task_id
        ''',
        values: {
          'taskId': taskId,
          'qcStartedAt': now.toIso8601String(),
          'notes': notes,
          'statusReason': 'QA Disapproved: $notes',
          'updatedAt': now.toIso8601String(),
          'updatedBy': userId,
        },
      );

      if (result.isNotEmpty) {
        await _createTaskLog(
          taskId,
          'QA_DISAPPROVE',
          'QA Disapproved task. Notes: $notes',
          userId,
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error in qaDisapproveTask: $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Start Task (Move to In QC)
  Future<bool> qaStartTask({
    required String taskId,
    required String userId,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final result = await DatabaseConnection.query(
        '''
        UPDATE task_cards
        SET workflow_status = 'In QC',
            qc_started_at = @qcStartedAt,
            qc_notes = @notes,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE task_id = @taskId
        RETURNING task_id
        ''',
        values: {
          'taskId': taskId,
          'qcStartedAt': now.toIso8601String(),
          'notes': notes,
          'updatedAt': now.toIso8601String(),
          'updatedBy': userId,
        },
      );

      if (result.isNotEmpty) {
        await _createTaskLog(
          taskId,
          'QA_START',
          'QA Started task. Notes: $notes',
          userId,
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error in qaStartTask: $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Complete Task (Move to Work Done, with attachments)
  Future<bool> qaCompleteTask({
    required String taskId,
    required String userId,
    String? notes,
    List<String>? attachments,
  }) async {
    try {
      final now = DateTime.now();
      final result = await DatabaseConnection.query(
        '''
        UPDATE task_cards
        SET workflow_status = 'Work Done',
            qc_completed_at = @qcCompletedAt,
            qc_notes = @notes,
            qc_completed_attachments = @attachments,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE task_id = @taskId
        RETURNING task_id
        ''',
        values: {
          'taskId': taskId,
          'qcCompletedAt': now.toIso8601String(),
          'notes': notes,
          'attachments': attachments != null ? jsonEncode(attachments) : null,
          'updatedAt': now.toIso8601String(),
          'updatedBy': userId,
        },
      );

      if (result.isNotEmpty) {
        await _createTaskLog(
          taskId,
          'QA_COMPLETE',
          'QA Completed task. Notes: $notes',
          userId,
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error in qaCompleteTask: $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Redo Task (Move to Redo, with attachments)
  Future<bool> qaRedoTask({
    required String taskId,
    required String userId,
    required String notes,
    List<String>? attachments,
  }) async {
    try {
      final now = DateTime.now();
      final result = await DatabaseConnection.query(
        '''
        UPDATE task_cards
        SET workflow_status = 'Redo',
            qc_notes = @notes,
            qc_completed_attachments = @attachments,
            status_reason = @statusReason,
            updated_at = @updatedAt,
            updated_by = @updatedBy
        WHERE task_id = @taskId
        RETURNING task_id
        ''',
        values: {
          'taskId': taskId,
          'notes': notes,
          'attachments': attachments != null ? jsonEncode(attachments) : null,
          'statusReason': 'QA Redo: $notes',
          'updatedAt': now.toIso8601String(),
          'updatedBy': userId,
        },
      );

      if (result.isNotEmpty) {
        await _createTaskLog(
          taskId,
          'QA_REDO',
          'QA Set Redo. Reason: $notes',
          userId,
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error in qaRedoTask: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // DELAYED TASK CARDS (overdue + overtime)
  // ==========================================

  /// Get count of delayed task cards (to_date passed, status still In Progress or Redo).
  Future<int> getDelayedTaskCardsCount() async {
    try {
      final result = await DatabaseConnection.queryOne('''
        SELECT COUNT(*) as total
        FROM task_cards tc
        WHERE (tc.is_deleted IS NULL OR tc.is_deleted = FALSE)
          AND tc.to_date IS NOT NULL
          AND tc.to_date::date < CURRENT_DATE
          AND tc.workflow_status IN ('In Progress', 'Redo')
        ''');
      return (result?['total'] as num?)?.toInt() ?? 0;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting delayed task cards count: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get delayed task cards with details (filtered and paginated).
  Future<Map<String, dynamic>> getDelayedTaskCardsWithDetails({
    bool includeOvertimeOnly = false,
    int page = 1,
    int limit = 10,
    String? search,
    String? employeeId,
    String? projectId,
    DateTime? month,
  }) async {
    try {
      final params = <String, dynamic>{};
      final conditions = <String>[
        '(tc.is_deleted IS NULL OR tc.is_deleted = FALSE)',
        'tc.to_date IS NOT NULL',
        'tc.to_date::date < CURRENT_DATE',
        "tc.workflow_status IN ('In Progress', 'Redo')",
      ];

      if (employeeId != null && employeeId.isNotEmpty) {
        conditions.add('tc.employee_id = @employeeId');
        params['employeeId'] = employeeId;
      }

      if (projectId != null && projectId.isNotEmpty) {
        conditions.add('tc.project_id = @projectId');
        params['projectId'] = projectId;
      }

      if (month != null) {
        conditions.add(
          'EXTRACT(MONTH FROM tc.to_date) = @monthVal AND EXTRACT(YEAR FROM tc.to_date) = @yearVal',
        );
        params['monthVal'] = month.month;
        params['yearVal'] = month.year;
      }

      if (search != null && search.isNotEmpty) {
        conditions.add(
          '(tc.task_name ILIKE @search OR p.project_name ILIKE @search OR e.employee_name ILIKE @search)',
        );
        params['search'] = '%$search%';
      }

      final whereClause = conditions.join(' AND ');

      final sql =
          '''
        SELECT
          tc.task_id,
          tc.task_name,
          tc.task_description,
          tc.task_duration,
          tc.from_date,
          tc.to_date,
          tc.assigned_at,
          tc.workflow_status,
          tc.employee_id,
          tc.project_id,
          tc.created_by,
          json_build_object(
            'employee_id', e.employee_id,
            'employee_name', e.employee_name,
            'employee_personal_email', e.employee_personal_email,
            'employee_role', e.employee_role,
            'employee_img', e.employee_img
          ) as employee_details,
          json_build_object(
            'project_id', p.project_id,
            'project_name', p.project_name
          ) as project_details,
          json_build_object(
            'id', COALESCE(ab_admin.admin_id, ab_emp.employee_id),
            'name', COALESCE(ab_admin.admin_name, ab_emp.employee_name),
            'email', COALESCE(ab_admin.admin_personal_email, ab_emp.employee_personal_email),
            'role', COALESCE(ab_admin.admin_role, ab_emp.employee_role),
            'profile_image', COALESCE(ab_admin.admin_img, ab_emp.employee_img)
          ) as assigned_by_details
        FROM task_cards tc
        LEFT JOIN employees e ON tc.employee_id = e.employee_id
        LEFT JOIN projects p ON tc.project_id = p.project_id
        LEFT JOIN admins ab_admin ON tc.created_by::text = ab_admin.admin_id::text
        LEFT JOIN employees ab_emp ON tc.created_by::text = ab_emp.employee_id::text
        WHERE $whereClause
        ORDER BY tc.to_date ASC
      ''';

      final rows = await DatabaseConnection.query(sql, values: params);

      // If no matching rows from DB filters, return empty early
      if (rows.isEmpty) {
        return {
          'data': <Map<String, dynamic>>[],
          'total': 0,
          'page': page,
          'limit': limit,
        };
      }

      final taskIds = rows
          .map((r) => r['task_id']?.toString())
          .whereType<String>()
          .toList();
      final hoursByTask = await _timeTrackingRepository.getTotalHoursByTaskIds(
        taskIds,
      );

      final processedList = <Map<String, dynamic>>[];
      for (final row in rows) {
        final taskId = row['task_id']?.toString();
        if (taskId == null) continue;

        final fromDate = row['from_date'] != null
            ? DateTime.tryParse(row['from_date'].toString())
            : null;
        final toDate = row['to_date'] != null
            ? DateTime.tryParse(row['to_date'].toString())
            : null;
        final totalTimeTaken = hoursByTask[taskId] ?? 0.0;
        final totalTimeGiven = TaskDurationHelper.getAllocatedHours(
          taskDuration: row['task_duration']?.toString(),
          fromDate: fromDate,
          toDate: toDate,
        );
        final hoursExtra = (totalTimeTaken - totalTimeGiven) > 0
            ? (totalTimeTaken - totalTimeGiven)
            : 0.0;

        if (includeOvertimeOnly && hoursExtra <= 0) continue;

        // Helper to format date
        String formatDate(DateTime? dt) {
          if (dt == null) return 'Unknown Date';
          return '${dt.day}/${dt.month}/${dt.year}';
        }

        final assignedByMap =
            row['assigned_by_details'] as Map<String, dynamic>?;
        final assignerName = assignedByMap?['name'] ?? 'Unknown Admin';
        final assignerRole = assignedByMap?['role'];

        final employeeMap = row['employee_details'] as Map<String, dynamic>?;
        final employeeName =
            employeeMap?['employee_name'] ?? 'Unknown Employee';

        final taskName = row['task_name']?.toString() ?? 'Untitled Task';
        final projectName =
            (row['project_details'] is Map
                    ? (row['project_details'] as Map)['project_name']
                    : 'Unknown Project')
                ?.toString();

        final assignedAtStr = row['assigned_at']?.toString();
        final assignedDate = assignedAtStr != null
            ? formatDate(DateTime.tryParse(assignedAtStr))
            : 'Unknown Date';

        final fromDateStr = formatDate(fromDate);
        final toDateStr = formatDate(toDate);

        // Construct detailed message
        final sb = StringBuffer();

        // Assigner part
        sb.write('$assignerName');
        if (assignerRole != null && assignerRole.toString().isNotEmpty) {
          sb.write(' ($assignerRole)');
        }
        sb.write(' assigned the task "$taskName"');

        // Project part
        if (projectName != null && projectName != 'Unknown Project') {
          sb.write(' for project "$projectName"');
        }

        // Employee and Dates part
        sb.write(' to $employeeName on $assignedDate.');
        sb.write(
          ' The task was scheduled to start on $fromDateStr and complete by $toDateStr.',
        );

        // Status part
        if (hoursExtra > 0) {
          sb.write(
            ' However, the task has exceeded the allocated time by ${hoursExtra.toStringAsFixed(1)} hours.',
          );
        } else if (toDate != null) {
          final now = DateTime.now();
          final endOfDueDate = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            23,
            59,
            59,
          );
          if (now.isAfter(endOfDueDate)) {
            final daysLate = now.difference(endOfDueDate).inDays;
            sb.write(
              ' As of today, the task is still incomplete and is overdue by ${daysLate == 0 ? "less than 24 hours" : "$daysLate days"}.',
            );
          } else {
            sb.write(' The task is currently in progress.');
          }
        }

        processedList.add({
          'task_id': taskId,
          'task_name': row['task_name']?.toString(),
          'task_description': row['task_description']?.toString(),
          'project_id': row['project_id']?.toString(),
          'project_name': projectName,
          'assigned_at': row['assigned_at']?.toString(),
          'from_date': row['from_date']?.toString(),
          'to_date': row['to_date']?.toString(),
          'assigned_by': row['assigned_by_details'],
          'total_time_given_hours': totalTimeGiven,
          'total_time_taken_hours': totalTimeTaken,
          'hours_extra': hoursExtra,
          'employee': row['employee_details'] is Map
              ? row['employee_details'] as Map<String, dynamic>
              : null,
          'workflow_status': row['workflow_status']?.toString(),
          'delay_reason': sb.toString(),
        });
      }

      final totalCount = processedList.length;
      final startIndex = (page - 1) * limit;

      // Handle page out of bounds
      if (startIndex >= totalCount && totalCount > 0) {
        // Optionally you could return empty or adjust page, staying safe with empty list
        return {
          'data': <Map<String, dynamic>>[],
          'total': totalCount,
          'page': page,
          'limit': limit,
        };
      }

      final endIndex = (startIndex + limit) > totalCount
          ? totalCount
          : (startIndex + limit);
      final paginatedList = totalCount > 0
          ? processedList.sublist(startIndex, endIndex)
          : <Map<String, dynamic>>[];

      return {
        'data': paginatedList,
        'total': totalCount,
        'page': page,
        'limit': limit,
      };
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting delayed task cards with details: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Helper to save task attachments to table
  Future<void> _saveTaskAttachments(
    String taskId,
    List<dynamic> attachments,
    String createdBy,
  ) async {
    if (attachments.isEmpty) return;

    for (final attachment in attachments) {
      if (attachment is Map<String, dynamic>) {
        await DatabaseConnection.queryOne(
          '''
            INSERT INTO task_attachments (
              task_id, attachment_type, title, url, created_by
            ) VALUES (
              @taskId, @type, @title, @url, @createdBy
            )
          ''',
          values: {
            'taskId': taskId,
            'type': attachment['attachment_type'] ?? 'file',
            'title': attachment['name'] ?? attachment['title'] ?? 'Untitled',
            'url': attachment['url'],
            'createdBy': createdBy,
          },
        );
      }
    }
  }

  /// Export delayed tasks to Excel
  Future<List<int>?> exportDelayedTaskCards({
    bool includeOvertimeOnly = false,
    String? search,
    String? employeeId,
    String? projectId,
    DateTime? month,
  }) async {
    try {
      final result = await getDelayedTaskCardsWithDetails(
        includeOvertimeOnly: includeOvertimeOnly,
        page: 1,
        limit: 10000,
        search: search,
        employeeId: employeeId,
        projectId: projectId,
        month: month,
      );

      final data = result['data'] as List<dynamic>;

      final excel = Excel.createExcel();
      final sheet = excel['Delayed Tasks'];
      excel.setDefaultSheet('Delayed Tasks');

      // Headers
      sheet.appendRow([
        TextCellValue('S.No'),
        TextCellValue('Task Name'),
        TextCellValue('Project'),
        TextCellValue('Employee'),
        TextCellValue('Assigned Date'),
        TextCellValue('Status'),
        TextCellValue('Given Hours'),
        TextCellValue('Taken Hours'),
        TextCellValue('Extra Hours'),
        TextCellValue('Reason'),
      ]);

      int index = 1;
      for (final item in data) {
        final task = item as Map<String, dynamic>;
        final employee = task['employee'] as Map<String, dynamic>?;

        sheet.appendRow([
          IntCellValue(index++),
          TextCellValue(task['task_name']?.toString() ?? ''),
          TextCellValue(task['project_name']?.toString() ?? ''),
          TextCellValue(employee?['employee_name']?.toString() ?? ''),
          TextCellValue(task['assigned_at']?.toString() ?? ''),
          TextCellValue(task['workflow_status']?.toString() ?? ''),
          DoubleCellValue(
            double.tryParse(
                  task['total_time_given_hours']?.toString() ?? '0',
                ) ??
                0.0,
          ),
          DoubleCellValue(
            double.tryParse(
                  task['total_time_taken_hours']?.toString() ?? '0',
                ) ??
                0.0,
          ),
          DoubleCellValue(
            double.tryParse(task['hours_extra']?.toString() ?? '0') ?? 0.0,
          ),
          TextCellValue(task['delay_reason']?.toString() ?? ''),
        ]);
      }

      return excel.encode();
    } catch (e, stackTrace) {
      _logger.error('Error exporting delayed tasks', e, stackTrace);
      rethrow;
    }
  }
}
