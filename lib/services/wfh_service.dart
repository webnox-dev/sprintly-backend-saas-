import '../domain/models/wfh_request.dart';
import '../data/repositories/wfh_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

import 'unified_notification_service.dart';

/// WFH (Work From Home) service for business logic
class WFHService {
  final WFHRepository _repository = WFHRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('WFHService');

  /// Get all WFH requests with filters
  Future<Map<String, dynamic>> getAllWFHRequests({
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
    return await _repository.getAll(
      page: page,
      limit: limit,
      status: status,
      requesterType: requesterType,
      requesterId: requesterId,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Get WFH request by ID
  Future<WFHRequest> getWFHRequestById(String wfhId) async {
    final wfh = await _repository.getById(wfhId);
    if (wfh == null) {
      throw AppException(code: 'NOT_FOUND', message: 'WFH request not found');
    }
    return wfh;
  }

  /// Create WFH request
  Future<WFHRequest> createWFHRequest(Map<String, dynamic> data) async {
    // Validate required fields
    // Support both field names
    final employeeId =
        data['employee_id']?.toString() ?? data['requester_id']?.toString();
    final requesterType = data['requester_type']?.toString() ?? 'Employee';
    final employeeName = data['employee_name']?.toString() ?? '';
    final startDate = data['start_date']?.toString();
    final endDate = data['end_date']?.toString();

    if (employeeId == null || employeeId.isEmpty) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'Employee ID is required',
      );
    }

    if (startDate == null || startDate.isEmpty) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'Start date is required',
      );
    }

