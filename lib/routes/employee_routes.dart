import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/employee_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../config/app_config.dart';


/// Employee routes handler
class EmployeeRoutes {
  final EmployeeService _service = EmployeeService();
  final AppLogger _logger = AppLogger('EmployeeRoutes');

  Router get router {
    final router = Router();

    // Renamed and moved to v2 with secret key protection (JWT disabled)
    router.get('/v2/employees/list', _getAllEmployeesV2);
    router.post('/v2/employees/get-details', _getEmployeeDetailsByIdV2);

    // Old endpoints closed as requested (re-enabling GET /employees for backward compatibility with admin dashboard)
    router.get('/employees', _getAllEmployees);
    // router.post('/employees/getEmployeeDetailsById', _getEmployeeDetailsById);

    // GET /api/employees/:id - Get employee by ID (Still JWT protected)
    router.get('/employees/<id>', _getEmployeeById);

    // POST /api/employees - Create employee
    router.post('/employees', _createEmployee);

    // PUT /api/employees/:id - Update employee
    router.put('/employees/<id>', _updateEmployee);

    // DELETE /api/employees/:id - Delete employee
    router.delete('/employees/<id>', _deleteEmployee);

    // PUT /api/employees/:id/status - Update employee status
    router.put('/employees/<id>/status', _updateStatus);

    // POST /api/employees/:id/exit - Exit employee
    router.post('/employees/<id>/exit', _exitEmployee);

    // POST /api/employees/:id/reenter - Re-enter employee
    router.post('/employees/<id>/reenter', _reenterEmployee);

    // GET /api/employees/qc - Get QA Analyst employees
    router.get('/employees/qc', _getQCEmployees);

    // GET /api/employees/birthdays - Get employees with birthdays
    router.get('/employees/birthdays', _getBirthdays);

    // GET /api/employees/anniversaries - Get employees with anniversaries
    router.get('/employees/anniversaries', _getAnniversaries);

    // GET /api/employees/overview - Get employee overview
    router.get('/employees/overview', _getOverview);

    // GET /api/employees/present - Get present employees
    router.get('/employees/present', _getPresentEmployees);

    // GET /api/employees/wfh - Get WFH employees
    router.get('/employees/wfh', _getWFHEmployees);

    // GET /api/employees/permission - Get employees on permission
    router.get('/employees/permission', _getPermissionEmployees);

    // GET /api/employees/late - Get late employees
    router.get('/employees/late', _getLateEmployees);

    // POST /api/employees/export - Export employees to Excel
    router.post('/employees/export', _exportEmployees);

    // POST /api/employees/:id/resend-credentials - Resend credentials
    router.post('/employees/<id>/resend-credentials', _resendCredentials);

    return router;
  }

