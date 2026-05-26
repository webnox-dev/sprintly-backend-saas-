import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../domain/models/letter_template.dart';
import '../data/repositories/salary_calculation_repository.dart';
import '../data/repositories/certificate_content_template_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/letter_template_repository.dart';
import '../core/utils/logger.dart';

class LetterGenerationService {
  final AppLogger _logger = AppLogger('LetterGenerationService');
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final CertificateContentTemplateRepository _certRepo =
      CertificateContentTemplateRepository();
  final LetterTemplateRepository _templateRepo = LetterTemplateRepository();
  final SalaryCalculationRepository _salaryRepo = SalaryCalculationRepository();

  // Font cache for server-side
  static pw.Font? _cachedFont;
  static pw.Font? _cachedFontBold;
  static pw.Font? _cachedFontItalic;
  static pw.Font? _cachedFontBoldItalic;

  Future<void> _ensureFontsLoaded() async {
    if (_cachedFont != null &&
        _cachedFontBold != null &&
        _cachedFontItalic != null &&
        _cachedFontBoldItalic != null) {
      return;
    }

    try {
      final regFile = File('assets/fonts/Poppins-Regular.ttf');
      final boldFile = File('assets/fonts/Poppins-Bold.ttf');
      final italicFile = File('assets/fonts/Poppins-Italic.ttf');
      final boldItalicFile = File('assets/fonts/Poppins-BoldItalic.ttf');

      if (regFile.existsSync()) {
        _cachedFont = pw.Font.ttf(
          regFile.readAsBytesSync().buffer.asByteData(),
        );
        _cachedFontBold = pw.Font.ttf(
          boldFile.readAsBytesSync().buffer.asByteData(),
        );
        _cachedFontItalic = pw.Font.ttf(
          italicFile.readAsBytesSync().buffer.asByteData(),
        );
        _cachedFontBoldItalic = pw.Font.ttf(
          boldItalicFile.readAsBytesSync().buffer.asByteData(),
        );
      } else {
        _logger.warning(
          'Font files not found at assets/fonts/, falling back to Helvetica',
        );
        _cachedFont = pw.Font.helvetica();
        _cachedFontBold = pw.Font.helveticaBold();
        _cachedFontItalic = pw.Font.helveticaOblique();
        _cachedFontBoldItalic = pw.Font.helveticaBoldOblique();
      }
    } catch (e) {
      _logger.error('Error loading fonts: $e');
      _cachedFont = pw.Font.helvetica();
      _cachedFontBold = pw.Font.helveticaBold();
      _cachedFontItalic = pw.Font.helveticaOblique();
      _cachedFontBoldItalic = pw.Font.helveticaBoldOblique();
    }
  }

  Future<Uint8List> generatePdf({
    required String templateId,
    required String employeeId,
    Map<String, String>? customData,
  }) async {
    await _ensureFontsLoaded();

    // Fetch employee and template
    final employee = await _employeeRepo.getById(employeeId);
    if (employee == null) throw Exception('Employee not found');

    final template = await _templateRepo.getTemplateById(templateId);
    if (template == null) throw Exception('Letter template not found');

    // Process placeholders (similar to frontend)
    // We'll combine salary calculation if needed

    final allRanges = await _salaryRepo.getAllRanges();

    // Matched Range
    dynamic matchedRange; // Since backend has own model
    for (var range in allRanges) {
      if (employee.employeeActualSalary >= range.salaryStart &&
          employee.employeeActualSalary <= range.salaryEnd) {
        matchedRange = range;
        break;
      }
    }

    // Experience
    // Experience & Date Parsing (Handle DD-MM-YYYY)
    DateTime? doj;
    try {
      if (employee.employeeDOJ.contains('-')) {
        final parts = employee.employeeDOJ.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          doj = DateTime(year, month, day);
        }
      }
      doj ??= DateTime.tryParse(employee.employeeDOJ);
    } catch (e) {
      _logger.error('Error parsing DOJ: ${employee.employeeDOJ}');
    }

