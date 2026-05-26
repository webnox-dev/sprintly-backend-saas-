import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../data/repositories/leave_report_repository.dart';
import '../domain/models/consolidated_leave_report.dart';
import '../core/utils/logger.dart';

/// Service for leave report business logic and Excel generation
class LeaveReportService {
  final LeaveReportRepository _repository = LeaveReportRepository();
  final AppLogger _logger = AppLogger('LeaveReportService');

  /// Get leave policy configuration
  Future<LeavePolicyConfig> getLeavePolicyConfig() async {
    return await _repository.getLeavePolicyConfig();
  }

  /// Update leave policy configuration
  Future<LeavePolicyConfig> updateLeavePolicyConfig({
    required int allowedLeaveDaysPerMonth,
    required double allowedPermissionHoursPerMonth,
    required int allowedWfhDaysPerMonth,
    required String updatedBy,
  }) async {
    return await _repository.updateLeavePolicyConfig(
      allowedLeaveDaysPerMonth: allowedLeaveDaysPerMonth,
      allowedPermissionHoursPerMonth: allowedPermissionHoursPerMonth,
      allowedWfhDaysPerMonth: allowedWfhDaysPerMonth,
      updatedBy: updatedBy,
    );
  }

  /// Get consolidated leave report for all employees
  Future<Map<String, dynamic>> getConsolidatedReport({
    required int month,
    required int year,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    _logger.info('Getting consolidated report for $month/$year');

    final policy = await _repository.getLeavePolicyConfig();
    final employees = await _repository.getConsolidatedReport(
      month: month,
      year: year,
      search: search,
      page: page,
      limit: limit,
    );
    final totalCount = await _repository.getConsolidatedReportCount(
      month: month,
      year: year,
      search: search,
    );

    final totalPages = (totalCount / limit).ceil();

    return {
      'month': month,
      'year': year,
      'month_display': '${getMonthName(month)} $year',
      'policy': policy.toJson(),
      'employees': employees.map((e) => e.toJson()).toList(),
      'pagination': {
        'current_page': page,
        'total_pages': totalPages,
        'total_items': totalCount,
        'items_per_page': limit,
        'has_next': page < totalPages,
        'has_previous': page > 1,
      },
    };
  }

  /// Get detailed leave report for a specific employee with HRMS calculations
  Future<Map<String, dynamic>> getEmployeeDetailReport({
    required String employeeId,
    int? year,
  }) async {
    _logger.info('Getting detail report for employee: $employeeId');

    final policy = await _repository.getLeavePolicyConfig();
    final employee = await _repository.getEmployeeDetails(employeeId);

    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    final reportYear = year ?? DateTime.now().year;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    final leaveRecords = await _repository.getEmployeeLeaveRecords(
      employeeId: employeeId,
      year: year,
    );

    final permissionRecords = await _repository.getEmployeePermissionRecords(
      employeeId: employeeId,
      year: year,
    );

    final wfhRecords = await _repository.getEmployeeWfhRecords(
      employeeId: employeeId,
      year: year,
    );

    // Calculate comprehensive monthly data
    final monthlyData = _calculateMonthlyHrmsData(
      leaveRecords: leaveRecords,
      permissionRecords: permissionRecords,
      wfhRecords: wfhRecords,
      policy: policy,
      year: reportYear,
      currentMonth: reportYear == currentYear ? currentMonth : 12,
    );

    // Calculate excess for each record based on cumulative usage per month
    final permissionRecordsWithExcess = _calculatePermissionExcess(
      permissionRecords,
      policy,
    );
    final wfhRecordsWithExcess = _calculateWfhExcess(wfhRecords, policy);

    return {
      'employee': employee.toJson(),
      'policy': policy.toJson(),
      'year_filter': year,
      'monthly_summary': monthlyData['monthly_summary'],
      'leave_balance': monthlyData['leave_balance'],
      'yearly_summary': monthlyData['yearly_summary'],
      'leave_records': monthlyData['leave_records'],
      'permission_records': permissionRecordsWithExcess
          .map((r) => r.toJson())
          .toList(),
      'wfh_records': wfhRecordsWithExcess.map((r) => r.toJson()).toList(),
    };
  }

  /// Calculate comprehensive monthly HRMS data for leaves, permissions, and WFH
  /// This is the core calculation for HR salary processing
  Map<String, dynamic> _calculateMonthlyHrmsData({
    required List<LeaveRecord> leaveRecords,
    required List<PermissionRecord> permissionRecords,
    required List<WfhRecord> wfhRecords,
    required LeavePolicyConfig policy,
    required int year,
    required int currentMonth,
  }) {
    // Sort records by date (ascending) for proper calculation
    final sortedLeaveRecords = List<LeaveRecord>.from(leaveRecords)
      ..sort((a, b) => a.leaveFromDate.compareTo(b.leaveFromDate));

    // Track monthly data
    final monthlyData = <int, Map<String, dynamic>>{};
    double carryForwardLeaves = 0;
    double totalPaidUsedYtd = 0;
    double totalUnpaidUsedYtd = 0;

    // Initialize all months up to current month
    for (int m = 1; m <= currentMonth; m++) {
      monthlyData[m] = {
        'sno': m,
        'month': m,
        'year': year,
        'month_display': '${getMonthName(m)} $year',
        // Leave data
        'total_leaves_taken': 0.0,
        'total_paid_leaves': 0.0,
        'total_unpaid_leaves': 0.0,
        'pending_leaves': 0.0,
        // Permission data
        'total_permission_hours': 0.0,
        'pending_permission_hours': 0.0,
        // WFH data
        'total_wfh_taken': 0,
        'pending_wfh': 0,
        // Flags
        'has_excess_leaves': false,
        'has_excess_permissions': false,
        'has_excess_wfh': false,
        // Detailed breakdown
        'leave_records': <Map<String, dynamic>>[],
      };
    }

    // ============ PROCESS LEAVES MONTH BY MONTH ============
    for (int month = 1; month <= currentMonth; month++) {
      final monthData = monthlyData[month]!;

      // Get leaves taken this month
      final monthLeaves = sortedLeaveRecords
          .where((r) => r.month == month && r.year == year)
          .toList();

      // Available paid leaves for this month = 1 (new) + carry forward
      final newPaidLeaves = policy.allowedLeaveDaysPerMonth.toDouble();
      final totalAvailable = newPaidLeaves + carryForwardLeaves;

      // Calculate leaves taken and categorize as paid/unpaid
      double leavesTakenThisMonth = 0;
      double paidUsedThisMonth = 0;
      double unpaidUsedThisMonth = 0;
      double remainingPaidPool = totalAvailable;

      final processedLeaveRecords = <Map<String, dynamic>>[];

      for (final leave in monthLeaves) {
        leavesTakenThisMonth += leave.totalLeaveDays;

        double paidPortion = 0;
        double unpaidPortion = 0;

        if (remainingPaidPool >= leave.totalLeaveDays) {
          // Fully paid
          paidPortion = leave.totalLeaveDays;
          remainingPaidPool -= leave.totalLeaveDays;
          paidUsedThisMonth += leave.totalLeaveDays;
        } else if (remainingPaidPool > 0) {
          // Partially paid
          paidPortion = remainingPaidPool;
          unpaidPortion = leave.totalLeaveDays - remainingPaidPool;
          paidUsedThisMonth += paidPortion;
          unpaidUsedThisMonth += unpaidPortion;
          remainingPaidPool = 0;
        } else {
          // Fully unpaid
          unpaidPortion = leave.totalLeaveDays;
          unpaidUsedThisMonth += leave.totalLeaveDays;
        }

        // Create enhanced leave record
        final leaveJson = leave.toJson();
        leaveJson['is_paid_leave'] = paidPortion > 0 && unpaidPortion == 0;
        leaveJson['paid_portion'] = paidPortion;
        leaveJson['unpaid_portion'] = unpaidPortion;
        leaveJson['payment_status'] = unpaidPortion > 0
            ? (paidPortion > 0 ? 'Partial' : 'Unpaid')
            : 'Paid';

        processedLeaveRecords.add(leaveJson);
      }

      // Calculate pending leaves (remaining paid leaves as of this month)
      final pendingLeaves = remainingPaidPool > 0 ? remainingPaidPool : 0.0;

      // Update month data
      monthData['total_leaves_taken'] = leavesTakenThisMonth;
      monthData['total_paid_leaves'] = paidUsedThisMonth;
      monthData['total_unpaid_leaves'] = unpaidUsedThisMonth;
      monthData['pending_leaves'] = pendingLeaves;
      monthData['has_excess_leaves'] = unpaidUsedThisMonth > 0;
      monthData['leave_records'] = processedLeaveRecords;

      // Carry forward remaining paid leaves to next month
      carryForwardLeaves = pendingLeaves;

      totalPaidUsedYtd += paidUsedThisMonth;
      totalUnpaidUsedYtd += unpaidUsedThisMonth;
    }

    // ============ PROCESS PERMISSIONS MONTH BY MONTH ============
    for (int month = 1; month <= currentMonth; month++) {
      final monthData = monthlyData[month]!;

      // Get permissions for this month
      final monthPermissions = permissionRecords
          .where((r) => r.month == month && r.year == year)
          .toList();

      double totalPermissionHours = 0;
      for (final perm in monthPermissions) {
        totalPermissionHours += perm.durationHours;
      }

      // Calculate pending permission hours
      final allowedHours = policy.allowedPermissionHoursPerMonth;
      final pendingHours = (allowedHours - totalPermissionHours).clamp(
        0.0,
        allowedHours,
      );

      monthData['total_permission_hours'] = totalPermissionHours;
      monthData['pending_permission_hours'] = pendingHours;
      monthData['has_excess_permissions'] = totalPermissionHours > allowedHours;
    }

    // ============ PROCESS WFH MONTH BY MONTH ============
    for (int month = 1; month <= currentMonth; month++) {
      final monthData = monthlyData[month]!;

      // Get WFH for this month
      final monthWfh = wfhRecords
          .where((r) => r.month == month && r.year == year)
          .toList();

      int totalWfhDays = 0;
      for (final wfh in monthWfh) {
        totalWfhDays += wfh.totalDays;
      }

      // Calculate pending WFH days
      final allowedWfh = policy.allowedWfhDaysPerMonth;
      final pendingWfh = (allowedWfh - totalWfhDays).clamp(0, allowedWfh);

      monthData['total_wfh_taken'] = totalWfhDays;
      monthData['pending_wfh'] = pendingWfh;
      monthData['has_excess_wfh'] = totalWfhDays > allowedWfh;
    }

    // ============ BUILD MONTHLY SUMMARY ============
    final monthlySummary = <Map<String, dynamic>>[];
    for (int m = 1; m <= currentMonth; m++) {
      final data = monthlyData[m]!;
      monthlySummary.add({
        'sno': m,
        'month': m,
        'year': year,
        'month_display': data['month_display'],
        // Leave data for HRMS
        'total_leaves_taken': data['total_leaves_taken'],
        'total_paid_leaves': data['total_paid_leaves'],
        'total_unpaid_leaves': data['total_unpaid_leaves'],
        'pending_leaves': data['pending_leaves'],
        // Permission data for HRMS
        'total_permission_hours': data['total_permission_hours'],
        'pending_permission_hours': data['pending_permission_hours'],
        // WFH data for HRMS
        'total_wfh_taken': data['total_wfh_taken'],
        'pending_wfh': data['pending_wfh'],
        // Flags for HR alerts
        'has_excess_leaves': data['has_excess_leaves'],
        'has_excess_permissions': data['has_excess_permissions'],
        'has_excess_wfh': data['has_excess_wfh'],
        // Legacy format for compatibility
        'leave_summary': {
          'total_days': data['total_leaves_taken'],
          'paid_days': data['total_paid_leaves'],
          'unpaid_days': data['total_unpaid_leaves'],
          'excess_days': data['total_unpaid_leaves'],
          'is_exceeded': data['has_excess_leaves'],
          'carry_forward_available': 0.0,
          'total_available': 0.0,
          'carry_forward_to_next': data['pending_leaves'],
        },
        'permission_summary': {
          'total_hours': data['total_permission_hours'],
          'excess_hours': data['has_excess_permissions']
              ? data['total_permission_hours'] -
                    policy.allowedPermissionHoursPerMonth
              : 0.0,
          'is_exceeded': data['has_excess_permissions'],
        },
        'wfh_summary': {
          'total_days': data['total_wfh_taken'],
          'excess_days': data['has_excess_wfh']
              ? data['total_wfh_taken'] - policy.allowedWfhDaysPerMonth
              : 0,
          'is_exceeded': data['has_excess_wfh'],
        },
      });
    }

    // ============ COLLECT ALL LEAVE RECORDS ============
    final allProcessedRecords = <Map<String, dynamic>>[];
    for (int m = 1; m <= currentMonth; m++) {
      allProcessedRecords.addAll(
        (monthlyData[m]!['leave_records'] as List<Map<String, dynamic>>),
      );
    }

    // Sort by date descending for display
    allProcessedRecords.sort((a, b) {
      final dateA = DateTime.parse(a['leave_from_date']);
      final dateB = DateTime.parse(b['leave_from_date']);
      return dateB.compareTo(dateA);
    });

    // ============ CALCULATE YEARLY TOTALS ============
    double yearlyLeavesTaken = 0;
    double yearlyPaidLeaves = 0;
    double yearlyUnpaidLeaves = 0;
    double yearlyPermissionHours = 0;
    int yearlyWfhDays = 0;

    for (int m = 1; m <= currentMonth; m++) {
      final data = monthlyData[m]!;
      yearlyLeavesTaken += data['total_leaves_taken'] as double;
      yearlyPaidLeaves += data['total_paid_leaves'] as double;
      yearlyUnpaidLeaves += data['total_unpaid_leaves'] as double;
      yearlyPermissionHours += data['total_permission_hours'] as double;
      yearlyWfhDays += data['total_wfh_taken'] as int;
    }

    // Current pending as of now
    final currentPendingLeaves = carryForwardLeaves;
    final totalAllowedPermissions =
        policy.allowedPermissionHoursPerMonth * currentMonth;
    final currentPendingPermissions =
        (totalAllowedPermissions - yearlyPermissionHours).clamp(
          0.0,
          totalAllowedPermissions,
        );
    final totalAllowedWfh = policy.allowedWfhDaysPerMonth * currentMonth;
    final currentPendingWfh = (totalAllowedWfh - yearlyWfhDays).clamp(
      0,
      totalAllowedWfh,
    );

    return {
      'monthly_summary': monthlySummary,
      'leave_records': allProcessedRecords,
      'yearly_summary': {
        'total_leaves_taken': yearlyLeavesTaken,
        'total_paid_leaves': yearlyPaidLeaves,
        'total_unpaid_leaves': yearlyUnpaidLeaves,
        'pending_leaves': currentPendingLeaves,
        'total_permission_hours': yearlyPermissionHours,
        'pending_permission_hours': currentPendingPermissions,
        'total_wfh_days': yearlyWfhDays,
        'pending_wfh_days': currentPendingWfh,
      },
      'leave_balance': {
        'total_paid_available_ytd':
            (currentMonth * policy.allowedLeaveDaysPerMonth).toDouble(),
        'total_paid_used': totalPaidUsedYtd,
        'total_unpaid_used': totalUnpaidUsedYtd,
        'current_carry_forward': currentPendingLeaves,
        'pending_leaves': currentPendingLeaves,
      },
    };
  }

  /// Calculate which permission records caused excess usage
  List<PermissionRecord> _calculatePermissionExcess(
    List<PermissionRecord> records,
    LeavePolicyConfig policy,
  ) {
    // Group by month-year
    final monthlyUsage = <String, double>{};
    final result = <PermissionRecord>[];

    for (final record in records) {
      final key = '${record.month}-${record.year}';
      final currentUsage = monthlyUsage[key] ?? 0;
      final newUsage = currentUsage + record.durationHours;
      monthlyUsage[key] = newUsage;

      final isExcess = newUsage > policy.allowedPermissionHoursPerMonth;
      double excessHours = 0;
      if (isExcess) {
        if (currentUsage >= policy.allowedPermissionHoursPerMonth) {
          excessHours = record.durationHours;
        } else {
          excessHours = newUsage - policy.allowedPermissionHoursPerMonth;
        }
      }

      result.add(
        PermissionRecord(
          permissionId: record.permissionId,
          permissionDate: record.permissionDate,
          permissionFromTime: record.permissionFromTime,
          permissionToTime: record.permissionToTime,
          durationHours: record.durationHours,
          permissionStatus: record.permissionStatus,
          permissionRemarks: record.permissionRemarks,
          month: record.month,
          year: record.year,
          isExcess: isExcess,
          excessHours: excessHours,
        ),
      );
    }

    return result;
  }

  /// Calculate which WFH records caused excess usage
  List<WfhRecord> _calculateWfhExcess(
    List<WfhRecord> records,
    LeavePolicyConfig policy,
  ) {
    // Group by month-year
    final monthlyUsage = <String, int>{};
    final result = <WfhRecord>[];

    for (final record in records) {
      final key = '${record.month}-${record.year}';
      final currentUsage = monthlyUsage[key] ?? 0;
      final newUsage = currentUsage + record.totalDays;
      monthlyUsage[key] = newUsage;

      final isExcess = newUsage > policy.allowedWfhDaysPerMonth;
      int excessDays = 0;
      if (isExcess) {
        if (currentUsage >= policy.allowedWfhDaysPerMonth) {
          excessDays = record.totalDays;
        } else {
          excessDays = newUsage - policy.allowedWfhDaysPerMonth;
        }
      }

      result.add(
        WfhRecord(
          wfhId: record.wfhId,
          startDate: record.startDate,
          endDate: record.endDate,
          totalDays: record.totalDays,
          wfhStatus: record.wfhStatus,
          reason: record.reason,
          month: record.month,
          year: record.year,
          isExcess: isExcess,
          excessDays: excessDays,
        ),
      );
    }

    return result;
  }

  /// Generate consolidated report Excel for all employees
  Future<Uint8List> generateConsolidatedExcel({
    required int month,
    required int year,
  }) async {
    _logger.info('Generating consolidated Excel for $month/$year');

    final policy = await _repository.getLeavePolicyConfig();
    final data = await _repository.getConsolidatedReportForExport(
      month: month,
      year: year,
    );

    final excel = Excel.createExcel();
    final sheetName = 'Leave Report ${getMonthName(month)} $year';

    // Remove default sheet and create new one
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
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'Consolidated Leave Report - ${getMonthName(month)} $year',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Policy info row
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('L2'));
    final policyCell = sheet.cell(CellIndex.indexByString('A2'));
    policyCell.value = TextCellValue(
      'Policy: ${policy.allowedLeaveDaysPerMonth} leaves/month | ${policy.allowedPermissionHoursPerMonth}h permissions/month | ${policy.allowedWfhDaysPerMonth} WFH/month',
    );
    policyCell.cellStyle = CellStyle(
      italic: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Headers (row 4)
    final headers = [
      'S.No',
      'Employee ID',
      'Employee Name',
      'Role',
      'Designation',
      'Total Leave Days',
      'Paid Leaves',
      'Unpaid Leaves',
      'Excess Leaves',
      'Permission Hours',
      'Excess Permission',
      'WFH Days',
      'Excess WFH',
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
    for (final row in data) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = IntCellValue(
        sNo,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        row['employee_id']?.toString() ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        row['employee_name']?.toString() ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(
        row['employee_role']?.toString() ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        row['employee_designation']?.toString() ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = DoubleCellValue(
        double.tryParse(row['total_leave_days']?.toString() ?? '') ?? 0.0,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = DoubleCellValue(
        double.tryParse(row['paid_leave_days']?.toString() ?? '') ?? 0.0,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = DoubleCellValue(
        double.tryParse(row['unpaid_leave_days']?.toString() ?? '') ?? 0.0,
      );

      // Excess leaves with red highlight
      final excessLeaves =
          double.tryParse(row['excess_leave_days']?.toString() ?? '') ?? 0.0;
      final excessLeaveCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
      );
      excessLeaveCell.value = DoubleCellValue(excessLeaves);
      if (excessLeaves > 0) {
        excessLeaveCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex))
          .value = DoubleCellValue(
        double.tryParse(row['total_permission_hours']?.toString() ?? '') ?? 0.0,
      );

      // Excess permission with red highlight
      final excessPermission =
          double.tryParse(row['excess_permission_hours']?.toString() ?? '') ??
          0.0;
      final excessPermCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
      );
      excessPermCell.value = DoubleCellValue(excessPermission);
      if (excessPermission > 0) {
        excessPermCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex))
          .value = IntCellValue(
        int.tryParse(row['total_wfh_days']?.toString() ?? '') ?? 0,
      );

      // Excess WFH with red highlight
      final excessWfh =
          int.tryParse(row['excess_wfh_days']?.toString() ?? '') ?? 0;
      final excessWfhCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex),
      );
      excessWfhCell.value = IntCellValue(excessWfh);
      if (excessWfh > 0) {
        excessWfhCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      rowIndex++;
      sNo++;
    }

    // Set column widths
    sheet.setColumnWidth(0, 8); // S.No
    sheet.setColumnWidth(1, 15); // Employee ID
    sheet.setColumnWidth(2, 25); // Employee Name
    sheet.setColumnWidth(3, 15); // Role
    sheet.setColumnWidth(4, 20); // Designation
    sheet.setColumnWidth(5, 18); // Total Leave Days
    sheet.setColumnWidth(6, 12); // Paid Leaves
    sheet.setColumnWidth(7, 14); // Unpaid Leaves
    sheet.setColumnWidth(8, 14); // Excess Leaves
    sheet.setColumnWidth(9, 18); // Permission Hours
    sheet.setColumnWidth(10, 16); // Excess Permission
    sheet.setColumnWidth(11, 12); // WFH Days
    sheet.setColumnWidth(12, 12); // Excess WFH

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    _logger.info('Generated consolidated Excel with ${data.length} rows');
    return Uint8List.fromList(bytes);
  }

