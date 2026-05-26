import '../database/connection.dart';
import '../../domain/models/consolidated_leave_report.dart';
import '../../core/utils/logger.dart';

/// Repository for leave report related database operations
/// Uses optimized SQL queries with proper JOIN operations
class LeaveReportRepository {
  final AppLogger _logger = AppLogger('LeaveReportRepository');

  /// Get or create default leave policy configuration
  Future<LeavePolicyConfig> getLeavePolicyConfig() async {
    try {
      final result = await DatabaseConnection.query('''
        SELECT * FROM leave_policy_config WHERE config_id = 'default' LIMIT 1
      ''');

      if (result.isNotEmpty) {
        return LeavePolicyConfig.fromJson(result.first);
      }

      // Return default config if not found
      return LeavePolicyConfig.defaultConfig();
    } catch (e) {
      _logger.error('Error getting leave policy config: ${e.toString()}');
      return LeavePolicyConfig.defaultConfig();
    }
  }

  /// Update leave policy configuration
  Future<LeavePolicyConfig> updateLeavePolicyConfig({
    required int allowedLeaveDaysPerMonth,
    required double allowedPermissionHoursPerMonth,
    required int allowedWfhDaysPerMonth,
    required String updatedBy,
  }) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO leave_policy_config (
        config_id,
        allowed_leave_days_per_month,
        allowed_permission_hours_per_month,
        allowed_wfh_days_per_month,
        updated_by,
        updated_at
      ) VALUES (
        'default',
        @allowedLeave,
        @allowedPermission,
        @allowedWfh,
        @updatedBy,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (config_id) DO UPDATE SET
        allowed_leave_days_per_month = @allowedLeave,
        allowed_permission_hours_per_month = @allowedPermission,
        allowed_wfh_days_per_month = @allowedWfh,
        updated_by = @updatedBy,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    ''',
      values: {
        'allowedLeave': allowedLeaveDaysPerMonth,
        'allowedPermission': allowedPermissionHoursPerMonth,
        'allowedWfh': allowedWfhDaysPerMonth,
        'updatedBy': updatedBy,
      },
    );

    if (result.isNotEmpty) {
      return LeavePolicyConfig.fromJson(result.first);
    }
    return LeavePolicyConfig.defaultConfig();
  }

  /// Get consolidated leave report for all employees for a specific month
  /// Uses optimized CTE queries with proper JOINs
  Future<List<EmployeeConsolidatedSummary>> getConsolidatedReport({
    required int month,
    required int year,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final policy = await getLeavePolicyConfig();
    final offset = (page - 1) * limit;

    _logger.info('Fetching consolidated report for $month/$year');

    // Build search clause
    String searchClause = '';
    final params = <String, dynamic>{
      'month': month,
      'year': year,
      'allowedLeave': policy.allowedLeaveDaysPerMonth,
      'allowedPermission': policy.allowedPermissionHoursPerMonth,
      'allowedWfh': policy.allowedWfhDaysPerMonth,
      'limit': limit,
      'offset': offset,
    };

    if (search != null && search.isNotEmpty) {
      searchClause = '''
        AND (
          e.employee_name ILIKE '%' || @search || '%' 
          OR e.employee_id ILIKE '%' || @search || '%'
        )
      ''';
      params['search'] = search;
    }

    final sql =
        '''
      WITH leave_stats AS (
        SELECT 
          lz.employee_id,
          COALESCE(SUM(lz.total_leave_days), 0) as total_leave_days,
          COALESCE(SUM(CASE WHEN lz.is_paid_leave = true THEN lz.total_leave_days ELSE 0 END), 0) as paid_leave_days,
          COALESCE(SUM(CASE WHEN lz.is_paid_leave = false THEN lz.total_leave_days ELSE 0 END), 0) as unpaid_leave_days
        FROM leave_zone lz
        WHERE lz.leave_status = 1
          AND EXTRACT(MONTH FROM lz.leave_from_date) = @month
          AND EXTRACT(YEAR FROM lz.leave_from_date) = @year
        GROUP BY lz.employee_id
      ),
      permission_stats AS (
        SELECT 
          p.employee_id,
          COALESCE(SUM(
            EXTRACT(EPOCH FROM (p.permission_to_time - p.permission_from_time)) / 3600.0
          ), 0) as total_permission_hours
        FROM permissions p
        WHERE p.permission_status = 1
          AND EXTRACT(MONTH FROM p.permission_date) = @month
          AND EXTRACT(YEAR FROM p.permission_date) = @year
        GROUP BY p.employee_id
      ),
      wfh_stats AS (
        SELECT 
          w.employee_id,
          COALESCE(SUM(w.total_days), 0) as total_wfh_days
        FROM work_from_home_requests w
        WHERE w.wfh_status = 1
          AND EXTRACT(MONTH FROM w.start_date) = @month
          AND EXTRACT(YEAR FROM w.start_date) = @year
        GROUP BY w.employee_id
      )
      SELECT 
        e.employee_id,
        e.employee_uuid,
        e.employee_name,
        e.employee_role,
        e.employee_designation,
        e.employee_img as employee_profile_image,
        @month as month,
        @year as year,
        COALESCE(ls.total_leave_days, 0) as total_leave_days,
        COALESCE(ls.paid_leave_days, 0) as paid_leave_days,
        COALESCE(ls.unpaid_leave_days, 0) as unpaid_leave_days,
        GREATEST(0, COALESCE(ls.total_leave_days, 0) - @allowedLeave) as excess_leave_days,
        COALESCE(ps.total_permission_hours, 0) as total_permission_hours,
        GREATEST(0, COALESCE(ps.total_permission_hours, 0) - @allowedPermission) as excess_permission_hours,
        COALESCE(ws.total_wfh_days, 0) as total_wfh_days,
        GREATEST(0, COALESCE(ws.total_wfh_days, 0) - @allowedWfh) as excess_wfh_days,
        COALESCE(ls.total_leave_days, 0) > @allowedLeave as is_leave_exceeded,
        COALESCE(ps.total_permission_hours, 0) > @allowedPermission as is_permission_exceeded,
        COALESCE(ws.total_wfh_days, 0) > @allowedWfh as is_wfh_exceeded
      FROM employees e
      LEFT JOIN leave_stats ls ON e.employee_id = ls.employee_id
      LEFT JOIN permission_stats ps ON e.employee_id = ps.employee_id
      LEFT JOIN wfh_stats ws ON e.employee_id = ws.employee_id
      WHERE e.status = 1
        $searchClause
      ORDER BY e.employee_name ASC
      LIMIT @limit OFFSET @offset
    ''';

    final result = await DatabaseConnection.query(sql, values: params);

    _logger.info('Found ${result.length} employees in report');

    return result
        .map((row) => EmployeeConsolidatedSummary.fromJson(row))
        .toList();
  }

  /// Get total count for pagination
  Future<int> getConsolidatedReportCount({
    required int month,
    required int year,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    String searchClause = '';

    if (search != null && search.isNotEmpty) {
      searchClause = '''
        AND (
          e.employee_name ILIKE '%' || @search || '%' 
          OR e.employee_id ILIKE '%' || @search || '%'
        )
      ''';
      params['search'] = search;
    }

    final result = await DatabaseConnection.query('''
      SELECT COUNT(*) as count
      FROM employees e
      WHERE e.status = 1
        $searchClause
    ''', values: params.isNotEmpty ? params : null);

    if (result.isEmpty) return 0;
    final countVal = result.first['count'];
    if (countVal is int) return countVal;
    return int.tryParse(countVal?.toString() ?? '0') ?? 0;
  }

  /// Get employee details
  Future<EmployeeDetails?> getEmployeeDetails(String employeeId) async {
    final result = await DatabaseConnection.query(
      '''
      SELECT 
        employee_id,
        employee_uuid,
        employee_name,
        employee_role,
        employee_designation,
        employee_img,
        employee_actual_salary,
        employee_total_leave_days_in_year,
        employee_pending_leave_count
      FROM employees
      WHERE employee_id = @employeeId
    ''',
      values: {'employeeId': employeeId},
    );

    if (result.isEmpty) return null;
    return EmployeeDetails.fromJson(result.first);
  }

  /// Get all leave records for an employee (only approved)
  Future<List<LeaveRecord>> getEmployeeLeaveRecords({
    required String employeeId,
    int? year,
  }) async {
    String yearClause = year != null
        ? 'AND EXTRACT(YEAR FROM leave_from_date) = @year'
        : '';

    final params = <String, dynamic>{
      'employeeId': employeeId,
      if (year != null) 'year': year,
    };

    final result = await DatabaseConnection.query('''
      SELECT 
        leave_id,
        leave_from_date,
        leave_to_date,
        total_leave_days,
        leave_type,
        is_paid_leave,
        leave_status,
        leave_remarks,
        leave_approval_rejection_remarks as admin_remarks,
        EXTRACT(MONTH FROM leave_from_date)::INTEGER as month,
        EXTRACT(YEAR FROM leave_from_date)::INTEGER as year,
        approved_at
      FROM leave_zone
      WHERE employee_id = @employeeId
        AND leave_status = 1
        $yearClause
      ORDER BY leave_from_date DESC
    ''', values: params);

    return result.map((row) => LeaveRecord.fromJson(row)).toList();
  }

  /// Get all permission records for an employee (only approved)
  Future<List<PermissionRecord>> getEmployeePermissionRecords({
    required String employeeId,
    int? year,
  }) async {
    String yearClause = year != null
        ? 'AND EXTRACT(YEAR FROM permission_date) = @year'
        : '';

    final params = <String, dynamic>{
      'employeeId': employeeId,
      if (year != null) 'year': year,
    };

    final result = await DatabaseConnection.query('''
      SELECT 
        permission_id,
        permission_date,
        permission_from_time::TEXT as permission_from_time,
        permission_to_time::TEXT as permission_to_time,
        EXTRACT(EPOCH FROM (permission_to_time - permission_from_time)) / 3600.0 as duration_hours,
        permission_status,
        permission_remarks,
        permission_approval_rejection_remarks as admin_remarks,
        EXTRACT(MONTH FROM permission_date)::INTEGER as month,
        EXTRACT(YEAR FROM permission_date)::INTEGER as year
      FROM permissions
      WHERE employee_id = @employeeId
        AND permission_status = 1
        $yearClause
      ORDER BY permission_date DESC
    ''', values: params);

    return result.map((row) => PermissionRecord.fromJson(row)).toList();
  }

  /// Get all WFH records for an employee (only approved)
  Future<List<WfhRecord>> getEmployeeWfhRecords({
    required String employeeId,
    int? year,
  }) async {
    String yearClause = year != null
        ? 'AND EXTRACT(YEAR FROM start_date) = @year'
        : '';

    final params = <String, dynamic>{
      'employeeId': employeeId,
      if (year != null) 'year': year,
    };

    final result = await DatabaseConnection.query('''
      SELECT 
        wfh_id,
        start_date,
        end_date,
        total_days,
        wfh_status,
        reason,
        approval_rejection_remarks as admin_remarks,
        EXTRACT(MONTH FROM start_date)::INTEGER as month,
        EXTRACT(YEAR FROM start_date)::INTEGER as year
      FROM work_from_home_requests
      WHERE employee_id = @employeeId
        AND wfh_status = 1
        $yearClause
      ORDER BY start_date DESC
    ''', values: params);

    return result.map((row) => WfhRecord.fromJson(row)).toList();
  }

  /// Get monthly summary for an employee
  Future<List<MonthlySummary>> getEmployeeMonthlySummary({
    required String employeeId,
    int? year,
  }) async {
    final policy = await getLeavePolicyConfig();

    String yearClause = year != null ? 'WHERE year = @year' : '';

    final sql =
        '''
      WITH leave_data AS (
        SELECT 
          EXTRACT(MONTH FROM leave_from_date)::INTEGER as month,
          EXTRACT(YEAR FROM leave_from_date)::INTEGER as year,
          COALESCE(SUM(total_leave_days), 0) as total_leave_days,
          COALESCE(SUM(CASE WHEN is_paid_leave = true THEN total_leave_days ELSE 0 END), 0) as paid_leave_days,
          COALESCE(SUM(CASE WHEN is_paid_leave = false THEN total_leave_days ELSE 0 END), 0) as unpaid_leave_days
        FROM leave_zone
        WHERE employee_id = @employeeId AND leave_status = 1
        GROUP BY EXTRACT(MONTH FROM leave_from_date), EXTRACT(YEAR FROM leave_from_date)
      ),
      permission_data AS (
        SELECT 
          EXTRACT(MONTH FROM permission_date)::INTEGER as month,
          EXTRACT(YEAR FROM permission_date)::INTEGER as year,
          COALESCE(SUM(
            EXTRACT(EPOCH FROM (permission_to_time - permission_from_time)) / 3600.0
          ), 0) as total_permission_hours
        FROM permissions
        WHERE employee_id = @employeeId AND permission_status = 1
        GROUP BY EXTRACT(MONTH FROM permission_date), EXTRACT(YEAR FROM permission_date)
      ),
      wfh_data AS (
        SELECT 
          EXTRACT(MONTH FROM start_date)::INTEGER as month,
          EXTRACT(YEAR FROM start_date)::INTEGER as year,
          COALESCE(SUM(total_days), 0) as total_wfh_days
        FROM work_from_home_requests
        WHERE employee_id = @employeeId AND wfh_status = 1
        GROUP BY EXTRACT(MONTH FROM start_date), EXTRACT(YEAR FROM start_date)
      ),
      combined AS (
        SELECT 
          COALESCE(ld.month, pd.month, wd.month) as month,
          COALESCE(ld.year, pd.year, wd.year) as year,
          COALESCE(ld.total_leave_days, 0) as total_leave_days,
          COALESCE(ld.paid_leave_days, 0) as paid_leave_days,
          COALESCE(ld.unpaid_leave_days, 0) as unpaid_leave_days,
          COALESCE(pd.total_permission_hours, 0) as total_permission_hours,
          COALESCE(wd.total_wfh_days, 0) as total_wfh_days
        FROM leave_data ld
        FULL OUTER JOIN permission_data pd ON ld.month = pd.month AND ld.year = pd.year
        FULL OUTER JOIN wfh_data wd ON COALESCE(ld.month, pd.month) = wd.month 
          AND COALESCE(ld.year, pd.year) = wd.year
      )
      SELECT 
        month,
        year,
        total_leave_days,
        paid_leave_days,
        unpaid_leave_days,
        GREATEST(0, total_leave_days - @allowedLeave) as excess_leave_days,
        total_leave_days > @allowedLeave as is_leave_exceeded,
        total_permission_hours,
        GREATEST(0, total_permission_hours - @allowedPermission) as excess_permission_hours,
        total_permission_hours > @allowedPermission as is_permission_exceeded,
        total_wfh_days,
        GREATEST(0, total_wfh_days - @allowedWfh) as excess_wfh_days,
        total_wfh_days > @allowedWfh as is_wfh_exceeded
      FROM combined
      $yearClause
      ORDER BY year DESC, month DESC
    ''';

    final params = <String, dynamic>{
      'employeeId': employeeId,
      'allowedLeave': policy.allowedLeaveDaysPerMonth,
      'allowedPermission': policy.allowedPermissionHoursPerMonth,
      'allowedWfh': policy.allowedWfhDaysPerMonth,
      if (year != null) 'year': year,
    };

    final result = await DatabaseConnection.query(sql, values: params);

    return result.map((row) {
      final monthNum = int.tryParse(row['month']?.toString() ?? '0') ?? 0;
      final yearNum = int.tryParse(row['year']?.toString() ?? '0') ?? 0;

      double parseDouble(dynamic val) =>
          double.tryParse(val?.toString() ?? '0') ?? 0.0;
      int parseInt(dynamic val) => int.tryParse(val?.toString() ?? '0') ?? 0;

      return MonthlySummary(
        month: monthNum,
        year: yearNum,
        monthDisplay: '${getMonthName(monthNum)} $yearNum',
        leaveSummary: LeaveSummary(
          totalDays: parseDouble(row['total_leave_days']),
          paidDays: parseDouble(row['paid_leave_days']),
          unpaidDays: parseDouble(row['unpaid_leave_days']),
          excessDays: parseDouble(row['excess_leave_days']),
          isExceeded: row['is_leave_exceeded'] == true,
        ),
        permissionSummary: PermissionSummary(
          totalHours: parseDouble(row['total_permission_hours']),
          excessHours: parseDouble(row['excess_permission_hours']),
          isExceeded: row['is_permission_exceeded'] == true,
        ),
        wfhSummary: WfhSummary(
          totalDays: parseInt(row['total_wfh_days']),
          excessDays: parseInt(row['excess_wfh_days']),
          isExceeded: row['is_wfh_exceeded'] == true,
        ),
      );
    }).toList();
  }

  /// Get all consolidated data for Excel export (all employees for a month)
  Future<List<Map<String, dynamic>>> getConsolidatedReportForExport({
    required int month,
    required int year,
  }) async {
    final policy = await getLeavePolicyConfig();

    final sql = '''
      WITH leave_stats AS (
        SELECT 
          lz.employee_id,
          COALESCE(SUM(lz.total_leave_days), 0) as total_leave_days,
          COALESCE(SUM(CASE WHEN lz.is_paid_leave = true THEN lz.total_leave_days ELSE 0 END), 0) as paid_leave_days,
          COALESCE(SUM(CASE WHEN lz.is_paid_leave = false THEN lz.total_leave_days ELSE 0 END), 0) as unpaid_leave_days
        FROM leave_zone lz
        WHERE lz.leave_status = 1
          AND EXTRACT(MONTH FROM lz.leave_from_date) = @month
          AND EXTRACT(YEAR FROM lz.leave_from_date) = @year
        GROUP BY lz.employee_id
      ),
      permission_stats AS (
        SELECT 
          p.employee_id,
          COALESCE(SUM(
            EXTRACT(EPOCH FROM (p.permission_to_time - p.permission_from_time)) / 3600.0
          ), 0) as total_permission_hours
        FROM permissions p
        WHERE p.permission_status = 1
          AND EXTRACT(MONTH FROM p.permission_date) = @month
          AND EXTRACT(YEAR FROM p.permission_date) = @year
        GROUP BY p.employee_id
      ),
      wfh_stats AS (
        SELECT 
          w.employee_id,
          COALESCE(SUM(w.total_days), 0) as total_wfh_days
        FROM work_from_home_requests w
        WHERE w.wfh_status = 1
          AND EXTRACT(MONTH FROM w.start_date) = @month
          AND EXTRACT(YEAR FROM w.start_date) = @year
        GROUP BY w.employee_id
      )
      SELECT 
        e.employee_id,
        e.employee_name,
        e.employee_role,
        e.employee_designation,
        COALESCE(ls.total_leave_days, 0) as total_leave_days,
        COALESCE(ls.paid_leave_days, 0) as paid_leave_days,
        COALESCE(ls.unpaid_leave_days, 0) as unpaid_leave_days,
        GREATEST(0, COALESCE(ls.total_leave_days, 0) - @allowedLeave) as excess_leave_days,
        ROUND(COALESCE(ps.total_permission_hours, 0)::NUMERIC, 2) as total_permission_hours,
        ROUND(GREATEST(0, COALESCE(ps.total_permission_hours, 0) - @allowedPermission)::NUMERIC, 2) as excess_permission_hours,
        COALESCE(ws.total_wfh_days, 0) as total_wfh_days,
        GREATEST(0, COALESCE(ws.total_wfh_days, 0) - @allowedWfh) as excess_wfh_days
      FROM employees e
      LEFT JOIN leave_stats ls ON e.employee_id = ls.employee_id
      LEFT JOIN permission_stats ps ON e.employee_id = ps.employee_id
      LEFT JOIN wfh_stats ws ON e.employee_id = ws.employee_id
      WHERE e.status = 1
      ORDER BY e.employee_name ASC
    ''';

    final result = await DatabaseConnection.query(
      sql,
      values: {
        'month': month,
        'year': year,
        'allowedLeave': policy.allowedLeaveDaysPerMonth,
        'allowedPermission': policy.allowedPermissionHoursPerMonth,
        'allowedWfh': policy.allowedWfhDaysPerMonth,
      },
    );

    return result;
  }
}
