import '../data/repositories/task_card_request_repository.dart';
import '../domain/models/task_card_request.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';
import '../data/repositories/employee_repository.dart';

/// TaskCardRequest service for handling request flow business logic
class TaskCardRequestService {
  final TaskCardRequestRepository _repository = TaskCardRequestRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('TaskCardRequestService');

  // ==========================================
  // ADMIN - TASK CARD REQUEST OPERATIONS
  // ==========================================

  /// Get all task card requests with filters
  Future<Map<String, dynamic>> getAllTaskCardRequests({
    int page = 1,
    int limit = 50,
    String? status,
    String? employeeId,
    String? projectId,
    String? search,
  }) async {
    try {
      return await _repository.getAllTaskCardRequests(
        page: page,
        limit: limit,
        status: status,
        employeeId: employeeId,
        projectId: projectId,
        search: search,
      );
    } catch (e) {
      _logger.error('Error in getAllTaskCardRequests service: $e');
      rethrow;
    }
  }

  /// Get task card request by ID
  Future<TaskCardRequest> getTaskCardRequestById(String requestId) async {
    try {
      final request = await _repository.getTaskCardRequestById(requestId);
      if (request == null) {
        throw NotFoundException(resource: 'TaskCardRequest', id: requestId);
      }
      return request;
    } catch (e, stackTrace) {
      _logger.error('Error getting task card request by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<TaskCardRequest> approveTaskCardRequest(
    String requestId,
    String approvedBy,
    String? remarks,
  ) async {
    try {
      final approvedRequest = await _repository.approveTaskCardRequest(
        requestId,
        approvedBy,
        remarks,
      );

      // Send push notification and email in background - do not block response
      final approved = approvedRequest;
      final empId = approved.employeeId;
      final taskName = approved.taskName ?? 'Task';
      final empRepo = _employeeRepository;
      final taskDesc = approved.taskDescription ?? 'No description';
      final taskType = approved.taskType ?? 'Task';
      final priority = approved.priorityLevel ?? 'Medium';
      final projectName =
          approved.projectDetails?['project_name']?.toString() ??
          'Unknown Project';
      final fromDate = approved.fromDate?.toString().split(' ')[0] ?? 'N/A';
      final toDate = approved.toDate?.toString().split(' ')[0] ?? 'N/A';

      Future(() async {
        try {
          final employee = await empRepo.getById(empId);
          final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
              ? employee!.employeeCompanyEmail
              : employee?.employeePersonalEmail;

          await UnifiedNotificationService.notifyTaskRequestApproved(
            requestId: requestId,
            taskName: taskName,
            employeeId: empId,
            approvedById: approvedBy,
            remarks: remarks,
            employeeEmail: empEmail,
            employeeName: employee?.employeeName,
            projectName: projectName,
            taskDescription: taskDesc,
            taskType: taskType,
            priorityLevel: priority,
            fromDate: fromDate,
            toDate: toDate,
          );
        } catch (e) {
          _logger.warning(
            'Failed to send task request approval notifications: $e',
          );
        }
      });

      return approvedRequest;
    } catch (e, stackTrace) {
      _logger.error('Error approving task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<TaskCardRequest> rejectTaskCardRequest(
    String requestId,
    String rejectedBy,
    String reason,
  ) async {
    try {
      // Validate reason is provided
      if (reason.isEmpty) {
        throw ValidationException({
          'reason': ['Reason is required when rejecting a request'],
        });
      }

      final rejectedRequest = await _repository.rejectTaskCardRequest(
        requestId,
        rejectedBy,
        reason,
      );

      // Send push notification and email in background - do not block response
      final rejected = rejectedRequest;
      final empId = rejected.employeeId;
      final taskName = rejected.taskName ?? 'Task';
      final empRepo = _employeeRepository;
      final taskDesc = rejected.taskDescription ?? 'No description';
      final taskType = rejected.taskType ?? 'Task';
      final projectName =
          rejected.projectDetails?['project_name']?.toString() ??
          'Unknown Project';
      final fromDate = rejected.fromDate?.toString().split(' ')[0] ?? 'N/A';
      final toDate = rejected.toDate?.toString().split(' ')[0] ?? 'N/A';

      Future(() async {
        try {
          final employee = await empRepo.getById(empId);
          final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
              ? employee!.employeeCompanyEmail
              : employee?.employeePersonalEmail;

          await UnifiedNotificationService.notifyTaskRequestRejected(
            requestId: requestId,
            taskName: taskName,
            employeeId: empId,
            rejectedById: rejectedBy,
            reason: reason,
            employeeEmail: empEmail,
            employeeName: employee?.employeeName,
            projectName: projectName,
            taskDescription: taskDesc,
            taskType: taskType,
            fromDate: fromDate,
            toDate: toDate,
          );
        } catch (e) {
          _logger.warning(
            'Failed to send task request rejection notifications: $e',
          );
        }
      });

      return rejectedRequest;
    } catch (e, stackTrace) {
      _logger.error('Error rejecting task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TASK CARD REQUEST OPERATIONS
  // ==========================================

  Future<TaskCardRequest> createTaskCardRequest(
    Map<String, dynamic> data,
    String employeeId,
  ) async {
    try {
      final request = await _repository.createTaskCardRequest(data, employeeId);

      // Send notifications in background
      Future(() async {
        try {
          final employeeDetails =
              data['employee_details'] as Map<String, dynamic>? ?? {};
          final projectDetails =
              data['project_details'] as Map<String, dynamic>? ?? {};

          await UnifiedNotificationService.notifyTaskRequestCreated(
            requestId: request.requestId,
            taskName: request.taskName ?? 'Task',
            employeeId: employeeId,
            employeeName: employeeDetails['employee_name'] ?? 'Employee',
            employeeEmail:
                employeeDetails['employee_personal_email'] ??
                employeeDetails['employee_company_email'],
            projectName: projectDetails['project_name'] ?? 'Unknown Project',
            taskDescription: request.taskDescription,
            taskType: request.taskType,
            priorityLevel: request.priorityLevel,
            fromDate: request.fromDate?.toString().split(' ')[0],
            toDate: request.toDate?.toString().split(' ')[0],
            taskDuration: request.taskDuration,
          );
        } catch (e) {
          _logger.warning('Failed to send task request notifications: $e');
        }
      });

      return request;
    } catch (e, stackTrace) {
      _logger.error('Error creating task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee's task card requests
  Future<List<TaskCardRequest>> getEmployeeTaskCardRequests(
    String employeeId,
  ) async {
    try {
      return await _repository.getEmployeeTaskCardRequests(employeeId);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee task card requests: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Cancel task card request
  Future<bool> cancelTaskCardRequest(
    String requestId,
    String employeeId,
  ) async {
    try {
      return await _repository.cancelTaskCardRequest(requestId, employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error cancelling task card request: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================
}
