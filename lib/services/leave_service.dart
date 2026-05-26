import '../data/repositories/leave_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../domain/models/leave.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'dart:convert';

import 'unified_notification_service.dart';

/// Leave service for business logic operations
/// Matches the exact schema of leave_zone table
class LeaveService {
  final LeaveRepository _repository = LeaveRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('LeaveService');

  /// Get all leave records with pagination and filters
  Future<Map<String, dynamic>> getAllLeaves({
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
      return await _repository.getAll(
        page: page,
        limit: limit,
        employeeId: employeeId,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
      );
    } catch (e) {
      _logger.error('getAllLeaves error', e);
      rethrow;
    }
  }

  /// Get leave by ID
  Future<Leave?> getLeaveById(String leaveId) async {
    try {
      return await _repository.getById(leaveId);
    } catch (e) {
      _logger.error('getLeaveById error', e);
      rethrow;
    }
  }

  /// Get leaves by employee ID
  Future<List<Leave>> getLeavesByEmployeeId(String employeeId) async {
    try {
      return await _repository.getByEmployeeId(employeeId);
    } catch (e) {
      _logger.error('getLeavesByEmployeeId error', e);
      rethrow;
    }
  }

  /// Create leave request - matches exact schema
  Future<Leave> createLeaveRequest({
    required String employeeId,
    String? leaveFromDate,
    String? leaveToDate,
    String? leaveRemarks,
    bool isPaidLeave = false,
    String? leaveApprovalRejectionRemarks,
    int? leaveStatus,
    String? leaveType,
    String? selectedDates, // JSON string or will be converted
    List<dynamic>? selectedDatesList, // Alternative: pass as list
    num? totalLeaveDays,
    bool isHalfDay = false,
    String? halfDayType,
  }) async {
    try {
      // Validate dates if provided
      if (leaveFromDate != null && leaveToDate != null) {
        final fromDate = DateTime.parse(leaveFromDate);
        final toDate = DateTime.parse(leaveToDate);

        if (toDate.isBefore(fromDate)) {
          throw ValidationException({
            'date': ['End date cannot be before start date'],
          });
        }
      }

      // Handle selectedDates - convert list to JSON if provided
      List<dynamic>? dates;
      if (selectedDatesList != null && selectedDatesList.isNotEmpty) {
        dates = selectedDatesList;
      } else if (selectedDates != null && selectedDates.isNotEmpty) {
        // Try to parse JSON string
        try {
          dates = jsonDecode(selectedDates) as List<dynamic>;
        } catch (_) {
          // If not valid JSON, ignore
        }
      }

      final leave = await _repository.create(
        employeeId: employeeId,
        leaveFromDate: leaveFromDate,
        leaveToDate: leaveToDate,
        leaveRemarks: leaveRemarks,
        isPaidLeave: isPaidLeave,
        leaveApprovalRejectionRemarks: leaveApprovalRejectionRemarks,
        leaveStatus: leaveStatus,
        leaveType: leaveType,
        selectedDates: dates,
        totalLeaveDays: totalLeaveDays,
        isHalfDay: isHalfDay,
        halfDayType: halfDayType,
      );

      // Send notifications (async)
      Future(() async {
        try {
          final employee = await _employeeRepository.getById(employeeId);
          final empName = employee?.employeeName ?? employeeId;
          final fromStr =
              leave.leaveFromDate?.toIso8601String().split('T')[0] ?? 'N/A';
          final toStr =
              leave.leaveToDate?.toIso8601String().split('T')[0] ?? fromStr;
          final totalDays = leave.totalLeaveDays?.toString() ?? '1';

          await UnifiedNotificationService.notifyLeaveRequested(
            leaveId: leave.leaveId,
            employeeId: employeeId,
            employeeName: empName,
            leaveType: leave.leaveType ?? 'Leave',
            fromDate: fromStr,
            toDate: toStr,
            totalDays: totalDays,
            reason: leave.leaveRemarks ?? 'N/A',
            isHalfDay: leave.isHalfDay ?? false,
            halfDayType: leave.halfDayType,
            isPaidLeave: leave.isPaidLeave ?? false,
          );
        } catch (e) {
          _logger.warning('Failed to send leave request notifications: $e');
        }
      });

      return leave;
    } catch (e) {
      _logger.error('createLeaveRequest error', e);
      rethrow;
    }
  }

