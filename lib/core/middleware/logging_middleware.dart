import 'package:shelf/shelf.dart';
import '../utils/logger.dart';

/// Logging middleware
Middleware loggingMiddleware() {
  final logger = AppLogger('HTTP');

  return (Handler handler) {
    return (Request request) async {
      final startTime = DateTime.now();
      
      logger.info('${request.method} ${request.url.path}');

      final response = await handler(request);

      final duration = DateTime.now().difference(startTime);
      logger.info(
        '${request.method} ${request.url.path} - ${response.statusCode} (${duration.inMilliseconds}ms)',
      );

      return response;
    };
  };
}

