import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'support/auth_fakes.dart';

Matcher failure(FailureKind kind) =>
    isA<AuthFailure>().having((value) => value.kind, 'kind', kind);

DioException httpError(int status) {
  final request = RequestOptions(path: '/test-only');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: request, statusCode: status),
  );
}

void main() {
  late MemorySessionStorage storage;
  late FakeAuthRemote remote;
  late AuthRepositoryImpl repository;
  setUp(() {
    storage = MemorySessionStorage();
    remote = FakeAuthRemote();
    repository = AuthRepositoryImpl(remote: remote, storage: storage);
  });
  tearDown(() async => repository.dispose());

  test(
    'missing contract never fabricates login or registration success',
    () async {
      final blocked = AuthRepositoryImpl(
        remote: const ContractMissingAuthDataSource(),
        storage: storage,
      );
      addTearDown(blocked.dispose);
      await expectLater(
        blocked.login(identifier: 'student', password: 'password'),
        throwsA(failure(FailureKind.integrationUnavailable)),
      );
      await expectLater(
        blocked.register(registrationInput),
        throwsA(failure(FailureKind.integrationUnavailable)),
      );
      expect(storage.value, isNull);
      expect(storage.writes, 0);
    },
  );

  test(
    'login stores only credential, and restart validates user remotely',
    () async {
      expect(
        await repository.login(identifier: 'student', password: 'password'),
        studentUser,
      );
      expect(storage.value, testCredential);
      final restored = AuthRepositoryImpl(remote: remote, storage: storage);
      addTearDown(restored.dispose);
      expect(await restored.getCurrentUser(), studentUser);
      expect(remote.currentUserCalls, 1);
    },
  );

  test('empty storage restores signed out without a backend call', () async {
    expect(await repository.getCurrentUser(), isNull);
    expect(remote.currentUserCalls, 0);
  });

  test(
    'initial 401 means invalid credentials, not an expired session',
    () async {
      remote.onLogin = (_, _) async => throw httpError(401);
      final expiry = <AuthFailure?>[];
      final subscription = repository.sessionExpired.listen(expiry.add);
      addTearDown(subscription.cancel);
      await expectLater(
        repository.login(identifier: 'student', password: 'wrong'),
        throwsA(failure(FailureKind.invalidCredentials)),
      );
      expect(expiry, isEmpty);
      expect(storage.clears, 0);
    },
  );

  test('session 401 erases credential and emits one expiry event', () async {
    storage.value = testCredential;
    remote.onCurrentUser = () async => throw httpError(401);
    final expired = repository.sessionExpired.first;
    await expectLater(
      repository.getCurrentUser(),
      throwsA(failure(FailureKind.sessionExpired)),
    );
    expect(await expired, isNull);
    expect(storage.value, isNull);
    expect(repository.credential, isNull);
    expect(storage.clears, 1);
  });

  test('timeout during restoration retains credential for retry', () async {
    storage.value = testCredential;
    remote.onCurrentUser = () async => throw DioException(
      requestOptions: RequestOptions(path: '/test-only'),
      type: DioExceptionType.receiveTimeout,
    );
    await expectLater(
      repository.getCurrentUser(),
      throwsA(failure(FailureKind.timeout)),
    );
    expect(storage.value, testCredential);
    remote.onCurrentUser = null;
    expect(await repository.getCurrentUser(), studentUser);
  });

  test('network failures and inactive accounts remain distinct', () async {
    remote.onLogin = (_, _) async => throw DioException(
      requestOptions: RequestOptions(path: '/test-only'),
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      repository.login(identifier: 'student', password: 'password'),
      throwsA(failure(FailureKind.network)),
    );
    remote.onLogin = (_, _) async => throw const ApiException(
      AuthFailure(FailureKind.inactiveAccount, 'Tài khoản bị khóa.'),
    );
    await expectLater(
      repository.login(identifier: 'student', password: 'password'),
      throwsA(failure(FailureKind.inactiveAccount)),
    );
  });

  test('confirmed backend field errors survive repository mapping', () async {
    const apiFailure = AuthFailure(
      FailureKind.validation,
      'Email đã tồn tại.',
      fieldErrors: {
        'email': 'Email đã được sử dụng.',
        'username': 'Tên đã tồn tại.',
      },
    );
    remote.onRegister = (_) async => throw const ApiException(apiFailure);
    await expectLater(
      repository.register(registrationInput),
      throwsA(same(apiFailure)),
    );
  });

  test(
    'registration without server session does not auto-login or create Student',
    () async {
      final result = await repository.register(registrationInput);
      expect(result.user, isNull);
      expect(storage.value, isNull);
      expect(storage.writes, 0);
    },
  );

  test(
    'registration uses a session only when explicitly supplied by adapter',
    () async {
      remote.onRegister = (_) async =>
          const RegistrationModel(message: 'Thành công', session: testSession);
      final result = await repository.register(registrationInput);
      expect(result.user, studentUser);
      expect(storage.value, testCredential);
    },
  );

  test(
    'remote logout failure still removes local credential and returns warning',
    () async {
      await repository.login(identifier: 'student', password: 'password');
      remote.onLogout = () async => throw httpError(500);
      expect(await repository.logout(), isNotNull);
      expect(repository.credential, isNull);
      expect(storage.value, isNull);
    },
  );

  test(
    'storage deletion failure blocks normal logout until retry succeeds',
    () async {
      await repository.login(identifier: 'student', password: 'password');
      storage.clearError = StateError('test storage unavailable');
      await expectLater(
        repository.logout(),
        throwsA(failure(FailureKind.storage)),
      );
      expect(repository.credential, isNull);
      storage.clearError = null;
      await repository.logout();
      expect(storage.value, isNull);
    },
  );

  test(
    'expired credential deletion failure is reported, not silently signed out',
    () async {
      storage.value = testCredential;
      storage.clearError = StateError('test storage unavailable');
      remote.onCurrentUser = () async => throw httpError(401);
      final expired = repository.sessionExpired.first;
      await expectLater(
        repository.getCurrentUser(),
        throwsA(failure(FailureKind.storage)),
      );
      expect(await expired, failure(FailureKind.storage));
    },
  );

  test('late login response cannot recreate a logged-out session', () async {
    final pending = Completer<AuthSessionModel>();
    remote.onLogin = (_, _) => pending.future;
    final login = repository.login(identifier: 'student', password: 'password');
    final rejected = expectLater(
      login,
      throwsA(failure(FailureKind.sessionExpired)),
    );
    await repository.logout();
    pending.complete(testSession);
    await rejected;
    expect(storage.value, isNull);
  });

  test('late storage read cannot resurrect credential after logout', () async {
    storage.pendingRead = Completer<SessionCredential?>();
    final restore = repository.getCurrentUser();
    await repository.logout();
    storage.pendingRead!.complete(testCredential);
    expect(await restore, isNull);
    expect(repository.credential, isNull);
    expect(remote.currentUserCalls, 0);
  });

  test('unsafe credential is rejected before persistence', () async {
    remote.onLogin = (_, _) async => const AuthSessionModel(
      user: studentUser,
      credential: SessionCredential(
        kind: CredentialKind.bearer,
        value: 'unsafe\r\nheader',
      ),
    );
    await expectLater(
      repository.login(identifier: 'student', password: 'password'),
      throwsA(failure(FailureKind.server)),
    );
    expect(storage.writes, 0);
  });

  test('saving credentials failure cannot authenticate the user', () async {
    storage.writeError = StateError('test storage unavailable');
    await expectLater(
      repository.login(identifier: 'student', password: 'password'),
      throwsA(failure(FailureKind.storage)),
    );
    expect(repository.credential, isNull);
  });
}
