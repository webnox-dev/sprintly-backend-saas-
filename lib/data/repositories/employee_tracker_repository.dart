import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Employee Tracker Repository for admin tracking employee activities
class EmployeeTrackerRepository {
  final AppLogger _logger = AppLogger('EmployeeTrackerRepository');

  /// Get all employees with their daily status for a specific date
  Future<Map<String, dynamic>> getEmployeeTrackerList({
    required String date,
    String? search,
    String? statusFilter,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final offset = (page - 1) * limit;

      // Build search conditions
      var searchCondition = '';
      final searchParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        searchCondition = '''
          AND (
            LOWER(e.employee_name) LIKE LOWER(@search) OR
            LOWER(e.employee_id) LIKE LOWER(@search) OR
            LOWER(e.employee_designation) LIKE LOWER(@search)
          )
        ''';
        searchParams['search'] = '%$search%';
      }

      final baseCte =
          '''
        WITH employee_status AS (
          SELECT 
            e.employee_id,
            EXISTS (SELECT 1 FROM leave_zone l WHERE l.employee_id = e.employee_id AND l.leave_status = 1 AND @date::date BETWEEN l.leave_from_date AND l.leave_to_date) as is_leave,
            EXISTS (SELECT 1 FROM work_from_home_requests w WHERE w.employee_id = e.employee_id AND w.wfh_status = 1 AND @date::date BETWEEN w.start_date AND w.end_date) as is_wfh,
            EXISTS (SELECT 1 FROM employee_attendance a WHERE a.employee_id = e.employee_id AND a.work_date::text = @date::text) as is_present,
            EXISTS (SELECT 1 FROM permissions p WHERE p.employee_id = e.employee_id AND p.permission_status = 1 AND p.permission_date = @date::date) as has_permission,
            COALESCE((SELECT ((EXTRACT(HOUR FROM CAST(clock_on_for_the_day AS timestamp)) * 60) + EXTRACT(MINUTE FROM CAST(clock_on_for_the_day AS timestamp))) > (9 * 60 + 16) FROM employee_attendance a WHERE a.employee_id = e.employee_id AND a.work_date::text = CAST(@date AS text) ORDER BY clock_on_for_the_day ASC LIMIT 1), false) as is_late
          FROM employees e
          WHERE e.status = 1
          $searchCondition
        )
      ''';

      // Count total active employees and calculate summaries
      final summarySql =
          '''
        $baseCte
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN is_leave THEN 1 ELSE 0 END)::int as leave_count,
          SUM(CASE WHEN NOT is_leave AND is_wfh THEN 1 ELSE 0 END)::int as wfh_count,
          SUM(CASE WHEN NOT is_leave AND NOT is_wfh AND is_present THEN 1 ELSE 0 END)::int as present_count,
          SUM(CASE WHEN NOT is_leave AND NOT is_wfh AND is_present AND has_permission THEN 1 ELSE 0 END)::int as permission_count
        FROM employee_status
      ''';

      final summaryParams = {'date': date, ...searchParams};

      final countResult = await DatabaseConnection.queryOne(
        summarySql,
        values: summaryParams,
      );
      final total = _safeToNum(countResult?['total'])?.toInt() ?? 0;
      final presentCount =
          _safeToNum(countResult?['present_count'])?.toInt() ?? 0;
      final leaveCount = _safeToNum(countResult?['leave_count'])?.toInt() ?? 0;
      final wfhCount = _safeToNum(countResult?['wfh_count'])?.toInt() ?? 0;
      final permissionCount =
          _safeToNum(countResult?['permission_count'])?.toInt() ?? 0;
      final absentCount = total - presentCount - leaveCount - wfhCount;

      String statusCondition = '';
      if (statusFilter != null && statusFilter != 'all') {
        switch (statusFilter) {
          case 'present':
            statusCondition =
                'AND s.is_present = true AND s.is_leave = false AND s.is_wfh = false';
            break;
          case 'leave':
            statusCondition = 'AND s.is_leave = true';
            break;
          case 'permission':
            statusCondition = 'AND s.has_permission = true';
            break;
          case 'wfh':
            statusCondition = 'AND s.is_wfh = true AND s.is_leave = false';
            break;
          case 'no_status':
            statusCondition =
                'AND s.is_present = false AND s.is_leave = false AND s.is_wfh = false';
            break;
          case 'late':
            statusCondition =
                'AND s.is_late = true AND s.has_permission = false AND s.is_leave = false AND s.is_wfh = false';
            break;
          case 'underwork':
            // Logic handled after results are fetched for now as it depends on total worked hours across records
            // To filter in SQL, we'd need a more complex JOIN. 
            // I'll update the employeesSql to include the calculation.
            break;
        }
      }

      // We need to calculate work status in the SQL if we want to filter by it efficiently
      final workStatusCte = '''
        , attendance_calc AS (
          SELECT 
            employee_id,
            SUM(CAST(COALESCE(worked_hrs, '0') AS NUMERIC)) as total_hrs
          FROM employee_attendance
          WHERE work_date::text = @date::text
          GROUP BY employee_id
        ),
        work_status_data AS (
          SELECT 
            e.employee_id,
            COALESCE(ac.total_hrs, 0) as total_worked_hrs,
            CASE 
              WHEN COALESCE(ac.total_hrs, 0) * 60 < 540 THEN 'underwork'
              WHEN COALESCE(ac.total_hrs, 0) * 60 > 550 THEN 'overwork'
              ELSE 'normal'
            END as calculated_work_status
          FROM employees e
          LEFT JOIN attendance_calc ac ON e.employee_id = ac.employee_id
          JOIN employee_status s ON e.employee_id = s.employee_id
          WHERE e.status = 1
        )
      ''';

      if (statusFilter != null) {
        if (statusFilter == 'underwork') {
          statusCondition = 'AND wsd.calculated_work_status = \'underwork\' AND s.is_present = true';
        } else if (statusFilter == 'overwork') {
          statusCondition = 'AND wsd.calculated_work_status = \'overwork\' AND s.is_present = true';
        } else if (statusFilter == 'normal') {
          statusCondition = 'AND wsd.calculated_work_status = \'normal\' AND s.is_present = true';
        }
      }

      final filteredCountSql =
          '''
        $baseCte
        $workStatusCte
        SELECT COUNT(*) as filtered_total
        FROM employees e
        JOIN employee_status s ON e.employee_id = s.employee_id
        JOIN work_status_data wsd ON e.employee_id = wsd.employee_id
        WHERE e.status = 1
        $statusCondition
      ''';

      final filteredCountResult = await DatabaseConnection.queryOne(
        filteredCountSql,
        values: summaryParams,
      );
      final filteredTotal =
          _safeToNum(filteredCountResult?['filtered_total'])?.toInt() ?? total;

      // Simple query - Get employees first
      final employeesSql =
          '''
        $baseCte
        $workStatusCte
        SELECT 
          e.employee_id,
          e.employee_name,
          e.employee_role,
          e.employee_designation,
          e.employee_img,
          e.employee_personal_email as employee_email,
          e.employee_phone_num as employee_phone
        FROM employees e
        JOIN employee_status s ON e.employee_id = s.employee_id
        JOIN work_status_data wsd ON e.employee_id = wsd.employee_id
        WHERE e.status = 1
        $statusCondition
        ORDER BY e.employee_name ASC
        LIMIT @limit OFFSET @offset
      ''';

      final empParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        ...searchParams,
        'date': date,
      };

