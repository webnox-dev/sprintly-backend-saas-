/// Base application exception
class AppException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  AppException({required this.code, required this.message, this.details});

  @override
  String toString() => 'AppException($code): $message';
}

/// Not found exception
class NotFoundException extends AppException {
  NotFoundException({required String resource, String? id})
    : super(
        code: 'NOT_FOUND',
        message: '$resource${id != null ? ' with id $id' : ''} not found',
      );
}

/// Validation exception
class ValidationException extends AppException {
  final Map<String, List<String>> errors;

  ValidationException(this.errors)
    : super(
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: {'errors': errors},
      );
}

/// Unauthorized exception
class UnauthorizedException extends AppException {
  UnauthorizedException({String? message, super.details})
    : super(
        code: 'UNAUTHORIZED',
        message: message ?? 'Unauthorized access',
      );
}

/// Conflict exception (duplicate data)
class ConflictException extends AppException {
  ConflictException({required String resource, String? field})
    : super(
        code: 'CONFLICT',
        message:
            '$resource already exists${field != null ? ' with this $field' : ''}',
      );
}

/// Forbidden exception (access denied)
class ForbiddenException extends AppException {
  ForbiddenException({String? message, super.details})
    : super(
        code: 'FORBIDDEN',
        message: message ?? 'Access denied',
      );
}

/// Database exception
class DatabaseException extends AppException {
  DatabaseException({required super.message, super.details})
    : super(code: 'DATABASE_ERROR');
}
