import '../database/connection.dart';
import '../../core/utils/logger.dart';

class EmployeePerformanceRepository {
  final AppLogger _logger = AppLogger('EmployeePerformanceRepository');

  /// Get summary of all employees' performance for a given date range
  Future<List<Map<String, dynamic>>> getAllEmployeesPerformanceSummary({
    required String fromDate,
    required String toDate,
    String? search,
    int? minLateDays,
    int? minUnderworkedDays,
    int? minOvertimeDays,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'fromDate': fromDate,
        'toDate': toDate,
      };

      String searchClause = '';
      if (search != null && search.isNotEmpty) {
        searchClause = 'AND (employee_name ILIKE @search OR employee_id ILIKE @search OR employee_designation ILIKE @search)';
        params['search'] = '%$search%';
      }

      final List<String> filteringClauses = [];
      if (minLateDays != null) {
        filteringClauses.add('late_days >= @minLateDays');
        params['minLateDays'] = minLateDays;
      }
      if (minUnderworkedDays != null) {
        filteringClauses.add('underwork_days >= @minUnderworkedDays');
        params['minUnderworkedDays'] = minUnderworkedDays;
      }
      if (minOvertimeDays != null) {
        filteringClauses.add('overtime_days >= @minOvertimeDays');
        params['minOvertimeDays'] = minOvertimeDays;
      }

      String filterClause = '';
      if (filteringClauses.isNotEmpty) {
        filterClause = 'AND ${filteringClauses.join(' AND ')}';
      }

      final sql = '''
        WITH EmployeeDailyStats AS (
            -- Get daily worked hours and first clock-in per employee per day
            SELECT 
                employee_id,
                work_date::date as date,
                SUM(
                  CASE 
                    WHEN clock_off_for_the_day IS NOT NULL AND clock_off_for_the_day != '' AND clock_on_for_the_day IS NOT NULL AND clock_on_for_the_day != '' THEN
                      EXTRACT(EPOCH FROM (clock_off_for_the_day::TIMESTAMPTZ - clock_on_for_the_day::TIMESTAMPTZ))/3600.0
                    ELSE 0 
                  END
                ) as worked_hrs,
                MIN(CASE WHEN clock_on_for_the_day != '' THEN clock_on_for_the_day::TIMESTAMPTZ ELSE NULL END) as first_clock_in
            FROM employee_attendance
            WHERE work_date::date >= @fromDate::date AND work_date::date <= @toDate::date
            GROUP BY employee_id, work_date::date
        ),
        EmployeeAggregatedStats AS (
            -- Aggregate daily stats into counts and sums per employee
            SELECT 
                employee_id,
                COUNT(CASE WHEN worked_hrs > 9.0 THEN 1 END) as overtime_days,
                SUM(CASE WHEN worked_hrs > 9.0 THEN worked_hrs - 9.0 ELSE 0 END) as total_overtime_hours,
                COUNT(CASE WHEN worked_hrs < 9.0 THEN 1 END) as underwork_days,
                COUNT(CASE WHEN first_clock_in::time > '09:30:00'::time THEN 1 END) as late_days,
                SUM(worked_hrs) as total_worked_hours,
                COUNT(DISTINCT date) as present_days
            FROM EmployeeDailyStats
            GROUP BY employee_id
        ),
        LeaveStats AS (
            -- Calculate total leave days in the period
            SELECT 
                employee_id,
                SUM(LEAST(leave_to_date::date, @toDate::date) - GREATEST(leave_from_date::date, @fromDate::date) + 1) as leave_days
            FROM leave_zone
            WHERE leave_status = 1 
              AND leave_from_date::date <= @toDate::date 
              AND leave_to_date::date >= @fromDate::date
            GROUP BY employee_id
        ),
        WFHStats AS (
            -- Calculate total WFH days in the period
            SELECT 
                employee_id,
                SUM(LEAST(end_date::date, @toDate::date) - GREATEST(start_date::date, @fromDate::date) + 1) as wfh_days
            FROM work_from_home_requests
            WHERE wfh_status = 1 
              AND start_date::date <= @toDate::date 
              AND end_date::date >= @fromDate::date
            GROUP BY employee_id
        ),
        PermissionStats AS (
            -- Calculate total approved permission hours in the period
            SELECT 
                employee_id,
                SUM(EXTRACT(EPOCH FROM (permission_to_time - permission_from_time))/3600.0) as permission_hours
            FROM permissions
            WHERE permission_status = 1
              AND permission_date::date >= @fromDate::date
              AND permission_date::date <= @toDate::date
            GROUP BY employee_id
        ),
        PendingLeaveStats AS (
            SELECT 
                employee_id,
                SUM(LEAST(leave_to_date::date, @toDate::date) - GREATEST(leave_from_date::date, @fromDate::date) + 1) as pending_leave_days
            FROM leave_zone
            WHERE leave_status = 0 -- Pending
              AND leave_from_date::date <= @toDate::date 
              AND leave_to_date::date >= @fromDate::date
            GROUP BY employee_id
        ),
        PendingPermissionStats AS (
            SELECT 
                employee_id,
                SUM(EXTRACT(EPOCH FROM (permission_to_time - permission_from_time))/3600.0) as pending_permission_hours
            FROM permissions
            WHERE permission_status = 0 -- Pending
              AND permission_date::date >= @fromDate::date
              AND permission_date::date <= @toDate::date
            GROUP BY employee_id
        ),
        PendingWFHStats AS (
            SELECT 
                employee_id,
                SUM(LEAST(end_date::date, @toDate::date) - GREATEST(start_date::date, @fromDate::date) + 1) as pending_wfh_days
            FROM work_from_home_requests
            WHERE wfh_status = 0 -- Pending
              AND start_date::date <= @toDate::date 
              AND end_date::date >= @fromDate::date
            GROUP BY employee_id
        ),
        FinalSummary AS (
            -- Join everything together
            SELECT 
                e.employee_id,
                e.employee_name,
                e.employee_designation,
                e.employee_img,
                COALESCE(stats.total_worked_hours, 0) as total_worked_hours,
                COALESCE(stats.overtime_days, 0) as overtime_days,
                COALESCE(stats.total_overtime_hours, 0) as total_overtime_hours,
                COALESCE(stats.underwork_days, 0) as underwork_days,
                COALESCE(stats.late_days, 0) as late_days,
                COALESCE(stats.present_days, 0) as present_days,
                COALESCE(ls.leave_days, 0) as leave_days,
                COALESCE(ws.wfh_days, 0) as wfh_days,
                COALESCE(ps.permission_hours, 0) as permission_hours,
                COALESCE(pls.pending_leave_days, 0) as pending_leave_days,
                COALESCE(pps.pending_permission_hours, 0) as pending_permission_hours,
                COALESCE(pws.pending_wfh_days, 0) as pending_wfh_days
            FROM employees e
            LEFT JOIN EmployeeAggregatedStats stats ON e.employee_id = stats.employee_id
            LEFT JOIN LeaveStats ls ON e.employee_id = ls.employee_id
            LEFT JOIN WFHStats ws ON e.employee_id = ws.employee_id
            LEFT JOIN PermissionStats ps ON e.employee_id = ps.employee_id
            LEFT JOIN PendingLeaveStats pls ON e.employee_id = pls.employee_id
            LEFT JOIN PendingPermissionStats pps ON e.employee_id = pps.employee_id
            LEFT JOIN PendingWFHStats pws ON e.employee_id = pws.employee_id
            WHERE e.status = 1
        )
        SELECT * FROM FinalSummary
        WHERE 1=1
        $searchClause
        $filterClause
        ORDER BY employee_name ASC;
      ''';

      return await DatabaseConnection.query(sql, values: params);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting all employees performance summary: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }


