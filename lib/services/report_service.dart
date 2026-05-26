import '../data/repositories/report_repository.dart';
import '../data/models/daily_report_model.dart';
import '../core/utils/logger.dart';

class ReportService {
  final ReportRepository _repository = ReportRepository();
  final AppLogger _logger = AppLogger('ReportService');

  /// Submit a daily report
  Future<void> submitReport(Map<String, dynamic> data) async {
    try {
      final report = DailyReport.fromJson(data);

      // Check if report already exists for today to prevent duplicates (optional logic)
      final exists = await _repository.checkReportExists(
        report.employeeId,
        report.reportDate,
      );
      if (exists) {
        _logger.warning(
          'Report already exists for employee ${report.employeeId} on ${report.reportDate}. Proceeding to create (might fail if ID conflict).',
        );
      }

      await _repository.createReport(report);
    } catch (e, stackTrace) {
      _logger.error('Error in service submitting report: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a report exists
  Future<bool> checkReportExists(String employeeId, String date) async {
    try {
      return await _repository.checkReportExists(employeeId, date);
    } catch (e, stackTrace) {
      _logger.error('Error checking report existence: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get report history
  Future<List<Map<String, dynamic>>> getReportHistory(
    String employeeId, {
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _repository.getReportHistory(
        employeeId,
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting report history: $e', e, stackTrace);
      rethrow;
    }
  }
}
