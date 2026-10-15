import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';

enum ApiOperation {
  login,
  register,
  profile,
  refresh,
  logout,
  verifyEmail,
  resendEmail,
}

/// Matches the NestJS default exception shape and messages in AuthService/policy.
abstract final class ApiErrorMapper {
  static ApiException map(DioException error, ApiOperation operation) {
    if (error.error is AuthFailure) {
      return ApiException(error.error as AuthFailure);
    }
    if (error.error is ApiException) return error.error as ApiException;
    if ({
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type)) {
      return const ApiException(
        AuthFailure(
          FailureKind.timeout,
          'Kết nối quá thời gian chờ. Vui lòng thử lại.',
        ),
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate) {
      return const ApiException(
        AuthFailure(
          FailureKind.network,
          'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
        ),
      );
    }
    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;
    final messages = message is String
        ? [message]
        : message is List
        ? message.whereType<String>().toList()
        : <String>[];
    final text = messages.join(' ');
    final status = error.response?.statusCode;
    if (status == 503 && operation == ApiOperation.resendEmail) {
      return const ApiException(
        AuthFailure(
          FailureKind.server,
          'Hiện chưa thể gửi email xác minh. Vui lòng thử lại sau.',
        ),
      );
    }
    if (status == 429) {
      return const ApiException(
        AuthFailure(
          FailureKind.rateLimited,
          'Bạn đã gửi quá nhiều yêu cầu. Vui lòng chờ rồi thử lại.',
        ),
      );
    }
    if (status == 403) {
      if (text == 'Email has not been verified') {
        return const ApiException(
          AuthFailure(
            FailureKind.emailUnverified,
            'Email chưa được xác minh. Vui lòng xác minh email trước khi đăng nhập.',
          ),
        );
      }
      if (text == 'Account is not active' ||
          text == 'Student is not active' ||
          text == 'University is suspended or inactive' ||
          text.contains('not active or is waiting for approval') ||
          text == 'Company has not been verified or is inactive') {
        return const ApiException(
          AuthFailure(
            FailureKind.inactiveAccount,
            'Tài khoản hoặc hồ sơ không hoạt động, đang chờ duyệt hoặc bị tạm khóa.',
          ),
        );
      }
      return const ApiException(
        AuthFailure(
          FailureKind.forbidden,
          'Tài khoản chưa được phép thực hiện thao tác này.',
        ),
      );
    }
    if (status == 401) {
      // Public registration and OTP calls do not have a session to expire.
      if (operation == ApiOperation.register ||
          operation == ApiOperation.verifyEmail ||
          operation == ApiOperation.resendEmail) {
        return const ApiException(
          AuthFailure(
            FailureKind.server,
            'Máy chủ chưa cho phép ứng dụng kết nối. Vui lòng liên hệ hỗ trợ.',
          ),
        );
      }
      if (operation == ApiOperation.login) {
        return const ApiException(
          AuthFailure(
            FailureKind.invalidCredentials,
            'Tên đăng nhập hoặc mật khẩu không đúng.',
          ),
        );
      }
      return const ApiException(
        AuthFailure(
          FailureKind.sessionExpired,
          'Phiên đã hết hạn hoặc không còn hợp lệ. Vui lòng đăng nhập lại.',
        ),
      );
    }
    if (status == 409) {
      return const ApiException(
        AuthFailure(
          FailureKind.validation,
          'Tên đăng nhập hoặc email đã được sử dụng.',
          fieldErrors: {
            'username': 'Tên đăng nhập hoặc email đã được sử dụng.',
            'email': 'Tên đăng nhập hoặc email đã được sử dụng.',
          },
        ),
      );
    }
    if (status == 400 || status == 422) {
      if (text == 'Invalid or expired OTP') {
        return const ApiException(
          AuthFailure(
            FailureKind.validation,
            'Mã xác minh không đúng hoặc đã hết hạn.',
            fieldErrors: {'otp': 'Mã không đúng hoặc đã hết hạn.'},
          ),
        );
      }
      final errors = <String, String>{};
      const labels = {
        'username': 'Tên đăng nhập',
        'email': 'Email',
        'password': 'Mật khẩu',
        'fullName': 'Họ và tên',
        'phone': 'Số điện thoại',
        'otp': 'Mã xác minh',
      };
      for (final entry in messages) {
        final field = RegExp(r'^([a-zA-Z]+)\b').firstMatch(entry)?.group(1);
        if (field != null && labels.containsKey(field)) {
          final key = field == 'username' && operation == ApiOperation.login
              ? 'identifier'
              : field;
          errors[key] = '${labels[field]} không hợp lệ.';
        }
      }
      return ApiException(
        AuthFailure(
          FailureKind.validation,
          'Vui lòng kiểm tra thông tin đã nhập.',
          fieldErrors: errors,
        ),
      );
    }
    return const ApiException(
      AuthFailure(
        FailureKind.server,
        'Máy chủ chưa xử lý được yêu cầu. Vui lòng thử lại.',
      ),
    );
  }
}