  /// Get detailed daily performance for all employees in a date range
  Future<List<Map<String, dynamic>>> getAllEmployeesDailyPerformance({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final sql = '''
        SELECT 
          e.employee_id,
          e.employee_name,
          e.employee_designation,
          d.date::text,
          COALESCE(att.total_worked_hours, 0) as worked_hours,
          att.first_clock_in as clock_in,
          att.last_clock_out as clock_out,
          l.leave_type,
          l.is_half_day as leave_is_half_day,
          l.half_day_type as leave_half_day_period,
          l.is_paid_leave as is_paid_leave,
          w.reason as wfh_reason,
          p.permission_from_time,
          p.permission_to_time,
          EXTRACT(EPOCH FROM (p.permission_to_time - p.permission_from_time))/3600.0 as permission_hours,
          CASE 
            WHEN l.leave_id IS NOT NULL THEN 'leave'
            WHEN w.wfh_id IS NOT NULL THEN 'wfh'
            WHEN att.has_attendance IS NOT NULL THEN 'present'
            ELSE 'absent'
          END as status
        FROM employees e
        CROSS JOIN (
          SELECT generate_series(@fromDate::date, @toDate::date, '1 day'::interval)::date as date
        ) d
        LEFT JOIN (
          SELECT 
            employee_id,
            work_date::date as work_date,
            MIN(clock_on_for_the_day) as first_clock_in,
            MAX(clock_off_for_the_day) as last_clock_out,
            SUM(
              CASE 
                WHEN clock_off_for_the_day IS NOT NULL AND clock_off_for_the_day != '' AND clock_on_for_the_day IS NOT NULL AND clock_on_for_the_day != '' THEN 
                  EXTRACT(EPOCH FROM (clock_off_for_the_day::timestamp - clock_on_for_the_day::timestamp))/3600.0
                ELSE 0 
              END
            ) as total_worked_hours,
            1 as has_attendance
          FROM employee_attendance
          WHERE work_date::date BETWEEN @fromDate::date AND @toDate::date
          GROUP BY employee_id, work_date::date
        ) att ON att.employee_id = e.employee_id AND att.work_date = d.date
        LEFT JOIN leave_zone l ON l.employee_id = e.employee_id AND l.leave_status = 1 AND d.date BETWEEN l.leave_from_date::date AND l.leave_to_date::date
        LEFT JOIN work_from_home_requests w ON w.employee_id = e.employee_id AND w.wfh_status = 1 AND d.date >= w.start_date::date AND d.date <= w.end_date::date
        LEFT JOIN permissions p ON p.employee_id = e.employee_id AND p.permission_status = 1 AND p.permission_date::date = d.date
        WHERE e.status = 1
        ORDER BY e.employee_name ASC, d.date ASC
      ''';

      return await DatabaseConnection.query(
        sql,
        values: {'fromDate': fromDate, 'toDate': toDate},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting all employees daily performance: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get detailed daily performance for a specific employee
  Future<List<Map<String, dynamic>>> getEmployeeDailyPerformance({
    required String employeeId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final params = {
        'employeeId': employeeId,
        'fromDate': fromDate,
        'toDate': toDate,
      };

      final sql = '''
        WITH RECURSIVE dates AS (
          SELECT @fromDate::date as date
          UNION ALL
          SELECT (date + INTERVAL '1 day')::date
          FROM dates
          WHERE date < @toDate::date
        )
        SELECT 
          d.date::text,
          COALESCE(att.total_worked_hours, 0) as worked_hours,
          att.first_clock_in as clock_in,
          att.last_clock_out as clock_out,
          CASE 
            WHEN l.leave_id IS NOT NULL THEN 'leave'
            WHEN w.wfh_id IS NOT NULL THEN 'wfh'
            WHEN att.has_attendance IS NOT NULL THEN 'present'
            ELSE 'absent'
          END as status,
          l.leave_type,
          l.is_half_day,
          l.half_day_type,
          l.is_paid_leave,
          w.reason as wfh_reason,
          p.permission_id,
          p.permission_from_time,
          p.permission_to_time,
          -- Calculate work status
          CASE 
            WHEN att.has_attendance IS NOT NULL THEN
              CASE 
                WHEN COALESCE(att.total_worked_hours, 0) * 60 < 540 THEN 'underwork'
                WHEN COALESCE(att.total_worked_hours, 0) * 60 > 550 THEN 'overwork'
                ELSE 'normal'
              END
            ELSE NULL
          END as work_status,
          CASE 
            WHEN att.has_attendance IS NOT NULL THEN
              (COALESCE(att.total_worked_hours, 0) * 60 - 540)::int
            ELSE 0
          END as excess_or_deficit_minutes
        FROM dates d
        LEFT JOIN (
          SELECT 
            employee_id,
            work_date::date as work_date,
            MIN(clock_on_for_the_day) as first_clock_in,
            MAX(clock_off_for_the_day) as last_clock_out,
            SUM(
              CASE 
                WHEN clock_off_for_the_day IS NOT NULL AND clock_off_for_the_day != '' AND clock_on_for_the_day IS NOT NULL AND clock_on_for_the_day != '' THEN 
                  EXTRACT(EPOCH FROM (clock_off_for_the_day::timestamp - clock_on_for_the_day::timestamp))/3600.0
                ELSE 0 
              END
            ) as total_worked_hours,
            1 as has_attendance
          FROM employee_attendance
          WHERE employee_id = @employeeId
          GROUP BY employee_id, work_date::date
        ) att ON att.employee_id = @employeeId AND att.work_date = d.date
        LEFT JOIN leave_zone l ON l.employee_id = @employeeId AND l.leave_status = 1 AND d.date BETWEEN l.leave_from_date::date AND l.leave_to_date::date
        LEFT JOIN work_from_home_requests w ON w.employee_id = @employeeId AND w.wfh_status = 1 AND d.date BETWEEN w.start_date::date AND w.end_date::date
        LEFT JOIN permissions p ON p.employee_id = @employeeId AND p.permission_status = 1 AND p.permission_date::date = d.date
        ORDER BY d.date ASC
      ''';

      return await DatabaseConnection.query(sql, values: params);
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee daily performance: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
