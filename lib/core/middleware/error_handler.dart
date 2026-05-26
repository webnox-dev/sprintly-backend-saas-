import 'package:shelf/shelf.dart';
import '../exceptions/app_exception.dart';
import '../response/api_response.dart';
import '../utils/logger.dart';

/// Error handling middleware
Middleware errorHandler() {
  return (Handler handler) {
    return (Request request) async {
      try {
        return await handler(request);
      } on HijackException {
        // Re-throw HijackException so WebSocket connections work properly
        // This exception is used by shelf_web_socket to hijack the connection
        rethrow;
      } on AppException catch (e) {
        final logger = AppLogger('ErrorHandler');
        logger.warning('AppException: ${e.message}');

        int statusCode = 500;
        switch (e.code) {
          case 'NOT_FOUND':
            statusCode = 404;
            break;
          case 'VALIDATION_ERROR':
            statusCode = 400;
            break;
          case 'UNAUTHORIZED':
            statusCode = 401;
            break;
          case 'CONFLICT':
            statusCode = 409;
            break;
          default:
            statusCode = 500;
        }

        return ApiResponse.error(
          code: e.code,
          message: e.message,
          details: e.details,
        ).toShelfResponse(statusCode: statusCode);
      } catch (e, stackTrace) {
        final logger = AppLogger('ErrorHandler');
        logger.error('Unhandled error: $e', e, stackTrace);

        return ApiResponse.error(
          code: 'INTERNAL_ERROR',
          message: 'Internal server error',
        ).toShelfResponse(statusCode: 500);
      }
    };
  };
}
