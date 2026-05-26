import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../data/repositories/letter_template_repository.dart';
import '../services/letter_generation_service.dart';
import '../services/payslip_generation_service.dart';

class LetterTemplateRoutes {
  final LetterTemplateRepository _repository = LetterTemplateRepository();

  Router get router {
    final router = Router();

    // GET /letter-templates - Fetch all templates
    router.get('/letter-templates', (Request request) async {
      try {
        final queryParams = request.url.queryParameters;
        final type = queryParams['type'];
        final templates = await _repository.getAllTemplates(type);

        return Response.ok(
          jsonEncode({
            'success': true,
            'data': templates.map((t) => t.toMap()).toList(),
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // GET /letter-templates/<id> - Fetch single template
    router.get('/letter-templates/<id>', (Request request, String id) async {
      try {
        final template = await _repository.getTemplateById(id);
        if (template == null) {
          return Response.notFound(
            jsonEncode({'success': false, 'message': 'Template not found'}),
            headers: {'content-type': 'application/json'},
          );
        }

        return Response.ok(
          jsonEncode({'success': true, 'data': template.toMap()}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // POST /letter-templates - Create template
    router.post('/letter-templates', (Request request) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);

        // Optionally get admin identifier from auth context if available
        data['created_by'] = 'admin';

        final template = await _repository.createTemplate(data);

        return Response.ok(
          jsonEncode({'success': true, 'data': template.toMap()}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // PUT /letter-templates/<id> - Update template
    router.put('/letter-templates/<id>', (Request request, String id) async {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);

        data['updated_by'] = 'admin';

        final template = await _repository.updateTemplate(id, data);

        return Response.ok(
          jsonEncode({'success': true, 'data': template.toMap()}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // DELETE /letter-templates/<id> - Delete template
    router.delete('/letter-templates/<id>', (Request request, String id) async {
      try {
        await _repository.deleteTemplate(id);

        return Response.ok(
          jsonEncode({'success': true, 'message': 'Template deleted'}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'message': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // GET /letter-templates/placeholders/<type> - Get allowed placeholders based on type
    router.get('/letter-templates/placeholders/<type>', (
      Request request,
      String type,
    ) async {
      List<String> placeholders = [
        '{{company_name}}',
        '{{company_address}}',
        '{{current_date}}',
      ];

      switch (type) {
        case 'payslip':
          placeholders.addAll([
            '{{employee_name}}',
            '{{employee_id}}',
            '{{employee_address}}',
            '{{employee_designation}}',
            '{{employee_role}}',
            '{{employee_doj}}',
            '{{employee_period}}',
            '{{designation}}',
            '{{department}}',
            '{{payslip_month}}',
            '{{basic_salary}}',
            '{{gross_salary}}',
            '{{total_deductions}}',
            '{{net_salary}}',
            '{{earnings_table}}',
            '{{deductions_table}}',
          ]);
          break;
        case 'offer_letter':
          placeholders.addAll([
            '{{employee_name}}',
            '{{employee_id}}',
            '{{employee_address}}',
            '{{employee_designation}}',
            '{{employee_role}}',
            '{{employee_doj}}',
            '{{employee_period}}',
            '{{designation}}',
            '{{department}}',
            '{{date_of_joining}}',
            '{{gross_salary}}',
            '{{basic_salary}}',
            '{{hra}}',
            '{{special_allowance}}',
            '{{medical_allowance}}',
            '{{conveyance_allowance}}',
            '{{annual_ctc}}',
            '{{salary_range_name}}',
            '{{ctc_table}}',
            '{{reporting_manager_name}}',
            '{{reporting_manager_designation}}',
            '{{office_location}}',
            '{{work_location}}',
            '{{work_mode}}',
            '{{employment_type}}',
            '{{working_hours}}',
            '{{has_probation}}',
            '{{probation_period}}',
            '{{probation_type}}',
            '{{notice_period}}',
            '{{notice_period_probation}}',
            '{{leave_entitlement}}',
            '{{work_days}}',
            '{{acceptance_deadline}}',
            '{{hr_manager_name}}',
            '{{hr_manager_designation}}',
            '{{hr_email}}',
            '{{hr_phone}}',
          ]);
          break;
        case 'termination':
        case 'relieving':
          placeholders.addAll([
            '{{employee_name}}',
            '{{employee_id}}',
            '{{employee_address}}',
            '{{employee_designation}}',
            '{{employee_role}}',
            '{{employee_doj}}',
            '{{employee_period}}',
            '{{designation}}',
            '{{department}}',
            '{{date_of_joining}}',
            '{{date_of_relieving}}',
            '{{last_working_date}}',
            '{{gross_salary}}',
            '{{notice_period}}',
            '{{exit_type}}',
            '{{conduct_rating}}',
            '{{clearance_status}}',
            '{{assets_returned}}',
            '{{exit_reason}}',
            '{{termination_reason}}',
            '{{relieving_remarks}}',
          ]);
          break;
        case 'internship_offer':
        case 'internship_certificate':
          placeholders.addAll([
            '{{employee_name}}',
            '{{employee_id}}',
            '{{employee_address}}',
            '{{employee_designation}}',
            '{{employee_role}}',
            '{{employee_doj}}',
            '{{employee_period}}',
            '{{designation}}',
            '{{department}}',
            '{{date_of_joining}}',
            '{{gross_salary}}',
            '{{internship_start_date}}',
            '{{internship_end_date}}',
            '{{internship_duration}}',
            '{{internship_domain}}',
            '{{role}}',
            '{{stipend}}',
            '{{reporting_manager}}',
            '{{office_location}}',
            '{{notice_period}}',
          ]);
          break;
      }

      return Response.ok(
        jsonEncode({'success': true, 'data': placeholders}),
        headers: {'content-type': 'application/json'},
      );
    });

    // GET /letter-templates/export/generate-pdf - Generate PDF letter
    router.get('/letter-templates/export/generate-pdf', _exportPdf);

    // GET /letter-templates/export/generate-payslip - Generate Payslip PDF
    router.get('/letter-templates/export/generate-payslip', _exportPayslip);

    return router;
  }

  /// GET /letter-templates/export/generate-pdf
  /// Generates a PDF letter for an employee based on a template
  Future<Response> _exportPdf(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final templateId = queryParams['template_id'];
      final employeeId = queryParams['employee_id'];

      if (templateId == null || employeeId == null) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'template_id and employee_id are required parameters',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final service = LetterGenerationService();

      // Extract custom data (any parameters that aren't template_id or employee_id)
      final customData = <String, String>{};
      queryParams.forEach((key, value) {
        if (key != 'template_id' && key != 'employee_id') {
          // Normalize key to {{key}} format.
          // Using plain keys (e.g. 'stipend') for blind replacement is dangerous
          // because it replaces 'stipend' inside '{{stipend}}', resulting in '{{8000}}'.
          final normalizedKey = (key.startsWith('{{') && key.endsWith('}}'))
              ? key
              : '{{$key}}';
          customData[normalizedKey] = value;
        }
      });

      // Log for debugging
      print(
        'Generating PDF for template $templateId and employee $employeeId with custom data: $customData',
      );

      final pdfBytes = await service.generatePdf(
        templateId: templateId,
        employeeId: employeeId,
        customData: customData,
      );

      final fileName =
          'Generated_Letter_${DateTime.now().millisecondsSinceEpoch}.pdf';

      return Response.ok(
        pdfBytes,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition': 'attachment; filename="$fileName"',
          'content-length': pdfBytes.length.toString(),
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// GET /letter-templates/export/generate-payslip
  /// Query params:
  ///   - employee_id (required)
  ///   - month (required, 1-12) - the target month
  ///   - year (required) - the target year
  ///   - months_count (optional, default=1) - how many months to generate
  ///     For "Last 2 months" pass months_count=2, etc.
  Future<Response> _exportPayslip(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final employeeId = queryParams['employee_id'];
      final monthStr = queryParams['month'];
      final yearStr = queryParams['year'];
      final monthsCountStr = queryParams['months_count'] ?? '1';

      if (employeeId == null || monthStr == null || yearStr == null) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'employee_id, month, and year are required parameters',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final month = int.tryParse(monthStr);
      final year = int.tryParse(yearStr);
      final monthsCount = int.tryParse(monthsCountStr) ?? 1;

      if (month == null || year == null || month < 1 || month > 12) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'Invalid month or year value',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final service = PayslipGenerationService();
      final monthNames = [
        '',
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

      late final List<int> pdfBytes;
      late final String fileName;

      if (monthsCount <= 1) {
        // Single month payslip
        pdfBytes = await service.generatePayslip(
          employeeId: employeeId,
          month: month,
          year: year,
        );
        fileName = 'Payslip_${employeeId}_${monthNames[month]}_$year.pdf';
      } else {
        // Multi-month: go backwards from the given month/year
        final monthYearList = <Map<String, int>>[];
        int m = month;
        int y = year;
        for (int i = 0; i < monthsCount; i++) {
          monthYearList.add({'month': m, 'year': y});
          m--;
          if (m < 1) {
            m = 12;
            y--;
          }
        }
        // Reverse to show oldest first
        monthYearList.reversed.toList();

        pdfBytes = await service.generateMultiMonthPayslip(
          employeeId: employeeId,
          monthYearList: monthYearList.reversed.toList(),
        );
        fileName = 'Payslip_${employeeId}_Last_${monthsCount}_Months_$year.pdf';
      }

      return Response.ok(
        pdfBytes,
        headers: {
          'content-type': 'application/pdf',
          'content-disposition': 'attachment; filename="$fileName"',
          'content-length': pdfBytes.length.toString(),
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
