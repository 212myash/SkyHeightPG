import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import '../../app/config/app_config.dart';
import 'api_exceptions.dart';
import 'api_interceptors.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storageService;

  ApiClient({SecureStorageService? storageService, Dio? dio})
      : _storageService = storageService ?? SecureStorageService() {
    if (dio != null) {
      _dio = dio;
    } else {
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          responseType: ResponseType.json,
        ),
      );
      _dio.interceptors.add(AuthInterceptor(_storageService));
    }
  }

  Dio get dio => _dio;
  SecureStorageService get storage => _storageService;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  Never _handleDioException(DioException e) {
    if (e.error is ApiException) {
      throw e.error as ApiException;
    }
    throw ApiException(
      message: e.message ?? 'An unexpected network error occurred.',
      statusCode: e.response?.statusCode,
      data: e.response?.data,
    );
  }
}
