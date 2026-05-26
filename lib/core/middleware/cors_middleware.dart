import 'package:shelf/shelf.dart';

/// CORS middleware
Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      return response.change(
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods':
              'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        },
      );
    };
  };
}

/// Handle OPTIONS requests for CORS
Handler corsHandler(Handler innerHandler) {
  return (Request request) {
    if (request.method == 'OPTIONS') {
      return Response.ok(
        '',
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods':
              'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    }
    return innerHandler(request);
  };
}
