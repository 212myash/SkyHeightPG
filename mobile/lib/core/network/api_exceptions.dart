/// Typed API Exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Session expired or invalid credentials.', super.data})
      : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException({super.message = 'Access denied. Insufficient permissions.', super.data})
      : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException({super.message = 'Requested resource not found.', super.data})
      : super(statusCode: 404);
}

class NetworkException extends ApiException {
  NetworkException({super.message = 'No internet connection or server unreachable.'})
      : super(statusCode: null);
}

class TimeoutException extends ApiException {
  TimeoutException({super.message = 'Connection timed out. Please check your network and try again.'})
      : super(statusCode: null);
}

class ValidationException extends ApiException {
  ValidationException({required super.message, super.data})
      : super(statusCode: 400);
}
