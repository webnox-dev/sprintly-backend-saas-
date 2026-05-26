import '../data/repositories/role_repository.dart';
import '../data/repositories/version_release_repository.dart';
import '../data/repositories/future_plan_repository.dart';
import '../data/repositories/monthly_working_days_repository.dart';
import '../domain/models/role.dart';
import '../domain/models/version_release.dart';
import '../domain/models/future_plan.dart';
import '../domain/models/monthly_working_days.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../data/database/connection.dart';

class SettingsService {
  final RoleRepository _roleRepository = RoleRepository();
  final VersionReleaseRepository _releaseRepository =
      VersionReleaseRepository();
  final FuturePlanRepository _planRepository = FuturePlanRepository();
  final MonthlyWorkingDaysRepository _workingDaysRepository =
      MonthlyWorkingDaysRepository();
  final AppLogger _logger = AppLogger('SettingsService');

  // --- Roles & Designations ---

  Future<List<Role>> getAllRoles() async {
    try {
      return await _roleRepository.getAllRoles();
    } catch (e, stackTrace) {
      _logger.error('Error getting all roles: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Role> getRoleById(String id) async {
    try {
      final role = await _roleRepository.getRoleById(id);
      if (role == null) {
        throw NotFoundException(resource: 'Role', id: id);
      }
      return role;
    } catch (e, stackTrace) {
      _logger.error('Error getting role by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Role> createRole(Role role) async {
    try {
      return await _roleRepository.createRole(role);
    } catch (e, stackTrace) {
      _logger.error('Error creating role: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Role> updateRole(String id, Map<String, dynamic> updates) async {
    try {
      final role = await _roleRepository.updateRole(id, updates);
      if (role == null) {
        throw NotFoundException(resource: 'Role', id: id);
      }
      return role;
    } catch (e, stackTrace) {
      _logger.error('Error updating role: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteRole(String id) async {
    try {
      final success = await _roleRepository.deleteRole(id);
      if (!success) {
        throw NotFoundException(resource: 'Role', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting role: $e', e, stackTrace);
      rethrow;
    }
  }

  // --- Version Releases ---

  Future<List<VersionRelease>> getAllReleases() async {
    try {
      return await _releaseRepository.getAllReleases();
    } catch (e, stackTrace) {
      _logger.error('Error getting all releases: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<VersionRelease> getReleaseById(String id) async {
    try {
      final release = await _releaseRepository.getReleaseById(id);
      if (release == null) {
        throw NotFoundException(resource: 'VersionRelease', id: id);
      }
      return release;
    } catch (e, stackTrace) {
      _logger.error('Error getting release by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<VersionRelease> createRelease(VersionRelease release) async {
    try {
      return await _releaseRepository.createRelease(release);
    } catch (e, stackTrace) {
      _logger.error('Error creating release: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<VersionRelease> updateRelease(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final release = await _releaseRepository.updateRelease(id, updates);
      if (release == null) {
        throw NotFoundException(resource: 'VersionRelease', id: id);
      }
      return release;
    } catch (e, stackTrace) {
      _logger.error('Error updating release: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteRelease(String id) async {
    try {
      final success = await _releaseRepository.deleteRelease(id);
      if (!success) {
        throw NotFoundException(resource: 'VersionRelease', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting release: $e', e, stackTrace);
      rethrow;
    }
  }

  // --- Future Plans ---

  Future<List<FuturePlan>> getAllPlans() async {
    try {
      return await _planRepository.getAllPlans();
    } catch (e, stackTrace) {
      _logger.error('Error getting all plans: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<FuturePlan> getPlanById(String id) async {
    try {
      final plan = await _planRepository.getPlanById(id);
      if (plan == null) {
        throw NotFoundException(resource: 'FuturePlan', id: id);
      }
      return plan;
    } catch (e, stackTrace) {
      _logger.error('Error getting plan by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<FuturePlan> createPlan(FuturePlan plan) async {
    try {
      return await _planRepository.createPlan(plan);
    } catch (e, stackTrace) {
      _logger.error('Error creating plan: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<FuturePlan> updatePlan(String id, Map<String, dynamic> updates) async {
    try {
      final plan = await _planRepository.updatePlan(id, updates);
      if (plan == null) {
        throw NotFoundException(resource: 'FuturePlan', id: id);
      }
      return plan;
    } catch (e, stackTrace) {
      _logger.error('Error updating plan: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deletePlan(String id) async {
    try {
      final success = await _planRepository.deletePlan(id);
      if (!success) {
        throw NotFoundException(resource: 'FuturePlan', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting plan: $e', e, stackTrace);
      rethrow;
    }
  }

  // --- Monthly Working Days ---

  Future<List<MonthlyWorkingDays>> getAllWorkingDays() async {
    try {
      return await _workingDaysRepository.getAll();
    } catch (e, stackTrace) {
      _logger.error('Error getting all working days: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<MonthlyWorkingDays> getWorkingDaysById(String id) async {
    try {
      final data = await _workingDaysRepository.getById(id);
      if (data == null) {
        throw NotFoundException(resource: 'MonthlyWorkingDays', id: id);
      }
      return data;
    } catch (e, stackTrace) {
      _logger.error('Error getting working days by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<MonthlyWorkingDays> createWorkingDays(MonthlyWorkingDays data) async {
    try {
      // Check if already exists for this month/year
      final existing = await _workingDaysRepository.getByMonthYear(
        data.month,
        data.year,
      );
      if (existing != null) {
        throw ConflictException(
          resource: 'Working days',
          field: 'month and year',
        );
      }

      // Auto-calculate counts
      final daysInMonth = DateTime(data.year, data.month + 1, 0).day;
      final workingCount = data.workingDateList.length.toDouble();

      final updatedData = MonthlyWorkingDays(
        month: data.month,
        year: data.year,
        workingDays: workingCount,
        nonWorkingDays: daysInMonth - workingCount,
        totalDays: daysInMonth,
        workingDateList: data.workingDateList,
        remarks: data.remarks,
        createdBy: data.createdBy,
        updatedBy: data.updatedBy,
      );

      return await _workingDaysRepository.create(updatedData);
    } catch (e, stackTrace) {
      _logger.error('Error creating working days: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<MonthlyWorkingDays> updateWorkingDays(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      // If working_date_list is in updates, recalculate counts
      if (updates.containsKey('working_date_list') ||
          updates.containsKey('month') ||
          updates.containsKey('year')) {
        final existing = await _workingDaysRepository.getById(id);
        if (existing == null) {
          throw NotFoundException(resource: 'MonthlyWorkingDays', id: id);
        }

        final month = updates['month'] ?? existing.month;
        final year = updates['year'] ?? existing.year;
        final List<String> dateList = updates['working_date_list'] != null
            ? List<String>.from(updates['working_date_list'] as Iterable)
            : existing.workingDateList;

        final daysInMonth = DateTime(year, month + 1, 0).day;
        final workingCount = dateList.length.toDouble();

        updates['working_days'] = workingCount;
        updates['non_working_days'] = daysInMonth - workingCount;
        updates['total_days'] = daysInMonth;
        updates['working_date_list'] = dateList;
      }

      final updated = await _workingDaysRepository.update(id, updates);
      if (updated == null) {
        throw NotFoundException(resource: 'MonthlyWorkingDays', id: id);
      }
      return updated;
    } catch (e, stackTrace) {
      _logger.error('Error updating working days: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteWorkingDays(String id) async {
    try {
      final success = await _workingDaysRepository.delete(id);
      if (!success) {
        throw NotFoundException(resource: 'MonthlyWorkingDays', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting working days: $e', e, stackTrace);
      rethrow;
    }
  }

  // --- System Task Logs ---

  Future<List<Map<String, dynamic>>> getSystemTaskLogs() async {
    try {
      final results = await DatabaseConnection.query('''
        SELECT * FROM system_task_logs 
        ORDER BY run_at DESC 
        LIMIT 50
        ''');
      return results;
    } catch (e, stackTrace) {
      _logger.error('Error getting system task logs: $e', e, stackTrace);
      rethrow;
    }
  }
}
