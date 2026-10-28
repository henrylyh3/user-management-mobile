import 'package:dio/dio.dart';

class ApiProblem implements Exception {
  const ApiProblem(
    this.message, {
    this.status,
    this.code,
    this.captchaRequired = false,
    this.errors = const {},
  });
  final String message;
  final int? status;
  final String? code;
  final bool captchaRequired;
  final Map<String, List<String>> errors;

  factory ApiProblem.fromDio(DioException exception) {
    final response = exception.response;
    final status = response?.statusCode;
    final body = response?.data;
    final data = body is Map ? body : const {};
    final errors = <String, List<String>>{};
    if (data['errors'] case final Map fields) {
      for (final entry in fields.entries) {
        if (entry.value is List) {
          errors[entry.key.toString()] = (entry.value as List)
              .whereType<String>()
              .toList();
        }
      }
    }
    String fallback = switch (status) {
      400 => 'Check the form and try again.',
      401 => 'Please sign in again.',
      403 => 'You do not have permission for this action.',
      404 => 'The requested item was not found.',
      409 => 'This change conflicts with the current account state.',
      413 => 'The image is too large.',
      429 => 'Too many requests. Wait a minute before trying again.',
      null => 'Cannot reach the server. Check your connection and try again.',
      _ => 'The service is temporarily unavailable. Try again later.',
    };
    // Never surface unexpected server exception details or raw response bodies.
    if (status != null && status < 500 && data['detail'] is String) {
      fallback = data['detail'] as String;
    }
    return ApiProblem(
      fallback,
      status: status,
      code: data['code'] is String ? data['code'] as String : null,
      captchaRequired: data['captchaRequired'] == true,
      errors: errors,
    );
  }

  @override
  String toString() => message;
}

Map<String, dynamic> jsonObject(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const ApiProblem('The server returned an invalid response.');
  }
  return value;
}

String jsonString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) {
    throw const ApiProblem('The server returned an invalid response.');
  }
  return field;
}
