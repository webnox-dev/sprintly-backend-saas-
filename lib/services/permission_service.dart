import '../data/repositories/permission_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../domain/models/permission.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

import 'unified_notification_service.dart';

/// Permission service for business logic operations
/// Matches exact database schema for permissions table
class PermissionService {
  final PermissionRepository _repository = PermissionRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('PermissionService');

  /// Get all permission records with pagination and filters
  Future<Map<String, dynamic>> getAllPermissions({
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
      _logger.error('getAllPermissions error', e);
      rethrow;
    }
  }

  /// Get permission by ID
  Future<Permission?> getPermissionById(String permissionId) async {
    try {
      return await _repository.getById(permissionId);
    } catch (e) {
      _logger.error('getPermissionById error', e);
      rethrow;
    }
  }

  /// Get permissions by employee ID
  Future<List<Permission>> getPermissionsByEmployeeId(String employeeId) async {
    try {
      return await _repository.getByEmployeeId(employeeId);
    } catch (e) {
      _logger.error('getPermissionsByEmployeeId error', e);
      rethrow;
    }
  }

  /// Create permission request - matches exact schema
  Future<Permission> createPermissionRequest({
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
      // Validate time format
      _validateTimeFormat(permissionFromTime);
      _validateTimeFormat(permissionToTime);

      // Validate that from time is before to time
      final fromParts = permissionFromTime.split(':');
      final toParts = permissionToTime.split(':');
      final fromMinutes =
          int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
      final toMinutes = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);

      if (toMinutes <= fromMinutes) {
        throw ValidationException({
          'time': ['End time must be after start time'],
        });
      }

      final permission = await _repository.create(
        employeeId: employeeId,
        permissionDate: permissionDate,
        permissionFromTime: permissionFromTime,
        permissionToTime: permissionToTime,
        requesterType: requesterType,
        permissionStatus: permissionStatus,
        permissionRemarks: permissionRemarks,
        createdBy: createdBy,
      );

      // Send notifications (async)
      Future(() async {
        try {
          final employee = await _employeeRepository.getById(employeeId);
          final empName = employee?.employeeName ?? employeeId;
          final dateStr = permission.permissionDate.toIso8601String().split(
            'T',
          )[0];

          await UnifiedNotificationService.notifyPermissionRequested(
            permissionId: permission.permissionId,
            employeeId: employeeId,
            employeeName: empName,
            permissionDate: dateStr,
            fromTime: permission.permissionFromTime,
            toTime: permission.permissionToTime,
            totalHours: permission.duration.inHours.toString(),
            reason: permission.permissionRemarks ?? 'N/A',
          );
        } catch (e) {
          _logger.warning(
            'Failed to send permission request notifications: $e',
          );
        }
      });

      return permission;
    } catch (e) {
      _logger.error('createPermissionRequest error', e);
      rethrow;
    }
  }

  /// Validate time format (HH:MM:SS or HH:MM)
  void _validateTimeFormat(String time) {
    final pattern = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$');
    if (!pattern.hasMatch(time)) {
      throw ValidationException({
        'time': ['Invalid time format: $time. Expected HH:MM:SS or HH:MM'],
      });
    }
  }

  /// Update permission request
  Future<Permission?> updatePermissionRequest(
    String permissionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Remove fields that shouldn't be updated directly
      updates.remove('permission_id');
      updates.remove('created_at');
      updates.remove('approved_by');
      updates.remove('rejected_by');
      updates.remove('approved_at');
      updates.remove('rejected_at');

      return await _repository.update(permissionId, updates);
    } catch (e) {
      _logger.error('updatePermissionRequest error', e);
      rethrow;
    }
  }

  /// Approve permission request
  Future<Permission?> approvePermissionRequest({
    required String permissionId,
    required String approvedBy,
    String? permissionApprovalRejectionRemarks,
  }) async {
    try {
      // Verify permission exists and is pending
      final permission = await _repository.getById(permissionId);
      if (permission == null) {
        throw NotFoundException(
          resource: 'Permission request',
          id: permissionId,
        );
      }

      if (!permission.isPending) {
        throw ValidationException({
          'status': ['Permission request is not in pending status'],
        });
      }

      final approvedPermission = await _repository.approve(
        permissionId: permissionId,
        approvedBy: approvedBy,
        permissionApprovalRejectionRemarks: permissionApprovalRejectionRemarks,
      );

      // Send push notification and email in background - do not block response
      if (approvedPermission != null) {
        final empId = approvedPermission.employeeId;
        final dateStr = approvedPermission.permissionDate
            .toIso8601String()
            .split('T')[0];
        final empRepo = _employeeRepository;
        final fromTime = approvedPermission.permissionFromTime;
        final toTime = approvedPermission.permissionToTime;
        final totalHours = approvedPermission.duration.inHours.toString();
        final permRemarks = approvedPermission.permissionRemarks ?? 'N/A';
        final remarks = permissionApprovalRejectionRemarks;

        Future(() async {
          try {
            final employee = await empRepo.getById(empId);
            final empName = employee?.employeeName;
            final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
                ? employee!.employeeCompanyEmail
                : employee?.employeePersonalEmail;

            await UnifiedNotificationService.notifyPermissionApproved(
              permissionId: permissionId,
              employeeId: empId,
              permissionDate: dateStr,
              fromTime: fromTime,
              toTime: toTime,
              totalHours: totalHours,
              reason: permRemarks,
              approvedById: approvedBy,
              remarks: remarks,
              employeeName: empName,
              employeeEmail: empEmail,
            );
          } catch (e) {
            _logger.warning(
              'Failed to send permission approval notifications: $e',
            );
          }
        }).catchError((e, st) {
          _logger.warning('Permission approval notifications error: $e');
        });
      }

      return approvedPermission;
    } catch (e) {
      _logger.error('approvePermissionRequest error', e);
      rethrow;
    }
  }

  /// Reject permission request
  Future<Permission?> rejectPermissionRequest({
    required String permissionId,
    required String rejectedBy,
    String? permissionApprovalRejectionRemarks,
  }) async {
    try {
      // Verify permission exists and is pending
      final permission = await _repository.getById(permissionId);
      if (permission == null) {
        throw NotFoundException(
          resource: 'Permission request',
          id: permissionId,
        );
      }

      if (!permission.isPending) {
        throw ValidationException({
          'status': ['Permission request is not in pending status'],
        });
      }

      final rejectedPermission = await _repository.reject(
        permissionId: permissionId,
        rejectedBy: rejectedBy,
        permissionApprovalRejectionRemarks: permissionApprovalRejectionRemarks,
      );

      // Send push notification and email in background - do not block response
      if (rejectedPermission != null) {
        final empId = rejectedPermission.employeeId;
        final dateStr = rejectedPermission.permissionDate
            .toIso8601String()
            .split('T')[0];
        final empRepo = _employeeRepository;
        final fromTime = rejectedPermission.permissionFromTime;
        final toTime = rejectedPermission.permissionToTime;
        final totalHours = rejectedPermission.duration.inHours.toString();
        final permRemarks = rejectedPermission.permissionRemarks ?? 'N/A';
        final rejectionRemarks = permissionApprovalRejectionRemarks;

        Future(() async {
          try {
            final employee = await empRepo.getById(empId);
            final empName = employee?.employeeName;
            final empEmail = employee?.employeeCompanyEmail.isNotEmpty == true
                ? employee!.employeeCompanyEmail
                : employee?.employeePersonalEmail;

            await UnifiedNotificationService.notifyPermissionRejected(
              permissionId: permissionId,
              employeeId: empId,
              permissionDate: dateStr,
              fromTime: fromTime,
              toTime: toTime,
              totalHours: totalHours,
              reason: permRemarks,
              rejectedById: rejectedBy,
              rejectionReason: rejectionRemarks,
              employeeName: empName,
              employeeEmail: empEmail,
            );
          } catch (e) {
            _logger.warning(
              'Failed to send permission rejection notifications: $e',
            );
          }
        }).catchError((e, st) {
          _logger.warning('Permission rejection notifications error: $e');
        });
      }

      return rejectedPermission;
    } catch (e) {
      _logger.error('rejectPermissionRequest error', e);
      rethrow;
    }
  }

  /// Delete permission request
  Future<bool> deletePermissionRequest(String permissionId) async {
    try {
      return await _repository.delete(permissionId);
    } catch (e) {
      _logger.error('deletePermissionRequest error', e);
      rethrow;
    }
  }

  /// Get permission statistics for an employee
  Future<Map<String, dynamic>> getEmployeePermissionStatistics(
    String employeeId,
  ) async {
    try {
      return await _repository.getEmployeeStatistics(employeeId);
    } catch (e) {
      _logger.error('getEmployeePermissionStatistics error', e);
      rethrow;
    }
  }

  /// Get pending permission requests (for admin)
  Future<List<Permission>> getPendingPermissionRequests() async {
    try {
      return await _repository.getPendingRequests();
    } catch (e) {
      _logger.error('getPendingPermissionRequests error', e);
      rethrow;
    }
  }
}
