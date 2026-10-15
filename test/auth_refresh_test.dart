import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'nest_auth_remote_data_source_test.dart'
    show ControllerAdapter, meFixture, activeStudent;
import 'support/auth_fakes.dart';
import 'support/nest_fixtures.dart';

const pairCredential = SessionCredential(
  kind: CredentialKind.bearer,
  value: 'test-access',
  refreshToken: 'test-refresh',
);
void main() {
  late MemorySessionStorage storage;
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  setUp(() async {
    storage = MemorySessionStorage()..value = pairCredential;
    dependencies = AppDependencies.create(sessionStorage: storage);
    adapter = ControllerAdapter()..response = meFixture(student: activeStudent);
    dependencies.apiClient.dio.httpClientAdapter = adapter;
    await dependencies.authRepository.getCurrentUser();
    adapter.requests.clear();
  });
  tearDown(() async => dependencies.dispose());
  Options getOptions() =>
      Options(extra: {'requiresAuth': true, 'requiresBearerAuth': true});

  test(
    'concurrent 401 shares one rotation, persists both tokens and retries once',
    () async {
      final refreshStarted = Completer<void>();
      final refreshDone = Completer<ResponseBody>();
      adapter.onRequest = (options) {
        if (options.path == '/auth/refresh-token') {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          expect(options.data, {'refreshToken': 'test-refresh'});
          expect(options.headers['Authorization'], isNull);
          return refreshDone.future;
        }
        return options.headers['Authorization'] == 'Bearer test-access-new'
            ? body(meFixture(student: activeStudent))
            : body(expiredResponse(), status: 401);
      };
      final requests = Future.wait([
        dependencies.apiClient.dio.get<Object?>(
          '/auth/me',
          options: getOptions(),
        ),
        dependencies.apiClient.dio.get<Object?>(
          '/auth/me',
          options: getOptions(),
        ),
      ]);
      await refreshStarted.future;
      refreshDone.complete(body(rotatedTokenPair));
      final results = await requests;
      expect(results.every((result) => result.statusCode == 200), isTrue);
      expect(
        adapter.requests.where(
          (request) => request.path == '/auth/refresh-token',
        ),
        hasLength(1),
      );
      expect(storage.value!.value, 'test-access-new');
      expect(storage.value!.refreshToken, 'test-refresh-new');
    },
  );

  test('revoked refresh clears credentials without retry loops', () async {
    adapter.onRequest = (options) => body(
      options.path == '/auth/refresh-token'
          ? {'statusCode': 401, 'message': 'Refresh token has been revoked'}
          : expiredResponse(),
      status: 401,
    );
    final expired = dependencies.authRepository.sessionExpired.first;
    await expectLater(
      dependencies.authRepository.getCurrentUser(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.sessionExpired,
        ),
      ),
    );
    expect(await expired, isNull);
    expect(storage.value, isNull);
    expect(adapter.requests, hasLength(2));
  });

  test('refresh timeout preserves token pair for explicit retry', () async {
    adapter.onRequest = (options) {
      if (options.path == '/auth/refresh-token') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return body(expiredResponse(), status: 401);
    };
    await expectLater(
      dependencies.authRepository.getCurrentUser(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.timeout,
        ),
      ),
    );
    expect(storage.value, pairCredential);
    expect(dependencies.authRepository.credential, pairCredential);
  });

  test('retry 401 expires session without refreshing a second time', () async {
    adapter.onRequest = (options) => options.path == '/auth/refresh-token'
        ? body(rotatedTokenPair)
        : body(expiredResponse(), status: 401);
    await expectLater(
      dependencies.authRepository.getCurrentUser(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.sessionExpired,
        ),
      ),
    );
    expect(
      adapter.requests.where(
        (request) => request.path == '/auth/refresh-token',
      ),
      hasLength(1),
    );
    expect(storage.value, isNull);
  });

  test(
    'rotation arriving after logout cannot recreate saved session',
    () async {
      final started = Completer<void>();
      final done = Completer<ResponseBody>();
      adapter.onRequest = (options) {
        if (options.path == '/auth/refresh-token') {
          started.complete();
          return done.future;
        }
        if (options.path == '/auth/logout') {
          return body({'message': 'Logged out successfully.'});
        }
        return body(expiredResponse(), status: 401);
      };
      final request = dependencies.apiClient.dio.get<Object?>(
        '/auth/me',
        options: getOptions(),
      );
      final checked = expectLater(request, throwsA(isA<DioException>()));
      await started.future;
      await dependencies.authRepository.logout();
      done.complete(body(rotatedTokenPair));
      await checked;
      expect(storage.value, isNull);
      expect(dependencies.authRepository.credential, isNull);
    },
  );

  test('generic protected 401 rotates tokens and retries once', () async {
    adapter.onRequest = (options) => options.path == '/auth/refresh-token'
        ? body(rotatedTokenPair)
        : options.headers['Authorization'] == 'Bearer test-access-new'
        ? body(meFixture(student: activeStudent))
        : body({'message': 'Unauthorized'}, status: 401);
    final user = await dependencies.authRepository.getCurrentUser();
    expect(user!.canAccessStudentApp, isTrue);
    expect(adapter.requests, hasLength(3));
    expect(storage.value!.refreshToken, 'test-refresh-new');
  });

  test('generic refresh 401 clears the rejected session', () async {
    adapter.onRequest = (_) => body({'message': 'Unauthorized'}, status: 401);
    await expectLater(
      dependencies.authRepository.getCurrentUser(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.sessionExpired,
        ),
      ),
    );
    expect(adapter.requests, hasLength(2));
    expect(storage.value, isNull);
  });

  test(
    'role denial preserves the session without refreshing or retrying',
    () async {
      adapter.onRequest = (_) => body({'message': 'Forbidden'}, status: 403);
      await expectLater(
        dependencies.authRepository.getCurrentUser(),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(storage.value, pairCredential);
    },
  );
}
