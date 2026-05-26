import '../data/repositories/leave_policy_repository.dart';
import '../data/repositories/leave_repository.dart';
import '../data/repositories/permission_repository.dart';
import '../data/repositories/wfh_repository.dart';
import '../domain/models/leave_policy_config.dart';
import '../core/utils/logger.dart';

class LeavePolicyService {
  final LeavePolicyRepository _policyRepo = LeavePolicyRepository();
  final LeaveRepository _leaveRepo = LeaveRepository();
  final PermissionRepository _permRepo = PermissionRepository();
  final WFHRepository _wfhRepo = WFHRepository();
  final AppLogger _logger = AppLogger('LeavePolicyService');

  Future<LeavePolicyConfig> getPolicy([String configId = 'default']) async {
    final config = await _policyRepo.getConfig(configId);
    if (config != null) return config;

    return LeavePolicyConfig(
      configId: 'default',
      allowedLeaveDaysPerMonth: 2,
      allowedPermissionHoursPerMonth: 2.0,
      allowedWfhDaysPerMonth: 1,
    );
  }

  Future<Map<String, dynamic>> getLeaveAllowanceStatus(
    String employeeId,
  ) async {
    try {
      final policy = await getPolicy();
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final leaves = await _leaveRepo.getByEmployeeId(employeeId);
      final perms = await _permRepo.getByEmployeeId(employeeId);
      final wfh = await _wfhRepo.getByEmployeeId(employeeId);

      final usedLeaves = leaves
          .where(
            (l) =>
                l.leaveStatus == 1 &&
                l.leaveFromDate != null &&
                l.leaveFromDate!.month == currentMonth &&
                l.leaveFromDate!.year == currentYear,
          )
          .fold<double>(
            0,
            (prev, l) => prev + (l.totalLeaveDays ?? 0).toDouble(),
          );

      final usedPermMinutes = perms
          .where(
            (p) =>
                p.permissionStatus == 1 &&
                p.permissionDate.month == currentMonth &&
                p.permissionDate.year == currentYear,
          )
          .fold<int>(0, (prev, p) => prev + p.duration.inMinutes);

      final usedPermHours = usedPermMinutes / 60.0;

      final usedWfh = wfh
          .where(
            (w) =>
                w.wfhStatus == 1 &&
                w.startDate.month == currentMonth &&
                w.startDate.year == currentYear,
          )
          .fold<double>(0, (prev, w) => prev + w.totalDays.toDouble());

      return {
        'policy': policy.toJson(),
        'usage': {
          'leaves': {
            'allowed': policy.allowedLeaveDaysPerMonth,
            'used': usedLeaves,
            'remaining': (policy.allowedLeaveDaysPerMonth - usedLeaves)
                .clamp(0, 99)
                .toDouble(),
          },
          'permissions': {
            'allowed': policy.allowedPermissionHoursPerMonth,
            'used': usedPermHours,
            'remaining': (policy.allowedPermissionHoursPerMonth - usedPermHours)
                .clamp(0, 99)
                .toDouble(),
          },
          'wfh': {
            'allowed': policy.allowedWfhDaysPerMonth,
            'used': usedWfh,
            'remaining': (policy.allowedWfhDaysPerMonth - usedWfh)
                .clamp(0, 99)
                .toDouble(),
          },
        },
        'period': {
          'month': currentMonth,
          'year': currentYear,
          'month_name': _getMonthName(currentMonth),
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error calculating leave allowance status', e, stackTrace);
      rethrow;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