  /// Update leave request
  Future<Leave?> updateLeaveRequest(
    String leaveId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Remove fields that shouldn't be updated directly
      updates.remove('leave_id');
      updates.remove('created_at');
      updates.remove('approved_by');
      updates.remove('rejected_by');
      updates.remove('approved_at');
      updates.remove('approved_time');
      updates.remove('rejected_at');
      updates.remove('rejected_time');

      return await _repository.update(leaveId, updates);
    } catch (e) {
      _logger.error('updateLeaveRequest error', e);
      rethrow;
    }
  }

  /// Approve leave request
  Future<Leave?> approveLeaveRequest({
    required String leaveId,
    required String approvedBy,
    String? leaveApprovalRejectionRemarks,
  }) async {
    try {
      // Verify leave exists and is pending
      final leave = await _repository.getById(leaveId);
      if (leave == null) {
        throw NotFoundException(resource: 'Leave request', id: leaveId);
      }

      if (leave.leaveStatus != 0) {
        throw ValidationException({
          'status': ['Leave request is not in pending status'],
        });
      }

      final approvedLeave = await _repository.approve(
        leaveId: leaveId,
        approvedBy: approvedBy,
        leaveApprovalRejectionRemarks: leaveApprovalRejectionRemarks,
      );

      // Send push notification and email in background - do not block response
      if (approvedLeave != null) {
        final empId = approvedLeave.employeeId;
        final empRepo = _employeeRepository;
        final fromDateStr =
            approvedLeave.leaveFromDate?.toString().split(' ')[0] ?? 'N/A';
        final toDateStr =
            approvedLeave.leaveToDate?.toString().split(' ')[0] ?? 'N/A';
        final totalDaysStr = approvedLeave.totalLeaveDays?.toString() ?? '1';
        final leaveTypeStr = approvedLeave.leaveType ?? 'Leave';
        final remarksStr = leaveApprovalRejectionRemarks;

        Future(() async {
          try {
            final employee = await empRepo.getById(empId);
            final empName = employee?.employeeName;
            final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
                ? employee!.employeeCompanyEmail
                : employee?.employeePersonalEmail;

            await UnifiedNotificationService.notifyLeaveApproved(
              leaveId: leaveId,
              employeeId: empId,
              leaveType: leaveTypeStr,
              fromDate: fromDateStr,
              toDate: toDateStr,
              totalDays: totalDaysStr,
              approvedById: approvedBy,
              remarks: remarksStr,
              employeeName: empName,
              employeeEmail: empEmail,
            );
          } catch (e) {
            _logger.warning('Failed to send leave approval notifications: $e');
          }
        }).catchError((e, st) {
          _logger.warning('Leave approval notifications error: $e');
        });
      }

      return approvedLeave;
    } catch (e) {
      _logger.error('approveLeaveRequest error', e);
      rethrow;
    }
  }

  /// Reject leave request
  Future<Leave?> rejectLeaveRequest({
    required String leaveId,
    required String rejectedBy,
    String? leaveApprovalRejectionRemarks,
  }) async {
    try {
      // Verify leave exists and is pending
      final leave = await _repository.getById(leaveId);
      if (leave == null) {
        throw NotFoundException(resource: 'Leave request', id: leaveId);
      }

      if (leave.leaveStatus != 0) {
        throw ValidationException({
          'status': ['Leave request is not in pending status'],
        });
      }

      final rejectedLeave = await _repository.reject(
        leaveId: leaveId,
        rejectedBy: rejectedBy,
        leaveApprovalRejectionRemarks: leaveApprovalRejectionRemarks,
      );

      // Send push notification and email in background - do not block response
      if (rejectedLeave != null) {
        final empId = rejectedLeave.employeeId;
        final empRepo = _employeeRepository;
        final fromDateStr =
            rejectedLeave.leaveFromDate?.toString().split(' ')[0] ?? 'N/A';
        final toDateStr =
            rejectedLeave.leaveToDate?.toString().split(' ')[0] ?? 'N/A';
        final totalDaysStr = rejectedLeave.totalLeaveDays?.toString() ?? '1';
        final leaveTypeStr = rejectedLeave.leaveType ?? 'Leave';
        final reasonStr = leaveApprovalRejectionRemarks;

        Future(() async {
          try {
            final employee = await empRepo.getById(empId);
            final empName = employee?.employeeName;
            final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
                ? employee!.employeeCompanyEmail
                : employee?.employeePersonalEmail;

            await UnifiedNotificationService.notifyLeaveRejected(
              leaveId: leaveId,
              employeeId: empId,
              leaveType: leaveTypeStr,
              fromDate: fromDateStr,
              toDate: toDateStr,
              totalDays: totalDaysStr,
              rejectedById: rejectedBy,
              reason: reasonStr,
              employeeName: empName,
              employeeEmail: empEmail,
            );
          } catch (e) {
            _logger.warning('Failed to send leave rejection notifications: $e');
          }
        }).catchError((e, st) {
          _logger.warning('Leave rejection notifications error: $e');
        });
      }

      return rejectedLeave;
    } catch (e) {
      _logger.error('rejectLeaveRequest error', e);
      rethrow;
    }
  }

  /// Delete leave request
  Future<bool> deleteLeaveRequest(String leaveId) async {
    try {
      return await _repository.delete(leaveId);
    } catch (e) {
      _logger.error('deleteLeaveRequest error', e);
      rethrow;
    }
  }

  /// Get leave statistics for an employee
  Future<Map<String, dynamic>> getEmployeeLeaveStatistics(
    String employeeId,
  ) async {
    try {
      return await _repository.getEmployeeStatistics(employeeId);
    } catch (e) {
      _logger.error('getEmployeeLeaveStatistics error', e);
      rethrow;
    }
  }

  /// Get pending leave requests (for admin)
  Future<List<Leave>> getPendingLeaveRequests() async {
    try {
      return await _repository.getPendingRequests();
    } catch (e) {
      _logger.error('getPendingLeaveRequests error', e);
      rethrow;
    }
  }
}
