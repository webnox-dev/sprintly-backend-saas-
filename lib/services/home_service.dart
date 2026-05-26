import '../data/database/connection.dart';
import '../data/repositories/task_card_repository.dart';
import '../data/repositories/announcement_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../domain/models/calendar_meeting.dart';
import '../core/utils/logger.dart';

/// Home Service for admin dashboard APIs
/// Provides consolidated data for the home screen
class HomeService {
  final AppLogger _logger = AppLogger('HomeService');
  final AnnouncementRepository _announcementRepository =
      AnnouncementRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  // ============================================================
  // API 1: HOME OVERVIEW
  // Endpoint: POST /api/home/overview
  // Purpose: Get task stats, charts data, and birthdays for a month
  // ============================================================

  /// Get home overview data for a specific month
  /// Required: month (1-12), year (e.g., 2026)
  Future<Map<String, dynamic>> getHomeOverview({
    required int month,
    required int year,
    String? date,
  }) async {
    try {
      _logger.info('Fetching home overview for $month/$year');

      // Calculate date range for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0); // Last day of month
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      // 1. Get task status counts for the month
      final taskStatusCounts = await _getTaskStatusCountsForMonth(
        startDateStr,
        endDateStr,
      );

      // 2. Get chart data (pie chart - status distribution, bar chart - weekly trend)
      final chartData = await _getChartDataForMonth(startDateStr, endDateStr);

      // 3. Get birthdays for the month
      final birthdays = await _getBirthdaysForMonth(month);

      // 4. Get delayed task cards count (overdue + still in progress)
      final delayedCount = await TaskCardRepository()
          .getDelayedTaskCardsCount();

      // 5. Get announcements for target date (defaults to today)
      DateTime filterDate = DateTime.now();
      if (date != null) {
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null) {
          filterDate = parsedDate;
        }
      }

      final (announcements, _) = await _announcementRepository
          .getAllAnnouncements(
            startDate: filterDate,
            endDate: filterDate,
            isActive: true,
            limit: 10,
            sortBy: 'created_at',
            sortOrder: 'DESC',
          );

      return {
        'month': month,
        'year': year,
        'month_name': _getMonthName(month),
        'task_stats': taskStatusCounts,
        'charts': chartData,
        'birthdays': birthdays,
        'delayed_tasks_count': delayedCount,
        'announcements': announcements.map((e) => e.toJson()).toList(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching home overview: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get task status counts for a specific month
  Future<Map<String, dynamic>> _getTaskStatusCountsForMonth(
    String startDate,
    String endDate,
  ) async {
    // Use UPPER() and check for multiple possible formats of workflow_status
    // Database may store values as 'In Progress', 'IN_PROGRESS', 'in_progress', etc.
    final sql = '''
      SELECT 
        COUNT(*) as total_tasks,
        COUNT(CASE WHEN created_at::date BETWEEN @startDate::date AND @endDate::date THEN 1 END) as created_this_month,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'TODO' THEN 1 END) as todo,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'ASSIGNED' THEN 1 END) as assigned,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) IN ('IN_PROGRESS', 'DEV_STARTED') THEN 1 END) as in_progress,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'DEV_COMPLETED' THEN 1 END) as dev_completed,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'QC_STARTED' THEN 1 END) as qc_started,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) IN ('COMPLETED', 'QC_COMPLETED') THEN 1 END) as completed,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'REJECTED' THEN 1 END) as rejected,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'REDO' THEN 1 END) as redo,
        COUNT(CASE WHEN UPPER(REPLACE(workflow_status, ' ', '_')) = 'ON_HOLD' THEN 1 END) as on_hold
      FROM task_cards
      WHERE (is_deleted IS NULL OR is_deleted = false)
    ''';

    final result = await DatabaseConnection.queryOne(
      sql,
      values: {'startDate': startDate, 'endDate': endDate},
    );

    // Get month-specific counts (tasks created/completed in this month)
    final monthSql = '''
      SELECT 
        COUNT(CASE WHEN created_at::date BETWEEN @startDate::date AND @endDate::date THEN 1 END) as created_this_month,
        COUNT(CASE WHEN dev_completed_at::date BETWEEN @startDate::date AND @endDate::date THEN 1 END) as dev_completed_this_month,
        COUNT(CASE WHEN qc_completed_at::date BETWEEN @startDate::date AND @endDate::date THEN 1 END) as completed_this_month
      FROM task_cards
      WHERE (is_deleted IS NULL OR is_deleted = false)
    ''';

    final monthResult = await DatabaseConnection.queryOne(
      monthSql,
      values: {'startDate': startDate, 'endDate': endDate},
    );

    // Helper function to safely parse int from dynamic value (handles both String and num)
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    return {
      'total_tasks': safeInt(result?['total_tasks']),
      'created_this_month': safeInt(monthResult?['created_this_month']),
      'completed_this_month': safeInt(monthResult?['completed_this_month']),
      'dev_completed_this_month': safeInt(
        monthResult?['dev_completed_this_month'],
      ),
      'status_breakdown': {
        'todo': safeInt(result?['todo']),
        'assigned': safeInt(result?['assigned']),
        'in_progress': safeInt(result?['in_progress']),
        'dev_completed': safeInt(result?['dev_completed']),
        'qc_started': safeInt(result?['qc_started']),
        'completed': safeInt(result?['completed']),
        'rejected': safeInt(result?['rejected']),
        'redo': safeInt(result?['redo']),
        'on_hold': safeInt(result?['on_hold']),
      },
    };
  }

  /// Get chart data for the month (pie chart + bar chart)
  Future<Map<String, dynamic>> _getChartDataForMonth(
    String startDate,
    String endDate,
  ) async {
    // PIE CHART: Status distribution
    final pieChartSql = '''
      SELECT 
        workflow_status,
        COUNT(*) as count
      FROM task_cards
      WHERE (is_deleted IS NULL OR is_deleted = false)
      GROUP BY workflow_status
      ORDER BY count DESC
    ''';
    final pieChartResult = await DatabaseConnection.query(pieChartSql);

    final pieChartData = pieChartResult.map((row) {
      final status = row['workflow_status']?.toString() ?? 'Unknown';
      // Handle both String and num types from database
      final countVal = row['count'];
      final count = countVal is num
          ? countVal.toInt()
          : int.tryParse(countVal?.toString() ?? '0') ?? 0;
      return {
        'status': status,
        'label': _formatWorkflowStatus(status),
        'count': count,
        'color': _getStatusColor(status),
      };
    }).toList();

    // BAR CHART: Weekly breakdown for the month
    final barChartSql = '''
      SELECT 
        EXTRACT(WEEK FROM created_at) as week_number,
        DATE_TRUNC('week', created_at)::date as week_start,
        COUNT(*) as total_created,
        COUNT(CASE WHEN workflow_status IN ('COMPLETED', 'QC_COMPLETED') THEN 1 END) as completed,
        COUNT(CASE WHEN workflow_status IN ('IN_PROGRESS', 'DEV_STARTED', 'DEV_COMPLETED', 'QC_STARTED') THEN 1 END) as in_progress
      FROM task_cards
      WHERE created_at::date BETWEEN @startDate::date AND @endDate::date
      AND (is_deleted IS NULL OR is_deleted = false)
      GROUP BY EXTRACT(WEEK FROM created_at), DATE_TRUNC('week', created_at)
      ORDER BY week_start
    ''';
    final barChartResult = await DatabaseConnection.query(
      barChartSql,
      values: {'startDate': startDate, 'endDate': endDate},
    );

    final barChartData = barChartResult.map((row) {
      // Handle both String and num types from database
      final weekNum = row['week_number'];
      final weekNumber = weekNum is num
          ? weekNum.toInt()
          : int.tryParse(weekNum?.toString() ?? '0') ?? 0;

      final totalCreated = row['total_created'];
      final totalCreatedInt = totalCreated is num
          ? totalCreated.toInt()
          : int.tryParse(totalCreated?.toString() ?? '0') ?? 0;

      final completed = row['completed'];
      final completedInt = completed is num
          ? completed.toInt()
          : int.tryParse(completed?.toString() ?? '0') ?? 0;

      final inProgress = row['in_progress'];
      final inProgressInt = inProgress is num
          ? inProgress.toInt()
          : int.tryParse(inProgress?.toString() ?? '0') ?? 0;

      return {
        'week_number': weekNumber,
        'week_start': row['week_start']?.toString().split('T')[0] ?? '',
        'total_created': totalCreatedInt,
        'completed': completedInt,
        'in_progress': inProgressInt,
      };
    }).toList();

    // EFFICIENCY METRICS
    final totalTasks = pieChartData.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );
    final completedTasks = pieChartData
        .where(
          (item) =>
              item['status'] == 'COMPLETED' || item['status'] == 'QC_COMPLETED',
        )
        .fold<int>(0, (sum, item) => sum + (item['count'] as int));

    final completionRate = totalTasks > 0
        ? (completedTasks / totalTasks * 100)
        : 0.0;

    return {
      'pie_chart': pieChartData,
      'bar_chart': barChartData,
      'efficiency': {
        'total_tasks': totalTasks,
        'completed_tasks': completedTasks,
        'completion_rate': double.parse(completionRate.toStringAsFixed(2)),
      },
    };
  }

  /// Get birthdays for a specific month
  Future<Map<String, dynamic>> _getBirthdaysForMonth(int month) async {
    final monthStr = month.toString().padLeft(2, '0');

    // Employee birthdays (DOB format: DD-MM-YYYY)
    final employeeSql = '''
      SELECT 
        employee_id, employee_name, employee_img, employee_dob,
        employee_designation, employee_role, employee_personal_email,
        employee_company_email, employee_doj
      FROM employees
      WHERE status = 1
      AND employee_dob IS NOT NULL
      AND SPLIT_PART(employee_dob, '-', 2) = @month
      ORDER BY CAST(SPLIT_PART(employee_dob, '-', 1) AS INTEGER)
    ''';
    final employeeResult = await DatabaseConnection.query(
      employeeSql,
      values: {'month': monthStr},
    );

    // Admin birthdays (DOB format: DD-MM-YYYY)
    final adminSql = '''
      SELECT 
        admin_id, admin_name, admin_img, admin_dob,
        admin_designation, admin_role, admin_personal_email,
        admin_company_email, admin_doj
      FROM admins
      WHERE status = 1
      AND admin_dob IS NOT NULL
      AND SPLIT_PART(admin_dob, '-', 2) = @month
      ORDER BY CAST(SPLIT_PART(admin_dob, '-', 1) AS INTEGER)
    ''';
    final adminResult = await DatabaseConnection.query(
      adminSql,
      values: {'month': monthStr},
    );

    final now = DateTime.now();

    // Format employee results with full profile
    final employees = employeeResult.map((row) {
      final dob = row['employee_dob']?.toString() ?? '';
      final doj = row['employee_doj']?.toString() ?? '';
      final age = _calculateAge(dob);
      final experience = _calculateExperience(doj);

      return {
        'id': row['employee_id'],
        'name': row['employee_name'],
        'image': row['employee_img'] ?? '',
        'dob': dob,
        'day': dob.isNotEmpty ? int.tryParse(dob.split('-')[0]) ?? 0 : 0,
        'age': age,
        'designation': row['employee_designation'] ?? '',
        'role': row['employee_role'] ?? '',
        'email':
            row['employee_company_email'] ??
            row['employee_personal_email'] ??
            '',
        'doj': doj,
        'experience': experience,
        'type': 'employee',
      };
    }).toList();

    // Format admin results with full profile
    final admins = adminResult.map((row) {
      final dob = row['admin_dob']?.toString() ?? '';
      final doj = row['admin_doj']?.toString() ?? '';
      final age = _calculateAge(dob);
      final experience = _calculateExperience(doj);

      return {
        'id': row['admin_id'],
        'name': row['admin_name'],
        'image': row['admin_img'] ?? '',
        'dob': dob,
        'day': dob.isNotEmpty ? int.tryParse(dob.split('-')[0]) ?? 0 : 0,
        'age': age,
        'designation': row['admin_designation'] ?? '',
        'role': row['admin_role'] ?? 'Admin',
        'email':
            row['admin_company_email'] ?? row['admin_personal_email'] ?? '',
        'doj': doj,
        'experience': experience,
        'type': 'admin',
      };
    }).toList();

    // Combine and sort by day
    final allBirthdays = [...admins, ...employees];
    allBirthdays.sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));

    // Find today's birthdays
    final todayDay = now.day;
    final todayMonth = now.month;

    final todaysBirthdays = allBirthdays.where((b) {
      return b['day'] == todayDay && month == todayMonth;
    }).toList();

    // Find upcoming birthdays (within next 7 days in this month)
    final upcomingBirthdays = <Map<String, dynamic>>[];
    for (var i = 1; i <= 7; i++) {
      final futureDate = now.add(Duration(days: i));
      if (futureDate.month == month) {
        for (var b in allBirthdays) {
          if (b['day'] == futureDate.day) {
            upcomingBirthdays.add({...b, 'days_until': i});
          }
        }
      }
    }

    return {
      'month': month,
      'month_name': _getMonthName(month),
      'all': allBirthdays,
      'today': todaysBirthdays,
      'upcoming': upcomingBirthdays,
      'total_count': allBirthdays.length,
    };
  }

