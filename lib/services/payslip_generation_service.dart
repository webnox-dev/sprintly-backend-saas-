import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/salary_calculation_repository.dart';
import '../core/utils/logger.dart';

class PayslipGenerationService {
  final AppLogger _logger = AppLogger('PayslipGenerationService');
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final SalaryCalculationRepository _salaryRepo = SalaryCalculationRepository();

  // Font cache
  static pw.Font? _cachedFont;
  static pw.Font? _cachedFontBold;

  Future<void> _ensureFontsLoaded() async {
    if (_cachedFont != null && _cachedFontBold != null) return;

    try {
      final regFile = File('assets/fonts/Poppins-Regular.ttf');
      final boldFile = File('assets/fonts/Poppins-Bold.ttf');

      if (regFile.existsSync()) {
        _cachedFont = pw.Font.ttf(
          regFile.readAsBytesSync().buffer.asByteData(),
        );
        _cachedFontBold = pw.Font.ttf(
          boldFile.readAsBytesSync().buffer.asByteData(),
        );
      } else {
        _cachedFont = pw.Font.helvetica();
        _cachedFontBold = pw.Font.helveticaBold();
      }
    } catch (e) {
      _logger.error('Error loading fonts: $e');
      _cachedFont = pw.Font.helvetica();
      _cachedFontBold = pw.Font.helveticaBold();
    }
  }