    if (endDate == null || endDate.isEmpty) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'End date is required',
      );
    }

    // Validate dates
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    if (end.isBefore(start)) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'End date cannot be before start date',
      );
    }

    final wfhRequest = WFHRequest(
      employeeId: employeeId,
      requesterType: requesterType,
      employeeName: employeeName,
      startDate: start,
      endDate: end,
      reason: data['reason']?.toString(),
      createdBy: data['created_by']?.toString() ?? employeeId,
    );

    final wfh = await _repository.create(wfhRequest);

    // Send notifications (async)
    Future(() async {
      try {
        final employee = await _employeeRepository.getById(employeeId);
        final empName = employee?.employeeName ?? employeeName;
        final fromStr = wfh.startDate.toIso8601String().split('T')[0];
        final toStr = wfh.endDate.toIso8601String().split('T')[0];
        final totalDays = wfh.totalDays.toString();

        await UnifiedNotificationService.notifyWFHRequested(
          wfhId: wfh.wfhId ?? '',
          employeeId: employeeId,
          employeeName: empName,
          fromDate: fromStr,
          toDate: toStr,
          totalDays: totalDays,
          reason: wfh.reason ?? 'N/A',
          employeeRole: requesterType,
        );
      } catch (e) {
        _logger.warning('Failed to send WFH request notifications: $e');
      }
    });

    return wfh;
  }

  /// Update WFH request
  Future<WFHRequest> updateWFHRequest(
    String wfhId,
    Map<String, dynamic> updates,
  ) async {
    // Check if WFH exists
    final existing = await _repository.getById(wfhId);
    if (existing == null) {
      throw AppException(code: 'NOT_FOUND', message: 'WFH request not found');
    }

    // Only allow update if status is pending
    if (existing.wfhStatus != 0) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'Cannot update WFH request that is already processed',
      );
    }

    // Build update map with allowed fields
    final allowedFields = ['start_date', 'end_date', 'reason', 'updated_by'];

    final filteredUpdates = <String, dynamic>{};
    for (final key in allowedFields) {
      if (updates.containsKey(key)) {
        filteredUpdates[key] = updates[key];
      }
    }

    final result = await _repository.update(wfhId, filteredUpdates);
    if (result == null) {
      throw AppException(
        code: 'UPDATE_FAILED',
        message: 'Failed to update WFH request',
      );
    }

    return result;
  }

  /// Delete WFH request
  Future<void> deleteWFHRequest(String wfhId) async {
    // Check if WFH exists
    final existing = await _repository.getById(wfhId);
    if (existing == null) {
      throw AppException(code: 'NOT_FOUND', message: 'WFH request not found');
    }

    // Only allow delete if status is pending
    if (existing.wfhStatus != 0) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'Cannot delete WFH request that is already processed',
      );
    }

    final deleted = await _repository.delete(wfhId);
    if (!deleted) {
      throw AppException(
        code: 'DELETE_FAILED',
        message: 'Failed to delete WFH request',
      );
    }
  }

  /// Approve or reject WFH request
  Future<WFHRequest> approveRejectWFHRequest({
    required String wfhId,
    required bool approve,
    required String actionBy,
    String? remarks,
  }) async {
    // Get existing WFH request
    final existing = await _repository.getById(wfhId);
    if (existing == null) {
      throw AppException(code: 'NOT_FOUND', message: 'WFH request not found');
    }

    // Prevent admin from approving their own request
    if (existing.requesterType == 'Admin' && existing.employeeId == actionBy) {
      throw AppException(
        code: 'FORBIDDEN',
        message: 'You cannot approve or reject your own WFH request',
      );
    }

    // Check if already processed
    if (existing.wfhStatus != 0) {
      throw AppException(
        code: 'VALIDATION_ERROR',
        message: 'WFH request has already been processed',
      );
    }

    WFHRequest? result;
    if (approve) {
      result = await _repository.approve(
        wfhId: wfhId,
        approvedBy: actionBy,
        remarks: remarks,
      );
    } else {
      result = await _repository.reject(
        wfhId: wfhId,
        rejectedBy: actionBy,
        remarks: remarks,
      );
    }

    if (result == null) {
      throw AppException(
        code: 'UPDATE_FAILED',
        message: 'Failed to ${approve ? 'approve' : 'reject'} WFH request',
      );
    }

    _logger.info(
      'WFH request $wfhId ${approve ? 'approved' : 'rejected'} by $actionBy',
    );

    // Send push notification and email in background - do not block response
    final empId = result.employeeId;
    final dates =
        '${result.startDate.toIso8601String().split('T')[0] ?? ''} - ${result.endDate.toIso8601String().split('T')[0] ?? ''}';
    final fromDate = result.startDate.toIso8601String().split('T')[0] ?? 'N/A';
    final toDate = result.endDate.toIso8601String().split('T')[0] ?? 'N/A';
    final totalDays = result.totalDays.toString() ?? '1';
    final reasonStr = result.reason ?? 'N/A';
    final empRepo = _employeeRepository;
    final isApprove = approve;
    final actionByUser = actionBy;
    final remarksStr = remarks;

    Future(() async {
      try {
        final employee = await empRepo.getById(empId);
        final empName = employee?.employeeName;
        final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
            ? employee!.employeeCompanyEmail
            : employee?.employeePersonalEmail;

        if (isApprove) {
          await UnifiedNotificationService.notifyWFHApproved(
            wfhId: wfhId,
            employeeId: empId,
            fromDate: fromDate,
            toDate: toDate,
            totalDays: totalDays,
            reason: reasonStr,
            approvedById: actionByUser,
            remarks: remarksStr,
            employeeName: empName,
            employeeEmail: empEmail,
          );
        } else {
          await UnifiedNotificationService.notifyWFHRejected(
            wfhId: wfhId,
            employeeId: empId,
            fromDate: fromDate,
            toDate: toDate,
            totalDays: totalDays,
            reason: reasonStr,
            rejectedById: actionByUser,
            employeeName: empName,
            employeeEmail: empEmail,
          );
        }
      } catch (e) {
        _logger.warning('Failed to send WFH notification: $e');
      }
    }).catchError((e, st) {
      _logger.warning('WFH notifications error: $e');
    });

    return result;
  }

  /// Get WFH requests by employee
  Future<List<WFHRequest>> getWFHRequestsByRequester(String employeeId) async {
    return await _repository.getByEmployeeId(employeeId);
  }
}
