import 'package:tip_app/core/errors/failures.dart';

/// A verified backend adapter maps its error DTO into this exception.
class ApiException implements Exception {
  const ApiException(this.failure);
  final AuthFailure failure;
}

const authIntegrationFailure = AuthFailure(
  FailureKind.integrationUnavailable,
  'Đăng nhập và đăng ký trực tuyến chưa khả dụng. Vui lòng thử lại sau.',
);