      final employees = await DatabaseConnection.query(
        employeesSql,
        values: empParams,
      );

      // Now for each employee, get their attendance for the date
      final employeesList = <Map<String, dynamic>>[];

      for (final emp in employees) {
        final empId = emp['employee_id'] as String?;
        if (empId == null) continue;

        // Get attendance for this employee on this date
        // Fetch ALL records sorted by clock_on_for_the_day ASC
        // Use first record's punch_in and last record's punch_out
        final attSql = '''
          SELECT 
            attendance_id,
            clock_on_for_the_day,
            clock_off_for_the_day,
            worked_hrs,
            task_id as current_task_id,
            is_remote_override
          FROM employee_attendance
          WHERE employee_id = @emp_id AND work_date = @date
          ORDER BY clock_on_for_the_day ASC
        ''';
        final attResults = await DatabaseConnection.query(
          attSql,
          values: {'emp_id': empId, 'date': date},
        );

        // Build a consolidated attendance result from all records
        Map<String, dynamic>? attResult;
        if (attResults.isNotEmpty) {
          final firstRecord = attResults.first;
          final lastRecord = attResults.last;

          // Sum up worked_hrs across all records
          double totalWorkedHrs = 0.0;
          for (final record in attResults) {
            final hrs = record['worked_hrs'];
            if (hrs is num) {
              totalWorkedHrs += hrs.toDouble();
            } else if (hrs is String) {
              totalWorkedHrs += double.tryParse(hrs) ?? 0.0;
            }
          }

          attResult = {
            'attendance_id': firstRecord['attendance_id'],
            'clock_on_for_the_day': firstRecord['clock_on_for_the_day'],
            'clock_off_for_the_day': lastRecord['clock_off_for_the_day'],
            'worked_hrs': totalWorkedHrs,
            'current_task_id': lastRecord['current_task_id'],
            'is_remote_override': firstRecord['is_remote_override'],
          };
        }

        // Get leave info
        final leaveSql = '''
          SELECT leave_id, leave_type, leave_status
          FROM leave_zone
          WHERE employee_id = @emp_id 
            AND leave_status = 1
            AND @date_val::date BETWEEN leave_from_date AND leave_to_date
          LIMIT 1
        ''';
        final leaveResult = await DatabaseConnection.queryOne(
          leaveSql,
          values: {'emp_id': empId, 'date_val': date},
        );

        // Get WFH info
        final wfhSql = '''
          SELECT wfh_id, reason
          FROM work_from_home_requests
          WHERE employee_id = @emp_id 
            AND wfh_status = 1
            AND @date_val::date BETWEEN start_date AND end_date
          LIMIT 1
        ''';
        final wfhResult = await DatabaseConnection.queryOne(
          wfhSql,
          values: {'emp_id': empId, 'date_val': date},
        );

        // Get permission info
        final permSql = '''
          SELECT permission_id, permission_from_time, permission_to_time
          FROM permissions
          WHERE employee_id = @emp_id 
            AND permission_status = 1
            AND permission_date = @date_val::date
          LIMIT 1
        ''';
        final permResult = await DatabaseConnection.queryOne(
          permSql,
          values: {'emp_id': empId, 'date_val': date},
        );

        // Determine status
        String dayStatus;
        String? workType;

        if (leaveResult != null) {
          dayStatus = 'leave';
          workType = null;
        } else if (wfhResult != null) {
          dayStatus = 'wfh';
          workType = 'WFH';
        } else if (attResult != null) {
          dayStatus = 'present';
          workType = (attResult['is_remote_override'] == true)
              ? 'Remote'
              : 'Office';
        } else {
          dayStatus = 'no_status';
          workType = null;
        }

        // Calculate work status
        final workedHrsRaw = attResult?['worked_hrs'];
        final workedHrs = workedHrsRaw is num
            ? workedHrsRaw.toDouble()
            : (workedHrsRaw is String
                  ? double.tryParse(workedHrsRaw) ?? 0.0
                  : 0.0);
        String workStatus;
        int excessOrDeficitMinutes;
        final workStatusMinutes = (workedHrs * 60).round();

        if (workStatusMinutes < 540) {
          workStatus = 'underwork';
          excessOrDeficitMinutes = workStatusMinutes - 540;
        } else if (workStatusMinutes > 550) {
          workStatus = 'overwork';
          excessOrDeficitMinutes = workStatusMinutes - 540;
        } else {
          workStatus = 'normal';
          excessOrDeficitMinutes = 0;
        }

        employeesList.add({
          'employee_id': emp['employee_id'],
          'employee_name': emp['employee_name'],
          'employee_role': emp['employee_role'],
          'employee_designation': emp['employee_designation'],
          'employee_img': emp['employee_img'],
          'employee_email': emp['employee_email'],
          'employee_phone': emp['employee_phone'],
          'day_status': dayStatus,
          'work_type': workType,
          'attendance': attResult != null
              ? {
                  'punch_in_time': attResult['clock_on_for_the_day']
                      ?.toString(),
                  'punch_out_time': attResult['clock_off_for_the_day']
                      ?.toString(),
                  'total_working_hours': workedHrs,
                  'work_status': workStatus,
                  'excess_or_deficit_minutes': excessOrDeficitMinutes,
                }
              : null,
          'leave_info': leaveResult != null
              ? {
                  'leave_id': leaveResult['leave_id']?.toString(),
                  'leave_type': leaveResult['leave_type'],
                  'leave_status': leaveResult['leave_status'],
                }
              : null,
          'permission_info': permResult != null
              ? {
                  'permission_id': permResult['permission_id']?.toString(),
                  'permission_from_time': permResult['permission_from_time']
                      ?.toString(),
                  'permission_to_time': permResult['permission_to_time']
                      ?.toString(),
                }
              : null,
          'wfh_info': wfhResult != null
              ? {
                  'wfh_id': wfhResult['wfh_id']?.toString(),
                  'reason': wfhResult['reason'],
                }
              : null,
          'current_task': null,
          'total_tasks_count': 0,
          'completed_tasks_count': 0,
          'is_late':
              _getLateMessage(attResult?['clock_on_for_the_day'], permResult) !=
              null,
          'late_message': _getLateMessage(
            attResult?['clock_on_for_the_day'],
            permResult,
          ),
        });
      }