  /// GET /api/employees
  Future<Response> _getAllEmployees(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final status = params['status'] != null
          ? params['status'] == 'true'
          : null;
      final role = params['role'];
      final designation = params['designation'];
      final search = params['search'];
      final sortBy = params['sortBy'];
      final ascending = params['order'] != 'desc';

      final result = await _service.getAllEmployees(
        page: page,
        limit: limit,
        status: status,
        role: role,
        designation: designation,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
      );

      return ApiResponse.success(
        data: (result['data'] as List).map((e) => e.toJson()).toList(),
        pagination: {
          'page': result['page'],
          'limit': result['limit'],
          'total': result['total'],
          'totalPages': result['totalPages'],
          'hasNext': result['page'] < result['totalPages'],
          'hasPrev': result['page'] > 1,
        },
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _getAllEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/:id
  Future<Response> _getEmployeeById(Request request, String id) async {
    try {
      final employee = await _service.getEmployeeById(id);
      return ApiResponse.success(data: employee.toJson()).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _getEmployeeById: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees/getEmployeeDetailsById
  Future<Response> _getEmployeeDetailsById(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employeeId']?.toString();

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Employee ID is required in the payload',
        ).toShelfResponse(statusCode: 400);
      }

      final employee = await _service.getEmployeeById(employeeId);
      return ApiResponse.success(data: employee.toJson(), message: 'Employee details fetched successfully').toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } catch (e, stackTrace) {
      _logger.error('Error in _getEmployeeDetailsById: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees
  Future<Response> _createEmployee(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // For now, we'll skip image upload (can be added later with multipart)
      final employee = await _service.createEmployee(data);

      return ApiResponse.success(
        data: employee.toJson(),
        message: 'Employee created successfully',
      ).toShelfResponse(statusCode: 201);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on ConflictException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 409);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _createEmployee: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/employees/:id
  Future<Response> _updateEmployee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employee = await _service.updateEmployee(id, data);

      return ApiResponse.success(
        data: employee.toJson(),
        message: 'Employee updated successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on ValidationException catch (e) {
      return ApiResponse.validationError(
        e.errors,
      ).toShelfResponse(statusCode: 400);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _updateEmployee: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/employees/:id
  Future<Response> _deleteEmployee(Request request, String id) async {
    try {
      await _service.deleteEmployee(id);
      return ApiResponse.success(
        message: 'Employee deleted successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _deleteEmployee: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/employees/:id/status
  Future<Response> _updateStatus(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final status = data['status'] as bool?;
      final changedBy = data['changedBy']?.toString() ?? 'system';

      if (status == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Status is required',
        ).toShelfResponse(statusCode: 400);
      }

      final employee = await _service.updateStatus(id, status, changedBy);

      return ApiResponse.success(
        data: employee.toJson(),
        message: 'Employee status updated successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _updateStatus: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees/:id/exit
  Future<Response> _exitEmployee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final doe = data['doe']?.toString();
      final exitReason = data['exitReason']?.toString() ?? '';
      final exitedBy = data['exitedBy']?.toString() ?? 'system';

      if (doe == null || doe.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Date of exit (doe) is required',
        ).toShelfResponse(statusCode: 400);
      }

      final employee = await _service.exitEmployee(
        id,
        doe,
        exitReason,
        exitedBy,
      );

      return ApiResponse.success(
        data: employee.toJson(),
        message: 'Employee exited successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _exitEmployee: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees/:id/reenter
  Future<Response> _reenterEmployee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final changedBy = data['changedBy']?.toString() ?? 'system';

      final employee = await _service.reenterEmployee(id, changedBy);

      return ApiResponse.success(
        data: employee.toJson(),
        message: 'Employee re-entered successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _reenterEmployee: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/qc
  Future<Response> _getQCEmployees(Request request) async {
    try {
      final employees = await _service.getQCEmployees();
      return ApiResponse.success(
        data: employees.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getQCEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/birthdays
  Future<Response> _getBirthdays(Request request) async {
    try {
      final params = request.url.queryParameters;
      final month = int.tryParse(params['month'] ?? '');

      final employees = await _service.getBirthdaysInMonth(month);
      return ApiResponse.success(
        data: employees.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getBirthdays: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/anniversaries
  Future<Response> _getAnniversaries(Request request) async {
    try {
      final employees = await _service.getAnniversariesToday();
      return ApiResponse.success(
        data: employees.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getAnniversaries: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/overview
  Future<Response> _getOverview(Request request) async {
    try {
      final overview = await _service.getOverviewToday();
      return ApiResponse.success(data: overview).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getOverview: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/present
  Future<Response> _getPresentEmployees(Request request) async {
    try {
      final params = request.url.queryParameters;
      final date = params['date'];

      final employees = await _service.getPresentEmployees(date);
      return ApiResponse.success(data: employees).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getPresentEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/wfh
  Future<Response> _getWFHEmployees(Request request) async {
    try {
      final params = request.url.queryParameters;
      final date = params['date'];

      final employees = await _service.getWFHEmployees(date);
      return ApiResponse.success(data: employees).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getWFHEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/permission
  Future<Response> _getPermissionEmployees(Request request) async {
    try {
      final params = request.url.queryParameters;
      final date = params['date'];

      final employees = await _service.getPermissionEmployees(date);
      return ApiResponse.success(data: employees).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getPermissionEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/employees/late
  Future<Response> _getLateEmployees(Request request) async {
    try {
      final params = request.url.queryParameters;
      final date = params['date'];

      final employees = await _service.getLateEmployees(date);
      return ApiResponse.success(data: employees).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getLateEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees/export
  Future<Response> _exportEmployees(Request request) async {
    try {
      // TODO: Implement Excel export functionality
      // For now, return a placeholder response
      return ApiResponse.error(
        code: 'NOT_IMPLEMENTED',
        message: 'Export functionality not yet implemented',
      ).toShelfResponse(statusCode: 501);
    } catch (e, stackTrace) {
      _logger.error('Error in _exportEmployees: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/employees/:id/resend-credentials
  Future<Response> _resendCredentials(Request request, String id) async {
    try {
      await _service.resendCredentials(id);
      return ApiResponse.success(
        message: 'Credentials resent successfully',
      ).toShelfResponse();
    } on NotFoundException {
      return ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Employee not found',
      ).toShelfResponse(statusCode: 404);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: _getStatusCode(e));
    } catch (e, stackTrace) {
      _logger.error('Error in _resendCredentials: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }



  // ---------------------------------------------------------------------------
  // V2 HANDLERS (SECRET KEY PROTECTED)
  // ---------------------------------------------------------------------------

  /// Wrapper for getAllEmployees with secret key check
  Future<Response> _getAllEmployeesV2(Request request) async {
    if (!_checkSecretKey(request)) return _secretKeyUnauthorized();
    return _getAllEmployees(request);
  }

  /// Wrapper for getEmployeeDetailsById with secret key check
  Future<Response> _getEmployeeDetailsByIdV2(Request request) async {
    if (!_checkSecretKey(request)) return _secretKeyUnauthorized();
    return _getEmployeeDetailsById(request);
  }

  /// Check if the request has the correct hardcoded secret key
  bool _checkSecretKey(Request request) {
    final headers = request.headers;
    final apiKey = headers['x-api-key'] ?? headers['X-API-KEY'] ?? headers['X-Api-Key'];
    
    final expectedKey = AppConfig.internalSecretKey;
    
    // Log for debugging if needed (remove in production)
    _logger.info('API Key Check: Received: "${apiKey ?? "NULL"}", Expected: "$expectedKey"');
    
    if (apiKey == null) return false;
    
    // Use trim() to avoid issues with trailing spaces in headers
    return apiKey.trim() == expectedKey.trim();
  }

  /// Return unauthorized response for secret key failure
  Response _secretKeyUnauthorized() {
    return ApiResponse.error(
      code: 'UNAUTHORIZED',
      message: 'Invalid or missing API key (x-api-key)',
    ).toShelfResponse(statusCode: 401);
  }

  /// Get HTTP status code from exception
  int _getStatusCode(AppException e) {
    switch (e.code) {
      case 'NOT_FOUND':
        return 404;
      case 'VALIDATION_ERROR':
        return 400;
      case 'UNAUTHORIZED':
        return 401;
      case 'CONFLICT':
        return 409;
      case 'DATABASE_ERROR':
        return 500;
      default:
        return 500;
    }
  }
}