    String period = 'N/A';
    if (doj != null) {
      final now = DateTime.now();
      final diff = now.difference(doj);
      final years = diff.inDays ~/ 365;
      final months = (diff.inDays % 365) ~/ 30;
      final days = (diff.inDays % 365) % 30;
      List<String> parts = [];
      if (years > 0) parts.add('$years Year${years > 1 ? 's' : ''}');
      if (months > 0) parts.add('$months Month${months > 1 ? 's' : ''}');
      if (days > 0 || parts.isEmpty) {
        parts.add('$days Day${days > 1 ? 's' : ''}');
      }
      period = parts.join(', ');
    }

    // Address detection/autocorrect
    final rawAddress = (template.headerConfig['address'] ?? '')
        .toString()
        .trim();
    String finalAddress = rawAddress;
    if (finalAddress.isEmpty ||
        finalAddress == 'Coimbatore, Tamil Nadu' ||
        finalAddress.toLowerCase().contains('coimbatore, tamil nadu')) {
      finalAddress =
          'No.721/2,\nVenky complex, Second floor,\nCross Cut Rd, Seth Narang Das Layout,\nCoimbatore, Tamil Nadu 641012';
    }

    final singleLineAddress = finalAddress
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final data = <String, String>{
      '{{employee_name}}': employee.employeeName,
      '{{employee_id}}': employee.employeeId,
      '{{employee_address}}': (employee.employeeAddress ?? 'N/A').replaceAll(
        '\n',
        ', ',
      ),
      '{{employee_designation}}': employee.employeeDesignation ?? 'N/A',
      '{{employee_role}}': employee.employeeRole,
      '{{employee_doj}}': DateFormat(
        'dd MMM yyyy',
      ).format(doj ?? DateTime.now()),
      '{{employee_period}}': period,
      '{{designation}}': employee.employeeDesignation ?? 'N/A',
      '{{company_name}}':
          template.headerConfig['companyName'] ?? 'Webnox Technologies',
      '{{company_address}}': singleLineAddress,
      '{{current_date}}': DateFormat('dd MMM yyyy').format(DateTime.now()),
      '{{date_of_joining}}': employee.employeeDOJ,
      '{{gross_salary}}': employee.employeeActualSalary.toStringAsFixed(2),
      '{{basic_salary}}': _calculateBasicSalary(matchedRange),
      '{{hra}}': _getComponentAmount(matchedRange, 'hra'),
      '{{medical_allowance}}': _getComponentAmount(matchedRange, 'medical'),
      '{{conveyance_allowance}}':
          _getComponentAmount(matchedRange, 'conveyance'),
      '{{special_allowance}}': _getComponentAmount(matchedRange, 'special'),
      '{{department}}': 'N/A', // Handled by frontend overrides normally
      '{{work_location}}': singleLineAddress,
      '{{work_mode}}': 'In-Office',
      '{{reporting_manager_name}}': 'N/A',
      '{{reporting_manager_designation}}': 'N/A',
      '{{leave_entitlement}}': '12',
      '{{work_days}}': 'Monday - Friday',
      '{{notice_period_probation}}': '15 Days',
      '{{acceptance_deadline}}': DateFormat('dd MMM yyyy')
          .format(DateTime.now().add(const Duration(days: 7))),
      '{{hr_manager_name}}': 'Suganya',
      '{{hr_manager_designation}}': 'HR Manager',
      '{{hr_email}}': 'hr@webnox.in',
      '{{hr_phone}}': '9876543210',
      // Relieving / Termination defaults
      '{{exit_type}}': 'Resignation',
      '{{date_of_relieving}}': DateFormat('dd MMM yyyy').format(DateTime.now()),
      '{{last_working_date}}': DateFormat('dd MMM yyyy').format(DateTime.now()),
      '{{conduct_rating}}': 'Good',
      '{{clearance_status}}': 'Completed',
      '{{assets_returned}}': 'Yes',
      '{{exit_reason}}': 'Personal reasons',
      '{{termination_reason}}': 'N/A',
      '{{relieving_remarks}}': '',
    };