      return {
        'employees': employeesList,
        'summary': {
          'total_employees': total,
          'present_count': presentCount,
          'leave_count': leaveCount,
          'permission_count': permissionCount,
          'wfh_count': wfhCount,
          'absent_count': absentCount > 0 ? absentCount : 0,
        },
        'pagination': {
          'total': filteredTotal,
          'page': page,
          'limit': limit,
          'total_pages': (filteredTotal / limit).ceil(),
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting employee tracker list: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get detailed timeline for a specific employee on a specific date
  Future<Map<String, dynamic>?> getEmployeeTrackerDetail({
    required String employeeId,
    required String date,
  }) async {
    try {
      final params = <String, dynamic>{'employee_id': employeeId, 'date': date};

      // Get employee details
      final employeeSql = '''
        SELECT 
          employee_id,
          employee_name,
          employee_role,
          employee_designation,
          employee_img,
          employee_personal_email as employee_email,
          employee_phone_num as employee_phone
        FROM employees
        WHERE employee_id = @employee_id
      ''';
      final employeeResult = await DatabaseConnection.queryOne(
        employeeSql,
        values: {'employee_id': employeeId},
      );

      if (employeeResult == null) {
        return null;
      }

      // Get attendance for the day - get ALL records sorted by punch in time
      final attendanceSql = '''
        SELECT 
          attendance_id,
          clock_on_for_the_day,
          clock_off_for_the_day,
          worked_hrs,
          task_id as current_task_id,
          is_remote_override,
          remote_reason
        FROM employee_attendance
        WHERE employee_id = @employee_id AND work_date::date = @date::date
        ORDER BY clock_on_for_the_day ASC
      ''';
      final attendanceResults = await DatabaseConnection.query(
        attendanceSql,
        values: params,
      );

      // Build consolidated attendance result from all records
      Map<String, dynamic>? attendanceResult;
      if (attendanceResults.isNotEmpty) {
        final firstRecord = attendanceResults.first;
        final lastRecord = attendanceResults.last;

        // Sum up worked_hrs across all records
        double totalWorkedHrs = 0.0;
        for (final record in attendanceResults) {
          final hrs = record['worked_hrs'];
          if (hrs is num) {
            totalWorkedHrs += hrs.toDouble();
          } else if (hrs is String) {
            totalWorkedHrs += double.tryParse(hrs) ?? 0.0;
          }
        }

        attendanceResult = {
          'attendance_id': firstRecord['attendance_id'],
          'clock_on_for_the_day': firstRecord['clock_on_for_the_day'],
          'clock_off_for_the_day': lastRecord['clock_off_for_the_day'],
          'worked_hrs': totalWorkedHrs,
          'current_task_id': lastRecord['current_task_id'],
          'is_remote_override': firstRecord['is_remote_override'],
          'remote_reason': firstRecord['remote_reason'],
        };
      }

      // Get leave info
      final leaveSql = '''
        SELECT 
          leave_id,
          leave_type,
          leave_from_date,
          leave_to_date,
          total_leave_days,
          is_half_day,
          half_day_type,
          leave_status,
          leave_remarks
        FROM leave_zone
        WHERE employee_id = @employee_id 
          AND leave_status = 1
          AND @date::date BETWEEN leave_from_date AND leave_to_date
        LIMIT 1
      ''';
      final leaveResult = await DatabaseConnection.queryOne(
        leaveSql,
        values: params,
      );

      // Get permission info
      final permissionSql = '''
        SELECT 
          permission_id,
          permission_from_time,
          permission_to_time,
          permission_status,
          permission_remarks,
          EXTRACT(EPOCH FROM (permission_to_time - permission_from_time)) / 3600.0 as permission_hours
        FROM permissions
        WHERE employee_id = @employee_id 
          AND permission_status = 1
          AND permission_date = @date::date
        LIMIT 1
      ''';
      final permissionResult = await DatabaseConnection.queryOne(
        permissionSql,
        values: params,
      );

      // Get WFH info
      final wfhSql = '''
        SELECT 
          wfh_id,
          start_date,
          end_date,
          total_days,
          wfh_status,
          reason
        FROM work_from_home_requests
        WHERE employee_id = @employee_id 
          AND wfh_status = 1
          AND @date::date BETWEEN start_date AND end_date
        LIMIT 1
      ''';
      final wfhResult = await DatabaseConnection.queryOne(
        wfhSql,
        values: params,
      );

      final timeTrackingSql = '''
        SELECT 
          tt.task_id,
          tt.task_name,
          tt.clock_in_time,
          tt.clock_out_time
        FROM task_card_time_tracking tt
        WHERE tt.employee_id = @employee_id 
          AND tt.work_date::date = @date::date
        ORDER BY tt.clock_in_time ASC
      ''';

      final timeTrackingBase = await DatabaseConnection.query(
        timeTrackingSql,
        values: params,
      );

      final timeTrackingResults = <Map<String, dynamic>>[];

      for (final row in timeTrackingBase) {
        final taskRow = Map<String, dynamic>.from(row);
        final taskId = taskRow['task_id'];

        // Generate a tracking ID since 'id' column might be missing
        taskRow['tracking_id'] =
            '${taskId}_${taskRow['clock_in_time'].toString()}';

        // Calculate duration since column might be missing
        final clockIn = taskRow['clock_in_time'];
        final clockOut = taskRow['clock_out_time'];
        if (clockIn is DateTime && clockOut is DateTime) {
          taskRow['duration_minutes'] = clockOut.difference(clockIn).inMinutes;
        } else {
          taskRow['duration_minutes'] = 0;
        }

        if (taskId != null && taskId.toString().isNotEmpty) {
          try {
            // Fetch task details - explicit cast to text for safe comparison
            final taskResults = await DatabaseConnection.queryOne(
              'SELECT task_type, priority_level, workflow_status, task_attachments, project_id FROM task_cards WHERE task_id::text = @task_id',
              values: {'task_id': taskId.toString()},
            );

            if (taskResults != null) {
              taskRow.addAll(taskResults);

              final projectId = taskResults['project_id'];
              if (projectId != null) {
                final projectResults = await DatabaseConnection.queryOne(
                  'SELECT project_name FROM projects WHERE project_id::text = @project_id',
                  values: {'project_id': projectId.toString()},
                );

                if (projectResults != null) {
                  taskRow['project_name'] = projectResults['project_name'];
                }
              }
            }
          } catch (e) {
            _logger.warning(
              'Failed to fetch task details for task_id: $taskId - $e',
            );
          }
        }
        timeTrackingResults.add(taskRow);
      }

      // Build timeline events
      final timeline = <Map<String, dynamic>>[];
      final tasksWorked = <Map<String, dynamic>>[];

      // Add punch in event
      if (attendanceResult != null &&
          attendanceResult['clock_on_for_the_day'] != null) {
        final punchIn = attendanceResult['clock_on_for_the_day'];
        timeline.add({
          'timeline_id': 'punch_in_${attendanceResult['attendance_id']}',
          'event_type': 'punch_in',
          'event_time': punchIn is DateTime
              ? punchIn.toIso8601String()
              : punchIn.toString(),
          'event_title': 'Day Started',
          'event_description': 'Punched in for the day',
          'icon': 'login',
          'color': 'green',
        });
      }

      // Add task events
      for (final tt in timeTrackingResults) {
        // Task start event
        final clockIn = tt['clock_in_time'];
        timeline.add({
          'timeline_id': 'task_start_${tt['tracking_id']}',
          'event_type': 'task_start',
          'event_time': clockIn is DateTime
              ? clockIn.toIso8601String()
              : clockIn?.toString(),
          'event_title': 'Started Task',
          'event_description': tt['task_name'] ?? 'Unknown Task',
          'icon': 'task',
          'color': 'blue',
          'task_details': {
            'task_id': tt['task_id'],
            'task_name': tt['task_name'],
            'project_id': tt['project_id']?.toString(),
            'project_name': tt['project_name'],
            'task_type': tt['task_type'],
            'priority_level': tt['priority_level'],
            'workflow_status': tt['workflow_status'],
            'duration_minutes': tt['duration_minutes'],
            'task_attachments': tt['task_attachments'] ?? [],
          },
        });

        // Task complete/pause event (if clocked out)
        if (tt['clock_out_time'] != null) {
          final isCompleted = tt['workflow_status'] == 'DONE';
          final clockOut = tt['clock_out_time'];
          timeline.add({
            'timeline_id':
                'task_${isCompleted ? 'complete' : 'pause'}_${tt['tracking_id']}',
            'event_type': isCompleted ? 'task_complete' : 'task_pause',
            'event_time': clockOut is DateTime
                ? clockOut.toIso8601String()
                : clockOut?.toString(),
            'event_title': isCompleted ? 'Completed Task' : 'Paused Task',
            'event_description': tt['task_name'] ?? 'Unknown Task',
            'icon': isCompleted ? 'check' : 'pause',
            'color': isCompleted ? 'green' : 'yellow',
            'task_details': {
              'task_id': tt['task_id'],
              'task_name': tt['task_name'],
              'project_id': tt['project_id']?.toString(),
              'project_name': tt['project_name'],
              'task_type': tt['task_type'],
              'priority_level': tt['priority_level'],
              'workflow_status': tt['workflow_status'],
              'duration_minutes': tt['duration_minutes'],
              'task_attachments': tt['task_attachments'] ?? [],
            },
          });
        }

        // Add to tasks worked list
        tasksWorked.add({
          'task_id': tt['task_id'],
          'task_name': tt['task_name'],
          'project_id': tt['project_id']?.toString(),
          'project_name': tt['project_name'],
          'task_type': tt['task_type'],
          'priority_level': tt['priority_level'],
          'workflow_status': tt['workflow_status'],
          'started_at': tt['clock_in_time']?.toString(),
          'completed_at': tt['clock_out_time']?.toString(),
          'duration_minutes': tt['duration_minutes'] ?? 0,
          'task_attachments': tt['task_attachments'] ?? [],
        });
      }

      // Add permission events if exists
      if (permissionResult != null) {
        final hours = _safeToNum(permissionResult['permission_hours']) ?? 0.0;
        final fromTime = _formatEventTime(
          permissionResult['permission_from_time'],
        );
        final toTime = _formatEventTime(permissionResult['permission_to_time']);

        timeline.add({
          'timeline_id':
              'permission_start_${permissionResult['permission_id']}',
          'event_type': 'permission_start',
          'event_time': '${date}T$fromTime',
          'event_title': 'Permission Started',
          'event_description':
              '${permissionResult['permission_remarks'] ?? 'Permission'} - ${hours.toStringAsFixed(1)} hours',
          'icon': 'exit',
          'color': 'orange',
        });

        timeline.add({
          'timeline_id': 'permission_end_${permissionResult['permission_id']}',
          'event_type': 'permission_end',
          'event_time': '${date}T$toTime',
          'event_title': 'Permission Ended',
          'event_description': 'Returned from permission',
          'icon': 'enter',
          'color': 'green',
        });
      }

      // Add punch out event
      if (attendanceResult != null &&
          attendanceResult['clock_off_for_the_day'] != null) {
        final punchOut = attendanceResult['clock_off_for_the_day'];
        timeline.add({
          'timeline_id': 'punch_out_${attendanceResult['attendance_id']}',
          'event_type': 'punch_out',
          'event_time': punchOut is DateTime
              ? punchOut.toIso8601String()
              : punchOut.toString(),
          'event_title': 'Day Ended',
          'event_description': 'Punched out for the day',
          'icon': 'logout',
          'color': 'red',
        });
      }

      // Sort timeline by event_time
      timeline.sort((a, b) {
        final timeA = a['event_time'] as String?;
        final timeB = b['event_time'] as String?;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeA.compareTo(timeB);
      });

      // Calculate summary
      final workedHrsRaw = attendanceResult?['worked_hrs'];
      final totalPunchBasedHours = workedHrsRaw is num
          ? workedHrsRaw.toDouble()
          : (workedHrsRaw is String
                ? double.tryParse(workedHrsRaw) ?? 0.0
                : 0.0);
      final totalTaskBasedMinutes = tasksWorked.fold<int>(
        0,
        (sum, task) =>
            sum + (_safeToNum(task['duration_minutes'])?.toInt() ?? 0),
      );
      final totalTaskBasedHours = totalTaskBasedMinutes / 60.0;

      final completedTasks = tasksWorked
          .where((t) => t['workflow_status'] == 'DONE')
          .length;
      final inProgressTasks = tasksWorked
          .where((t) => t['workflow_status'] == 'IN_PROGRESS')
          .length;

      // Work status calculation (9 hours = 540 minutes)
      final workStatusMinutes = (totalPunchBasedHours * 60).round();
      String workStatus;
      int excessOrDeficitMinutes;

      if (workStatusMinutes < 540) {
        // Less than 9h
        workStatus = 'underwork';
        excessOrDeficitMinutes = workStatusMinutes - 540;
      } else if (workStatusMinutes > 550) {
        // More than 9h 10m
        workStatus = 'overwork';
        excessOrDeficitMinutes = workStatusMinutes - 540;
      } else {
        workStatus = 'normal';
        excessOrDeficitMinutes = 0;
      }

      // Determine day status
      String dayStatus;
      String? workType;

      if (leaveResult != null) {
        dayStatus = 'leave';
        workType = null;
      } else if (wfhResult != null) {
        dayStatus = 'wfh';
        workType = 'WFH';
      } else if (attendanceResult != null) {
        dayStatus = 'present';
        workType = (attendanceResult['is_remote_override'] == true)
            ? 'Remote'
            : 'Office';
      } else {
        dayStatus = 'no_status';
        workType = null;
      }

      return {
        'date': date,
        'employee': _mapRowToJson(employeeResult),
        'day_status': dayStatus,
        'work_type': workType,
        'is_late':
            _getLateMessage(
              attendanceResult?['clock_on_for_the_day'],
              permissionResult,
            ) !=
            null,
        'late_message': _getLateMessage(
          attendanceResult?['clock_on_for_the_day'],
          permissionResult,
        ),
        'attendance_summary': attendanceResult != null
            ? {
                'punch_in_time': attendanceResult['clock_on_for_the_day']
                    ?.toString(),
                'punch_out_time': attendanceResult['clock_off_for_the_day']
                    ?.toString(),
                'total_punch_based_hours': totalPunchBasedHours,
                'total_task_based_hours': double.parse(
                  totalTaskBasedHours.toStringAsFixed(2),
                ),
                'work_status': workStatus,
                'excess_or_deficit_minutes': excessOrDeficitMinutes,
                'break_time_minutes':
                    ((totalPunchBasedHours - totalTaskBasedHours) * 60)
                        .round()
                        .clamp(0, 999),
              }
            : null,
        'leave_info': leaveResult != null
            ? {
                'leave_id': leaveResult['leave_id']?.toString(),
                'leave_type': leaveResult['leave_type'],
                'leave_from_date': leaveResult['leave_from_date']?.toString(),
                'leave_to_date': leaveResult['leave_to_date']?.toString(),
                'total_days': _safeToNum(leaveResult['total_leave_days']),
                'is_half_day': leaveResult['is_half_day'],
                'half_day_type': leaveResult['half_day_type'],
                'leave_status': leaveResult['leave_status'],
                'leave_remarks': leaveResult['leave_remarks'],
              }
            : null,
        'permission_info': permissionResult != null
            ? {
                'permission_id': permissionResult['permission_id']?.toString(),
                'permission_from_time': permissionResult['permission_from_time']
                    ?.toString(),
                'permission_to_time': permissionResult['permission_to_time']
                    ?.toString(),
                'permission_hours': _safeToNum(
                  permissionResult['permission_hours'],
                ),
                'permission_status': permissionResult['permission_status'],
                'permission_remarks': permissionResult['permission_remarks'],
              }
            : null,
        'wfh_info': wfhResult != null
            ? {
                'wfh_id': wfhResult['wfh_id']?.toString(),
                'start_date': wfhResult['start_date']?.toString(),
                'end_date': wfhResult['end_date']?.toString(),
                'total_days': _safeToNum(wfhResult['total_days']),
                'wfh_status': wfhResult['wfh_status'],
                'reason': wfhResult['reason'],
              }
            : null,
        'timeline': timeline,
        'tasks_worked': tasksWorked,
        'summary': {
          'total_tasks_worked': tasksWorked.length,
          'completed_tasks': completedTasks,
          'in_progress_tasks': inProgressTasks,
          'total_punch_based_hours': totalPunchBasedHours,
          'total_task_based_hours': double.parse(
            totalTaskBasedHours.toStringAsFixed(2),
          ),
          'productive_time_percentage': totalPunchBasedHours > 0
              ? double.parse(
                  ((totalTaskBasedHours / totalPunchBasedHours) * 100)
                      .toStringAsFixed(1),
                )
              : 0.0,
          'work_status': workStatus,
          'excess_or_deficit_hours': double.parse(
            (excessOrDeficitMinutes / 60.0).toStringAsFixed(2),
          ),
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting employee tracker detail: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Helper to map employee row to structured data
  Map<String, dynamic> _mapEmployeeRow(Map<String, dynamic> row) {
    // Determine day status
    String dayStatus;
    String? workType;

    final hasLeave = row['leave_id'] != null;
    final hasWfh = row['wfh_id'] != null;
    final hasAttendance = row['attendance_id'] != null;

    if (hasLeave) {
      dayStatus = 'leave';
      workType = null;
    } else if (hasWfh) {
      dayStatus = 'wfh';
      workType = 'WFH';
    } else if (hasAttendance) {
      dayStatus = 'present';
      workType = (row['is_remote_override'] == true) ? 'Remote' : 'Office';
    } else {
      dayStatus = 'absent';
      workType = null;
    }

    // Calculate work status
    final workedHrs = (row['worked_hrs'] as num?)?.toDouble() ?? 0.0;
    String workStatus;
    int excessOrDeficitMinutes;
    final workStatusMinutes = (workedHrs * 60).round();

    if (workStatusMinutes < 540) {
      workStatus = 'underwork';
      excessOrDeficitMinutes = workStatusMinutes - 540;
    } else if (workStatusMinutes > 550) {
      workStatus = 'overwork';
      excessOrDeficitMinutes = workStatusMinutes - 540;
    } else {
      workStatus = 'normal';
      excessOrDeficitMinutes = 0;
    }

    // Permission hours calculation
    double? permissionHours;
    if (row['permission_from_time'] != null &&
        row['permission_to_time'] != null) {
      // Simple hour difference (this is a rough estimate)
      permissionHours =
          2.0; // Default, actual calculation would need time parsing
    }

    return {
      'employee_id': row['employee_id'],
      'employee_name': row['employee_name'],
      'employee_role': row['employee_role'],
      'employee_designation': row['employee_designation'],
      'employee_img': row['employee_img'],
      'employee_email': row['employee_email'],
      'employee_phone': row['employee_phone'],
      'day_status': dayStatus,
      'work_type': workType,
      'attendance': hasAttendance
          ? {
              'punch_in_time': row['clock_on_for_the_day']?.toString(),
              'punch_out_time': row['clock_off_for_the_day']?.toString(),
              'total_working_hours': workedHrs,
              'work_status': workStatus,
              'excess_or_deficit_minutes': excessOrDeficitMinutes,
            }
          : null,
      'leave_info': hasLeave
          ? {
              'leave_id': row['leave_id']?.toString(),
              'leave_type': row['leave_type'],
              'leave_from_date': row['leave_from_date']?.toString(),
              'leave_to_date': row['leave_to_date']?.toString(),
              'total_days': _safeToNum(row['total_leave_days']),
              'is_half_day': row['is_half_day'],
              'half_day_type': row['half_day_type'],
              'leave_status': row['leave_status'],
              'leave_remarks': row['leave_remarks'],
            }
          : null,
      'permission_info': row['permission_id'] != null
          ? {
              'permission_id': row['permission_id']?.toString(),
              'permission_from_time': row['permission_from_time']?.toString(),
              'permission_to_time': row['permission_to_time']?.toString(),
              'permission_hours': permissionHours,
              'permission_status': row['permission_status'],
              'permission_remarks': row['permission_remarks'],
            }
          : null,
      'wfh_info': hasWfh
          ? {
              'wfh_id': row['wfh_id']?.toString(),
              'start_date': row['wfh_start_date']?.toString(),
              'end_date': row['wfh_end_date']?.toString(),
              'total_days': _safeToNum(row['wfh_total_days']),
              'wfh_status': row['wfh_status'],
              'reason': row['wfh_reason'],
            }
          : null,
      'current_task': row['current_task_id'] != null
          ? {
              'task_id': row['current_task_id'],
              'task_name': row['current_task_name'],
              'project_name': row['current_project_name'],
            }
          : null,
      'total_tasks_count': _safeToNum(row['total_tasks_count'])?.toInt() ?? 0,
      'completed_tasks_count':
          _safeToNum(row['completed_tasks_count'])?.toInt() ?? 0,
    };
  }

  /// Safely format a time value (handles Time objects from postgres)
  String _formatEventTime(dynamic timeValue) {
    if (timeValue == null) return '00:00:00';
    final str = timeValue.toString();
    // Handle "Time(HH:mm:ss.mmm)" format
    if (str.startsWith('Time(') && str.endsWith(')')) {
      return str.substring(5, str.length - 1);
    }
    return str;
  }

  /// Safely convert a dynamic value to a num (double)
  num? _safeToNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Convert database row to JSON-safe map
  Map<String, dynamic> _mapRowToJson(Map<String, dynamic> row) {
    final result = <String, dynamic>{};
    row.forEach((key, value) {
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String? _getLateMessage(dynamic punchIn, dynamic permission) {
    if (punchIn == null || permission != null) return null;
    DateTime? timeToCheck;
    if (punchIn is DateTime) {
      timeToCheck = punchIn;
    } else {
      final str = punchIn.toString();
      String timeStr = str;
      if (str.startsWith('Time(') && str.endsWith(')')) {
        timeStr = str.substring(5, str.length - 1);
      }
      try {
        if (timeStr.contains('T')) {
          timeToCheck = DateTime.parse(timeStr);
        } else {
          // HH:mm:ss
          final parts = timeStr.split(':');
          if (parts.length >= 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final punchInMinutes = hour * 60 + minute;
            final lateThresholdMinutes = 9 * 60 + 16;
            if (punchInMinutes > lateThresholdMinutes) {
              final lateBy = punchInMinutes - (9 * 60);
              return _formatLateMessage(lateBy);
            }
            return null;
          }
        }
      } catch (_) {}
    }

    if (timeToCheck != null) {
      final punchInMinutes = timeToCheck.hour * 60 + timeToCheck.minute;
      final lateThresholdMinutes = 9 * 60 + 16;
      if (punchInMinutes > lateThresholdMinutes) {
        final lateBy = punchInMinutes - (9 * 60);
        return _formatLateMessage(lateBy);
      }
    }
    return null;
  }

  String _formatLateMessage(int minutes) {
    if (minutes < 60) {
      return 'Arrived $minutes minutes late';
    } else {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) {
        return 'Arrived $h hour${h > 1 ? 's' : ''} late';
      }
      return 'Arrived $h hour${h > 1 ? 's' : ''} $m minutes late';
    }
  }
}
