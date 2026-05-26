import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/employee_performance_service.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class EmployeePerformanceRoutes {
  final EmployeePerformanceService _service = EmployeePerformanceService();
  final AppLogger _logger = AppLogger('EmployeePerformanceRoutes');

  Router get router {
    final router = Router();

    // Get summary of all employees
    router.get('/summary', (Request request) async {
      try {
        final queryParams = request.url.queryParameters;
        final fromDate =
            queryParams['fromDate'] ??
            DateTime.now()
                .subtract(Duration(days: 30))
                .toIso8601String()
                .split('T')[0];
        final toDate =
            queryParams['toDate'] ??
            DateTime.now().toIso8601String().split('T')[0];
        final search = queryParams['search'];
        final minLateDays = int.tryParse(queryParams['minLateDays'] ?? '');
        final minUnderworkedDays = int.tryParse(queryParams['minUnderworkedDays'] ?? '');
        final minOvertimeDays = int.tryParse(queryParams['minOvertimeDays'] ?? '');

        final data = await _service.getAllEmployeesSummary(
          fromDate: fromDate,
          toDate: toDate,
          search: search,
          minLateDays: minLateDays,
          minUnderworkedDays: minUnderworkedDays,
          minOvertimeDays: minOvertimeDays,
        );

        return ApiResponse.success(data: data).toShelfResponse();
      } catch (e, stackTrace) {
        _logger.error('Error in GET /performance/summary: $e', e, stackTrace);
        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: e.toString(),
        ).toShelfResponse(statusCode: 500);
      }
    });

    // Get detailed report for a specific employee
    router.get('/report/<employeeId>', (
      Request request,
      String employeeId,
    ) async {
      try {
        final queryParams = request.url.queryParameters;
        final fromDate =
            queryParams['fromDate'] ??
            DateTime.now()
                .subtract(Duration(days: 30))
                .toIso8601String()
                .split('T')[0];
        final toDate =
            queryParams['toDate'] ??
            DateTime.now().toIso8601String().split('T')[0];

        final report = await _service.getEmployeePerformanceReport(
          employeeId: employeeId,
          fromDate: fromDate,
          toDate: toDate,
        );

        return ApiResponse.success(data: report.toJson()).toShelfResponse();
      } catch (e, stackTrace) {
        _logger.error(
          'Error in GET /performance/report/$employeeId: $e',
          e,
          stackTrace,
        );
        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: e.toString(),
        ).toShelfResponse(statusCode: 500);
      }
    });

    // Export consolidated performance report for all employees to Excel
    router.get('/export/consolidated', (Request request) async {
      try {
        final queryParams = request.url.queryParameters;
        final fromDate =
            queryParams['fromDate'] ??
            DateTime.now()
                .subtract(Duration(days: 30))
                .toIso8601String()
                .split('T')[0];
        final toDate =
            queryParams['toDate'] ??
            DateTime.now().toIso8601String().split('T')[0];

        final result = await _service.getConsolidatedExcelExport(
          fromDate: fromDate,
          toDate: toDate,
        );

        final excelBytes = result['fileBytes'] as List<int>?;
        final fileName = result['fileName'] as String;

        if (excelBytes == null) {
          return ApiResponse.error(
            code: 'INTERNAL_ERROR',
            message: 'Failed to generate excel file',
          ).toShelfResponse(statusCode: 500);
        }

        return Response.ok(
          excelBytes,
          headers: {
            'Content-Type':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition': 'attachment; filename="$fileName"',
          },
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error in GET /performance/export/all: $e',
          e,
          stackTrace,
        );
        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: e.toString(),
        ).toShelfResponse(statusCode: 500);
      }
    });

    // Export detailed performance report for all employees to Excel
    router.get('/export/consolidated-detailed', (Request request) async {
      try {
        final queryParams = request.url.queryParameters;
        final fromDate =
            queryParams['fromDate'] ??
            DateTime.now()
                .subtract(Duration(days: 30))
                .toIso8601String()
                .split('T')[0];
        final toDate =
            queryParams['toDate'] ??
            DateTime.now().toIso8601String().split('T')[0];

        final result = await _service.getAllEmployeeDetailedExcelExport(
          fromDate: fromDate,
          toDate: toDate,
        );

        final excelBytes = result['fileBytes'] as List<int>?;
        final fileName = result['fileName'] as String;

        if (excelBytes == null) {
          return ApiResponse.error(
            code: 'INTERNAL_ERROR',
            message: 'Failed to generate excel file',
          ).toShelfResponse(statusCode: 500);
        }

        return Response.ok(
          excelBytes,
          headers: {
            'Content-Type':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition': 'attachment; filename="$fileName"',
          },
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error in GET /performance/export/consolidated-detailed: $e',
          e,
          stackTrace,
        );
        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: e.toString(),
        ).toShelfResponse(statusCode: 500);
      }
    });

    // Export employee performance to Excel (single employee)
    router.get('/export/<employeeId>', (
      Request request,
      String employeeId,
    ) async {
      try {
        final queryParams = request.url.queryParameters;
        final fromDate =
            queryParams['fromDate'] ??
            DateTime.now()
                .subtract(Duration(days: 30))
                .toIso8601String()
                .split('T')[0];
        final toDate =
            queryParams['toDate'] ??
            DateTime.now().toIso8601String().split('T')[0];

        final result = await _service.getEmployeeMonthlyExcelReport(
          employeeId: employeeId,
          fromDate: fromDate,
          toDate: toDate,
        );

        final excelBytes = result['fileBytes'] as List<int>?;
        final fileName = result['fileName'] as String;

        if (excelBytes == null) {
          return ApiResponse.error(
            code: 'INTERNAL_ERROR',
            message: 'Failed to generate excel file',
          ).toShelfResponse(statusCode: 500);
        }

        return Response.ok(
          excelBytes,
          headers: {
            'Content-Type':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition': 'attachment; filename="$fileName"',
          },
        );
      } catch (e, stackTrace) {
        _logger.error(
          'Error in GET /performance/export/$employeeId: $e',
          e,
          stackTrace,
        );
        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: e.toString(),
        ).toShelfResponse(statusCode: 500);
      }
    });

    return router;
  }
}
