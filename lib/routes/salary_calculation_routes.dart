import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../core/exceptions/app_exception.dart';
import '../services/salary_calculation_service.dart';
import '../data/repositories/salary_calculation_repository.dart';
import '../core/utils/logger.dart';

class SalaryCalculationRoutes {
  final Router _router = Router();
  late final SalaryCalculationService _service;
  final AppLogger _logger = AppLogger('SalaryCalculationRoutes');

  SalaryCalculationRoutes() {
    _service = SalaryCalculationService(SalaryCalculationRepository());
  }

  Router get router {
    _router.get('/salary-ranges', _getAllRanges);
    _router.get('/salary-ranges/<id>', _getRangeById);
    _router.post('/salary-ranges', _createRange);
    _router.put('/salary-ranges/<id>', _updateRange);
    _router.delete('/salary-ranges/<id>', _deleteRange);

    return _router;
  }

  Future<Response> _getAllRanges(Request request) async {
    try {
      final ranges = await _service.getAllSalaryRanges();
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Salary ranges fetched successfully',
          'data': ranges.map((r) => r.toMap()).toList(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Error fetching ranges: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getRangeById(Request request, String id) async {
    try {
      final range = await _service.getSalaryRangeById(id);
      if (range == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Salary range not found'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Salary range fetched successfully',
          'data': range.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Error fetching range: $e');
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _createRange(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final createdRange = await _service.createSalaryRange(data);
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Salary range created successfully',
          'data': createdRange.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Error creating range: $e');
      final msg = e is AppException ? e.message : e.toString();
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': msg}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _updateRange(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      final updatedRange = await _service.updateSalaryRange(id, data);
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Salary range updated successfully',
          'data': updatedRange.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Error updating range: $e');
      final msg = e is AppException ? e.message : e.toString();
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': msg}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteRange(Request request, String id) async {
    try {
      await _service.deleteSalaryRange(id);
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Salary range deleted successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _logger.error('Error deleting range: $e');
      final msg = e is AppException ? e.message : e.toString();
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': msg}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