  /// Generate detailed employee report Excel
  Future<Uint8List> generateEmployeeDetailExcel({
    required String employeeId,
    int? year,
  }) async {
    _logger.info('Generating employee detail Excel for: $employeeId');

    final employee = await _repository.getEmployeeDetails(employeeId);

    if (employee == null) {
      throw Exception('Employee not found: $employeeId');
    }

    final monthlySummary = await _repository.getEmployeeMonthlySummary(
      employeeId: employeeId,
      year: year,
    );

    final leaveRecords = await _repository.getEmployeeLeaveRecords(
      employeeId: employeeId,
      year: year,
    );

    final permissionRecords = await _repository.getEmployeePermissionRecords(
      employeeId: employeeId,
      year: year,
    );

    final wfhRecords = await _repository.getEmployeeWfhRecords(
      employeeId: employeeId,
      year: year,
    );

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#4A90D9'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    // ===== SUMMARY SHEET =====
    final summarySheet = excel['Summary'];

    // Employee info
    summarySheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('G1'),
    );
    summarySheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Employee Leave Report - ${employee.employeeName} (${employee.employeeId})',
    );
    summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );

    summarySheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Role:',
    );
    summarySheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
      employee.employeeRole ?? '-',
    );
    summarySheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
      'Designation:',
    );
    summarySheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(
      employee.employeeDesignation ?? '-',
    );

    // Monthly summary headers (row 6)
    final summaryHeaders = [
      'Month',
      'Leave Days',
      'Paid Leaves',
      'Unpaid Leaves',
      'Excess Leaves',
      'Permission Hours',
      'Excess Permission',
      'WFH Days',
      'Excess WFH',
    ];

    for (var i = 0; i < summaryHeaders.length; i++) {
      final cell = summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5),
      );
      cell.value = TextCellValue(summaryHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    // Monthly summary data
    var rowIndex = 6;
    for (final summary in monthlySummary) {
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(
        summary.monthDisplay,
      );
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = DoubleCellValue(
        summary.leaveSummary.totalDays,
      );
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = DoubleCellValue(
        summary.leaveSummary.paidDays,
      );
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = DoubleCellValue(
        summary.leaveSummary.unpaidDays,
      );

      final excessLeaveCell = summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
      );
      excessLeaveCell.value = DoubleCellValue(summary.leaveSummary.excessDays);
      if (summary.leaveSummary.isExceeded) {
        excessLeaveCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = DoubleCellValue(
        summary.permissionSummary.totalHours,
      );

      final excessPermCell = summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
      );
      excessPermCell.value = DoubleCellValue(
        summary.permissionSummary.excessHours,
      );
      if (summary.permissionSummary.isExceeded) {
        excessPermCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = IntCellValue(
        summary.wfhSummary.totalDays,
      );

      final excessWfhCell = summarySheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
      );
      excessWfhCell.value = IntCellValue(summary.wfhSummary.excessDays);
      if (summary.wfhSummary.isExceeded) {
        excessWfhCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#FF0000'),
          bold: true,
        );
      }

      rowIndex++;
    }

    // ===== LEAVE RECORDS SHEET =====
    final leaveSheet = excel['Leave Records'];
    final leaveHeaders = [
      'S.No',
      'From Date',
      'To Date',
      'Days',
      'Type',
      'Paid/Unpaid',
      'Status',
      'Remarks',
      'Month/Year',
    ];

    for (var i = 0; i < leaveHeaders.length; i++) {
      final cell = leaveSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(leaveHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    rowIndex = 1;
    var sNo = 1;
    for (final record in leaveRecords) {
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = IntCellValue(
        sNo,
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        record.leaveFromDate.toIso8601String().split('T')[0],
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        record.leaveToDate.toIso8601String().split('T')[0],
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = DoubleCellValue(
        record.totalLeaveDays,
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        record.leaveType ?? '-',
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        record.isPaidLeave ? 'Paid' : 'Unpaid',
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(
        'Approved',
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = TextCellValue(
        record.leaveRemarks ?? '-',
      );
      leaveSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
          .value = TextCellValue(
        '${getMonthName(record.month)} ${record.year}',
      );

      rowIndex++;
      sNo++;
    }

    // ===== PERMISSION RECORDS SHEET =====
    final permSheet = excel['Permission Records'];
    final permHeaders = [
      'S.No',
      'Date',
      'From Time',
      'To Time',
      'Duration',
      'Status',
      'Remarks',
      'Month/Year',
    ];

    for (var i = 0; i < permHeaders.length; i++) {
      final cell = permSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(permHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    rowIndex = 1;
    sNo = 1;
    for (final record in permissionRecords) {
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = IntCellValue(
        sNo,
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        record.permissionDate.toIso8601String().split('T')[0],
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        record.permissionFromTime,
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = TextCellValue(
        record.permissionToTime,
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        '${record.durationHours.toStringAsFixed(2)}h',
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        'Approved',
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(
        record.permissionRemarks ?? '-',
      );
      permSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .value = TextCellValue(
        '${getMonthName(record.month)} ${record.year}',
      );

      rowIndex++;
      sNo++;
    }

    // ===== WFH RECORDS SHEET =====
    final wfhSheet = excel['WFH Records'];
    final wfhHeaders = [
      'S.No',
      'Start Date',
      'End Date',
      'Days',
      'Status',
      'Reason',
      'Month/Year',
    ];

    for (var i = 0; i < wfhHeaders.length; i++) {
      final cell = wfhSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(wfhHeaders[i]);
      cell.cellStyle = headerStyle;
    }

    rowIndex = 1;
    sNo = 1;
    for (final record in wfhRecords) {
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = IntCellValue(
        sNo,
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(
        record.startDate.toIso8601String().split('T')[0],
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(
        record.endDate.toIso8601String().split('T')[0],
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = IntCellValue(
        record.totalDays,
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = TextCellValue(
        'Approved',
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = TextCellValue(
        record.reason ?? '-',
      );
      wfhSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
          .value = TextCellValue(
        '${getMonthName(record.month)} ${record.year}',
      );

      rowIndex++;
      sNo++;
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    _logger.info(
      'Generated employee detail Excel for: ${employee.employeeName}',
    );
    return Uint8List.fromList(bytes);
  }
}
