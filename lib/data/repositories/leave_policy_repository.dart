import '../database/connection.dart';
import '../../domain/models/leave_policy_config.dart';
import '../../core/utils/logger.dart';

class LeavePolicyRepository {
  final AppLogger _logger = AppLogger('LeavePolicyRepository');

  Future<LeavePolicyConfig?> getConfig([String configId = 'default']) async {
    try {
      final sql = 'SELECT * FROM leave_policy_config WHERE config_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': configId},
      );

      if (result == null) return null;
      return LeavePolicyConfig.fromJson(result);
    } catch (e, stackTrace) {
      _logger.error('Error fetching leave policy config', e, stackTrace);
      return null;
    }
  }

  Future<bool> updateConfig(LeavePolicyConfig config) async {
    try {
      final sql = '''
        INSERT INTO leave_policy_config (
          config_id, 
          allowed_leave_days_per_month, 
          allowed_permission_hours_per_month, 
          allowed_wfh_days_per_month, 
          updated_at, 
          updated_by
        ) VALUES (
          @id, 
          @leaves, 
          @perms, 
          @wfh, 
          CURRENT_TIMESTAMP, 
          @user
        )
        ON CONFLICT (config_id) DO UPDATE SET
          allowed_leave_days_per_month = EXCLUDED.allowed_leave_days_per_month,
          allowed_permission_hours_per_month = EXCLUDED.allowed_permission_hours_per_month,
          allowed_wfh_days_per_month = EXCLUDED.allowed_wfh_days_per_month,
          updated_at = CURRENT_TIMESTAMP,
          updated_by = EXCLUDED.updated_by
      ''';

      final affected = await DatabaseConnection.execute(
        sql,
        values: {
          'id': config.configId,
          'leaves': config.allowedLeaveDaysPerMonth,
          'perms': config.allowedPermissionHoursPerMonth,
          'wfh': config.allowedWfhDaysPerMonth,
          'user': config.updatedBy,
        },
      );

      return affected > 0;
    } catch (e, stackTrace) {
      _logger.error('Error updating leave policy config', e, stackTrace);
      return false;
    }
  }
}
