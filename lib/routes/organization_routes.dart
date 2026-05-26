import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// Routes for organization management
class OrganizationRoutes {
  final AuthService service = AuthService();
  final AppLogger logger = AppLogger('OrganizationRoutes');

  Router get router {
    final router = Router();

    // POST /api/organizations/register
    router.post('/register', handleRegisterOrganization);

    return router;
  }

  /// POST /api/organizations/register
  /// Public registration of a new organization
  Future<Response> handleRegisterOrganization(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final organizationName = data['organization_name']?.toString();
      final adminName = data['admin_name']?.toString();
      final adminEmail = data['admin_email']?.toString();
      final adminPhone = data['admin_phone']?.toString();
      final password = data['password']?.toString();

      if (organizationName == null || organizationName.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Organization name is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (adminName == null || adminName.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Admin name is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (adminEmail == null || adminEmail.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Admin email is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (password == null || password.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Password is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await service.registerOrganization(
        organizationName: organizationName,
        adminName: adminName,
        adminEmail: adminEmail,
        adminPhone: adminPhone ?? '',
        password: password,
        industry: data['industry']?.toString(),
        country: data['country']?.toString(),
      );

      return ApiResponse.success(
        message: 'Organization registered successfully',
        data: result['data'],
      ).toShelfResponse(statusCode: 201);
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      logger.error('Error in handleRegisterOrganization: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
