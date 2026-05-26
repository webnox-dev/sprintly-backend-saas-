import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/leave_policy_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class LeavePolicyRoutes {
  final LeavePolicyService _service = LeavePolicyService();
  final AppLogger _logger = AppLogger('LeavePolicyRoutes');

  Router get router {
    final router = Router();

    // GET /api/leave-policy - Get organization policy
    router.get('/leave-policy', _getPolicy);

    // GET /api/leave-policy/status/<employeeId> - Get employee allowance status
    router.get('/leave-policy/status/<employeeId>', _getAllowanceStatus);

    return router;
  }

  Future<Response> _getPolicy(Request request) async {
    try {
      final policy = await _service.getPolicy();
      return ApiResponse.success(data: policy.toJson()).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getPolicy', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getAllowanceStatus(
    Request request,
    String employeeId,
  ) async {
    try {
      if (employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employeeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      final status = await _service.getLeaveAllowanceStatus(employeeId);
      return ApiResponse.success(data: status).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in _getAllowanceStatus', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
