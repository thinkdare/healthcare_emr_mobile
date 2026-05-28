import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Clinical routes require X-Tenant-ID (the active facility UUID).
          // Inject it automatically if present; controllers that don't need it
          // (auth, billing, orgs) ignore unknown headers.
          final tenantId = await _storage.read(key: 'active_tenant_id');
          if (tenantId != null) {
            options.headers['X-Tenant-ID'] = tenantId;
          }

          if (kDebugMode) {
            debugPrint('REQUEST: ${options.method} ${options.uri.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('RESPONSE: ${response.statusCode} ${response.requestOptions.uri.path}');
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('ERROR: ${error.response?.statusCode} ${error.requestOptions.uri.path}');
          }

          if (error.response?.statusCode == 401) {
            await _storage.delete(key: 'auth_token');
            await _storage.delete(key: 'active_tenant_id');
            await _storage.delete(key: 'current_user');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Helper to decode JSON and handle Laravel API response format
  T _decode<T>(Response response) {
    if (response.data == null) {
      throw ApiException('Empty response', statusCode: response.statusCode);
    }

    // Handle non-2xx status codes
    if (response.statusCode != null && response.statusCode! >= 400) {
      final data = response.data;
      
      // Laravel error response format: { "success": false, "message": "...", "error": {...} }
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String? ?? 'Request failed';
        final error = data['error'] as Map<String, dynamic>?;
        final details = error?['details'] as Map<String, dynamic>?;
        
        throw ApiException(
          message,
          statusCode: response.statusCode,
          details: details,
        );
      }
      
      throw ApiException(
        'Request failed',
        statusCode: response.statusCode,
      );
    }

    // Handle successful response
    // Laravel success response format: { "success": true, "message": "...", "data": {...} }
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      
      // Return the entire response (including data, message, success)
      return data as T;
    } else if (response.data is String) {
      return jsonDecode(response.data) as T;
    } else {
      throw ApiException('Unexpected response format');
    }
  }

  Future<Map<String, dynamic>> get(
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
      return _decode<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _decode<Map<String, dynamic>>(e.response!);
      }
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> post(
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
      return _decode<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _decode<Map<String, dynamic>>(e.response!);
      }
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _decode<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _decode<Map<String, dynamic>>(e.response!);
      }
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> put(
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
      return _decode<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _decode<Map<String, dynamic>>(e.response!);
      }
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> delete(
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
      return _decode<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _decode<Map<String, dynamic>>(e.response!);
      }
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // Helper method to save token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Helper method to get token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Helper method to clear token
  Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // Tenant (active facility) helpers
  Future<void> saveTenantId(String tenantId) async {
    await _storage.write(key: 'active_tenant_id', value: tenantId);
  }

  Future<String?> getTenantId() async {
    return await _storage.read(key: 'active_tenant_id');
  }

  Future<void> clearTenantId() async {
    await _storage.delete(key: 'active_tenant_id');
  }

  /// Clear all auth state — call on logout.
  Future<void> clearAll() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'active_tenant_id');
    await _storage.delete(key: 'current_user');
  }
}