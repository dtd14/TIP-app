import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.origin,
    required this.credential,
    required this.onExpired,
    this.onRefresh,
    this.retryRequest,
  });
  final Uri origin;
  final SessionCredential? Function() credential;
  final Future<void> Function() onExpired;
  final Future<SessionCredential?> Function(SessionCredential)? onRefresh;
  final Future<Response<dynamic>> Function(RequestOptions)? retryRequest;

  bool _authenticated(RequestOptions options) =>
      options.extra['requiresAuth'] == true &&
      options.uri.scheme == origin.scheme &&
      options.uri.host == origin.host &&
      options.uri.port == origin.port;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_authenticated(options)) {
      final session = credential();
      if (options.extra['requiresBearerAuth'] == true &&
          session?.kind != CredentialKind.bearer) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: const ApiException(
              AuthFailure(
                FailureKind.sessionExpired,
                'Không có phiên đăng nhập hợp lệ. Vui lòng đăng nhập lại.',
              ),
            ),
          ),
        );
        return;
      }
      if (session != null) {
        if (session.kind == CredentialKind.cookie && kIsWeb) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Browser cookie transport requires a verified adapter.',
            ),
          );
          return;
        }
        final header = session.kind == CredentialKind.bearer
            ? 'Authorization'
            : 'Cookie';
        options.headers[header] = session.kind == CredentialKind.bearer
            ? 'Bearer ${session.value}'
            : session.value;
        options.extra['sessionCredential'] = session;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final failed = err.requestOptions.extra['sessionCredential'];
    if (!_authenticated(err.requestOptions) ||
        err.response?.statusCode != 401 ||
        failed is! SessionCredential) {
      handler.next(err);
      return;
    }
    if (err.requestOptions.extra['authRetried'] != true &&
        onRefresh != null &&
        retryRequest != null) {
      try {
        final refreshed = await onRefresh!(failed);
        if (refreshed != null) {
          final options = err.requestOptions;
          options.extra['authRetried'] = true;
          if (options.data is FormData) {
            options.data = (options.data as FormData).clone();
          }
          final response = await retryRequest!(options);
          handler.resolve(response);
          return;
        }
      } on DioException catch (retryError) {
        handler.reject(retryError);
        return;
      } on Object catch (error) {
        handler.reject(
          DioException(requestOptions: err.requestOptions, error: error),
        );
        return;
      }
    }
    if (identical(failed, credential())) {
      try {
        await onExpired();
      } on Object {
        /* Repository reports storage failures. */
      }
    }
    handler.next(err);
  }
}