  /// Calculate age from DOB (format: DD-MM-YYYY)
  int _calculateAge(String dob) {
    if (dob.isEmpty) return 0;
    try {
      final parts = dob.split('-');
      if (parts.length != 3) return 0;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birthDate = DateTime(year, month, day);
      final now = DateTime.now();

      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }

  /// Calculate experience from DOJ (format: DD-MM-YYYY or YYYY-MM-DD)
  Map<String, dynamic> _calculateExperience(String doj) {
    if (doj.isEmpty) return {'years': 0, 'months': 0, 'text': 'N/A'};
    try {
      DateTime joinDate;

      // Handle different date formats
      if (doj.contains('T')) {
        // ISO format: YYYY-MM-DDTHH:MM:SS
        joinDate = DateTime.parse(doj.split('T')[0]);
      } else if (doj.contains('-')) {
        final parts = doj.split('-');
        if (parts[0].length == 4) {
          // YYYY-MM-DD format
          joinDate = DateTime.parse(doj);
        } else {
          // DD-MM-YYYY format
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          joinDate = DateTime(year, month, day);
        }
      } else {
        return {'years': 0, 'months': 0, 'text': 'N/A'};
      }

      final now = DateTime.now();
      int years = now.year - joinDate.year;
      int months = now.month - joinDate.month;

      if (now.day < joinDate.day) {
        months--;
      }
      if (months < 0) {
        years--;
        months += 12;
      }

      String text;
      if (years > 0 && months > 0) {
        text =
            '$years year${years > 1 ? 's' : ''}, $months month${months > 1 ? 's' : ''}';
      } else if (years > 0) {
        text = '$years year${years > 1 ? 's' : ''}';
      } else if (months > 0) {
        text = '$months month${months > 1 ? 's' : ''}';
      } else {
        text = 'Less than a month';
      }

      return {'years': years, 'months': months, 'text': text};
    } catch (_) {
      return {'years': 0, 'months': 0, 'text': 'N/A'};
    }
  }

  // ============================================================
  // API 2: MONTHLY EVENTS (Calendar Feed)
  // Endpoint: POST /api/home/monthly-events
  // Purpose: Get all events for a month to populate calendar
  // ============================================================

  /// Get all events for a specific month (for calendar indicators)
  Future<Map<String, dynamic>> getMonthlyEvents({
    required int month,
    required int year,
  }) async {
    try {
      _logger.info('Fetching monthly events for $month/$year');

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);
      final startDateStr = _formatDate(startDate);
      final endDateStr = _formatDate(endDate);

      // Get task cards for the month
      final taskCardsSql = '''
        SELECT 
          task_id, task_name, workflow_status, priority_level,
          from_date, to_date, employee_id
        FROM task_cards
        WHERE (
          (from_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (to_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (@startDate::date BETWEEN from_date::date AND to_date::date)
        )
        AND (is_deleted IS NULL OR is_deleted = false)
        ORDER BY from_date
      ''';
      final taskCards = await DatabaseConnection.query(
        taskCardsSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Get approved leaves for the month
      final leavesSql = '''
        SELECT 
          l.leave_id, l.employee_id, l.leave_from_date, l.leave_to_date,
          l.leave_type, l.is_half_day,
          e.employee_name
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE (
          (l.leave_from_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (l.leave_to_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (@startDate::date BETWEEN l.leave_from_date::date AND l.leave_to_date::date)
        )
        AND l.leave_status = 1
        ORDER BY l.leave_from_date
      ''';
      final leaves = await DatabaseConnection.query(
        leavesSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Get approved WFH requests for the month
      final wfhSql = '''
        SELECT 
          w.wfh_id, w.employee_id, w.start_date, w.end_date, w.reason,
          e.employee_name
        FROM work_from_home_requests w
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        WHERE (
          (w.start_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (w.end_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (@startDate::date BETWEEN w.start_date::date AND w.end_date::date)
        )
        AND w.wfh_status = 1
        ORDER BY w.start_date
      ''';
      final wfhRequests = await DatabaseConnection.query(
        wfhSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Get approved permissions for the month
      final permissionsSql = '''
        SELECT 
          p.permission_id, p.employee_id, p.permission_date,
          p.permission_from_time, p.permission_to_time,
          e.employee_name
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.permission_date::date BETWEEN @startDate::date AND @endDate::date
        AND p.permission_status = 1
        ORDER BY p.permission_date
      ''';
      final permissions = await DatabaseConnection.query(
        permissionsSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Get company holidays for the month
      final holidaysSql = '''
        SELECT 
          holiday_id, holiday_name, from_date, to_date, total_days, is_optional
        FROM company_holidays
        WHERE (
          (from_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (to_date::date BETWEEN @startDate::date AND @endDate::date)
          OR (@startDate::date BETWEEN from_date::date AND COALESCE(to_date::date, from_date::date))
        )
        ORDER BY from_date
      ''';
      final holidays = await DatabaseConnection.query(
        holidaysSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Get meetings for the month
      final meetingsSql = '''
        SELECT meeting_date
        FROM calendar_meetings
        WHERE meeting_date BETWEEN @startDate::date AND @endDate::date
        AND (meeting_status != 'cancelled')
      ''';
      final meetings = await DatabaseConnection.query(
        meetingsSql,
        values: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      // Build date-wise event mapping for calendar indicators
      final dateEvents = <String, Map<String, int>>{};

      // Add task cards to date events
      for (var task in taskCards) {
        _addEventToDateRange(
          dateEvents,
          task['from_date'],
          task['to_date'] ?? task['from_date'],
          'task_cards',
        );
      }

      // Add leaves to date events
      for (var leave in leaves) {
        _addEventToDateRange(
          dateEvents,
          leave['leave_from_date'],
          leave['leave_to_date'],
          'leaves',
        );
      }

      // Add WFH to date events
      for (var wfh in wfhRequests) {
        _addEventToDateRange(
          dateEvents,
          wfh['start_date'],
          wfh['end_date'],
          'wfh',
        );
      }

      // Add permissions to date events
      for (var perm in permissions) {
        _addEventToDateRange(
          dateEvents,
          perm['permission_date'],
          perm['permission_date'],
          'permissions',
        );
      }

      // Add holidays to date events
      for (var holiday in holidays) {
        _addEventToDateRange(
          dateEvents,
          holiday['from_date'],
          holiday['to_date'] ?? holiday['from_date'],
          'holidays',
        );
      }

      // Add meetings to date events
      for (var meeting in meetings) {
        _addEventToDateRange(
          dateEvents,
          meeting['meeting_date'],
          meeting['meeting_date'],
          'meetings',
        );
      }

      return {
        'month': month,
        'year': year,
        'date_events': dateEvents,
        'summary': {
          'task_cards_count': taskCards.length,
          'leaves_count': leaves.length,
          'wfh_count': wfhRequests.length,
          'permissions_count': permissions.length,
          'holidays_count': holidays.length,
          'meetings_count': meetings.length,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching monthly events: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Helper to add events to date range
  void _addEventToDateRange(
    Map<String, Map<String, int>> dateEvents,
    dynamic startDate,
    dynamic endDate,
    String eventType,
  ) {
    if (startDate == null) return;

    final start = DateTime.parse(startDate.toString().split('T')[0]);
    final end = endDate != null
        ? DateTime.parse(endDate.toString().split('T')[0])
        : start;

    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final dateStr = _formatDate(date);
      dateEvents[dateStr] ??= {};
      dateEvents[dateStr]![eventType] =
          (dateEvents[dateStr]![eventType] ?? 0) + 1;
    }
  }

  // ============================================================
  // API 3: DATE DETAILS (Expansion Tile)
  // Endpoint: POST /api/home/date-details
  // Purpose: Get detailed events for a specific date
  // ============================================================

  /// Get detailed events for a specific date
  Future<Map<String, dynamic>> getDateDetails({required String date}) async {
    try {
      _logger.info('Fetching date details for: $date');

      // Get task cards for the date
      final taskCardsSql = '''
        SELECT 
          t.task_id, t.task_name, t.task_description, t.workflow_status,
          t.priority_level, t.from_date, t.to_date,
          e.employee_id, e.employee_name, e.employee_img, e.employee_designation,
          p.project_id, p.project_name
        FROM task_cards t
        LEFT JOIN employees e ON t.employee_id = e.employee_id
        LEFT JOIN projects p ON t.project_id = p.project_id
        WHERE (
          t.from_date::date = @date::date 
          OR t.to_date::date = @date::date 
          OR (@date::date BETWEEN t.from_date::date AND t.to_date::date)
        )
        AND (t.is_deleted IS NULL OR t.is_deleted = false)
        ORDER BY t.priority_level DESC, t.from_date
      ''';
      final taskCards = await DatabaseConnection.query(
        taskCardsSql,
        values: {'date': date},
      );

      // Get approved leaves for the date
      final leavesSql = '''
        SELECT 
          l.leave_id, l.employee_id, l.leave_from_date, l.leave_to_date,
          l.leave_type, l.leave_remarks, l.is_half_day, l.half_day_type,
          e.employee_name, e.employee_img, e.employee_designation
        FROM leave_zone l
        LEFT JOIN employees e ON l.employee_id = e.employee_id
        WHERE @date::date BETWEEN l.leave_from_date::date AND l.leave_to_date::date
        AND l.leave_status = 1
        ORDER BY e.employee_name
      ''';
      final leaves = await DatabaseConnection.query(
        leavesSql,
        values: {'date': date},
      );

      // Get approved WFH for the date
      final wfhSql = '''
        SELECT 
          w.wfh_id, w.employee_id, w.start_date, w.end_date, w.reason,
          e.employee_name, e.employee_img, e.employee_designation
        FROM work_from_home_requests w
        LEFT JOIN employees e ON w.employee_id = e.employee_id
        WHERE @date::date BETWEEN w.start_date::date AND w.end_date::date
        AND w.wfh_status = 1
        ORDER BY e.employee_name
      ''';
      final wfhRequests = await DatabaseConnection.query(
        wfhSql,
        values: {'date': date},
      );

      // Get approved permissions for the date
      final permissionsSql = '''
        SELECT 
          p.permission_id, p.employee_id, p.permission_date,
          p.permission_from_time, p.permission_to_time, p.permission_remarks,
          e.employee_name, e.employee_img, e.employee_designation
        FROM permissions p
        LEFT JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.permission_date::date = @date::date
        AND p.permission_status = 1
        ORDER BY p.permission_from_time
      ''';
      final permissions = await DatabaseConnection.query(
        permissionsSql,
        values: {'date': date},
      );

      // Get company holidays for the date
      final holidaysSql = '''
        SELECT 
          holiday_id, holiday_name, from_date, to_date, 
          total_days, holiday_remarks, is_optional
        FROM company_holidays
        WHERE @date::date BETWEEN from_date::date AND COALESCE(to_date::date, from_date::date)
        ORDER BY holiday_name
      ''';
      final holidays = await DatabaseConnection.query(
        holidaysSql,
        values: {'date': date},
      );

      // Get meetings for the date
      final meetingsSql = '''
        SELECT *
        FROM calendar_meetings
        WHERE meeting_date = @date::date
        AND (meeting_status != 'cancelled')
        ORDER BY meeting_start_time
      ''';
      final meetings = await DatabaseConnection.query(
        meetingsSql,
        values: {'date': date},
      );

      // Format responses
      return {
        'date': date,
        'task_cards': taskCards
            .map(
              (row) => {
                'task_id': row['task_id'],
                'task_name': row['task_name'],
                'task_description': row['task_description'],
                'workflow_status': row['workflow_status'],
                'priority_level': row['priority_level'],
                'from_date': row['from_date']?.toString().split('T')[0],
                'to_date': row['to_date']?.toString().split('T')[0],
                'employee': {
                  'id': row['employee_id'],
                  'name': row['employee_name'],
                  'image': row['employee_img'] ?? '',
                  'designation': row['employee_designation'] ?? '',
                },
                'project': {
                  'id': row['project_id'],
                  'name': row['project_name'] ?? '',
                },
              },
            )
            .toList(),
        'leaves': leaves
            .map(
              (row) => {
                'leave_id': row['leave_id'],
                'leave_type': row['leave_type'],
                'leave_remarks': row['leave_remarks'],
                'is_half_day': row['is_half_day'] ?? false,
                'half_day_type': row['half_day_type'],
                'from_date': row['leave_from_date']?.toString().split('T')[0],
                'to_date': row['leave_to_date']?.toString().split('T')[0],
                'employee': {
                  'id': row['employee_id'],
                  'name': row['employee_name'],
                  'image': row['employee_img'] ?? '',
                  'designation': row['employee_designation'] ?? '',
                },
              },
            )
            .toList(),
        'wfh_requests': wfhRequests
            .map(
              (row) => {
                'wfh_id': row['wfh_id'],
                'reason': row['reason'],
                'from_date': row['start_date']?.toString().split('T')[0],
                'to_date': row['end_date']?.toString().split('T')[0],
                'employee': {
                  'id': row['employee_id'],
                  'name': row['employee_name'],
                  'image': row['employee_img'] ?? '',
                  'designation': row['employee_designation'] ?? '',
                },
              },
            )
            .toList(),
        'permissions': permissions
            .map(
              (row) => {
                'permission_id': row['permission_id'],
                'permission_date': row['permission_date']?.toString().split(
                  'T',
                )[0],
                'from_time': row['permission_from_time']?.toString(),
                'to_time': row['permission_to_time']?.toString(),
                'remarks': row['permission_remarks'],
                'employee': {
                  'id': row['employee_id'],
                  'name': row['employee_name'],
                  'image': row['employee_img'] ?? '',
                  'designation': row['employee_designation'] ?? '',
                },
              },
            )
            .toList(),
        'holidays': holidays
            .map(
              (row) => {
                'holiday_id': row['holiday_id'],
                'holiday_name': row['holiday_name'],
                'from_date': row['from_date']?.toString().split('T')[0],
                'to_date': row['to_date']?.toString().split('T')[0],
                'total_days': row['total_days'] ?? 1,
                'remarks': row['holiday_remarks'],
                'is_optional': row['is_optional'] ?? false,
              },
            )
            .toList(),
        'announcements': (await _announcementRepository.getAllAnnouncements(
          startDate: DateTime.parse(date),
          endDate: DateTime.parse(date),
          isActive: true,
          limit: 10,
        )).$1.map((e) => e.toJson()).toList(),
        'counts': {
          'task_cards': taskCards.length,
          'leaves': leaves.length,
          'wfh_requests': wfhRequests.length,
          'permissions': permissions.length,
          'holidays': holidays.length,
          'meetings': meetings.length,
        },
        'meetings': meetings
            .map((row) => CalendarMeeting.fromJson(row).toJson())
            .toList(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error fetching date details: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
      case 'ON_HOLD':
        return 'On Hold';
      default:
        return status;
    }
  }

  String _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
        return '#94A3B8';
      case 'ASSIGNED':
        return '#3B82F6';
      case 'IN_PROGRESS':
      case 'DEV_STARTED':
        return '#F59E0B';
      case 'DEV_COMPLETED':
        return '#8B5CF6';
      case 'QC_STARTED':
        return '#EC4899';
      case 'QC_COMPLETED':
      case 'COMPLETED':
        return '#10B981';
      case 'REJECTED':
        return '#EF4444';
      case 'REDO':
        return '#F97316';
      case 'ON_HOLD':
        return '#6B7280';
      default:
        return '#64748B';
    }
  }

  /// Get employees with "No Status Today"
  Future<List<Map<String, dynamic>>> getNoStatusToday({String? date}) async {
    try {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final targetDate = date ?? todayStr;

      // If checking for today, only return results after 10:30 AM
      if (targetDate == todayStr) {
        if (now.hour < 10 || (now.hour == 10 && now.minute < 30)) {
          _logger.info('Self-check: Before 10:30 AM. Not showing any "No Status" employees for today.');
          return [];
        }
      }

      final employees = await _employeeRepository.getNoStatusEmployees(targetDate);
      return employees.map((e) {
        return {
          'id': e.employeeId,
          'name': e.employeeName,
          'profile_img': e.employeeImg,
          'role': e.employeeRole,
          'designation': e.employeeDesignation,
          'email': e.employeePersonalEmail,
          'phone_number': e.employeePhoneNum,
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error fetching no status today employees: $e', e, stackTrace);
      return [];
    }
  }
}
