import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_management_mobile/core/api_problem.dart';
import 'package:user_management_mobile/core/config.dart';

void main() {
  test('Problem Details retains CAPTCHA and field validation information', () {
    final options = RequestOptions(path: '/api/mobile/auth/signin');
    final problem = ApiProblem.fromDio(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {
            'detail': 'Complete human verification.',
            'code': 'captcha_required',
            'captchaRequired': true,
            'errors': {
              'Email': ['Enter a valid email.'],
            },
          },
        ),
      ),
    );
    expect(problem.captchaRequired, isTrue);
    expect(problem.code, 'captcha_required');
    expect(problem.errors['Email'], ['Enter a valid email.']);
  });
  test('Unexpected server details are not exposed', () {
    final options = RequestOptions(path: '/api/User');
    final problem = ApiProblem.fromDio(
      DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 500,
          data: {'detail': 'internal exception'},
        ),
      ),
    );
    expect(problem.message, isNot(contains('internal exception')));
  });
  test('Local storage URLs resolve to API origin', () {
    const config = AppConfig(apiUrl: 'https://api.example.test');
    expect(
      config.imageUri('/uploads/photo.png').toString(),
      'https://api.example.test/uploads/photo.png',
    );
    expect(config.imageUri('javascript:alert(1)'), isNull);
  });
}
