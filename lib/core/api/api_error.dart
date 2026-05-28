import 'package:dio/dio.dart';

class ApiError {
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  
  ApiError({
    required this.code,
    required this.message,
    this.details,
  });
  
  // Create from API error response
  factory ApiError.fromResponse(Response response) {
    final data = response.data;
    
    if (data != null && data is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>?;
      
      return ApiError(
        code: error?['code'] ?? 'UNKNOWN_ERROR',
        message: error?['message'] ?? 'An unknown error occurred',
        details: error?['details'] as Map<String, dynamic>?,
      );
    }
    
    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: 'An unknown error occurred',
    );
  }
  
  // Create from Dio exception (Dio 5.x)
  factory ApiError.fromException(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiError(
            code: 'TIMEOUT',
            message: 'Request timeout. Please check your internet connection.',
          );
          
        case DioExceptionType.badResponse:
          if (error.response != null) {
            return ApiError.fromResponse(error.response!);
          }
          return ApiError(
            code: 'BAD_RESPONSE',
            message: 'Invalid response from server',
          );
          
        case DioExceptionType.cancel:
          return ApiError(
            code: 'CANCELLED',
            message: 'Request was cancelled',
          );
          
        case DioExceptionType.connectionError:
          return ApiError(
            code: 'CONNECTION_ERROR',
            message: 'Connection error. Please check your internet connection.',
          );
          
        case DioExceptionType.badCertificate:
          return ApiError(
            code: 'BAD_CERTIFICATE',
            message: 'Security certificate error',
          );
          
        case DioExceptionType.unknown:
          return ApiError(
            code: 'NETWORK_ERROR',
            message: 'Network error. Please check your internet connection.',
          );
      }
    }
    
    return ApiError(
      code: 'UNKNOWN_ERROR',
      message: error.toString(),
    );
  }
  
  // Get user-friendly error message
  String get userMessage {
    // Handle validation errors
    if (code == 'VALIDATION_ERROR' && details != null) {
      final errors = <String>[];
      details!.forEach((key, value) {
        if (value is List) {
          errors.addAll(value.map((e) => e.toString()));
        } else {
          errors.add(value.toString());
        }
      });
      return errors.isNotEmpty ? errors.first : message;
    }
    
    return message;
  }
  
  // Get all validation errors
  Map<String, List<String>> get validationErrors {
    if (code == 'VALIDATION_ERROR' && details != null) {
      final Map<String, List<String>> errors = {};
      details!.forEach((key, value) {
        if (value is List) {
          errors[key] = value.map((e) => e.toString()).toList();
        } else if (value is String) {
          errors[key] = [value];
        }
      });
      return errors;
    }
    return {};
  }
  
  @override
  String toString() => 'ApiError(code: $code, message: $message)';
}