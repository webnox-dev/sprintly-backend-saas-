import '../data/repositories/admin_report_repository.dart';
import '../core/utils/logger.dart';

/// Service for admin-side employee reports management
class AdminReportService {
  final AdminReportRepository _repository = AdminReportRepository();
  final AppLogger _logger = AppLogger('AdminReportService');

  /// Get all employee reports with filters
  Future<Map<String, dynamic>> getAllEmployeeReports({
    String? search,
    String? employeeId,
    String? employeeName,
    String? designation,
    String? date,
    String? fromDate,
    String? toDate,
    String? status,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      return await _repository.getAllEmployeeReports(
        search: search,
        employeeId: employeeId,
        employeeName: employeeName,
        designation: designation,
        date: date,
        fromDate: fromDate,
        toDate: toDate,
        status: status,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all employee reports: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees who reported/not reported on a specific date
  Future<Map<String, dynamic>> getEmployeeReportStatus({
    required String date,
    String? search,
    String? designation,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      return await _repository.getEmployeeReportStatus(
        date: date,
        search: search,
        designation: designation,
        status: status,
        page: page,
        limit: limit,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting employee report status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Debug method to get raw employee_reports data
  Future<Map<String, dynamic>> getDebugReportsData() async {
    try {
      return await _repository.getDebugReportsData();
    } catch (e, stackTrace) {
      _logger.error('Error in debug: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get detailed report for a specific employee and date
  Future<Map<String, dynamic>?> getReportDetailsById({
    required String employeeId,
    required String reportId,
    required String date,
  }) async {
    try {
      return await _repository.getReportDetailsById(
        employeeId: employeeId,
        reportId: reportId,
        date: date,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting report details: $e', e, stackTrace);
      rethrow;
    }
  }
}
