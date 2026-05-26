import 'dart:convert';
import '../models/daily_report_model.dart';
import '../database/connection.dart';
import '../../core/utils/logger.dart';

class ReportRepository {
  final AppLogger _logger = AppLogger('ReportRepository');

  /// Create or update a daily report
  Future<void> createReport(DailyReport report) async {
    try {
      // Check if report already exists for this employee and date
      // We cannot use ON CONFLICT because the table lacks a unique constraint on (employee_id, report_date)
      final existingSql = '''
        SELECT report_id FROM employee_reports 
        WHERE employee_id = @employeeId AND report_date = @reportDate
      ''';

      final existing = await DatabaseConnection.queryOne(
        existingSql,
        values: {
          'employeeId': report.employeeId,
          'reportDate': report.reportDate,
        },
      );

      // Prepare values
      // Note: 'tasks' column does not exist in the new schema, so detailed task data is not saved.
      // 'work_type' is assumed null or defaults.
      // 'total_working_hrs' is text in the new schema.

      // Construct timestamps for clock on/off by combining date + time string
      DateTime? clockOn;
      if (report.dailyClockIn?.isNotEmpty == true) {
        // Using reportTime or dailyClockIn? dailyClockIn is better
        // If dailyClockIn is "HH:mm:ss", combine with reportDate "YYYY-MM-DD"
        if (report.dailyClockIn != null) {
          try {
            clockOn = DateTime.parse(
              '${report.reportDate}T${report.dailyClockIn}',
            );
          } catch (_) {}
        }
      }

      DateTime? clockOff;
      if (report.dailyClockOff?.isNotEmpty == true) {
        try {
          clockOff = DateTime.parse(
            '${report.reportDate}T${report.dailyClockOff}',
          );
        } catch (_) {}
      }

      final values = {
        'reportDate': report.reportDate,
        'employeeId': report.employeeId,
        'workType':
            report.workType ?? 'Office', // Use report data or default to Office
        'totalTasksCount': report.tasks.length,
        'totalWorkingHrs': report.totalHours.toString(),
        'clockOn': clockOn?.toIso8601String(),
        'clockOff': clockOff?.toIso8601String(),
        'currentUser': report.employeeId,
        'taskDetails': jsonEncode(report.tasks), // Serialize to JSON string
      };

      if (existing != null) {
        // UPDATE existing report
        final updateSql = '''
          UPDATE employee_reports SET
            total_tasks_count = @totalTasksCount,
            total_working_hrs = @totalWorkingHrs,
            clock_on_for_the_day = @clockOn,
            clock_off_for_the_day = @clockOff,
            task_details = @taskDetails,
            updated_by = @currentUser,
            updated_at = CURRENT_TIMESTAMP
          WHERE report_id = @reportId
        ''';

        final updateValues = {
          'totalTasksCount': values['totalTasksCount'],
          'totalWorkingHrs': values['totalWorkingHrs'],
          'clockOn': values['clockOn'],
          'clockOff': values['clockOff'],
          'taskDetails': values['taskDetails'], // Pass JSON string
          'currentUser': values['currentUser'],
          'reportId': existing['report_id'],
        };
        await DatabaseConnection.execute(updateSql, values: updateValues);
      } else {
        // INSERT new report
        final insertSql = '''
          INSERT INTO employee_reports (
            report_date, employee_id, work_type, total_tasks_count,
            total_working_hrs, clock_on_for_the_day, clock_off_for_the_day,
            task_details, created_by, updated_by
          ) VALUES (
            @reportDate, @employeeId, @workType, @totalTasksCount,
            @totalWorkingHrs, @clockOn, @clockOff,
            @taskDetails, @currentUser, @currentUser
          )
        ''';

        await DatabaseConnection.execute(insertSql, values: values);
      }
    } catch (e, stackTrace) {
      _logger.error('Error creating daily report: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a report exists for a specific employee and date
  Future<bool> checkReportExists(String employeeId, String date) async {
    try {
      final sql = '''
        SELECT 1 FROM employee_reports 
        WHERE employee_id = @employeeId AND report_date = @date
        LIMIT 1
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'employeeId': employeeId, 'date': date},
      );
      return result != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking report existence: $e', e, stackTrace);
      return false;
    }
  }

  /// Get report history for an employee with pagination
  Future<List<Map<String, dynamic>>> getReportHistory(
    String employeeId, {
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final offset = (page - 1) * limit;

      var sql = '''
        SELECT 
          report_id,
          report_date,
          employee_id,
          work_type,
          total_tasks_count,
          total_working_hrs,
          clock_on_for_the_day,
          clock_off_for_the_day,
          task_details,
          created_at,
          updated_at
        FROM employee_reports
        WHERE employee_id = @employeeId
      ''';

      final values = <String, dynamic>{
        'employeeId': employeeId,
        'limit': limit,
        'offset': offset,
      };

      if (startDate != null && startDate.isNotEmpty) {
        sql += ' AND report_date >= @startDate';
        values['startDate'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        sql += ' AND report_date <= @endDate';
        values['endDate'] = endDate;
      }

      sql += ' ORDER BY report_date DESC LIMIT @limit OFFSET @offset';

      _logger.info(
        'ReportRepository: Executing query for employeeId: $employeeId with values: $values',
      );

      final results = await DatabaseConnection.query(sql, values: values);

      // Map results to a format friendly for the frontend
      return results.map((row) {
        return {
          'report_id': row['report_id'],
          'date': row['report_date'], // Mapped to 'date' for frontend
          'employee_id': row['employee_id'],
          'total_hours':
              double.tryParse(row['total_working_hrs']?.toString() ?? '0') ??
              0.0,
          'tasks_count': row['total_tasks_count'], // Mapped to 'tasks_count'
          'daily_clock_in': row['clock_on_for_the_day'] != null
              ? DateTime.parse(
                  row['clock_on_for_the_day'].toString(),
                ).toLocal().toString().split(' ')[1].split('.')[0]
              : null,
          'daily_clock_off': row['clock_off_for_the_day'] != null
              ? DateTime.parse(
                  row['clock_off_for_the_day'].toString(),
                ).toLocal().toString().split(' ')[1].split('.')[0]
              : null,
          'submitted_at': row['created_at']
              .toString(), // Mapped to 'submitted_at'
          'status': 'submitted',
          'tasks': row['task_details'] is String
              ? jsonDecode(row['task_details'])
              : (row['task_details'] ?? []),
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error fetching report history: $e', e, stackTrace);
      return [];
    }
  }
}