    if (customData != null) data.addAll(customData);

    // Build PDF Document
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _cachedFont,
        bold: _cachedFontBold,
        italic: _cachedFontItalic,
        boldItalic: _cachedFontBoldItalic,
      ),
    );

    // Rich content parsing
    final bodyWidgets = _processDeltaToRichWidgets(
      template.bodyContent,
      data,
      _cachedFont!,
      _cachedFontBold!,
      _cachedFontItalic!,
      _cachedFontBoldItalic!,
    );

    // Header images
    Uint8List? logoBytes = _safeBase64Decode(
      template.headerConfig['logoBase64'],
      'logo',
    );
    Uint8List? sealBytes = _safeBase64Decode(
      template.footerConfig['sealBase64'],
      'seal',
    );
    Uint8List? watermarkBytes = _safeBase64Decode(
      template.watermarkConfig['imageBase64'],
      'watermark',
    );

    // Load defaults from assets if base64 missing or explicitly requested
    if (logoBytes == null && _isTrue(template.headerConfig['showLogo'], defaultVal: true)) {
      final file = File('assets/images/Webnox technologies private limited - logo.png');
      if (file.existsSync()) {
        logoBytes = file.readAsBytesSync();
        _logger.info('Loaded default logo from assets');
      } else {
        _logger.warning('Default logo not found at ${file.path}');
      }
    }
    if (sealBytes == null && _isTrue(template.footerConfig['showSeal'], defaultVal: true)) {
      final file = File('assets/images/seal.JPG');
      if (file.existsSync()) {
        sealBytes = file.readAsBytesSync();
        _logger.info('Loaded default seal from assets');
      } else {
        _logger.warning('Default seal not found at ${file.path}');
      }
    }
    if (watermarkBytes == null &&
        _isTrue(template.watermarkConfig['showWatermark'], defaultVal: true) &&
        _isTrue(template.watermarkConfig['isImage'], defaultVal: true)) {
      final file = File('assets/images/Webnox technologies private limited - logo.png');
      if (file.existsSync()) {
        watermarkBytes = file.readAsBytesSync();
        _logger.info('Loaded default watermark from assets');
      } else {
        _logger.warning('Default watermark not found at ${file.path}');
      }
    }

    // Best match role content
    final bestMatch = await _certRepo.findBestMatch(
      template.templateType,
      employee.employeeRole,
      employee.employeeDesignation,
    );

    List<pw.Widget> roleWidgets = [];
    if (bestMatch != null && bestMatch.bodyContent.isNotEmpty) {
      roleWidgets = _processDeltaToRichWidgets(
        bestMatch.bodyContent,
        data,
        _cachedFont!,
        _cachedFontBold!,
        _cachedFontItalic!,
        _cachedFontBoldItalic!,
      );
    }

    final PdfColor accentColor = PdfColor.fromInt(0xFF1A1A2E);
    final PdfColor darkText = PdfColors.grey900;
    final PdfColor medText = PdfColors.grey700;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          buildBackground: (pw.Context context) {
            if (_isTrue(template.watermarkConfig['showWatermark'], defaultVal: true)) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: () {
                      final val = template.watermarkConfig['opacity'];
                      if (val == null) return 0.1;
                      if (val is num) return val.toDouble();
                      return double.tryParse(val.toString()) ?? 0.1;
                    }(),
                    child: pw.Transform.rotate(
                      angle: () {
                        final val = template.watermarkConfig['rotation'];
                        if (val == null) return 0.0;
                        if (val is num) return val.toDouble();
                        return double.tryParse(val.toString()) ?? 0.0;
                      }(),
                      child:
                          _isTrue(template.watermarkConfig['isImage'], defaultVal: true) &&
                              watermarkBytes != null
                          ? pw.Image(pw.MemoryImage(watermarkBytes), width: 450)
                          : pw.Text(
                              template.watermarkConfig['text'] ??
                                  'CONFIDENTIAL',
                              style: pw.TextStyle(
                                font: _cachedFontBold,
                                fontSize: 80,
                                color: PdfColors.grey300,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }
            return pw.SizedBox.shrink();
          },
        ),
        header: (context) {
          if (context.pageNumber == 1) {
            return _buildHeader(
              template,
              logoBytes,
              _cachedFont!,
              _cachedFontBold!,
              accentColor,
              finalAddress,
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (context) {
          return _buildFooter(template, _cachedFont!, context, accentColor);
        },
        build: (context) {
          return [
            if (template.headerConfig['showDate'] == true) ...[
              pw.Align(
                alignment: (template.headerConfig['dateAlign'] == 'right')
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
                child: pw.Text(
                  'Date: ${DateFormat(template.headerConfig['dateFormat'] ?? 'dd MMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: _cachedFont,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // Add vertical spacing for certificates to simulate vertical centering
            if (template.templateType.toLowerCase().contains('certificate'))
              pw.SizedBox(height: 80),

            // Body Content: Strictly enforce only one source of content
            if (roleWidgets.isNotEmpty) ...[
              ...roleWidgets,
            ] else ...[
              ...bodyWidgets,
            ],

            // Signature & Acceptance Section (3-Column Layout)
            if ((template.footerConfig['showSignatureBlock'] ?? true) == true ||
                (template.footerConfig['showAcceptanceBlock'] ?? true) ==
                    true) ...[
              pw.SizedBox(height: 40),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Signatory Block (Left)
                  if ((template.footerConfig['showSignatureBlock'] ?? true) ==
                      true)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            template.footerConfig['signatoryDesignation'] ??
                                'For Webnox Technologies',
                            style: pw.TextStyle(
                              font: _cachedFontBold,
                              fontSize: 12,
                              color: darkText,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            template.footerConfig['signatoryName'] ??
                                'Human Resources Department',
                            style: pw.TextStyle(
                              font: _cachedFont,
                              fontSize: 10,
                              color: medText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    pw.Spacer(flex: 2),

                  // Seal (Left / Center / Right based on config)
                  if (_isTrue(template.footerConfig['showSeal'], defaultVal: true) &&
                      sealBytes != null)
                    () {
                      final nonNullSeal = sealBytes!;
                      final sealAlign = template.footerConfig['sealAlign'] ?? 'center';
                      final sealScale = () {
                        final val = template.footerConfig['sealScale'];
                        if (val == null) return 1.0;
                        if (val is num) return val.toDouble();
                        return double.tryParse(val.toString()) ?? 1.0;
                      }();
                      final sealWidget = pw.Container(
                        width: 80 * sealScale,
                        height: 80 * sealScale,
                        child: pw.Image(
                          pw.MemoryImage(nonNullSeal),
                          fit: pw.BoxFit.contain,
                        ),
                      );

                      if (sealAlign == 'left') {
                        return pw.Expanded(
                          flex: 1,
                          child: pw.Align(alignment: pw.Alignment.centerLeft, child: sealWidget),
                        );
                      } else if (sealAlign == 'right') {
                        return pw.Expanded(
                          flex: 1,
                          child: pw.Align(alignment: pw.Alignment.centerRight, child: sealWidget),
                        );
                      } else {
                        return pw.Expanded(
                          flex: 1,
                          child: pw.Center(child: sealWidget),
                        );
                      }
                    }()
                  else
                    pw.Spacer(flex: 1),

                  // Acceptance (Right)
                  if ((template.footerConfig['showAcceptanceBlock'] ?? true) ==
                      true)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            template.footerConfig['acceptanceLabel'] ??
                                'I accept the offer',
                            style: pw.TextStyle(
                              font: _cachedFontBold,
                              fontSize: 12,
                              color: darkText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    pw.Spacer(flex: 2),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _calculateBasicSalary(dynamic range) {
    if (range == null) return 'N/A';
    try {
      final earnings = range.earnings as List;
      if (earnings.isEmpty) return 'N/A';

      // Look for "basic"
      final basicComp = earnings.firstWhere(
        (e) => e.componentName.toString().toLowerCase().contains('basic'),
        orElse: () => null,
      );

      if (basicComp != null) {
        return basicComp.calculatedAmount.toStringAsFixed(2);
      }

      // Fallback to first earning
      return earnings.first.calculatedAmount.toStringAsFixed(2);
    } catch (e) {
      return 'N/A';
    }
  }

  pw.Widget _buildHeader(
    LetterTemplate template,
    Uint8List? logo,
    pw.Font font,
    pw.Font fontBold,
    PdfColor color,
    String finalAddress,
  ) {
    final logoAlign = template.headerConfig['logoAlign'] ?? 'left';
    final scale = () {
      final val = template.headerConfig['logoScale'];
      if (val == null) return 1.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 1.0;
    }();

    final logoWidget =
        (_isTrue(template.headerConfig['showLogo'], defaultVal: true) && logo != null)
        ? pw.Container(
            width: 100 * scale,
            height: 45 * scale,
            child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
          )
        : pw.SizedBox.shrink();

    final addressLines = finalAddress.split('\n');

    final infoWidget = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        ...addressLines.map(
          (line) => pw.Text(
            line.trim(),
            style: pw.TextStyle(
              font: fontBold, // Bold address lines as per frontend look
              fontSize: 9.5,
              color: color, // Use accent color for address
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            pw.CrossAxisAlignment.start, // Top aligned for better baseline
        children: logoAlign == 'right'
            ? [
                pw.Expanded(child: infoWidget),
                pw.SizedBox(width: 40),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(
                    top: 2,
                  ), // Visual adjustment
                  child: logoWidget,
                ),
              ]
            : [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(
                    top: 2,
                  ), // Visual adjustment
                  child: logoWidget,
                ),
                pw.SizedBox(width: 40),
                pw.Expanded(child: infoWidget),
              ],
      ),
    );
  }

  pw.Widget _buildFooter(
    LetterTemplate template,
    pw.Font font,
    pw.Context context,
    PdfColor color,
  ) {
    final systemGeneratedText =
        template.footerConfig['systemGeneratedText'] ??
        'This is a system-generated document and does not require a physical signature.';
    final showContact =
        (template.footerConfig['showContactBar'] ?? true).toString() == 'true';
    final phone = (template.footerConfig['phone'] ?? '9876557739').toString();
    final website = (template.footerConfig['website'] ?? 'webnox.in')
        .toString();
    final email = (template.footerConfig['email'] ?? 'contact@webnox.in')
        .toString();
    final generatedTimestamp =
        DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now());

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Always show system-generated text for all letters
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              '$systemGeneratedText  |  Generated on: $generatedTimestamp',
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ),
        if (showContact) ...[
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Tel: $phone',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                '  |  ',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey400,
                ),
              ),
              pw.Text(
                'Web: $website',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                '  |  ',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey400,
                ),
              ),
              pw.Text(
                'Email: $email',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                font: font,
                fontSize: 7.5,
                color: PdfColors.grey400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isTrue(dynamic value, {bool defaultVal = false}) {
    if (value == null) return defaultVal;
    if (value is bool) return value;
    if (value is String) {
      final s = value.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes' || s == 'on';
    }
    if (value is num) return value != 0;
    return defaultVal;
  }

  Uint8List? _safeBase64Decode(dynamic base64Value, String label) {
    if (base64Value == null) return null;
    try {
      String b64 = base64Value.toString();
      if (b64.isEmpty) return null;
      if (b64.contains(',')) b64 = b64.split(',').last;
      b64 = b64.replaceAll(RegExp(r'\s+'), '');
      final padLength = (4 - b64.length % 4) % 4;
      b64 = b64 + '=' * padLength;
      return base64Decode(b64);
    } catch (e) {
      _logger.error('Error decoding $label: $e');
      return null;
    }
  }

  List<pw.Widget> _processDeltaToRichWidgets(
    String deltaJson,
    Map<String, String> data,
    pw.Font font,
    pw.Font bold,
    pw.Font italic,
    pw.Font boldItalic,
  ) {
    try {
      final List delta = jsonDecode(deltaJson);
      final segments = <_RichSegment>[];

      for (var op in delta) {
        if (op is Map && op.containsKey('insert')) {
          var insert = op['insert'];
          if (insert is String) {
            final attrs = op['attributes'] ?? {};
            final isBold = attrs['bold'] == true;
            final isItalic = attrs['italic'] == true;
            final isUnderline = attrs['underline'] == true;
            final isHeading = attrs.containsKey('heading');
            final headingLevel = isHeading
                ? (int.tryParse(attrs['heading'].toString()) ?? 1)
                : 0;

            String text = insert;
            // Single-pass replacement using RegExp to prevent partial key collisions and recursive replacement issues.
            text = text.replaceAllMapped(RegExp(r'\{\{([^{}]*)\}\}'), (match) {
              final placeholder = match.group(0); // e.g., {{stipend}}
              final key = match.group(1); // e.g., stipend
              return data[placeholder] ?? data[key] ?? placeholder!;
            });

            segments.add(
              _RichSegment(
                text: text,
                isBold: isBold,
                isItalic: isItalic,
                isUnderline: isUnderline,
                headingLevel: headingLevel,
              ),
            );
          }
        }
      }

      final lines = <List<_RichSegment>>[];
      var currentLine = <_RichSegment>[];

      for (var seg in segments) {
        final parts = seg.text.split('\n');
        for (int i = 0; i < parts.length; i++) {
          if (i > 0) {
            lines.add(currentLine);
            currentLine = <_RichSegment>[];
          }
          if (parts[i].isNotEmpty) {
            currentLine.add(
              _RichSegment(
                text: parts[i],
                isBold: seg.isBold,
                isItalic: seg.isItalic,
                isUnderline: seg.isUnderline,
                headingLevel: seg.headingLevel,
              ),
            );
          }
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }

      final widgets = <pw.Widget>[];
      for (var line in lines) {
        final headingLevel = line.any((s) => s.headingLevel > 0)
            ? line.firstWhere((s) => s.headingLevel > 0).headingLevel
            : 0;

        final textSpans = line.map((seg) {
          pw.Font f = font;
          if (seg.isBold && seg.isItalic) {
            f = boldItalic;
          } else if (seg.isBold) {
            f = bold;
          } else if (seg.isItalic) {
            f = italic;
          }

          double fs;
          if (headingLevel == 1) {
            fs = 16;
          } else if (headingLevel == 2) {
            fs = 14;
          } else if (headingLevel == 3) {
            fs = 12;
          } else {
            fs = 10.5;
          }

          return pw.TextSpan(
            text: seg.text,
            style: pw.TextStyle(
              font: headingLevel > 0 ? bold : f,
              fontSize: fs,
              color: PdfColors.grey900,
              decoration: seg.isUnderline ? pw.TextDecoration.underline : null,
              lineSpacing: 5, // Increased line spacing for better readability
            ),
          );
        }).toList();

        if (line.length == 1 && line[0].text.trim() == 'RENDER_TABLE') {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              child: _buildCtcTable(data, font, bold),
            ),
          );
          continue;
        }

        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              bottom: headingLevel > 0 ? 8 : 4,
              top: headingLevel > 0 ? 6 : 0,
            ),
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(children: textSpans),
            ),
          ),
        );
      }

      return widgets;
    } catch (e) {
      _logger.error('Error processing rich text: $e');
      // Fallback: Handle HTML content by stripping tags and replacing placeholders
      try {
        String plainText = deltaJson;
        // Strip HTML tags
        plainText = plainText.replaceAll(RegExp(r'<[^>]*>'), '');
        // Decode HTML entities
        plainText = plainText
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'");
        // Replace placeholders
        plainText = plainText.replaceAllMapped(
            RegExp(r'\{\{([^{}]*)\}\}'), (match) {
          final placeholder = match.group(0);
          return data[placeholder] ?? placeholder!;
        });

        final lines = plainText.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final widgets = <pw.Widget>[];

        for (final line in lines) {
          if (line.trim() == 'RENDER_TABLE') {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                child: _buildCtcTable(data, font, bold),
              ),
            );
            continue;
          }
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                line.trim(),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10.5,
                  color: PdfColors.grey900,
                  lineSpacing: 5,
                ),
                textAlign: pw.TextAlign.justify,
              ),
            ),
          );
        }
        return widgets;
      } catch (fallbackErr) {
        _logger.error('HTML fallback also failed: $fallbackErr');
        return [pw.Text('Error processing document content.')];
      }
    }
  }

  pw.Widget _buildCtcTable(
      Map<String, String> data, pw.Font font, pw.Font bold) {
    final basic = double.tryParse(data['{{basic_salary}}'] ?? '0') ?? 0;
    final hra = double.tryParse(data['{{hra}}'] ?? '0') ?? 0;
    final medical = double.tryParse(data['{{medical_allowance}}'] ?? '0') ?? 0;
    final conveyance =
        double.tryParse(data['{{conveyance_allowance}}'] ?? '0') ?? 0;
    final special = double.tryParse(data['{{special_allowance}}'] ?? '0') ?? 0;
    final gross = double.tryParse(data['{{gross_salary}}'] ?? '0') ?? 0;
    final annual = double.tryParse(data['{{annual_ctc}}'] ?? '0') ?? (gross * 12);

    final rows = [
      ['Salary Component', 'Monthly (\u20B9)', 'Annual (\u20B9)'],
      ['Basic Salary', basic.toStringAsFixed(2), (basic * 12).toStringAsFixed(2)],
      ['House Rent Allowance (HRA)', hra.toStringAsFixed(2), (hra * 12).toStringAsFixed(2)],
      ['Medical Allowance', medical.toStringAsFixed(2), (medical * 12).toStringAsFixed(2)],
      ['Conveyance Allowance', conveyance.toStringAsFixed(2), (conveyance * 12).toStringAsFixed(2)],
      ['Special Allowance', special.toStringAsFixed(2), (special * 12).toStringAsFixed(2)],
      ['Gross Salary', gross.toStringAsFixed(2), (gross * 12).toStringAsFixed(2)],
      ['Total Cost to Company (CTC)', '', annual.toStringAsFixed(2)],
    ];

    return pw.TableHelper.fromTextArray(
      context: null,
      data: rows,
      headerStyle:
          pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
      },
      cellFormat: (col, data) {
        if (col > 0 && double.tryParse(data.toString()) != null) {
          return NumberFormat("#,##,###.00")
              .format(double.parse(data.toString()));
        }
        return data.toString();
      },
    );
  }

  String _getComponentAmount(dynamic range, String type) {
    if (range == null) return '0.00';
    try {
      final earnings = range.earnings as List;
      final comp = earnings.firstWhere(
        (e) => e.componentName.toLowerCase().contains(type.toLowerCase()),
      );
      return comp.calculatedAmount.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }
}

class _RichSegment {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final int headingLevel;
  _RichSegment({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.headingLevel = 0,
  });
}
