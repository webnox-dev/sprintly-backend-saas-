import 'dart:convert';
import 'package:shelf/shelf.dart';

class ResponseHelper {
  static Response ok(dynamic body) {
    return Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response internalServerError(String message) {
    return Response.internalServerError(
      body: jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response badRequest(String message) {
    return Response.badRequest(
      body: jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
  }

  static Response notFound(String message) {
    return Response.notFound(
      jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
  }
}
