import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/errors/api_error_mapper.dart';

/// Normalizes transport and decode failures. Feature rules belong in repositories.
Future<T> apiRequest<T>(
  Future<T> Function() action, {
  String? notFoundMessage,
}) async {
  try {
    return await action();
  } on DioException catch (error) {
    if (error.response?.statusCode == 404 && notFoundMessage != null) {
      throw AuthFailure(FailureKind.server, notFoundMessage);
    }
    throw ApiErrorMapper.map(error, ApiOperation.profile).failure;
  } on ApiException catch (error) {
    throw error.failure;
  } on FormatException {
    throw const AuthFailure(
      FailureKind.server,
      'Dữ liệu trả về chưa hợp lệ. Vui lòng thử lại sau.',
    );
  } on AuthFailure {
    rethrow;
  } on Object {
    throw const AuthFailure(
      FailureKind.unexpected,
      'Chưa thể tải dữ liệu. Vui lòng thử lại.',
    );
  }
}
