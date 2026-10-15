import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/network/auth_interceptor.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'support/auth_fakes.dart';

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;
  final requestStarted = Completer<void>();
  int status = 200;
  Completer<ResponseBody>? pending;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (!requestStarted.isCompleted) requestStarted.complete();
    return pending?.future ??
        ResponseBody.fromString(
          '{}',
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late RecordingAdapter adapter;
  late SessionCredential? credential;
  late int expiryCalls;
  setUp(() {
    credential = testCredential;
    expiryCalls = 0;
    adapter = RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        origin: Uri.parse('https://test.invalid'),
        credential: () => credential,
        onExpired: () async {
          expiryCalls++;
          credential = null;
        },
      ),
    );
  });
  tearDown(() => dio.close(force: true));
  test(
    'credential attached only to opted-in requests on configured origin',
    () async {
      await dio.get<dynamic>(
        '/private',
        options: Options(extra: {'requiresAuth': true}),
      );
      expect(adapter.last!.headers['Authorization'], 'Bearer test-only-token');
      await dio.get<dynamic>('/public');
      expect(adapter.last!.headers['Authorization'], isNull);
      await dio.get<dynamic>(
        'https://other.invalid/private',
        options: Options(extra: {'requiresAuth': true}),
      );
      expect(adapter.last!.headers['Authorization'], isNull);
    },
  );
  test('login 401 cannot invalidate a session', () async {
    adapter.status = 401;
    await expectLater(
      dio.post<dynamic>('/test-login'),
      throwsA(isA<DioException>()),
    );
    expect(expiryCalls, 0);
  });
  test(
    'protected 401 without a credential does not signal session expiry',
    () async {
      credential = null;
      adapter.status = 401;
      await expectLater(
        dio.get<dynamic>(
          '/private',
          options: Options(extra: {'requiresAuth': true}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(expiryCalls, 0);
    },
  );
  test('protected 401 expires current credential without refreshing', () async {
    adapter.status = 401;
    await expectLater(
      dio.get<dynamic>(
        '/private',
        options: Options(extra: {'requiresAuth': true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(expiryCalls, 1);
    expect(credential, isNull);
  });
  test('late 401 cannot invalidate a newer session', () async {
    adapter.pending = Completer<ResponseBody>();
    final request = dio.get<dynamic>(
      '/private',
      options: Options(extra: {'requiresAuth': true}),
    );
    final checked = expectLater(request, throwsA(isA<DioException>()));
    await adapter.requestStarted.future;
    credential = const SessionCredential(
      kind: CredentialKind.bearer,
      value: 'new-test-token',
    );
    adapter.pending!.complete(ResponseBody.fromString('{}', 401));
    await checked;
    expect(expiryCalls, 0);
    expect(credential!.value, 'new-test-token');
  });
}
