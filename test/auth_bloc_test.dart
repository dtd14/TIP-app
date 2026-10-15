import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tip_app/features/auth/domain/usecases/login.dart';
import 'package:tip_app/features/auth/domain/usecases/register.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_state.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_state.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_state.dart';
import 'support/auth_fakes.dart';

void main() {
  late FakeAuthRemote remote;
  late MemorySessionStorage storage;
  late AuthRepositoryImpl repository;
  setUp(() {
    remote = FakeAuthRemote();
    storage = MemorySessionStorage();
    repository = AuthRepositoryImpl(remote: remote, storage: storage);
  });
  tearDown(() async => repository.dispose());

  test('login validates before remote call', () async {
    final bloc = LoginBloc(Login(repository));
    addTearDown(bloc.close);
    final failed = bloc.stream.firstWhere(
      (state) => state.status == LoginStatus.failure,
    );
    bloc.add(const LoginSubmitted(identifier: ' ', password: ''));
    expect(
      (await failed).failure!.fieldErrors.keys,
      containsAll(['identifier', 'password']),
    );
    expect(remote.loginCalls, 0);
  });

  test(
    'login loading prevents duplicate submissions and preserves password bytes',
    () async {
      final pending = Completer<AuthSessionModel>();
      remote.onLogin = (_, _) => pending.future;
      final bloc = LoginBloc(Login(repository));
      addTearDown(bloc.close);
      final loading = bloc.stream.firstWhere((state) => state.isSubmitting);
      bloc.add(
        const LoginSubmitted(identifier: ' student ', password: ' password '),
      );
      await loading;
      bloc.add(const LoginSubmitted(identifier: 'student', password: 'other'));
      await Future<void>.delayed(Duration.zero);
      expect(remote.loginCalls, 1);
      expect(remote.lastIdentifier, 'student');
      expect(remote.lastPassword, ' password ');
      final success = bloc.stream.firstWhere(
        (state) => state.status == LoginStatus.success,
      );
      pending.complete(testSession);
      expect((await success).user, studentUser);
    },
  );

  test(
    'register rejects mismatched confirmation without remote call',
    () async {
      final bloc = RegisterBloc(Register(repository));
      addTearDown(bloc.close);
      final failed = bloc.stream.firstWhere(
        (state) => state.status == RegisterStatus.failure,
      );
      bloc.add(
        const RegisterSubmitted(
          input: registrationInput,
          confirmPassword: 'mismatch',
        ),
      );
      expect((await failed).failure!.fieldErrors, contains('confirmPassword'));
      expect(remote.registerCalls, 0);
    },
  );

  test('register loading prevents duplicate submissions', () async {
    final pending = Completer<RegistrationModel>();
    remote.onRegister = (_) => pending.future;
    final bloc = RegisterBloc(Register(repository));
    addTearDown(bloc.close);
    final loading = bloc.stream.firstWhere((state) => state.isSubmitting);
    bloc.add(
      const RegisterSubmitted(
        input: registrationInput,
        confirmPassword: 'test-password',
      ),
    );
    await loading;
    bloc.add(
      const RegisterSubmitted(
        input: registrationInput,
        confirmPassword: 'test-password',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(remote.registerCalls, 1);
    final done = bloc.stream.firstWhere(
      (state) => state.status == RegisterStatus.success,
    );
    pending.complete(const RegistrationModel(message: 'Đang chờ xác minh.'));
    expect((await done).outcome!.user, isNull);
  });

  test('register keeps server duplicate field errors', () async {
    remote.onRegister = (_) async => throw const ApiException(
      AuthFailure(
        FailureKind.validation,
        'Thông tin trùng.',
        fieldErrors: {'email': 'Email đã tồn tại.'},
      ),
    );
    final bloc = RegisterBloc(Register(repository));
    addTearDown(bloc.close);
    final failed = bloc.stream.firstWhere(
      (state) => state.status == RegisterStatus.failure,
    );
    bloc.add(
      const RegisterSubmitted(
        input: registrationInput,
        confirmPassword: 'test-password',
      ),
    );
    expect((await failed).failure!.fieldErrors['email'], 'Email đã tồn tại.');
  });

  test('auth restores real profile and signs out', () async {
    storage.value = testCredential;
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);
    final restored = bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.authenticated,
    );
    bloc.add(const AuthRestoreRequested());
    expect((await restored).user, studentUser);
    final signedOut = bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.unauthenticated,
    );
    bloc.add(const AuthLogoutRequested());
    expect((await signedOut).user, isNull);
    expect(storage.value, isNull);
  });

  test(
    'ACTIVE account without Student is authenticated and can logout',
    () async {
      final bloc = AuthBloc(repository);
      addTearDown(bloc.close);
      final authenticated = bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.authenticated,
      );
      bloc.add(const AuthSessionAccepted(nonStudentUser));
      expect((await authenticated).user!.canAccessStudentApp, isFalse);
      final signedOut = bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.unauthenticated,
      );
      bloc.add(const AuthLogoutRequested());
      await signedOut;
    },
  );

  test(
    'restoration network failure preserves retry and never grants access',
    () async {
      storage.value = testCredential;
      remote.onCurrentUser = () async => throw const ApiException(
        AuthFailure(FailureKind.network, 'Không có mạng.'),
      );
      final bloc = AuthBloc(repository);
      addTearDown(bloc.close);
      final failed = bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.restoreFailed,
      );
      bloc.add(const AuthRestoreRequested());
      expect((await failed).user, isNull);
      expect(storage.value, testCredential);
      remote.onCurrentUser = null;
      final retried = bloc.stream.firstWhere(
        (state) => state.status == AuthStatus.authenticated,
      );
      bloc.add(const AuthRestoreRequested());
      await retried;
    },
  );

  test('failed deletion leaves no user in memory and exposes retry', () async {
    await repository.login(identifier: 'student', password: 'password');
    storage.clearError = StateError('test storage failure');
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);
    final failed = bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.logoutFailed,
    );
    bloc.add(const AuthLogoutRequested());
    expect((await failed).user, isNull);
    storage.clearError = null;
    final signedOut = bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.unauthenticated,
    );
    bloc.add(const AuthLogoutRequested());
    await signedOut;
  });
}
