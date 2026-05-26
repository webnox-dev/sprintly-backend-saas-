import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../data/repositories/salary_calculation_repository.dart';
import '../domain/models/salary_range.dart';

class SalaryCalculationService {
  final SalaryCalculationRepository _repository;
  final AppLogger _logger = AppLogger('SalaryCalculationService');

  SalaryCalculationService(this._repository);

  Future<List<SalaryRange>> getAllSalaryRanges() async {
    return await _repository.getAllRanges();
  }

  Future<SalaryRange?> getSalaryRangeById(String id) async {
    return await _repository.getRangeById(id);
  }

  Future<SalaryRange> createSalaryRange(Map<String, dynamic> data) async {
    _validateRangeData(data);
    _logger.info('Creating new salary range: ${data['range_name']}');

    final result = await _repository.createRange(data);
    final rangeId = result['id'].toString();

    // Now save components
    final components = _prepareComponents(
      data,
      rangeId,
      double.parse(data['salary_start'].toString()),
    );
    await _repository.saveComponents(rangeId, components);

    final newRange = await _repository.getRangeById(rangeId);
    if (newRange == null) {
      throw AppException(
        code: 'CREATE_ERROR',
        message: 'Range created but not found',
      );
    }
    return newRange;
  }

  Future<SalaryRange> updateSalaryRange(
    String id,
    Map<String, dynamic> data,
  ) async {
    _validateRangeData(data);

    await _repository.updateRange(id, data);

    final components = _prepareComponents(
      data,
      id,
      double.parse(data['salary_start'].toString()),
    );
    await _repository.saveComponents(id, components);

    final updatedRange = await _repository.getRangeById(id);
    if (updatedRange == null) {
      throw AppException(
        code: 'UPDATE_ERROR',
        message: 'Failed to retrieve updated range',
      );
    }
    return updatedRange;
  }

  Future<void> deleteSalaryRange(String id) async {
    await _repository.deleteRange(id);
  }

  void _validateRangeData(Map<String, dynamic> data) {
    if (data['salary_start'] == null || data['salary_end'] == null) {
      throw ValidationException({
        'salary': ['Salary start and end are required'],
      });
    }

    final start = double.tryParse(data['salary_start'].toString()) ?? 0;
    final end = double.tryParse(data['salary_end'].toString()) ?? 0;

    if (start <= 0) {
      throw ValidationException({
        'salary_start': ['Salary start must be greater than 0'],
      });
    }
    if (end < start) {
      throw ValidationException({
        'salary_end': ['Salary end must be greater than or equal to start'],
      });
    }
  }

  List<dynamic> _prepareComponents(
    Map<String, dynamic> data,
    String rangeId,
    double salaryStart,
  ) {
    final List<dynamic> allComponents = [];

    // Earnings
    if (data['earnings'] != null && data['earnings'] is List) {
      final earnings = data['earnings'] as List;
      for (int i = 0; i < earnings.length; i++) {
        final c = earnings[i];
        final percentage =
            double.tryParse(c['percentage']?.toString() ?? '0') ?? 0;
        allComponents.add({
          'component_type': 'earning',
          'component_name': c['component_name'] ?? 'Earning ${i + 1}',
          'percentage': percentage,
          'calculated_amount': (salaryStart * percentage) / 100,
          'sort_order': c['sort_order'] ?? i,
        });
      }
    }

    // Deductions
    if (data['deductions'] != null && data['deductions'] is List) {
      final deductions = data['deductions'] as List;
      for (int i = 0; i < deductions.length; i++) {
        final c = deductions[i];
        final percentage =
            double.tryParse(c['percentage']?.toString() ?? '0') ?? 0;
        allComponents.add({
          'component_type': 'deduction',
          'component_name': c['component_name'] ?? 'Deduction ${i + 1}',
          'percentage': percentage,
          'calculated_amount': (salaryStart * percentage) / 100,
          'sort_order': c['sort_order'] ?? i,
        });
      }
    }

    return allComponents;
  }
}