  /// Generate payslip PDF for a specific employee and month/year
  Future<Uint8List> generatePayslip({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    await _ensureFontsLoaded();

    final employee = await _employeeRepo.getById(employeeId);
    if (employee == null) throw Exception('Employee not found');

    // Find matching salary range
    final allRanges = await _salaryRepo.getAllRanges();
    dynamic matchedRange;
    for (var range in allRanges) {
      if (employee.employeeActualSalary >= range.salaryStart &&
          employee.employeeActualSalary <= range.salaryEnd) {
        matchedRange = range;
        break;
      }
    }

    if (matchedRange == null) {
      throw Exception(
        'No salary configuration found for employee salary ₹${employee.employeeActualSalary}',
      );
    }

    final font = _cachedFont!;
    final fontBold = _cachedFontBold!;

    // Colors
    const PdfColor primaryColor = PdfColor.fromInt(0xFF1A1A2E);
    const PdfColor accentColor = PdfColor.fromInt(0xFF6366F1);
    const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);
    const PdfColor medText = PdfColor.fromInt(0xFF64748B);

    // Calculate amounts from the salary range components
    final grossSalary = employee.employeeActualSalary;
    final earnings = matchedRange.earnings as List;
    final deductions = matchedRange.deductions as List;

    // Calculate actual amounts proportional to the employee's salary
    final List<Map<String, dynamic>> earningsList = [];
    double totalEarnings = 0;
    for (var e in earnings) {
      final percentage = (e.percentage as num).toDouble();
      final amount = (grossSalary * percentage) / 100;
      earningsList.add({'name': e.componentName, 'amount': amount});
      totalEarnings += amount;
    }

    final List<Map<String, dynamic>> deductionsList = [];
    double totalDeductions = 0;
    for (var d in deductions) {
      final percentage = (d.percentage as num).toDouble();
      final amount = (grossSalary * percentage) / 100;
      deductionsList.add({'name': d.componentName, 'amount': amount});
      totalDeductions += amount;
    }

    final netPay = totalEarnings - totalDeductions;
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final payPeriod = '$monthName $year';

    // Number formatter
    final currencyFormat = NumberFormat('#,##,###.00', 'en_IN');

    // Load company logo
    Uint8List? logoBytes;
    final logoFile = File(
      'assets/images/Webnox technologies private limited - logo.png',
    );
    if (logoFile.existsSync()) {
      logoBytes = logoFile.readAsBytesSync();
    }

    // Build PDF
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════
              // HEADER - Company Info + Logo
              // ═══════════════════════════════════════════
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoBytes != null)
                      pw.Container(
                        width: 60,
                        height: 60,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Image(
                          pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    if (logoBytes != null) pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'WEBNOX TECHNOLOGIES PVT LTD',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'No.721/2, Venky Complex, Second Floor, Cross Cut Rd, Seth Narang Das Layout, Coimbatore, Tamil Nadu 641012',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColor.fromInt(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor(1, 1, 1, 0.15),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: const PdfColor(1, 1, 1, 0.2)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'PAYSLIP',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            payPeriod,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: PdfColor.fromInt(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ═══════════════════════════════════════════
              // EMPLOYEE INFORMATION
              // ═══════════════════════════════════════════
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            'Employee Name',
                            employee.employeeName,
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                          pw.SizedBox(height: 8),
                          _infoRow(
                            'Employee ID',
                            employee.employeeId,
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                          pw.SizedBox(height: 8),
                          _infoRow(
                            'Designation',
                            employee.employeeDesignation ?? 'N/A',
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            'Department',
                            employee.employeeRole,
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                          pw.SizedBox(height: 8),
                          _infoRow(
                            'Date of Joining',
                            _formatDate(employee.employeeDOJ),
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                          pw.SizedBox(height: 8),
                          _infoRow(
                            'Pay Period',
                            payPeriod,
                            font,
                            fontBold,
                            darkText,
                            medText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ═══════════════════════════════════════════
              // EARNINGS & DEDUCTIONS TABLE
              // ═══════════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Earnings Column
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        children: [
                          // Header
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFF1F5F9),
                              borderRadius: const pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(7),
                                topRight: pw.Radius.circular(7),
                              ),
                            ),
                            child: pw.Text(
                              'EARNINGS',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: darkText,
                              ),
                            ),
                          ),
                          // Rows
                          ...earningsList.map(
                            (e) => _tableRow(
                              e['name'],
                              currencyFormat.format(e['amount']),
                              font,
                              darkText,
                              medText,
                            ),
                          ),
                          // Total
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(color: borderColor),
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Total Earnings',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 10,
                                    color: darkText,
                                  ),
                                ),
                                pw.Text(
                                  '₹${currencyFormat.format(totalEarnings)}',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 10,
                                    color: darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Deductions Column
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        children: [
                          // Header
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFF1F5F9),
                              borderRadius: const pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(7),
                                topRight: pw.Radius.circular(7),
                              ),
                            ),
                            child: pw.Text(
                              'DEDUCTIONS',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: darkText,
                              ),
                            ),
                          ),
                          // Rows
                          ...deductionsList.map(
                            (d) => _tableRow(
                              d['name'],
                              currencyFormat.format(d['amount']),
                              font,
                              darkText,
                              medText,
                            ),
                          ),
                          // Add empty rows to match earnings count if needed
                          if (deductionsList.length < earningsList.length)
                            ...List.generate(
                              earningsList.length - deductionsList.length,
                              (_) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                child: pw.SizedBox(height: 12),
                              ),
                            ),
                          // Total
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(color: borderColor),
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Total Deductions',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 10,
                                    color: darkText,
                                  ),
                                ),
                                pw.Text(
                                  '₹${currencyFormat.format(totalDeductions)}',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 10,
                                    color: darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // ═══════════════════════════════════════════
              // NET PAY SUMMARY
              // ═══════════════════════════════════════════
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor, width: 1.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NET PAY',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: medText,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _numberToWords(netPay.round()),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: medText,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      '₹${currencyFormat.format(netPay)}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 22,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ═══════════════════════════════════════════
              // SALARY SUMMARY BAR
              // ═══════════════════════════════════════════
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      'Gross Salary',
                      '₹${currencyFormat.format(grossSalary)}',
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    _verticalDivider(),
                    _summaryItem(
                      'Total Earnings',
                      '₹${currencyFormat.format(totalEarnings)}',
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    _verticalDivider(),
                    _summaryItem(
                      'Total Deductions',
                      '₹${currencyFormat.format(totalDeductions)}',
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    _verticalDivider(),
                    _summaryItem(
                      'Net Pay',
                      '₹${currencyFormat.format(netPay)}',
                      font,
                      fontBold,
                      accentColor,
                      medText,
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ═══════════════════════════════════════════
              // FOOTER
              // ═══════════════════════════════════════════
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a system-generated payslip and does not require a signature.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: medText,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.Text(
                    'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: medText,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Tel: 9876557739  |  Web: webnox.in  |  Email: contact@webnox.in',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7.5,
                      color: PdfColor.fromInt(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate payslip PDF for multiple months (one page per month)
  Future<Uint8List> generateMultiMonthPayslip({
    required String employeeId,
    required List<Map<String, int>> monthYearList,
  }) async {
    await _ensureFontsLoaded();

    final employee = await _employeeRepo.getById(employeeId);
    if (employee == null) throw Exception('Employee not found');

    // Find matching salary range
    final allRanges = await _salaryRepo.getAllRanges();
    dynamic matchedRange;
    for (var range in allRanges) {
      if (employee.employeeActualSalary >= range.salaryStart &&
          employee.employeeActualSalary <= range.salaryEnd) {
        matchedRange = range;
        break;
      }
    }

    if (matchedRange == null) {
      throw Exception(
        'No salary configuration found for employee salary ₹${employee.employeeActualSalary}',
      );
    }

    final font = _cachedFont!;
    final fontBold = _cachedFontBold!;

    // Colors
    const PdfColor primaryColor = PdfColor.fromInt(0xFF1A1A2E);
    const PdfColor accentColor = PdfColor.fromInt(0xFF6366F1);
    const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
    const PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);
    const PdfColor medText = PdfColor.fromInt(0xFF64748B);

    final grossSalary = employee.employeeActualSalary;
    final earnings = matchedRange.earnings as List;
    final deductions = matchedRange.deductions as List;

    final List<Map<String, dynamic>> earningsList = [];
    double totalEarnings = 0;
    for (var e in earnings) {
      final percentage = (e.percentage as num).toDouble();
      final amount = (grossSalary * percentage) / 100;
      earningsList.add({'name': e.componentName, 'amount': amount});
      totalEarnings += amount;
    }

    final List<Map<String, dynamic>> deductionsList = [];
    double totalDeductions = 0;
    for (var d in deductions) {
      final percentage = (d.percentage as num).toDouble();
      final amount = (grossSalary * percentage) / 100;
      deductionsList.add({'name': d.componentName, 'amount': amount});
      totalDeductions += amount;
    }

    final netPay = totalEarnings - totalDeductions;
    final currencyFormat = NumberFormat('#,##,###.00', 'en_IN');

    Uint8List? logoBytes;
    final logoFile = File(
      'assets/images/Webnox technologies private limited - logo.png',
    );
    if (logoFile.existsSync()) {
      logoBytes = logoFile.readAsBytesSync();
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    // Add one page per month
    for (final my in monthYearList) {
      final month = my['month']!;
      final year = my['year']!;
      final monthName = DateFormat('MMMM').format(DateTime(year, month));
      final payPeriod = '$monthName $year';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPayslipPage(
              font: font,
              fontBold: fontBold,
              employee: employee,
              payPeriod: payPeriod,
              earningsList: earningsList,
              deductionsList: deductionsList,
              totalEarnings: totalEarnings,
              totalDeductions: totalDeductions,
              netPay: netPay,
              grossSalary: grossSalary,
              currencyFormat: currencyFormat,
              logoBytes: logoBytes,
              primaryColor: primaryColor,
              accentColor: accentColor,
              lightBg: lightBg,
              borderColor: borderColor,
              darkText: darkText,
              medText: medText,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ─── SHARED PAGE BUILDER ────────────────────────────────────

  pw.Widget _buildPayslipPage({
    required pw.Font font,
    required pw.Font fontBold,
    required dynamic employee,
    required String payPeriod,
    required List<Map<String, dynamic>> earningsList,
    required List<Map<String, dynamic>> deductionsList,
    required double totalEarnings,
    required double totalDeductions,
    required double netPay,
    required double grossSalary,
    required NumberFormat currencyFormat,
    Uint8List? logoBytes,
    required PdfColor primaryColor,
    required PdfColor accentColor,
    required PdfColor lightBg,
    required PdfColor borderColor,
    required PdfColor darkText,
    required PdfColor medText,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // HEADER
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              if (logoBytes != null) pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WEBNOX TECHNOLOGIES PVT LTD',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'No.721/2, Venky Complex, Second Floor, Cross Cut Rd, Seth Narang Das Layout, Coimbatore, Tamil Nadu 641012',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(1, 1, 1, 0.15),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: const PdfColor(1, 1, 1, 0.2)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PAYSLIP',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      payPeriod,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // EMPLOYEE INFO
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Employee Name',
                      employee.employeeName,
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    pw.SizedBox(height: 8),
                    _infoRow(
                      'Employee ID',
                      employee.employeeId,
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    pw.SizedBox(height: 8),
                    _infoRow(
                      'Designation',
                      employee.employeeDesignation ?? 'N/A',
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Department',
                      employee.employeeRole,
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    pw.SizedBox(height: 8),
                    _infoRow(
                      'Date of Joining',
                      _formatDate(employee.employeeDOJ),
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                    pw.SizedBox(height: 8),
                    _infoRow(
                      'Pay Period',
                      payPeriod,
                      font,
                      fontBold,
                      darkText,
                      medText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // EARNINGS & DEDUCTIONS
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Text(
                        'EARNINGS',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: darkText,
                        ),
                      ),
                    ),
                    ...earningsList.map(
                      (e) => _tableRow(
                        e['name'],
                        currencyFormat.format(e['amount']),
                        font,
                        darkText,
                        medText,
                      ),
                    ),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: borderColor),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Earnings',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: darkText,
                            ),
                          ),
                          pw.Text(
                            '₹${currencyFormat.format(totalEarnings)}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Text(
                        'DEDUCTIONS',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: darkText,
                        ),
                      ),
                    ),
                    ...deductionsList.map(
                      (d) => _tableRow(
                        d['name'],
                        currencyFormat.format(d['amount']),
                        font,
                        darkText,
                        medText,
                      ),
                    ),
                    if (deductionsList.length < earningsList.length)
                      ...List.generate(
                        earningsList.length - deductionsList.length,
                        (_) => pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: pw.SizedBox(height: 12),
                        ),
                      ),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: borderColor),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Deductions',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: darkText,
                            ),
                          ),
                          pw.Text(
                            '₹${currencyFormat.format(totalDeductions)}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // NET PAY
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor, width: 1.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NET PAY',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: medText,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _numberToWords(netPay.round()),
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: medText,
                    ),
                  ),
                ],
              ),
              pw.Text(
                '₹${currencyFormat.format(netPay)}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 22,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // SUMMARY BAR
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(
                'Gross Salary',
                '₹${currencyFormat.format(grossSalary)}',
                font,
                fontBold,
                darkText,
                medText,
              ),
              _verticalDivider(),
              _summaryItem(
                'Total Earnings',
                '₹${currencyFormat.format(totalEarnings)}',
                font,
                fontBold,
                darkText,
                medText,
              ),
              _verticalDivider(),
              _summaryItem(
                'Total Deductions',
                '₹${currencyFormat.format(totalDeductions)}',
                font,
                fontBold,
                darkText,
                medText,
              ),
              _verticalDivider(),
              _summaryItem(
                'Net Pay',
                '₹${currencyFormat.format(netPay)}',
                font,
                fontBold,
                accentColor,
                medText,
              ),
            ],
          ),
        ),
        pw.Spacer(),

        // FOOTER
        pw.Divider(color: borderColor, thickness: 0.5),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a system-generated payslip and does not require a signature.',
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: medText,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 7, color: medText),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Tel: 9876557739  |  Web: webnox.in  |  Email: contact@webnox.in',
              style: pw.TextStyle(
                font: font,
                fontSize: 7.5,
                color: PdfColor.fromInt(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HELPER WIDGETS ───────────────────────────────────────

  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font font,
    pw.Font bold,
    PdfColor darkText,
    PdfColor medText,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 9, color: medText),
          ),
        ),
        pw.Text(
          ': ',
          style: pw.TextStyle(font: font, fontSize: 9, color: medText),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: bold, fontSize: 9, color: darkText),
          ),
        ),
      ],
    );
  }

  pw.Widget _tableRow(
    String name,
    String amount,
    pw.Font font,
    PdfColor darkText,
    PdfColor medText,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFFF1F5F9),
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(font: font, fontSize: 9, color: medText),
          ),
          pw.Text(
            '₹$amount',
            style: pw.TextStyle(font: font, fontSize: 9, color: darkText),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(
    String label,
    String value,
    pw.Font font,
    pw.Font bold,
    PdfColor valueColor,
    PdfColor labelColor,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 8, color: labelColor),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(font: bold, fontSize: 10, color: valueColor),
        ),
      ],
    );
  }

  pw.Widget _verticalDivider() {
    return pw.Container(
      width: 1,
      height: 30,
      color: const PdfColor.fromInt(0xFFE2E8F0),
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime? dt = DateTime.tryParse(dateStr);
      if (dt == null) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          dt = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
      if (dt != null) {
        return DateFormat('dd MMM yyyy').format(dt);
      }
    } catch (_) {}
    return dateStr;
  }

  /// Convert a number to words (Indian format)
  String _numberToWords(int n) {
    if (n == 0) return 'Rupees Zero Only';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String twoDigits(int n) {
      if (n < 20) return ones[n];
      return '${tens[n ~/ 10]} ${ones[n % 10]}'.trim();
    }

    String threeDigits(int n) {
      if (n >= 100) {
        return '${ones[n ~/ 100]} Hundred ${twoDigits(n % 100)}'.trim();
      }
      return twoDigits(n);
    }

    final parts = <String>[];
    if (n >= 10000000) {
      parts.add('${twoDigits(n ~/ 10000000)} Crore');
      n %= 10000000;
    }
    if (n >= 100000) {
      parts.add('${twoDigits(n ~/ 100000)} Lakh');
      n %= 100000;
    }
    if (n >= 1000) {
      parts.add('${twoDigits(n ~/ 1000)} Thousand');
      n %= 1000;
    }
    if (n > 0) {
      parts.add(threeDigits(n));
    }

    return 'Rupees ${parts.join(' ')} Only';
  }
}
