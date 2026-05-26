import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../data/repositories/employee_tracker_repository.dart';
import '../../core/utils/logger.dart';

/// Employee Tracker Service for business logic
class EmployeeTrackerService {
  final EmployeeTrackerRepository _repository = EmployeeTrackerRepository();
  final AppLogger _logger = AppLogger('EmployeeTrackerService');

  /// Get list of all employees with their daily status
  Future<Map<String, dynamic>> getEmployeeTrackerList({
    required String date,
    String? search,
    String? statusFilter,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      _logger.info('Fetching employee tracker list for date: $date');

      // Validate date format
      if (!_isValidDate(date)) {
        throw ArgumentError('Invalid date format. Expected YYYY-MM-DD');
      }

      final result = await _repository.getEmployeeTrackerList(
        date: date,
        search: search,
        statusFilter: statusFilter,
        page: page,
        limit: limit,
      );

      // The repository now handles status filtering in SQL to correctly support pagination.

      _logger.info(
        'Successfully fetched ${(result['employees'] as List).length} employees',
      );
      return result;
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeeTrackerList: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get detailed timeline for a specific employee
  Future<Map<String, dynamic>?> getEmployeeTrackerDetail({
    required String employeeId,
    required String date,
  }) async {
    try {
      _logger.info(
        'Fetching employee tracker detail for: $employeeId on $date',
      );

      // Validate date format
      if (!_isValidDate(date)) {
        throw ArgumentError('Invalid date format. Expected YYYY-MM-DD');
      }

      // Validate employee ID
      if (employeeId.isEmpty) {
        throw ArgumentError('Employee ID is required');
      }

      final result = await _repository.getEmployeeTrackerDetail(
        employeeId: employeeId,
        date: date,
      );

      if (result == null) {
        _logger.warning('Employee not found: $employeeId');
        return null;
      }

      _logger.info('Successfully fetched detail for employee: $employeeId');
      return result;
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeeTrackerDetail: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Validate date format (YYYY-MM-DD)
  bool _isValidDate(String date) {
    try {
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!regex.hasMatch(date)) return false;

      // Try to parse the date
      DateTime.parse(date);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Export employee tracker list to Excel
  Future<Uint8List> exportEmployeeTrackerExcel({
    required String date,
    String? search,
    String? statusFilter,
  }) async {
    try {
      _logger.info('Exporting employee tracker to Excel for date: $date');

      // Validate date format
      if (!_isValidDate(date)) {
        throw ArgumentError('Invalid date format. Expected YYYY-MM-DD');
      }

      // Fetch all records (use a large limit)
      final result = await _repository.getEmployeeTrackerList(
        date: date,
        search: search,
        statusFilter: statusFilter,
        page: 1,
        limit: 100000, // Practically all records
      );

      final employees = result['employees'] as List<dynamic>;

      final excel = Excel.createExcel();
      final sheetName = 'Employee Tracker $date';
      excel.delete('Sheet1');
      final sheet = excel[sheetName];

      // Header styling
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4A90D9'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Title row
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('Employee Tracker - $date');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Filters info
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('F2'));
      final filtersCell = sheet.cell(CellIndex.indexByString('A2'));
      filtersCell.value = TextCellValue(
        'Filters: Status: ${statusFilter ?? 'All'} | Search: ${search ?? 'None'}',
      );
      filtersCell.cellStyle = CellStyle(
        italic: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Headers (row 4)
      final headers = [
        'S.No',
        'Employee ID',
        'Employee Name',
        'Role',
        'Day Status',
        'Work Performance',
        'Status Information',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Data rows
      var rowIndex = 4;
      var sNo = 1;
      for (final emp in employees) {
        final map = emp as Map<String, dynamic>;

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          sNo,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          map['employee_id']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          map['employee_name']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          map['employee_role']?.toString() ?? '',
        );

        // Format day status
        String dayStatus = map['day_status']?.toString() ?? 'no_status';
        if (dayStatus == 'no_status') {
          dayStatus = 'No Status';
        } else if (dayStatus.isNotEmpty) {
          dayStatus = dayStatus[0].toUpperCase() + dayStatus.substring(1);
        }
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          dayStatus,
        );

        // Format status info string
        String statusInfo = '';
        if (map['is_late'] == true && map['late_message'] != null) {
          statusInfo += '[Late: ${map['late_message']}] ';
        }
        if (map['permission_info'] != null) {
          final p = map['permission_info'] as Map<String, dynamic>;
          statusInfo += '[Permission: ${p['start']} - ${p['end']}] ';
        }
        if (dayStatus == 'Leave' && map['leave_info'] != null) {
          final l = map['leave_info'] as Map<String, dynamic>;
          statusInfo += '[Leave: ${l['type']}] ';
        }
        if (dayStatus == 'Wfh' && map['wfh_info'] != null) {
          final w = map['wfh_info'] as Map<String, dynamic>;
          statusInfo += '[WFH: ${w['reason']}] ';
        }

        // Format work performance
        String workPerformance = '-';
        if (map['attendance'] != null) {
          final att = map['attendance'] as Map<String, dynamic>;
          final workStatus = att['work_status']?.toString() ?? 'normal';
          final excess = att['excess_or_deficit_minutes'] as int? ?? 0;
          final absMinutes = excess.abs();
          final h = absMinutes ~/ 60;
          final m = absMinutes % 60;
          final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

          if (workStatus == 'overwork') {
            workPerformance = 'Overworked ($timeStr)';
          } else if (workStatus == 'underwork') {
            workPerformance = 'Underworked ($timeStr)';
          } else {
            workPerformance = 'Normal';
          }
        }
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          workPerformance,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          statusInfo.trim(),
        );

        rowIndex++;
        sNo++;
      }

      // Set column widths
      sheet.setColumnWidth(0, 8); // S.No
      sheet.setColumnWidth(1, 15); // Employee ID
      sheet.setColumnWidth(2, 25); // Employee Name
      sheet.setColumnWidth(3, 20); // Role
      sheet.setColumnWidth(4, 15); // Day Status
      sheet.setColumnWidth(5, 25); // Work Performance
      sheet.setColumnWidth(6, 40); // Status Information

      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      _logger.info(
        'Generated Employee Tracker Excel with ${employees.length} rows',
      );
      return Uint8List.fromList(bytes);
    } catch (e, stackTrace) {
      _logger.error('Error generating Excel: $e', e, stackTrace);
      rethrow;
    }
  }
}
