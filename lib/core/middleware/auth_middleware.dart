import 'package:shelf/shelf.dart';
import '../../services/auth_service.dart';
import '../../core/response/api_response.dart';

/// Authentication middleware
/// Verifies JWT token and adds user info to request context
Middleware authMiddleware() {
  final authService = AuthService();

  return (Handler handler) {
    return (Request request) async {
      // Skip auth for public endpoints
      final path = request.url.path;
      if (isPublicEndpoint(path)) {
        return handler(request);
      }

      // Get token from Authorization header or Query Parameter (for downloads)
      String? token;
      final authHeader = request.headers['authorization'];

      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7); // Remove 'Bearer ' prefix
      } else if (request.url.queryParameters.containsKey('token')) {
        token = request.url.queryParameters['token'];
      }

      if (token == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required. Please provide a valid token.',
        ).toShelfResponse(statusCode: 401);
      }

      try {
        // Verify token
        final user = await authService.verifyToken(token);
        if (user == null) {
          return ApiResponse.error(
            code: 'UNAUTHORIZED',
            message: 'Invalid or expired token',
          ).toShelfResponse(statusCode: 401);
        }

        // Add user info to request context
        final updatedRequest = request.change(
          context: {
            ...request.context,
            'user': user,
            'employeeId': user.employeeId,
            'email': user.email,
            'role': user.role,
            'organizationId': user.organizationId,
          },
        );

        // Debug log
        print(
          '[AuthMiddleware] User verified: ${user.employeeId}, Role: ${user.role}',
        );

        return handler(updatedRequest);
      } catch (e) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid token',
        ).toShelfResponse(statusCode: 401);
      }
    };
  };
}

/// Check if endpoint is public (doesn't require authentication)
bool isPublicEndpoint(String path) {
  // Handle root path (empty string or /)
  if (path.isEmpty || path == '/') {
    return true;
  }

  // Handle health endpoint
  if (path == 'health' || path == '/health') {
    return true;
  }

  final publicPaths = [
    'api/auth/login',
    'api/auth/employee-login',
    'api/auth/verify-otp',
    'api/auth/resend-otp',
    'api/auth/forgot-password',
    'api/auth/reset-password',
    'api/auth/change-password',
    '/api/auth/login',
    '/api/auth/employee-login',
    '/api/auth/verify-otp',
    '/api/auth/resend-otp',
    '/api/auth/forgot-password',
    '/api/auth/reset-password',
    '/api/auth/change-password',
    'api/auth/verify-email/employee',
    '/api/auth/verify-email/employee',
    'api/auth/verify-email/admin',
    '/api/auth/verify-email/admin',
    'api/auth/resend-verification-otp',
    '/api/auth/resend-verification-otp',
    'api/auth/discover-workspaces',
    '/api/auth/discover-workspaces',
    'api/auth/sessions/revoke-with-credentials',
    '/api/auth/sessions/revoke-with-credentials',
    // WebSocket endpoint - authentication is handled via subprotocol
    'api/chat/ws',
    '/api/chat/ws',
    // Time tracking endpoints - employee_id is passed as parameter
    'api/time-tracking/daily',
    '/api/time-tracking/daily',
    'api/time-tracking/active',
    '/api/time-tracking/active',
    // Face recognition endpoints - for biometric kiosk device
    'api/face/',
    '/api/face/',
    // Report endpoints - allow employee_id based access (temporarily public for debug)
    'api/reports/',
    '/api/reports/',
    // V2 Employee endpoints (Secret Key protected)
    'api/v2/employees/list',
    '/api/v2/employees/list',
    'api/v2/employees/get-details',
    '/api/v2/employees/get-details',
    'api/organizations/register',
    '/api/organizations/register',
    'super/auth/login',
    '/super/auth/login',
  ];

  // Debug log for path checking
  // print('DEBUG: Checking permissions for path: "$path"');

  // Specific check for Swagger UI at /api to avoid wildcard matching all /api routes
  if (path == 'api' ||
      path == '/api' ||
      path == 'api/' ||
      path == '/api/' ||
      path == 'api/index.html' ||
      path == '/api/index.html' ||
      path == 'api/swagger.yaml' ||
      path == '/api/swagger.yaml' ||
      // Also keep the /spi route just in case
      path == '/spi' ||
      path.startsWith('spi/')) {
    return true;
  }

  // Skip authentication for all /super routes as they have their own independent 
  // auth logic and different JWT secret.
  if (path == 'super' ||
      path == '/super' ||
      path.startsWith('super/') ||
      path.startsWith('/super/')) {
    return true;
  }

  return publicPaths.any(
    (publicPath) => path == publicPath || path.startsWith(publicPath),
  );
}
