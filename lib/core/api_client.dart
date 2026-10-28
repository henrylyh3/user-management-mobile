import 'package:dio/dio.dart';

import 'api_problem.dart';

abstract interface class AccessSession {
  String? get accessToken;
  int get generation;
  Future<void> refresh();
  Future<void> invalidate();
}

class ApiClient {
  ApiClient(String origin, {Dio? transport}) : dio = transport ?? Dio() {
    dio.options = BaseOptions(
      baseUrl: origin.replaceAll(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      followRedirects: false,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'UserManagementMobile/0.1',
      },
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra['authenticated'] == true) {
            if (options.extra['generation'] != session?.generation) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: const ApiProblem(
                    'The session has changed. Please try again.',
                  ),
                ),
              );
            }
            final token = session?.accessToken;
            if (token == null) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: const ApiProblem(
                    'Unlock your session or sign in again.',
                  ),
                ),
              );
            }
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  AccessSession? session;

  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Future<dynamic> Function()? bodyFactory,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    if (!path.startsWith('/api/') || path.startsWith('//')) {
      throw ArgumentError('Only relative ASP.NET API paths are allowed.');
    }
    final sentToken = session?.accessToken;
    final sentGeneration = session?.generation;
    Future<Response<dynamic>> send() async => dio.request<dynamic>(
      path,
      data: bodyFactory == null ? data : await bodyFactory(),
      queryParameters: query,
      options: Options(
        method: method,
        extra: {'authenticated': authenticated, 'generation': sentGeneration},
      ),
    );
    try {
      return (await send()).data;
    } on DioException catch (error) {
      if (error.error case final ApiProblem problem) throw problem;
      if (!authenticated ||
          error.response?.statusCode != 401 ||
          session == null) {
        throw ApiProblem.fromDio(error);
      }
      // A concurrent request may already have replaced the rejected access token.
      if (session!.generation != sentGeneration) {
        throw const ApiProblem('The session has changed. Please try again.');
      }
      if (session!.accessToken == sentToken) await session!.refresh();
      if (session!.generation != sentGeneration) {
        throw const ApiProblem('The session has changed. Please try again.');
      }
      if (session!.accessToken == null) {
        throw const ApiProblem('Please sign in again.', status: 401);
      }
      try {
        return (await send()).data;
      } on DioException catch (retryError) {
        if (retryError.response?.statusCode == 401 &&
            session!.generation == sentGeneration) {
          await session!.invalidate();
        }
        if (retryError.error case final ApiProblem problem) throw problem;
        throw ApiProblem.fromDio(retryError);
      }
    }
  }
}
