import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/data/datasources/auth_api_error_mapper.dart';

AuthFailure mapped(
  int status,
  Object? message,
  AuthOperation operation, {
  bool nest = true,
}) {
  final request = RequestOptions(path: '/test-only');
  return AuthApiErrorMapper.map(
    DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: status,
        data: {'message': message, if (nest) 'statusCode': status},
      ),
    ),
    operation,
  ).failure;
}

void main() {
  test('401 maps by operation regardless of the error body shape', () {
    expect(
      mapped(401, 'Invalid username or password', AuthOperation.login).kind,
      FailureKind.invalidCredentials,
    );
    expect(
      mapped(401, 'Unauthorized', AuthOperation.login, nest: false).kind,
      FailureKind.invalidCredentials,
    );
    expect(
      mapped(401, 'Unauthorized', AuthOperation.profile).kind,
      FailureKind.sessionExpired,
    );
    for (final operation in [AuthOperation.profile, AuthOperation.refresh]) {
      expect(
        mapped(401, 'Unauthorized', operation, nest: false).kind,
        FailureKind.sessionExpired,
      );
    }
  });
  test('email verification is distinct from inactive account', () {
    expect(
      mapped(403, 'Email has not been verified', AuthOperation.login).kind,
      FailureKind.emailUnverified,
    );
    expect(
      mapped(403, 'Account is not active', AuthOperation.login).kind,
      FailureKind.inactiveAccount,
    );
    expect(
      mapped(403, 'Student is not active', AuthOperation.login).kind,
      FailureKind.inactiveAccount,
    );
  });
  test('Nest DTO error array maps fields without displaying raw errors', () {
    final failure = mapped(400, [
      'password must be longer than or equal to 8 characters',
      'username should not be empty',
    ], AuthOperation.login);
    expect(failure.fieldErrors.keys, containsAll(['password', 'identifier']));
    expect(failure.message, isNot(contains('8 characters')));
  });
  test(
    'combined duplicate message marks both fields without guessing which collided',
    () {
      final failure = mapped(
        409,
        'Username or email is already registered',
        AuthOperation.register,
      );
      expect(failure.fieldErrors.keys, containsAll(['email', 'username']));
    },
  );
  test('email service failure gives a delivery-specific message', () {
    final failure = mapped(
      503,
      'Email delivery is unavailable',
      AuthOperation.resendEmail,
    );
    expect(failure.kind, FailureKind.server);
    expect(
      failure.message,
      'Hiện chưa thể gửi email xác minh. Vui lòng thử lại sau.',
    );
  });

  test('rate limit and expired OTP are actionable failures', () {
    expect(
      mapped(
        429,
        'Too many requests. Try again later.',
        AuthOperation.login,
      ).kind,
      FailureKind.rateLimited,
    );
    expect(
      mapped(
        400,
        'Invalid or expired OTP',
        AuthOperation.verifyEmail,
      ).fieldErrors,
      contains('otp'),
    );
  });
}
