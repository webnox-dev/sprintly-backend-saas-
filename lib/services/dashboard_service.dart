import '../data/database/connection.dart';
import '../core/utils/logger.dart';

/// Dashboard service for consolidated admin dashboard data
class DashboardService {
  final AppLogger _logger = AppLogger('DashboardService');

  /// Get consolidated calendar events for a specific date
  /// Includes: Leaves, WFH, Task Cards, Company Holidays, and Permissions
  Future<Map<String, dynamic>> getCalendarEvents(String date) async {
    try {
      _logger.info('Fetching calendar events for date: $date');

      // 1. Get approved leaves for the date
      final leavesSql = '''
        SELECT 
          l.leave_id, l.employee_id, l.leave_from_date, l.leave_to_date, 
          l.leave_remarks, l.leave_type, l.leave_status, l.is_half_day, l.half_day_type,
          e.employee_name, e.employee_img, e.employee_designation
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE @date BETWEEN l.leave_from_date AND l.leave_to_date
        AND l.leave_status = 1
        ORDER BY e.employee_name
      ''';
      final leavesResult = await DatabaseConnection.query(
        leavesSql,
        values: {'date': date},
      );

      // 2. Get approved WFH requests for the date
      final wfhSql = '''
        SELECT 
          w.wfh_id, w.employee_id, w.start_date, w.end_date, w.reason, w.wfh_status,
          e.employee_name, e.employee_img, e.employee_designation
        FROM work_from_home_requests w
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        WHERE @date BETWEEN w.start_date AND w.end_date
        AND w.wfh_status = 1
        ORDER BY e.employee_name
      ''';
      final wfhResult = await DatabaseConnection.query(
        wfhSql,
        values: {'date': date},
      );

      // 3. Get task cards for the date (assigned or due on that date)
      final taskCardsSql = '''
        SELECT 
          t.task_id, t.task_name, t.task_description, t.workflow_status, 
          t.priority_level, t.from_date, t.to_date, t.employee_id, t.project_id,
          e.employee_name, e.employee_img, e.employee_designation,
          p.project_name
        FROM task_cards t
        LEFT JOIN employees e ON t.employee_id = e.employee_id
        LEFT JOIN projects p ON t.project_id = p.project_id
        WHERE (t.from_date = @date OR t.to_date = @date OR (@date BETWEEN t.from_date AND t.to_date))
        AND (t.is_deleted IS NULL OR t.is_deleted = false)
        ORDER BY t.priority_level DESC, t.from_date
      ''';
      final taskCardsResult = await DatabaseConnection.query(
        taskCardsSql,
        values: {'date': date},
      );

      // 4. Get company holidays for the date
      final holidaysSql = '''
        SELECT 
          holiday_id, holiday_name, from_date, to_date, total_days, holiday_remarks, is_optional
        FROM company_holidays
        WHERE @date::date BETWEEN from_date AND COALESCE(to_date, from_date)
        ORDER BY holiday_name
      ''';
      final holidaysResult = await DatabaseConnection.query(
        holidaysSql,
        values: {'date': date},
      );

      // 5. Get approved permissions for the date
      final permissionsSql = '''
        SELECT 
          p.permission_id, p.employee_id, p.permission_date, 
          p.permission_from_time, p.permission_to_time,
          p.permission_remarks, p.permission_status,
          e.employee_name, e.employee_img, e.employee_designation
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.permission_date = @date::date
        AND p.permission_status = 1
        ORDER BY e.employee_name
      ''';
      final permissionsResult = await DatabaseConnection.query(
        permissionsSql,
        values: {'date': date},
      );

      // Format the response
      final leaves = leavesResult
          .map(
            (row) => {
              'leave_id': row['leave_id'],
              'employee_id': row['employee_id'],
              'employee_name': row['employee_name'],
              'employee_img': row['employee_img'] ?? '',
              'employee_designation': row['employee_designation'] ?? '',
              'leave_from_date': row['leave_from_date']?.toString().split(
                'T',
              )[0],
              'leave_to_date': row['leave_to_date']?.toString().split('T')[0],
              'leave_remarks': row['leave_remarks'],
              'leave_type': row['leave_type'],
              'is_half_day': row['is_half_day'] ?? false,
              'half_day_type': row['half_day_type'],
            },
          )
          .toList();

      final wfhRequests = wfhResult
          .map(
            (row) => {
              'wfh_id': row['wfh_id'],
              'employee_id': row['employee_id'],
              'employee_name': row['employee_name'],
              'employee_img': row['employee_img'] ?? '',
              'employee_designation': row['employee_designation'] ?? '',
              'start_date': row['start_date']?.toString().split('T')[0],
              'end_date': row['end_date']?.toString().split('T')[0],
              'reason': row['reason'],
            },
          )
          .toList();

      final taskCards = taskCardsResult
          .map(
            (row) => {
              'task_id': row['task_id'],
              'task_name': row['task_name'],
              'task_description': row['task_description'],
              'workflow_status': row['workflow_status'],
              'priority_level': row['priority_level'],
              'from_date': row['from_date']?.toString().split('T')[0],
              'to_date': row['to_date']?.toString().split('T')[0],
              'employee_id': row['employee_id'],
              'employee_name': row['employee_name'],
              'employee_img': row['employee_img'] ?? '',
              'employee_designation': row['employee_designation'] ?? '',
              'project_id': row['project_id'],
              'project_name': row['project_name'] ?? '',
            },
          )
          .toList();

      final holidays = holidaysResult
          .map(
            (row) => {
              'holiday_id': row['holiday_id'],
              'holiday_name': row['holiday_name'],
              'from_date': row['from_date']?.toString().split('T')[0],
              'to_date': row['to_date']?.toString().split('T')[0],
              'total_days': row['total_days'] ?? 1,
              'holiday_remarks': row['holiday_remarks'],
              'is_optional': row['is_optional'] ?? false,
            },
          )
          .toList();

      final permissions = permissionsResult
          .map(
            (row) => {
              'permission_id': row['permission_id'],
              'employee_id': row['employee_id'],
              'employee_name': row['employee_name'],
              'employee_img': row['employee_img'] ?? '',
              'employee_designation': row['employee_designation'] ?? '',
              'permission_date': row['permission_date']?.toString().split(
                'T',
              )[0],
              'permission_from_time': row['permission_from_time'],
              'permission_to_time': row['permission_to_time'],
              'permission_remarks': row['permission_remarks'],
            },
          )
          .toList();

      return {
        'date': date,
        'leaves': leaves,
        'leaves_count': leaves.length,
        'wfh_requests': wfhRequests,
        'wfh_count': wfhRequests.length,
        'task_cards': taskCards,
        'task_cards_count': taskCards.length,
        'company_holidays': holidays,
        'holidays_count': holidays.length,
        'permissions': permissions,
        'permissions_count': permissions.length,
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching calendar events: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get birthdays for the current month (both admins and employees)
  Future<Map<String, dynamic>> getBirthdays({int? month}) async {
    try {
      final targetMonth = month ?? DateTime.now().month;
      final monthStr = targetMonth.toString().padLeft(2, '0');
      _logger.info('Fetching birthdays for month: $targetMonth');

      // Get employee birthdays - DOB format is DD-MM-YYYY
      // Using PostgreSQL SPLIT_PART function
      final employeeBirthdaysSql = '''
        SELECT 
          employee_id, employee_name, employee_img, employee_dob, 
          employee_designation, employee_role, employee_phone_num
        FROM employees
        WHERE status = 1
        AND SPLIT_PART(employee_dob, '-', 2) = @month
        ORDER BY CAST(SPLIT_PART(employee_dob, '-', 1) AS INTEGER)
      ''';
      final employeeBirthdays = await DatabaseConnection.query(
        employeeBirthdaysSql,
        values: {'month': monthStr},
      );

      // Get admin birthdays - DOB format is DD-MM-YYYY
      final adminBirthdaysSql = '''
        SELECT 
          admin_id, admin_name, admin_img, admin_dob, 
          admin_role, admin_phone_num, admin_designation
        FROM admins
        WHERE status = 1
        AND SPLIT_PART(admin_dob, '-', 2) = @month
        ORDER BY CAST(SPLIT_PART(admin_dob, '-', 1) AS INTEGER)
      ''';
      final adminBirthdays = await DatabaseConnection.query(
        adminBirthdaysSql,
        values: {'month': monthStr},
      );

      // Format employee birthdays
      final employees = employeeBirthdays.map((row) {
        final dob = row['employee_dob']?.toString() ?? '';
        final day = dob.isNotEmpty ? dob.split('-')[0] : '';
        return {
          'id': row['employee_id'],
          'name': row['employee_name'],
          'image': row['employee_img'] ?? '',
          'dob': dob,
          'day': day,
          'designation': row['employee_designation'] ?? '',
          'role': row['employee_role'] ?? '',
          'phone': row['employee_phone_num'] ?? '',
          'type': 'employee',
        };
      }).toList();

      // Format admin birthdays
      final admins = adminBirthdays.map((row) {
        final dob = row['admin_dob']?.toString() ?? '';
        final day = dob.isNotEmpty ? dob.split('-')[0] : '';
        return {
          'id': row['admin_id'],
          'name': row['admin_name'],
          'image': row['admin_img'] ?? '',
          'dob': dob,
          'day': day,
          'designation': row['admin_designation'] ?? row['admin_role'] ?? '',
          'role': row['admin_role'] ?? '',
          'phone': row['admin_phone_num'] ?? '',
          'type': 'admin',
        };
      }).toList();

      // Combine and sort by day
      final allBirthdays = [...admins, ...employees];
      allBirthdays.sort((a, b) {
        final dayA = int.tryParse(a['day']?.toString() ?? '0') ?? 0;
        final dayB = int.tryParse(b['day']?.toString() ?? '0') ?? 0;
        return dayA.compareTo(dayB);
      });

      // Find today's birthdays
      final today = DateTime.now();
      final todayStr =
          '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}';
      final todaysBirthdays = allBirthdays.where((b) {
        final dob = b['dob']?.toString() ?? '';
        if (dob.isEmpty) return false;
        final parts = dob.split('-');
        if (parts.length < 2) return false;
        return '${parts[0]}-${parts[1]}' == todayStr;
      }).toList();

      // Find upcoming birthdays (next 7 days)
      final upcomingBirthdays = <Map<String, dynamic>>[];
      for (var i = 1; i <= 7; i++) {
        final futureDate = today.add(Duration(days: i));
        final futureDayMonth =
            '${futureDate.day.toString().padLeft(2, '0')}-${futureDate.month.toString().padLeft(2, '0')}';
        for (var b in allBirthdays) {
          final dob = b['dob']?.toString() ?? '';
          if (dob.isEmpty) continue;
          final parts = dob.split('-');
          if (parts.length < 2) continue;
          if ('${parts[0]}-${parts[1]}' == futureDayMonth) {
            upcomingBirthdays.add({...b, 'days_until': i});
          }
        }
      }

      return {
        'month': targetMonth,
        'month_name': _getMonthName(targetMonth),
        'all_birthdays': allBirthdays,
        'total_count': allBirthdays.length,
        'admin_count': admins.length,
        'employee_count': employees.length,
        'todays_birthdays': todaysBirthdays,
        'todays_count': todaysBirthdays.length,
        'upcoming_birthdays': upcomingBirthdays,
        'upcoming_count': upcomingBirthdays.length,
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching birthdays: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task card analytics for pie and bar charts
  Future<Map<String, dynamic>> getTaskAnalytics() async {
    try {
      _logger.info('Fetching task card analytics');

      // 1. Get task counts by workflow status (for pie chart)
      final statusCountsSql = '''
        SELECT 
          workflow_status, 
          COUNT(*) as count
        FROM task_cards
        WHERE (is_deleted IS NULL OR is_deleted = false)
        GROUP BY workflow_status
        ORDER BY count DESC
      ''';
      final statusCounts = await DatabaseConnection.query(statusCountsSql);

      // 2. Get task counts by priority level
      final priorityCountsSql = '''
        SELECT 
          priority_level, 
          COUNT(*) as count
        FROM task_cards
        WHERE (is_deleted IS NULL OR is_deleted = false)
        GROUP BY priority_level
        ORDER BY count DESC
      ''';
      final priorityCounts = await DatabaseConnection.query(priorityCountsSql);

      // 3. Get monthly task completion trend (last 6 months)
      final monthlyTrendSql = '''
        SELECT 
          TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') as month,
          COUNT(*) as total_created,
          COUNT(CASE WHEN workflow_status = 'COMPLETED' OR workflow_status = 'QC_COMPLETED' THEN 1 END) as completed,
          COUNT(CASE WHEN workflow_status = 'IN_PROGRESS' OR workflow_status = 'DEV_STARTED' THEN 1 END) as in_progress
        FROM task_cards
        WHERE created_at >= NOW() - INTERVAL '6 months'
        AND (is_deleted IS NULL OR is_deleted = false)
        GROUP BY DATE_TRUNC('month', created_at)
        ORDER BY month
      ''';
      final monthlyTrend = await DatabaseConnection.query(monthlyTrendSql);

      // 4. Get efficiency metrics
      final efficiencyMetricsSql = '''
        SELECT 
          COUNT(*) as total_tasks,
          COUNT(CASE WHEN workflow_status = 'COMPLETED' OR workflow_status = 'QC_COMPLETED' THEN 1 END) as completed_tasks,
          COUNT(CASE WHEN workflow_status = 'TODO' OR workflow_status = 'ASSIGNED' THEN 1 END) as pending_tasks,
          COUNT(CASE WHEN workflow_status = 'IN_PROGRESS' OR workflow_status = 'DEV_STARTED' OR workflow_status = 'QC_STARTED' THEN 1 END) as in_progress_tasks,
          COUNT(CASE WHEN workflow_status = 'REJECTED' OR workflow_status = 'REDO' THEN 1 END) as rejected_tasks,
          AVG(EXTRACT(EPOCH FROM (dev_completed_at - dev_started_at)) / 3600) as avg_dev_hours,
          AVG(EXTRACT(EPOCH FROM (qc_completed_at - qc_started_at)) / 3600) as avg_qc_hours
        FROM task_cards
        WHERE (is_deleted IS NULL OR is_deleted = false)
      ''';
      final efficiencyResult = await DatabaseConnection.queryOne(
        efficiencyMetricsSql,
      );

      // 5. Get top 5 employees by completed tasks
      final topEmployeesSql = '''
        SELECT 
          t.employee_id,
          e.employee_name,
          e.employee_img,
          COUNT(*) as completed_count
        FROM task_cards t
        LEFT JOIN employees e ON t.employee_id = e.employee_id
        WHERE (t.workflow_status = 'COMPLETED' OR t.workflow_status = 'QC_COMPLETED')
        AND (t.is_deleted IS NULL OR t.is_deleted = false)
        AND t.employee_id IS NOT NULL
        GROUP BY t.employee_id, e.employee_name, e.employee_img
        ORDER BY completed_count DESC
        LIMIT 5
      ''';
      final topEmployees = await DatabaseConnection.query(topEmployeesSql);

      // 6. Get tasks by project
      final tasksByProjectSql = '''
        SELECT 
          t.project_id,
          p.project_name,
          COUNT(*) as total_tasks,
          COUNT(CASE WHEN t.workflow_status = 'COMPLETED' OR t.workflow_status = 'QC_COMPLETED' THEN 1 END) as completed_tasks
        FROM task_cards t
        LEFT JOIN projects p ON t.project_id = p.project_id
        WHERE (t.is_deleted IS NULL OR t.is_deleted = false)
        AND t.project_id IS NOT NULL
        GROUP BY t.project_id, p.project_name
        ORDER BY total_tasks DESC
        LIMIT 10
      ''';
      final tasksByProject = await DatabaseConnection.query(tasksByProjectSql);

      // Calculate overall efficiency
      final totalTasks =
          (efficiencyResult?['total_tasks'] as num?)?.toInt() ?? 0;
      final completedTasks =
          (efficiencyResult?['completed_tasks'] as num?)?.toInt() ?? 0;
      final pendingTasks =
          (efficiencyResult?['pending_tasks'] as num?)?.toInt() ?? 0;
      final inProgressTasks =
          (efficiencyResult?['in_progress_tasks'] as num?)?.toInt() ?? 0;
      final rejectedTasks =
          (efficiencyResult?['rejected_tasks'] as num?)?.toInt() ?? 0;
      final avgDevHours =
          (efficiencyResult?['avg_dev_hours'] as num?)?.toDouble() ?? 0.0;
      final avgQcHours =
          (efficiencyResult?['avg_qc_hours'] as num?)?.toDouble() ?? 0.0;

      final completionRate = totalTasks > 0
          ? (completedTasks / totalTasks * 100)
          : 0.0;
      final rejectionRate = totalTasks > 0
          ? (rejectedTasks / totalTasks * 100)
          : 0.0;

      // Format status counts for pie chart
      final statusData = statusCounts
          .map(
            (row) => {
              'status': row['workflow_status'] ?? 'Unknown',
              'count': (row['count'] as num?)?.toInt() ?? 0,
              'label': _formatWorkflowStatus(
                row['workflow_status']?.toString() ?? '',
              ),
            },
          )
          .toList();

      // Format priority counts
      final priorityData = priorityCounts
          .map(
            (row) => {
              'priority': row['priority_level'] ?? 'Medium',
              'count': (row['count'] as num?)?.toInt() ?? 0,
            },
          )
          .toList();

      // Format monthly trend for bar chart
      final trendData = monthlyTrend
          .map(
            (row) => {
              'month': row['month'] ?? '',
              'total_created': (row['total_created'] as num?)?.toInt() ?? 0,
              'completed': (row['completed'] as num?)?.toInt() ?? 0,
              'in_progress': (row['in_progress'] as num?)?.toInt() ?? 0,
            },
          )
          .toList();

      // Format top employees
      final topPerformers = topEmployees
          .map(
            (row) => {
              'employee_id': row['employee_id'],
              'employee_name': row['employee_name'] ?? 'Unknown',
              'employee_img': row['employee_img'] ?? '',
              'completed_count': (row['completed_count'] as num?)?.toInt() ?? 0,
            },
          )
          .toList();

      // Format tasks by project
      final projectData = tasksByProject
          .map(
            (row) => {
              'project_id': row['project_id'],
              'project_name': row['project_name'] ?? 'No Project',
              'total_tasks': (row['total_tasks'] as num?)?.toInt() ?? 0,
              'completed_tasks': (row['completed_tasks'] as num?)?.toInt() ?? 0,
              'completion_rate': (row['total_tasks'] as num?)?.toInt() != 0
                  ? ((row['completed_tasks'] as num?)?.toInt() ?? 0) /
                        ((row['total_tasks'] as num?)?.toInt() ?? 1) *
                        100
                  : 0.0,
            },
          )
          .toList();

      return {
        'summary': {
          'total_tasks': totalTasks,
          'completed_tasks': completedTasks,
          'pending_tasks': pendingTasks,
          'in_progress_tasks': inProgressTasks,
          'rejected_tasks': rejectedTasks,
          'completion_rate': double.parse(completionRate.toStringAsFixed(2)),
          'rejection_rate': double.parse(rejectionRate.toStringAsFixed(2)),
          'avg_dev_hours': double.parse(avgDevHours.toStringAsFixed(2)),
          'avg_qc_hours': double.parse(avgQcHours.toStringAsFixed(2)),
        },
        'status_distribution': statusData,
        'priority_distribution': priorityData,
        'monthly_trend': trendData,
        'top_performers': topPerformers,
        'tasks_by_project': projectData,
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching task analytics: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Helper to format workflow status for display
  String _formatWorkflowStatus(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
        return 'To Do';
      case 'ASSIGNED':
        return 'Assigned';
      case 'IN_PROGRESS':
      case 'DEV_STARTED':
        return 'In Progress';
      case 'DEV_COMPLETED':
        return 'Dev Completed';
      case 'QC_STARTED':
        return 'QC Started';
      case 'QC_COMPLETED':
      case 'COMPLETED':
        return 'Completed';
      case 'REJECTED':
        return 'Rejected';
      case 'REDO':
        return 'Redo';
      default:
        return status;
    }
  }

  /// Helper to get month name
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
