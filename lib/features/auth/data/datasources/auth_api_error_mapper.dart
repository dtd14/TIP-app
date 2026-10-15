import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/api_error_mapper.dart';

enum AuthOperation {
  login,
  register,
  profile,
  refresh,
  logout,
  verifyEmail,
  resendEmail,
}

/// Auth keeps its operation names while sharing transport and policy mapping.
abstract final class AuthApiErrorMapper {
  static ApiException map(DioException error, AuthOperation operation) =>
      ApiErrorMapper.map(error, ApiOperation.values.byName(operation.name));
}
