import '../data/repositories/task_card_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../domain/models/task_card.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

import 'unified_notification_service.dart';

/// TaskCard service for business logic
/// Provides proper naming conventions and business logic layer
class TaskCardService {
  final TaskCardRepository _repository = TaskCardRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('TaskCardService');

  // ==========================================
  // ADMIN - TASK CARD OPERATIONS
  // ==========================================

  /// Get all task cards with pagination and filters
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
    String? excludeWorkflowStatus,
    List<String>? workflowStatusIn,
    bool isDevStarted = false,
    String? excludeTaskId,
  }) async {
    try {
      return await _repository.getAllTaskCards(
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
    } catch (e, stackTrace) {
      _logger.error('Error getting all task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get delayed task cards count (for home section).
  Future<int> getDelayedTaskCardsCount() async {
    try {
      return await _repository.getDelayedTaskCardsCount();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting delayed task cards count: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get delayed task cards with details (for admin dialog).
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
      return await _repository.getDelayedTaskCardsWithDetails(
        includeOvertimeOnly: includeOvertimeOnly,
        page: page,
        limit: limit,
        search: search,
        employeeId: employeeId,
        projectId: projectId,
        month: month,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting delayed task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task card by ID
  Future<TaskCard> getTaskCardById(String taskId) async {
    try {
      final taskCard = await _repository.getTaskCardById(taskId);
      if (taskCard == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }
      return taskCard;
    } catch (e, stackTrace) {
      _logger.error('Error getting task card by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create new task card
  Future<TaskCard> createNewTaskCard(
    Map<String, dynamic> data,
    String createdBy,
  ) async {
    try {
      final taskCard = await _repository.createNewTaskCard(data, createdBy);

      // Send push notifications in background - do not block response
      final card = taskCard;
      Future(() async {
        try {
          String empName = 'Employee';
          String empEmail = '';
          if (card.employeeId != null && card.employeeId!.isNotEmpty) {
            final emp = await _employeeRepository.getById(card.employeeId!);
            if (emp != null) {
              empName = emp.employeeName;
              empEmail = emp.employeePersonalEmail.isNotEmpty
                  ? emp.employeePersonalEmail
                  : emp.employeeCompanyEmail;
            }
          }

          if (card.employeeId != null && card.employeeId!.isNotEmpty) {
            // Fetch full task card for project details
            final fullCard =
                (await _repository.getTaskCardById(card.taskId)) ?? card;

            await UnifiedNotificationService.notifyTaskCreated(
              taskId: card.taskId,
              taskName: card.taskName ?? 'New Task',
              projectName:
                  fullCard.projectDetails?['project_name']?.toString() ??
                  'Unknown',
              employeeId: card.employeeId!,
              employeeName: empName,
              employeeEmail: empEmail,
              assignedById: createdBy,
            );
          }
        } catch (e) {
          _logger.warning('Failed to send task creation notification: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Task creation notifications error: $e');
      });

      return taskCard;
    } catch (e, stackTrace) {
      _logger.error('Error creating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update task card
  Future<TaskCard> updateTaskCard(
    String taskId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      final taskCard = await _repository.updateTaskCard(
        taskId,
        updates,
        updatedBy,
      );

      // Send notifications in background - do not block response
      final card = taskCard;
      final updatedByUser = updatedBy;
      Future(() async {
        try {
          String empName = 'Employee';
          String empEmail = '';
          if (card.employeeId != null && card.employeeId!.isNotEmpty) {
            final emp = await _employeeRepository.getById(card.employeeId!);
            if (emp != null) {
              empName = emp.employeeName;
              empEmail = emp.employeePersonalEmail.isNotEmpty
                  ? emp.employeePersonalEmail
                  : emp.employeeCompanyEmail;
            }

            // Fetch full task card for project details
            final fullCard =
                (await _repository.getTaskCardById(card.taskId)) ?? card;

            await UnifiedNotificationService.notifyTaskUpdated(
              taskId: card.taskId,
              taskName: card.taskName ?? 'Task',
              projectName:
                  fullCard.projectDetails?['project_name']?.toString() ??
                  'Unknown',
              employeeId: card.employeeId!,
              employeeName: empName,
              updatedById: updatedByUser,
              employeeEmail: empEmail,
              taskDescription: card.taskDescription,
              taskType: card.taskType,
              priorityLevel: card.priorityLevel,
              fromDate: card.fromDate?.toString().split(' ').first,
              toDate: card.toDate?.toString().split(' ').first,
              taskDuration: card.taskDuration,
            );
          }
        } catch (e) {
          _logger.warning('Failed to send task update notification: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Task update notifications error: $e');
      });

      return taskCard;
    } catch (e, stackTrace) {
      _logger.error('Error updating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete task card (soft delete)
  Future<bool> deleteTaskCard(String taskId, String deletedBy) async {
    try {
      // Get task card details before deletion
      final taskCard = await getTaskCardById(taskId);

      final deleted = await _repository.deleteTaskCard(taskId, deletedBy);

      // Send notifications in background - do not block response
      if (deleted) {
        final card = taskCard;
        final deletedByUser = deletedBy;
        Future(() async {
          try {
            String empName = 'Employee';
            String empEmail = '';
            if (card.employeeId != null && card.employeeId!.isNotEmpty) {
              final emp = await _employeeRepository.getById(card.employeeId!);
              if (emp != null) {
                empName = emp.employeeName;
                empEmail = emp.employeePersonalEmail.isNotEmpty
                    ? emp.employeePersonalEmail
                    : emp.employeeCompanyEmail;
              }

              await UnifiedNotificationService.notifyTaskDeleted(
                taskId: card.taskId,
                taskName: card.taskName ?? 'Task',
                projectName:
                    card.projectDetails?['project_name']?.toString() ??
                    'Unknown',
                employeeId: card.employeeId!,
                employeeName: empName,
                deletedById: deletedByUser,
                reason: 'Task deleted by admin',
                employeeEmail: empEmail,
              );
            }
          } catch (e) {
            _logger.warning('Failed to send task deletion notifications: $e');
          }
        }).catchError((e, st) {
          _logger.warning('Task deletion notifications error: $e');
        });
      }

      return deleted;
    } catch (e, stackTrace) {
      _logger.error('Error deleting task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Duplicate task card to multiple employees
  Future<List<TaskCard>> duplicateTaskCard(
    String taskId,
    List<String> employeeIds,
    String duplicatedBy, {
    List<dynamic>? newAttachments,
    Map<String, dynamic>? overrides,
  }) async {
    try {
      // Validate employee list
      if (employeeIds.isEmpty) {
        throw ValidationException({
          'employee_ids': ['At least one employee is required'],
        });
      }

      // Get original task card for notifications
      final originalTask = await getTaskCardById(taskId);
      final taskName =
          overrides?['task_name']?.toString() ??
          originalTask.taskName ??
          'Task';

      final duplicatedTasks = await _repository.duplicateTaskCard(
        taskId,
        employeeIds,
        duplicatedBy,
        newAttachments: newAttachments,
        overrides: overrides,
      );

      // Send notifications in background - do not block response
      final tasks = duplicatedTasks;
      final taskNameStr = taskName;
      final duplicatedByUser = duplicatedBy;
      final original = originalTask;
      Future(() async {
        try {
          for (final duplicatedTask in tasks) {
            if (duplicatedTask.employeeId != null &&
                duplicatedTask.employeeId!.isNotEmpty) {
              String empName = 'Employee';
              String empEmail = '';
              final emp = await _employeeRepository.getById(
                duplicatedTask.employeeId!,
              );
              if (emp != null) {
                empName = emp.employeeName;
                empEmail = emp.employeePersonalEmail.isNotEmpty
                    ? emp.employeePersonalEmail
                    : emp.employeeCompanyEmail;
              }

              // Fetch full task card for project details
              final fullCard =
                  (await _repository.getTaskCardById(duplicatedTask.taskId)) ??
                  duplicatedTask;

              await UnifiedNotificationService.notifyTaskDuplicated(
                taskId: duplicatedTask.taskId,
                taskName: taskNameStr,
                originalTaskName: original.taskName ?? 'Task',
                projectName:
                    fullCard.projectDetails?['project_name']?.toString() ??
                    'Unknown',
                employeeId: duplicatedTask.employeeId!,
                employeeName: empName,
                duplicatedById: duplicatedByUser,
                employeeEmail: empEmail,
                taskDescription: duplicatedTask.taskDescription,
                taskType: duplicatedTask.taskType,
                priorityLevel: duplicatedTask.priorityLevel,
                fromDate: duplicatedTask.fromDate?.toString().split(' ').first,
                toDate: duplicatedTask.toDate?.toString().split(' ').first,
                taskDuration: duplicatedTask.taskDuration,
              );
            }
          }
        } catch (e) {
          _logger.warning('Failed to send task duplication notifications: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Task duplication notifications error: $e');
      });

      return duplicatedTasks;
    } catch (e, stackTrace) {
      _logger.error('Error duplicating task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Reassign task card to another employee
  Future<TaskCard> reassignTaskCard(
    String taskId,
    String newEmployeeId,
    String reason,
    String reassignedBy,
  ) async {
    try {
      // Validate inputs
      if (newEmployeeId.isEmpty) {
        throw ValidationException({
          'new_employee_id': ['New employee ID is required'],
        });
      }

      // Get original task card to get old employee ID
      final originalTask = await getTaskCardById(taskId);
      final oldEmployeeId = originalTask.employeeId;

      final reassignedTask = await _repository.reassignTaskCard(
        taskId,
        newEmployeeId,
        reason,
        reassignedBy,
      );

      // Send notifications in background - do not block response
      final task = reassignedTask;
      final reasonStr = reason;
      final reassignedByUser = reassignedBy;
      Future(() async {
        try {
          String newEmpName = 'Employee';
          String oldEmpName = 'Previous Employee';

          final newEmp = await _employeeRepository.getById(newEmployeeId);
          if (newEmp != null) newEmpName = newEmp.employeeName;

          if (oldEmployeeId != null) {
            final oldEmp = await _employeeRepository.getById(oldEmployeeId);
            if (oldEmp != null) oldEmpName = oldEmp.employeeName;
          }

          // Fetch emails for reassign notification
          String newEmpEmail = '';
          String oldEmpEmail = '';

          if (newEmp != null) {
            newEmpEmail = newEmp.employeePersonalEmail.isNotEmpty
                ? newEmp.employeePersonalEmail
                : newEmp.employeeCompanyEmail;
          }

          if (oldEmployeeId != null) {
            final oldEmp = await _employeeRepository.getById(oldEmployeeId);
            if (oldEmp != null && oldEmployeeId != newEmployeeId) {
              oldEmpEmail = oldEmp.employeePersonalEmail.isNotEmpty
                  ? oldEmp.employeePersonalEmail
                  : oldEmp.employeeCompanyEmail;
            }
          }

          // Fetch full task card for project details
          final fullCard = (await _repository.getTaskCardById(taskId)) ?? task;

          await UnifiedNotificationService.notifyTaskReassigned(
            taskId: taskId,
            taskName: task.taskName ?? 'Task',
            projectName:
                fullCard.projectDetails?['project_name']?.toString() ??
                'Unknown',
            newEmployeeId: newEmployeeId,
            newEmployeeName: newEmpName,
            oldEmployeeId: oldEmployeeId,
            oldEmployeeName: oldEmpName,
            reassignedById: reassignedByUser,
            reason: reasonStr,
            newEmployeeEmail: newEmpEmail,
            oldEmployeeEmail: oldEmpEmail,
            taskDescription: task.taskDescription,
            taskType: task.taskType,
            priorityLevel: task.priorityLevel,
            fromDate: task.fromDate?.toString().split(' ').first,
            toDate: task.toDate?.toString().split(' ').first,
            taskDuration: task.taskDuration,
          );
        } catch (e) {
          _logger.warning('Failed to send task reassignment notifications: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Task reassignment notifications error: $e');
      });

      return reassignedTask;
    } catch (e, stackTrace) {
      _logger.error('Error reassigning task card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update task card status only
  Future<TaskCard> updateTaskCardStatusById(
    String taskId,
    String workflowStatus,
    String updatedBy,
  ) async {
    try {
      // Validate workflow status
      final validStatuses = [
        'TODO',
        'In Progress',
        'Dev Completed',
        'In QC',
        'Work Done',
        'Redo',
      ];

      if (!validStatuses.contains(workflowStatus)) {
        throw ValidationException({
          'workflow_status': [
            'Invalid status. Valid values: ${validStatuses.join(', ')}',
          ],
        });
      }

      return await _repository.updateTaskCardStatusById(
        taskId,
        workflowStatus,
        updatedBy,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating task card status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task cards by employee ID
  Future<List<TaskCard>> getTaskCardsByEmployeeId(String employeeId) async {
    try {
      return await _repository.getTaskCardsByEmployeeId(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting task cards by employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task card logs
  Future<List<TaskCardLog>> getTaskCardLogs(String taskId) async {
    try {
      // Verify task exists
      final task = await _repository.getTaskCardById(taskId);
      if (task == null) {
        throw NotFoundException(resource: 'TaskCard', id: taskId);
      }

      return await _repository.getTaskCardLogs(taskId);
    } catch (e, stackTrace) {
      _logger.error('Error getting task card logs: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TASK CARD OPERATIONS
  // ==========================================

  /// Get employee's task cards
  Future<List<TaskCard>> getEmployeeTaskCards(String employeeId) async {
    try {
      return await _repository.getEmployeeTaskCards(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting employee task cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Employee accepts or rejects task
  Future<TaskCard> updateEmployeeTaskDecision(
    String taskId,
    String employeeId,
    int status,
    String? reason,
  ) async {
    try {
      // Validate status
      if (status != 1 && status != 2) {
        throw ValidationException({
          'status': ['Status must be 1 (accept) or 2 (reject)'],
        });
      }

      // Require reason for rejection
      if (status == 2 && (reason == null || reason.isEmpty)) {
        throw ValidationException({
          'reason': ['Reason is required when rejecting a task'],
        });
      }

      return await _repository.updateEmployeeTaskDecision(
        taskId,
        employeeId,
        status,
        reason,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating employee task decision: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Employee starts/pauses/completes task
  Future<Map<String, dynamic>> updateEmployeeWorkStatus(
    String taskId,
    String employeeId,
    int employeeTaskStatus,
  ) async {
    try {
      // Validate status
      final validStatuses = [3, 4, 5]; // 3=started, 4=paused, 5=completed
      if (!validStatuses.contains(employeeTaskStatus)) {
        throw ValidationException({
          'employee_task_status': [
            'Status must be 3 (started), 4 (paused), or 5 (completed)',
          ],
        });
      }

      return await _repository.updateEmployeeWorkStatus(
        taskId,
        employeeId,
        employeeTaskStatus,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating employee work status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add dev/qc notes and attachments
  Future<TaskCard> addTaskNotes(
    String taskId,
    String employeeId,
    String? devNotes,
    String? qcNotes,
    List<dynamic>? attachments,
  ) async {
    try {
      return await _repository.addTaskNotes(
        taskId,
        employeeId,
        devNotes,
        qcNotes,
        attachments,
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding task notes: $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Approve Task
  Future<bool> qaApproveTask({
    required String taskId,
    required String userId,
    String? notes,
  }) async {
    try {
      final ok = await _repository.qaApproveTask(
        taskId: taskId,
        userId: userId,
        notes: notes,
      );
      if (ok) {
        _sendQaApprovedNotifications(taskId, userId, notes);
      }
      return ok;
    } catch (e, stackTrace) {
      _logger.error('Error approving task (QA): $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Disapprove Task
  Future<bool> qaDisapproveTask({
    required String taskId,
    required String userId,
    required String notes,
  }) async {
    try {
      final ok = await _repository.qaDisapproveTask(
        taskId: taskId,
        userId: userId,
        notes: notes,
      );
      if (ok) {
        _sendQaRejectedNotifications(taskId, userId, notes);
      }
      return ok;
    } catch (e, stackTrace) {
      _logger.error('Error disapproving task (QA): $e', e, stackTrace);
      rethrow;
    }
  }

  void _sendQaApprovedNotifications(
    String taskId,
    String approvedBy,
    String? notes,
  ) async {
    try {
      final task = await getTaskCardById(taskId);
      final employeeId = task.employeeId;
      if (employeeId == null || employeeId.isEmpty) return;
      final emp = await _employeeRepository.getById(employeeId);
      final email = emp?.employeeCompanyEmail.isNotEmpty == true
          ? emp!.employeeCompanyEmail
          : emp?.employeePersonalEmail;
      final projectName =
          task.projectDetails?['project_name']?.toString() ?? 'Unknown';
      final taskName = task.taskName ?? 'Task';
      if (email != null && email.isNotEmpty && emp != null) {
        await UnifiedNotificationService.notifyTaskQaApproved(
          taskId: taskId,
          taskName: taskName,
          projectName: projectName,
          employeeId: employeeId,
          employeeName: emp.employeeName,
          employeeEmail: email,
          approvedById: approvedBy,
          notes: notes,
        );
      }
    } catch (e) {
      _logger.warning('Failed to send QA approved notifications: $e');
    }
  }

  void _sendQaRejectedNotifications(
    String taskId,
    String rejectedBy,
    String notes,
  ) async {
    try {
      final task = await getTaskCardById(taskId);
      final employeeId = task.employeeId;
      if (employeeId == null || employeeId.isEmpty) return;
      final emp = await _employeeRepository.getById(employeeId);
      final email = emp?.employeeCompanyEmail.isNotEmpty == true
          ? emp!.employeeCompanyEmail
          : emp?.employeePersonalEmail;
      final projectName =
          task.projectDetails?['project_name']?.toString() ?? 'Unknown';
      final taskName = task.taskName ?? 'Task';
      if (email != null && email.isNotEmpty && emp != null) {
        await UnifiedNotificationService.notifyTaskQaRejected(
          taskId: taskId,
          taskName: taskName,
          projectName: projectName,
          employeeId: employeeId,
          employeeName: emp.employeeName,
          employeeEmail: email,
          rejectedById: rejectedBy,
          notes: notes,
        );
      }
    } catch (e) {
      _logger.warning('Failed to send QA rejected notifications: $e');
    }
  }

  /// QA Start Task
  Future<bool> qaStartTask({
    required String taskId,
    required String userId,
    String? notes,
  }) async {
    try {
      return await _repository.qaStartTask(
        taskId: taskId,
        userId: userId,
        notes: notes,
      );
    } catch (e, stackTrace) {
      _logger.error('Error starting task (QA): $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Complete Task
  Future<bool> qaCompleteTask({
    required String taskId,
    required String userId,
    String? notes,
    List<String>? attachments,
  }) async {
    try {
      return await _repository.qaCompleteTask(
        taskId: taskId,
        userId: userId,
        notes: notes,
        attachments: attachments,
      );
    } catch (e, stackTrace) {
      _logger.error('Error completing task (QA): $e', e, stackTrace);
      rethrow;
    }
  }

  /// QA Redo Task
  Future<bool> qaRedoTask({
    required String taskId,
    required String userId,
    required String notes,
    List<String>? attachments,
  }) async {
    try {
      return await _repository.qaRedoTask(
        taskId: taskId,
        userId: userId,
        notes: notes,
        attachments: attachments,
      );
    } catch (e, stackTrace) {
      _logger.error('Error submitting redo task (QA): $e', e, stackTrace);
      rethrow;
    }
  }
}
