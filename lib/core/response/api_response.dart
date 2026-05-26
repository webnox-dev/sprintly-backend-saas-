import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Standard API response format
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final Map<String, dynamic>? error;
  final Map<String, dynamic>? pagination;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.pagination,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'success': success,
    };

    if (data != null) {
      json['data'] = data;
    }

    if (message != null) {
      json['message'] = message;
    }

    if (error != null) {
      json['error'] = error;
    }

    if (pagination != null) {
      json['pagination'] = pagination;
    }

    return json;
  }

  Response toShelfResponse({int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(toJson(), toEncodable: (item) {
        if (item is DateTime) return item.toIso8601String();
        return item;
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }

  /// Success response
  factory ApiResponse.success({
    dynamic data,
    String? message,
    Map<String, dynamic>? pagination,
  }) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
      pagination: pagination,
    );
  }

  /// Error response
  factory ApiResponse.error({
    required String code,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return ApiResponse(
      success: false,
      error: {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
    );
  }

  /// Validation error response
  factory ApiResponse.validationError(Map<String, List<String>> errors) {
    return ApiResponse(
      success: false,
      error: {
        'code': 'VALIDATION_ERROR',
        'message': 'Validation failed',
        'details': errors,
      },
    );
  }
}

