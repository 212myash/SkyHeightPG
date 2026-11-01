import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import 'api_exceptions.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;

  AuthInterceptor(this._storageService);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';

    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiException apiException;

    final response = err.response;
    final statusCode = response?.statusCode;
    final data = response?.data;

    String errorMessage = 'An unexpected error occurred.';
    if (data is Map<String, dynamic> && data['message'] != null) {
      errorMessage = data['message'].toString();
    } else if (err.message != null && err.message!.isNotEmpty) {
      errorMessage = err.message!;
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        apiException = TimeoutException(
          message: 'Connection timed out. Please check your network.',
        );
        break;
      case DioExceptionType.connectionError:
        apiException = NetworkException(
          message: 'Could not connect to Sky Height PG server. Ensure the backend is running.',
        );
        break;
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          apiException = UnauthorizedException(message: errorMessage, data: data);
        } else if (statusCode == 403) {
          apiException = ForbiddenException(message: errorMessage, data: data);
        } else if (statusCode == 404) {
          apiException = NotFoundException(message: errorMessage, data: data);
        } else if (statusCode == 400) {
          apiException = ValidationException(message: errorMessage, data: data);
        } else {
          apiException = ApiException(
            message: errorMessage,
            statusCode: statusCode,
            data: data,
          );
        }
        break;
      default:
        apiException = ApiException(
          message: errorMessage,
          statusCode: statusCode,
          data: data,
        );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
        message: apiException.message,
      ),
    );
  }
}
