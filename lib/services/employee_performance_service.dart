import '../data/repositories/employee_performance_repository.dart';
import '../data/repositories/monthly_working_days_repository.dart';
import '../domain/models/employee_performance_report.dart';
import '../core/utils/logger.dart';
import 'package:intl/intl.dart';

import 'package:excel/excel.dart';

class EmployeePerformanceService {
  final EmployeePerformanceRepository _repository =
      EmployeePerformanceRepository();
  final AppLogger _logger = AppLogger('EmployeePerformanceService');

  /// Get summary of all employees' performance
  Future<Map<String, dynamic>> getAllEmployeesSummary({
    required String fromDate,
    required String toDate,
    String? search,
    int? minLateDays,
    int? minUnderworkedDays,
    int? minOvertimeDays,
  }) async {
    try {
      final results = await _repository.getAllEmployeesPerformanceSummary(
        fromDate: fromDate,
        toDate: toDate,
        search: search,
        minLateDays: minLateDays,
        minUnderworkedDays: minUnderworkedDays,
        minOvertimeDays: minOvertimeDays,
      );

      int? totalWorkingDays;
      final startDateTime = DateTime.parse(fromDate);
      final endDateTime = DateTime.parse(toDate);
      
      // Only fetch working days if querying for a single month (e.g., from 01 to 30/31)
      if (startDateTime.month == endDateTime.month && startDateTime.year == endDateTime.year) {
        final workingDaysRepo = MonthlyWorkingDaysRepository();
        final config = await workingDaysRepo.getByMonthYear(startDateTime.month, startDateTime.year);
        if (config != null && config.workingDateList.isNotEmpty) {
          totalWorkingDays = config.workingDateList.length;
        }
      }

      final mappedResults = results.map((record) {
        final map = Map<String, dynamic>.from(record);
        final rawHours = _parseDouble(map['total_worked_hours']);
        map['total_worked_hours'] = rawHours;
        map['formatted_total_worked_hours'] = _formatDuration(rawHours);
        map['present_days'] = _parseInt(map['present_days']);
        map['leave_days'] = _parseInt(map['leave_days']);
        map['wfh_days'] = _parseInt(map['wfh_days']);
        map['late_days'] = _parseInt(map['late_days']);
        map['underwork_days'] = _parseInt(map['underwork_days']);
        map['overtime_days'] = _parseInt(map['overtime_days']);
        final otRawHours = _parseDouble(map['total_overtime_hours']);
        map['total_overtime_hours'] = otRawHours;
        map['formatted_total_overtime_hours'] = _formatDuration(otRawHours);
        final pRawHours = _parseDouble(map['permission_hours']);
        map['permission_hours'] = pRawHours;
        map['formatted_permission_hours'] = _formatDuration(pRawHours);
        
        // Pending fields
        map['pending_leave_days'] = _parseInt(map['pending_leave_days']);
        final ppRawHours = _parseDouble(map['pending_permission_hours']);
        map['pending_permission_hours'] = ppRawHours;
        map['formatted_pending_permission_hours'] = _formatDuration(ppRawHours);
        map['pending_wfh_days'] = _parseInt(map['pending_wfh_days']);
        
        return map;
      }).toList();

      return {
        'total_working_days': totalWorkingDays,
        'summaries': mappedResults,
      };
    } catch (e, stackTrace) {
      _logger.error('Error in getAllEmployeesSummary: $e', e, stackTrace);
      rethrow;
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Get the Sunday that starts the week containing the given date
  DateTime _getWeekStartSunday(DateTime date) {
    // DateTime.weekday: 1=Monday, 7=Sunday
    // For Sunday start, if today is Sunday (7), go back 0 days
    // If Monday (1), go back 1 day, etc.
    int daysToSubtract = date.weekday % 7; // Sunday=0, Mon=1, ... Sat=6
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  /// Generate week ranges for a given date range (Sunday to Saturday weeks)
  List<Map<String, dynamic>> _generateWeekRanges(
    DateTime fromDate,
    DateTime toDate,
  ) {
    final weeks = <Map<String, dynamic>>[];

    // Start from the Sunday of the week containing fromDate
    DateTime weekStart = _getWeekStartSunday(fromDate);
    int weekIndex = 1;

    while (weekStart.isBefore(toDate) || weekStart.isAtSameMomentAs(toDate)) {
      final weekEnd = weekStart.add(const Duration(days: 6));

      weeks.add({
        'index': weekIndex,
        'start': weekStart,
        'end': weekEnd,
        'label':
            '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd').format(weekEnd)}',
      });

      weekStart = weekStart.add(const Duration(days: 7));
      weekIndex++;

      // Safety limit
      if (weekIndex > 10) break;
    }

    return weeks;
  }

  /// Get detailed performance report for a specific employee
  Future<EmployeePerformanceReport> getEmployeePerformanceReport({
    required String employeeId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final summaryResponse = await getAllEmployeesSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
      final allEmps = summaryResponse['summaries'] as List<Map<String, dynamic>>;
      final empInfo = allEmps.firstWhere(
        (e) => e['employee_id'] == employeeId,
        orElse: () => throw Exception('Employee not found'),
      );

      // 2. Get daily performance records
      final dailyRecords = await _repository.getEmployeeDailyPerformance(
        employeeId: employeeId,
        fromDate: fromDate,
        toDate: toDate,
      );

      final dailyPerformance = <DailyPerformance>[];

      double totalHours = 0;
      int presentDays = 0;
      int leaveDays = 0;
      int wfhDays = 0;
      int lateDays = 0;
      int underworkDays = 0;
      int overtimeDays = 0;
      double totalOvertimeHours = 0.0;

      // Parse dates
      final fromDateTime = DateTime.parse(fromDate);
      final toDateTime = DateTime.parse(toDate);

      // Generate week ranges (Sunday to Saturday)
      final weekRanges = _generateWeekRanges(fromDateTime, toDateTime);

      // Initialize weekly hours map with week ranges
      final weeklyHoursMap = <int, double>{};
      for (final week in weekRanges) {
        weeklyHoursMap[week['index'] as int] = 0.0;
      }

      final monthlyHoursMap = <int, double>{}; // month -> totalHours

      for (final record in dailyRecords) {
        final dateStr = record['date'] as String;
        final date = DateTime.parse(dateStr);
        final workedHours = _parseDouble(record['worked_hours']);
        final clockIn = record['clock_in']?.toString() ?? '';
        final clockOut = record['clock_out']?.toString();
        final status = record['status'] as String;

        // Late calculation (threshold 9:30 AM)
        bool isLate = false;
        if (clockIn.isNotEmpty) {
          try {
            final punchInTime = DateTime.parse(clockIn);
            final threshold = DateTime(
              punchInTime.year,
              punchInTime.month,
              punchInTime.day,
              9,
              30,
            );
            if (punchInTime.isAfter(threshold)) {
              isLate = true;
            }
          } catch (_) {}
        }

        final workStatusMinutes = (workedHours * 60).round();
        String? workStatus;
        int excessOrDeficitMinutes = 0;

        if (status == 'present' || status == 'wfh') {
           if (workStatusMinutes < 540) {
            workStatus = 'underwork';
            excessOrDeficitMinutes = workStatusMinutes - 540;
            underworkDays++;
          } else if (workStatusMinutes > 540) {
            workStatus = 'overtime';
            excessOrDeficitMinutes = workStatusMinutes - 540;
            overtimeDays++;
            totalOvertimeHours += (excessOrDeficitMinutes / 60.0);
          } else {
            workStatus = 'normal';
            excessOrDeficitMinutes = 0;
          }
        }

        dailyPerformance.add(
          DailyPerformance(
            date: dateStr,
            workedHours: workedHours,
            formattedWorkedHours: _formatDuration(workedHours),
            clockIn: clockIn,
            clockOut: clockOut,
            status: status,
            isLate: isLate,
            workStatus: workStatus,
            excessOrDeficitMinutes: excessOrDeficitMinutes,
            leaveType: record['leave_type'],
            permissionDuration: record['permission_id'] != null
                ? 'Permission' // Could be improved if times were parsed
                : null,
            wfhReason: record['wfh_reason'],
          ),
        );

        // Accumulate stats
        totalHours += workedHours;
        if (status == 'present') presentDays++;
        if (status == 'leave') leaveDays++;
        if (status == 'wfh') wfhDays++;
        if (isLate) lateDays++;

        // Weekly grouping (find which week range this date belongs to)
        for (final week in weekRanges) {
          final weekStart = week['start'] as DateTime;
          final weekEnd = week['end'] as DateTime;
          if ((date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart)) &&
              (date.isBefore(weekEnd) || date.isAtSameMomentAs(weekEnd))) {
            final weekIndex = week['index'] as int;
            weeklyHoursMap[weekIndex] =
                (weeklyHoursMap[weekIndex] ?? 0) + workedHours;
            break;
          }
        }

        // Monthly grouping
        final month = date.month;
        monthlyHoursMap[month] = (monthlyHoursMap[month] ?? 0) + workedHours;
      }

      // 3. Construct Summaries

      // Weekly Summary with proper date range labels (for 4-5 weeks)
      final weeklyHoursData = weekRanges.map((week) {
        final weekIndex = week['index'] as int;
        final hours = weeklyHoursMap[weekIndex] ?? 0.0;
        return BarChartData(
          label: week['label'] as String,
          value: double.parse(hours.toStringAsFixed(2)),
          fullDate: DateFormat('yyyy-MM-dd').format(week['start'] as DateTime),
        );
      }).toList();

      // Monthly Summary (if range is a year, this shows months)
      final monthlyHoursData = monthlyHoursMap.entries.map((e) {
        return BarChartData(
          label: DateFormat('MMM').format(DateTime(2024, e.key)),
          value: double.parse(e.value.toStringAsFixed(2)),
        );
      }).toList();

      // Daily Hours for the first week (Sunday to Saturday)
      // Get the current week's daily data
      final firstWeek = weekRanges.isNotEmpty ? weekRanges.first : null;
      final dailyHoursData = <BarChartData>[];

      if (firstWeek != null) {
        final weekStart = firstWeek['start'] as DateTime;
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        for (int i = 0; i < 7; i++) {
          final day = weekStart.add(Duration(days: i));
          final dayStr = DateFormat('yyyy-MM-dd').format(day);

          // Find if there's performance data for this day
          final dayData = dailyPerformance
              .where((p) => p.date.startsWith(dayStr))
              .toList();
          final hours = dayData.isNotEmpty ? dayData.first.workedHours : 0.0;

          dailyHoursData.add(
            BarChartData(label: dayNames[i], value: hours, fullDate: dayStr),
          );
        }
      }

      return EmployeePerformanceReport(
        employeeId: employeeId,
        employeeName: empInfo['employee_name'],
        employeeImg: empInfo['employee_img'],
        designation: empInfo['employee_designation'],
        dailyPerformance: dailyPerformance,
        weeklySummary: WeeklySummary(
          totalWorkedHours: double.parse(totalHours.toStringAsFixed(2)),
          presentDays: presentDays,
          leaveDays: leaveDays,
          wfhDays: wfhDays,
          lateDays: lateDays,
          permissionHours: _parseDouble(empInfo['permission_hours']),
          formattedPermissionHours: empInfo['formatted_permission_hours'] ?? '0 hrs',
          pendingLeaves: _parseDouble(empInfo['pending_leave_days']),
          pendingPermissionHours: _parseDouble(empInfo['pending_permission_hours']),
          pendingWfhDays: _parseInt(empInfo['pending_wfh_days']),
          underworkDays: underworkDays,
          overtimeDays: overtimeDays,
          totalOvertimeHours: double.parse(totalOvertimeHours.toStringAsFixed(2)),
          dailyHours: dailyHoursData,
        ),
        monthlySummary: MonthlySummary(
          totalWorkedHours: double.parse(totalHours.toStringAsFixed(2)),
          presentDays: presentDays,
          leaveDays: leaveDays,
          wfhDays: wfhDays,
          permissionHours: _parseDouble(empInfo['permission_hours']),
          formattedPermissionHours: empInfo['formatted_permission_hours'] ?? '0 hrs',
          pendingLeaves: _parseDouble(empInfo['pending_leave_days']),
          pendingPermissionHours: _parseDouble(empInfo['pending_permission_hours']),
          pendingWfhDays: _parseInt(empInfo['pending_wfh_days']),
          underworkDays: underworkDays,
          overtimeDays: overtimeDays,
          totalOvertimeHours: double.parse(totalOvertimeHours.toStringAsFixed(2)),
          weeklyHours: weeklyHoursData,
        ),
        yearlySummary: YearlySummary(
          totalWorkedHours: double.parse(totalHours.toStringAsFixed(2)),
          totalPresentDays: presentDays,
          monthlyHours: monthlyHoursData,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Generate Monthly Performance Report for a specific employee in Excel
  Future<Map<String, dynamic>> getEmployeeMonthlyExcelReport({
    required String employeeId,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      // 1. Get Employee Info
      final summaryResponse = await getAllEmployeesSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
      final allEmps = summaryResponse['summaries'] as List<Map<String, dynamic>>;
      final empInfo = allEmps.firstWhere(
        (e) => e['employee_id'] == employeeId,
        orElse: () => throw Exception('Employee not found'),
      );

      // 2. Get Daily Records
      final dailyRecords = await _repository.getEmployeeDailyPerformance(
        employeeId: employeeId,
        fromDate: fromDate,
        toDate: toDate,
      );

      // 3. Get Working Days Config
      final startDateTime = DateTime.parse(fromDate);
      final workingDaysRepo = MonthlyWorkingDaysRepository();
      final workingDaysConfig = await workingDaysRepo.getByMonthYear(
        startDateTime.month,
        startDateTime.year,
      );
      final workingDateSet = workingDaysConfig?.workingDateList.toSet() ?? {};

      final excel = Excel.createExcel();

      // Sheet Name
      final sheetName =
          '${DateFormat('MMM yyyy').format(startDateTime)} Monthly Report';

      // Rename default sheet
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      // Common Style
      final commonStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // --- Header Section ---

      // Title
      sheet.merge(
        CellIndex.indexByString('A1'),
        CellIndex.indexByString('F1'),
        customValue: TextCellValue('Employee Performance Report'),
      );
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.cellStyle = titleStyle;

      sheet.appendRow([TextCellValue('')]); // Spacer

      // Helper to add styled row
      void addStyledRow(List<CellValue> cells, {CellStyle? style}) {
        sheet.appendRow(cells);
        for (final cell in sheet.rows.last) {
          cell?.cellStyle = style ?? commonStyle;
        }
      }

      // Employee Details
      addStyledRow([
        TextCellValue('Employee Name'),
        TextCellValue(empInfo['employee_name']?.toString() ?? '-'),
        TextCellValue(''),
        TextCellValue('Employee ID'),
        TextCellValue(empInfo['employee_id']?.toString() ?? '-'),
      ]);

      addStyledRow([
        TextCellValue('Role'),
        TextCellValue(''), // Role placeholder
        TextCellValue(''),
        TextCellValue('Designation'),
        TextCellValue(empInfo['employee_designation']?.toString() ?? '-'),
      ]);

      addStyledRow([
        TextCellValue('Period'),
        TextCellValue('$fromDate to $toDate'),
      ]);

      sheet.appendRow([TextCellValue('')]); // Spacer

      // --- Summary Section ---
      double totalWorkedHours = 0;
      int presentDays = 0;
      int fullDayLeaves = 0;
      int halfDayLeaves = 0;
      int wfhDays = 0;
      int lateDays = 0;

      for (final record in dailyRecords) {
        final workedHours = _parseDouble(record['worked_hours']);
        totalWorkedHours += workedHours;

        final status = record['status'];
        final isHalfDay = record['is_half_day'] == true;

        if (status == 'present') presentDays++;
        if (status == 'wfh') wfhDays++;
        if (status == 'leave') {
          if (isHalfDay) {
            halfDayLeaves++;
          } else {
            fullDayLeaves++;
          }
        }

        // Late Check
        final clockIn = record['clock_in']?.toString();
        if (clockIn != null && clockIn.isNotEmpty) {
          try {
            final punchInTime = DateTime.parse(clockIn);
            final threshold = DateTime(
              punchInTime.year,
              punchInTime.month,
              punchInTime.day,
              9,
              30,
            );
            if (punchInTime.isAfter(threshold)) {
              lateDays++;
            }
          } catch (_) {}
        }
      }

      addStyledRow(
        [TextCellValue('Summary')],
        style: CellStyle(
          bold: true,
          fontSize: 12,
          fontFamily: getFontFamily(FontFamily.Calibri),
        ),
      );

      addStyledRow([
        TextCellValue('Total Worked Days'),
        IntCellValue(presentDays + wfhDays),
        TextCellValue('Total Worked Hours'),
        TextCellValue(_formatDuration(totalWorkedHours)),
      ]);

      addStyledRow([
        TextCellValue('In Leave'),
        TextCellValue('Full: $fullDayLeaves, Half: $halfDayLeaves'),
        TextCellValue('Total WFH Days'),
        IntCellValue(wfhDays),
      ]);

      addStyledRow([TextCellValue('Total Late Days'), IntCellValue(lateDays)]);

      sheet.appendRow([TextCellValue('')]); // Spacer

      // --- Data Table ---

      // Headers
      final headers = [
        'S.No',
        'Date',
        'Day',
        'Punch In Date',
        'Punch In Time',
        'Punch Out Date',
        'Punch Out Time',
        'Total Worked Hours',
        'Work Status',
        'Work Type',
        'isPermission',
        'isLeave',
        'isPaid Leave',
        'Remarks',
        'isLate',
        'Late Duration',
      ];

      addStyledRow(
        headers.map((h) => TextCellValue(h)).toList(),
        style: headerStyle,
      );

      int sno = 1;
      for (final record in dailyRecords) {
        final dateStr = record['date']?.toString() ?? '';
        final date = DateTime.parse(dateStr);
        final dayName = DateFormat('EEE').format(date);

        // Punch Data
        final clockInRaw = record['clock_in']?.toString();
        final clockOutRaw = record['clock_out']?.toString();

        String punchInDate = '-';
        String punchInTime = '-';
        String punchOutDate = '-';
        String punchOutTime = '-';

        if (clockInRaw != null && clockInRaw.isNotEmpty) {
          final dt = DateTime.parse(clockInRaw);
          punchInDate = DateFormat('yyyy-MM-dd').format(dt);
          punchInTime = DateFormat('hh:mm a').format(dt);
        }

        if (clockOutRaw != null && clockOutRaw.isNotEmpty) {
          final dt = DateTime.parse(clockOutRaw);
          final diff = dt.difference(DateTime.parse(clockInRaw!)).inMinutes;
          // Ensure valid clock out
          if (diff > 0) {
            punchOutDate = DateFormat('yyyy-MM-dd').format(dt);
            punchOutTime = DateFormat('hh:mm a').format(dt);
          }
        }

        // Total Worked Hours
        final workedHours = _parseDouble(record['worked_hours']);
        final totalWorkedHoursStr = _formatDuration(workedHours);

        // Work Status & Type
        final status = record['status']?.toString() ?? '-';
        final isWorkingDay = workingDateSet.isNotEmpty 
            ? workingDateSet.contains(dateStr.split('T')[0]) 
            : date.weekday != DateTime.sunday;
            
        String workStatus = status;
        String workType = '-';

        if (status == 'present') {
          workType = 'WFO';
          workStatus = 'P';
        } else if (status == 'wfh') {
          workType = 'WFH';
          workStatus = 'WFH';
        } else if (status == 'leave') {
          workStatus = 'A';
        } else {
          if (!isWorkingDay) {
            workStatus = 'WO';
          } else {
            workStatus = 'A';
          }
        }

        // Permission
        final permissionId = record['permission_id'];
        final isPermission = permissionId != null ? 'Yes' : 'No';

        // Leave
        String isLeave = 'No';
        if (status == 'leave') {
          if (record['is_half_day'] == true) {
            final period = record['half_day_type']?.toString() ?? '';
            isLeave = 'Yes - Half Day ($period)';
          } else {
            isLeave = 'Yes - Full Day';
          }
        }
        final isPaidLeave = record['is_paid_leave'] == true ? 'Yes' : 'No';

        // Remarks
        String remarks = '-';
        if (status == 'leave') {
          remarks = record['leave_type']?.toString() ?? '-';
        } else if (status == 'wfh') {
          remarks = record['wfh_reason']?.toString() ?? '-';
        }

        // Late Check & Duration
        String isLate = 'No';
        String lateDuration = '-';

        if (clockInRaw != null && clockInRaw.isNotEmpty) {
          try {
            final punchInTimeDt = DateTime.parse(clockInRaw);
            final threshold = DateTime(
              punchInTimeDt.year,
              punchInTimeDt.month,
              punchInTimeDt.day,
              9,
              30,
            );
            if (punchInTimeDt.isAfter(threshold)) {
              isLate = 'Yes';
              final diff = punchInTimeDt.difference(threshold);
              lateDuration = _formatDuration(diff.inMinutes / 60.0);
            }
          } catch (_) {}
        }

        addStyledRow([
          IntCellValue(sno++),
          TextCellValue(dateStr),
          TextCellValue(dayName),
          TextCellValue(punchInDate),
          TextCellValue(punchInTime),
          TextCellValue(punchOutDate),
          TextCellValue(punchOutTime),
          TextCellValue(totalWorkedHoursStr),
          TextCellValue(workStatus),
          TextCellValue(workType),
          TextCellValue(isPermission),
          TextCellValue(isLeave),
          TextCellValue(isPaidLeave),
          TextCellValue(remarks),
          TextCellValue(isLate),
          TextCellValue(lateDuration),
        ], style: commonStyle);
      }

      // Auto-fit Logic
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20.0);
      }

      // Generate filename: Sanjay Prasath G Feb Month 2026 - Webnox Monthly report
      final monthStr = DateFormat('MMM').format(startDateTime);
      final yearStr = DateFormat('yyyy').format(startDateTime);
      final empName = empInfo['employee_name']?.toString() ?? 'Employee';
      final fileName =
          '$empName $monthStr Month $yearStr - Webnox Monthly report.xlsx';

      return {'fileBytes': excel.encode(), 'fileName': fileName};
    } catch (e, stackTrace) {
      _logger.error(
        'Error in getEmployeeMonthlyExcelReport: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Generate Consolidated Excel Export for all employees
  Future<Map<String, dynamic>> getConsolidatedExcelExport({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final data = await _repository.getAllEmployeesDailyPerformance(
        fromDate: fromDate,
        toDate: toDate,
      );

      final excel = Excel.createExcel();

      // Sheet Name
      final sheetName = 'Consolidated Report';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      // Styles
      final commonStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Title
      sheet.merge(
        CellIndex.indexByString('A1'),
        CellIndex.indexByString('H1'),
        customValue: TextCellValue('Consolidated Performance Report'),
      );
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

      sheet.appendRow([TextCellValue('Period: $fromDate to $toDate')]);
      sheet.cell(CellIndex.indexByString('A2')).cellStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );

      final downloadDate =
          DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      sheet.appendRow([TextCellValue('Data upto $downloadDate')]);
      sheet.cell(CellIndex.indexByString('A3')).cellStyle = CellStyle(
        italic: true,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );

      sheet.appendRow([TextCellValue('')]);

      // Create Header Row
      final start = DateTime.parse(fromDate);
      final end = DateTime.parse(toDate);
      final List<DateTime> dates = [];
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        dates.add(start.add(Duration(days: i)));
      }

      final List<CellValue> headers = [
        TextCellValue('S.No'),
        TextCellValue('Employee ID'),
        TextCellValue('Employee Name'),
      ];

      for (final date in dates) {
        final dayStr = DateFormat('d').format(date);
        final dayName = _getShortDayName(date.weekday);
        headers.add(TextCellValue('$dayStr $dayName'));
      }

      headers.addAll([
        TextCellValue('Total Present Days'),
        TextCellValue('Total Full Leaves'),
        TextCellValue('Total Half Leaves'),
        TextCellValue('Total Permission Hrs'),
        TextCellValue('Total WFH Days'),
        TextCellValue('Final Worked Days'),
        TextCellValue('Final Actual Work Days'),
      ]);

      // Fetch working days config for ALL months in the report range
      final workingDaysRepo = MonthlyWorkingDaysRepository();
      
      // Collect all unique year-month combos in the date range
      final monthYearSet = <String>{};
      for (final d in dates) {
        monthYearSet.add('${d.year}-${d.month}');
      }
      
      // Load each month's config and build the unified working date set
      final workingDateSet = <String>{};
      for (final ym in monthYearSet) {
        final parts = ym.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final config = await workingDaysRepo.getByMonthYear(m, y);
        if (config != null) {
          for (final dateStr in config.workingDateList) {
            // Normalize to YYYY-MM-DD (strip time if present)
            final normalizedDate = dateStr.split('T')[0].trim();
            workingDateSet.add(normalizedDate);
          }
        }
      }
      
      _logger.info('Working date set has ${workingDateSet.length} dates for range: $fromDate to $toDate');

      // Add Headers with style
      sheet.appendRow(headers);
      for (final cell in sheet.rows.last) {
        cell?.cellStyle = headerStyle;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final nameStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Left,
      );

      // Group data by employee
      final Map<String, Map<String, dynamic>> employeeData = {};

      for (final row in data) {
        final empId = row['employee_id'] as String;
        if (!employeeData.containsKey(empId)) {
          employeeData[empId] = {
            'id': empId,
            'name': row['employee_name'],
            'days': <String, Map<String, dynamic>>{},
          };
        }

        final date = (row['date'] as String).split('T')[0];
        employeeData[empId]!['days'][date] = row;
      }

      int index = 1;

      // Group keys to ensure we include everyone
      for (final empId in employeeData.keys) {
        final emp = employeeData[empId]!;
        final List<CellValue> row = [
          IntCellValue(index++),
          TextCellValue(empId),
          TextCellValue(emp['name']),
        ];

        double presentDaysCount = 0;
        double fullDayLeavesCount = 0;
        double halfDayLeavesCount = 0;
        double permissionHoursCount = 0;
        double wfhDaysCount = 0;
        double finalWorkedDaysCount = 0;

        for (final date in dates) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final dayData = emp['days'][dateStr];
          final isWorkingDay = workingDateSet.isNotEmpty 
              ? workingDateSet.contains(dateStr)
              : date.weekday != DateTime.sunday; // Fallback to non-Sunday as working day

          String cellValue = '';

          if (dayData != null) {
            final status = dayData['status'];
            final isHalfDay = dayData['leave_is_half_day'] == true;
            final halfDayPeriod = dayData['leave_half_day_period'];
            final permHrs = _parseDouble(dayData['permission_hours']);

            if (permHrs > 0) {
              permissionHoursCount += permHrs;
            }

            if (status == 'present') {
              cellValue = 'P';
              presentDaysCount++;
              finalWorkedDaysCount++;
            } else if (status == 'wfh') {
              cellValue = 'WFH';
              wfhDaysCount++;
              finalWorkedDaysCount++;
            } else if (status == 'leave') {
              if (isHalfDay) {
                halfDayLeavesCount++;
                finalWorkedDaysCount += 0.5;
                cellValue = (halfDayPeriod == 'First Half' ? 'L/P' : 'P/L'); // Using P/L for readability
              } else {
                cellValue = 'A';
                fullDayLeavesCount++;
              }
            } else {
              // No valid status, determine if WO or A
              if (date.isAfter(today)) {
                cellValue = '-';
              } else if (!isWorkingDay) {
                cellValue = 'WO';
              } else {
                cellValue = 'A';
                fullDayLeavesCount++;
              }
            }
          } else {
            // No attendance/leave data
            if (date.isAfter(today)) {
              cellValue = '-';
            } else if (!isWorkingDay) {
              cellValue = 'WO';
            } else {
              cellValue = 'A';
              fullDayLeavesCount++;
            }
          }
          row.add(TextCellValue(cellValue));
        }

        row.add(DoubleCellValue(presentDaysCount));
        row.add(DoubleCellValue(fullDayLeavesCount));
        row.add(DoubleCellValue(halfDayLeavesCount));
        row.add(TextCellValue(_formatDuration(permissionHoursCount)));
        row.add(DoubleCellValue(wfhDaysCount));
        row.add(DoubleCellValue(finalWorkedDaysCount));

        // Final Actual Work Days: count days in the range that are working days
        double actualWorkDays;
        if (workingDateSet.isNotEmpty) {
          // Count dates that appear in our working date set
          actualWorkDays = dates
              .where((d) => workingDateSet.contains(DateFormat('yyyy-MM-dd').format(d)))
              .length
              .toDouble();
        } else {
          // Fallback: count non-Sunday days in the range
          actualWorkDays = dates
              .where((d) => d.weekday != DateTime.sunday)
              .length
              .toDouble();
        }
        row.add(DoubleCellValue(actualWorkDays));

        sheet.appendRow(row);

        // Apply style to row
        for (int i = 0; i < sheet.rows.last.length; i++) {
          final cell = sheet.rows.last[i];
          if (cell != null) {
            // Apply left alignment specifically to Employee Name (index 2)
            if (i == 2) {
              cell.cellStyle = nameStyle;
            } else {
              cell.cellStyle = commonStyle;
            }
          }
        }
      }

      // Auto-fit Logic & Column Adjustments
      sheet.setColumnWidth(0, 8.0); // S.No
      sheet.setColumnWidth(1, 15.0); // Employee ID
      sheet.setColumnWidth(2, 30.0); // Employee Name (Proper gap/width)

      // Adjust Width for Date Columns
      for (int i = 3; i < 3 + dates.length; i++) {
        sheet.setColumnWidth(i, 10.0);
      }

      // Adjust Width for Summary Columns
      for (int i = 3 + dates.length; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }

      final fileName =
          'Webnox_Consolidated_Performance_Report_${fromDate}_to_$toDate.xlsx';

      return {'fileBytes': excel.encode(), 'fileName': fileName};
    } catch (e, stackTrace) {
      _logger.error('Error generating consolidated excel: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Generate Detailed Excel Export for all employees
  Future<Map<String, dynamic>> getAllEmployeeDetailedExcelExport({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      // 1. Get Employee Summary (for consolidated data)
      final summaryResponse = await getAllEmployeesSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
      final allEmps = summaryResponse['summaries'] as List<Map<String, dynamic>>;

      // 2. Get Daily Records
      final data = await _repository.getAllEmployeesDailyPerformance(
        fromDate: fromDate,
        toDate: toDate,
      );

      // 3. Get Working Days Config
      final start = DateTime.parse(fromDate);
      final end = DateTime.parse(toDate);
      final List<DateTime> dates = [];
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        dates.add(start.add(Duration(days: i)));
      }

      final monthYearSet = <String>{};
      for (final d in dates) {
        monthYearSet.add('${d.year}-${d.month}');
      }
      
      final workingDaysRepo = MonthlyWorkingDaysRepository();
      final workingDateSet = <String>{};
      for (final ym in monthYearSet) {
        final parts = ym.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final config = await workingDaysRepo.getByMonthYear(m, y);
        if (config != null) {
          for (final dateStr in config.workingDateList) {
            final normalizedDate = dateStr.split('T')[0].trim();
            workingDateSet.add(normalizedDate);
          }
        }
      }

      final excel = Excel.createExcel();

      // Sheet Name
      final sheetName = 'Detailed Report';
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      // Styles
      final commonStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      final titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Title
      sheet.merge(
        CellIndex.indexByString('A1'),
        CellIndex.indexByString('S1'),
        customValue: TextCellValue('All Employee Detailed Performance Report'),
      );
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

      sheet.appendRow([TextCellValue('Period: $fromDate to $toDate')]);
      sheet.cell(CellIndex.indexByString('A2')).cellStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );

      final downloadDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      sheet.appendRow([TextCellValue('Data upto $downloadDate')]);
      sheet.cell(CellIndex.indexByString('A3')).cellStyle = CellStyle(
        italic: true,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );

      sheet.appendRow([TextCellValue('')]); // Spacer

      final headers = [
        'S No',
        'Date',
        'Day',
        'Work Status',
        'Work Type',
        'Punch In Time',
        'Punch Out Time',
        'Total Worked Hrs',
        'Late(Yes/No)',
        'Late Duration',
        'Overworked(Yes/No)',
        'Overworked Hours',
        'Permission(Yes/No)',
        'Permission Hours',
        'Leave(Yes/No)',
        'Work From Home(Yes/No)',
        'Remarks'
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      final headerRow = sheet.rows.last;
      for (final cell in headerRow) {
        cell?.cellStyle = headerStyle;
      }

      // Group data by employee
      final Map<String, Map<String, dynamic>> empDailyData = {};
      for (final row in data) {
        final empId = row['employee_id'] as String;
        if (!empDailyData.containsKey(empId)) {
          empDailyData[empId] = {};
        }
        final dateStr = (row['date'] as String).split('T')[0];
        empDailyData[empId]![dateStr] = row;
      }

      final today = DateTime.now();

      final empInfoStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#F0F0F0'),
        verticalAlign: VerticalAlign.Center,
      );

      for (var empInfo in allEmps) {
        final empId = empInfo['employee_id'] as String;
        final empName = empInfo['employee_name']?.toString() ?? '-';
        final designation = empInfo['employee_designation']?.toString() ?? '-';

        // Add Employee Info Header Rows (Stacked)
        sheet.appendRow([TextCellValue('Employee ID: $empId')]);
        for (final cell in sheet.rows.last) { cell?.cellStyle = empInfoStyle; }
        
        sheet.appendRow([TextCellValue('Name: $empName')]);
        for (final cell in sheet.rows.last) { cell?.cellStyle = empInfoStyle; }
        
        sheet.appendRow([TextCellValue('Role/Designation: $designation')]);
        for (final cell in sheet.rows.last) { cell?.cellStyle = empInfoStyle; }

        final dailyRecords = empDailyData[empId] ?? {};
        final startDate = DateTime.parse(fromDate);
        final endDate = DateTime.parse(toDate);

          int employeeSno = 1;
          for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
            final date = startDate.add(Duration(days: i));
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final dayName = DateFormat('EEE').format(date);
            final dayData = dailyRecords[dateStr];

            final isWorkingDay = workingDateSet.isNotEmpty 
                ? workingDateSet.contains(dateStr)
                : date.weekday != DateTime.sunday;

            String punchInTime = '-';
            String punchOutTime = '-';
            String totalWorkedHoursStr = '-';
            String workStatus = '-';
            String workType = '-';
            String isPermission = 'No';
            String permissionHours = '-';
            String isLeave = 'No';
            String isWFH = 'No';
            String remarks = '-';
            String isLate = 'No';
            String lateDuration = '-';
            String isOverworked = 'No';
            String overworkedHours = '-';

            if (dayData != null) {
              final clockInRaw = dayData['clock_in']?.toString();
              final clockOutRaw = dayData['clock_out']?.toString();
              
              if (clockInRaw != null && clockInRaw.isNotEmpty) {
                final dt = DateTime.parse(clockInRaw);
                punchInTime = DateFormat('hh:mm a').format(dt);
              }

              if (clockOutRaw != null && clockOutRaw.isNotEmpty) {
                final dt = DateTime.parse(clockOutRaw);
                final diff = dt.difference(DateTime.parse(clockInRaw!)).inMinutes;
                if (diff > 0) {
                  punchOutTime = DateFormat('hh:mm a').format(dt);
                }
              }

              final workedHours = _parseDouble(dayData['worked_hours']);
              if (workedHours > 0) {
                totalWorkedHoursStr = _formatHumanDuration(workedHours);
                
                // Overworked logic (Standard 9 hrs)
                if (workedHours > 9.0) {
                  isOverworked = 'Yes';
                  overworkedHours = _formatHumanDuration(workedHours - 9.0);
                }
              }

              final status = dayData['status']?.toString() ?? '-';
              
              if (status == 'present') {
                workType = 'In Office';
                workStatus = 'P';
              } else if (status == 'wfh') {
                workType = 'Remote';
                workStatus = 'WFH';
                isWFH = 'Yes';
              } else if (status == 'leave') {
                workStatus = 'A';
                isLeave = 'Yes';
              } else {
                if (date.isAfter(today)) {
                  workStatus = '-';
                } else if (!isWorkingDay) {
                  workStatus = 'WO';
                } else {
                  workStatus = 'A';
                }
              }

              final permHrs = _parseDouble(dayData['permission_hours']);
              if (permHrs > 0) {
                isPermission = 'Yes';
                permissionHours = _formatHumanDuration(permHrs);
              }

              if (status == 'leave') {
                if (dayData['leave_is_half_day'] == true) {
                  final period = dayData['leave_half_day_period']?.toString() ?? '';
                  isLeave = 'Yes (Half Day - $period)';
                } else {
                  isLeave = 'Yes (Full Day)';
                }
                remarks = dayData['leave_type']?.toString() ?? '-';
              } else if (status == 'wfh') {
                remarks = dayData['wfh_reason']?.toString() ?? '-';
              }

              if (clockInRaw != null && clockInRaw.isNotEmpty) {
                try {
                  final punchInTimeDt = DateTime.parse(clockInRaw);
                  final threshold = DateTime(
                    punchInTimeDt.year,
                    punchInTimeDt.month,
                    punchInTimeDt.day,
                    9,
                    30,
                  );
                  if (punchInTimeDt.isAfter(threshold)) {
                    isLate = 'Yes';
                    final diff = punchInTimeDt.difference(threshold);
                    lateDuration = _formatHumanDuration(diff.inMinutes / 60.0);
                  }
                } catch (_) {}
              }
            } else {
              if (date.isAfter(today)) {
                workStatus = '-';
              } else if (!isWorkingDay) {
                workStatus = 'WO';
              } else {
                workStatus = 'A';
              }
            }

            sheet.appendRow([
              IntCellValue(employeeSno++),
              TextCellValue(dateStr),
              TextCellValue(dayName),
              TextCellValue(workStatus),
              TextCellValue(workType),
              TextCellValue(punchInTime),
              TextCellValue(punchOutTime),
              TextCellValue(totalWorkedHoursStr),
              TextCellValue(isLate),
              TextCellValue(lateDuration),
              TextCellValue(isOverworked),
              TextCellValue(overworkedHours),
              TextCellValue(isPermission),
              TextCellValue(permissionHours),
              TextCellValue(isLeave),
              TextCellValue(isWFH),
              TextCellValue(remarks),
            ]);
          
          final lastRow = sheet.rows.last;
          for (final cell in lastRow) {
            cell?.cellStyle = commonStyle;
          }
        }

        // Add summary row for this employee
        final presentDays = _parseDouble(empInfo['present_days']);
        final leaveDays = _parseDouble(empInfo['leave_days']);
        final wfhDays = _parseDouble(empInfo['wfh_days']);
        final lateDays = _parseDouble(empInfo['late_days']);
        final permHrsSummary = _parseDouble(empInfo['permission_hours']);
        final overtimeHrsSummary = _parseDouble(empInfo['total_overtime_hours']);
        final totalHrsSummary = _parseDouble(empInfo['total_worked_hours']);

        sheet.appendRow([
          TextCellValue(''),
          TextCellValue('Summary for $empName:'),
          TextCellValue('Present: $presentDays'),
          TextCellValue('Leave: $leaveDays'),
          TextCellValue('WFH: $wfhDays'),
          TextCellValue('Late: $lateDays'),
          TextCellValue('Permissions: ${_formatHumanDuration(permHrsSummary)}'),
          TextCellValue('Overtime: ${_formatHumanDuration(overtimeHrsSummary)}'),
          TextCellValue('Total: ${_formatHumanDuration(totalHrsSummary)}'),
        ]);

        final summaryRow = sheet.rows.last;
        final summaryRowStyle = CellStyle(
          fontFamily: getFontFamily(FontFamily.Calibri),
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
          verticalAlign: VerticalAlign.Center,
        );

        for (final cell in summaryRow) {
          cell?.cellStyle = summaryRowStyle;
        }
        // Spacer after each employee
        sheet.appendRow([TextCellValue('')]);
      }

      // Auto-fit Logic & Column Adjustments
      sheet.setColumnWidth(0, 8.0);  // S.No
      sheet.setColumnWidth(1, 15.0); // Date
      sheet.setColumnWidth(2, 8.0);  // Day
      sheet.setColumnWidth(3, 12.0); // Work Status
      sheet.setColumnWidth(4, 12.0); // Work Type
      sheet.setColumnWidth(5, 15.0); // Punch In
      sheet.setColumnWidth(6, 15.0); // Punch Out
      sheet.setColumnWidth(7, 18.0); // Total Worked Hrs
      sheet.setColumnWidth(8, 12.0); // Late(Yes/No)
      sheet.setColumnWidth(9, 15.0); // Late Duration
      sheet.setColumnWidth(10, 15.0); // Overworked(Yes/No)
      sheet.setColumnWidth(11, 18.0); // Overworked Hours
      sheet.setColumnWidth(12, 15.0); // Permission(Yes/No)
      sheet.setColumnWidth(13, 15.0); // Permission Hours
      sheet.setColumnWidth(14, 18.0); // Leave(Yes/No)
      sheet.setColumnWidth(15, 18.0); // WFH(Yes/No)
      sheet.setColumnWidth(16, 25.0); // Remarks

      final excelData = excel.encode();
      if (excelData == null) {
        throw Exception('Failed to generate Excel data');
      }
      return {
        'fileName': 'All_Employee_Detailed_Report_${fromDate}_to_${toDate}.xlsx',
        'fileBytes': excelData,
      };
    } catch (e, stackTrace) {
      print('Excel Generation Error: $e');
      print(stackTrace);
      rethrow;
    }
  }

  double _roundToFirstDecimal(double val) {
    return (val * 10).ceil() / 10.0;
  }

  String _formatDuration(double hours) {
    if (hours <= 0) return '-';
    final rounded = _roundToFirstDecimal(hours);
    return '$rounded hrs';
  }

  String _formatHumanDuration(double hours) {
    if (hours <= 0) return '-';

    int totalMinutes = (hours * 60).round();
    int hr = totalMinutes ~/ 60;
    int min = totalMinutes % 60;

    if (hr > 0 && min > 0) {
      return '$hr hr $min minutes';
    } else if (hr > 0) {
      return '$hr hr';
    } else {
      return '$min minutes';
    }
  }

  String _getShortDayName(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return 'S';
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'Tu';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'Sat';
      default:
        return '';
    }
  }
}
