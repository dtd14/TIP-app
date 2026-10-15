import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/usecases/verify_email.dart';
import 'package:tip_app/features/auth/presentation/bloc/verify_email/verify_email_bloc.dart';
import 'support/auth_fakes.dart';

void main() {
  late FakeAuthRemote remote;
  late AuthRepositoryImpl repository;
  late VerifyEmailBloc bloc;
  setUp(() {
    remote = FakeAuthRemote();
    repository = AuthRepositoryImpl(
      remote: remote,
      storage: MemorySessionStorage(),
    );
    bloc = VerifyEmailBloc(
      VerifyEmail(repository),
      ResendVerificationEmail(repository),
    );
  });
  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });
  test(
    'verification rejects malformed OTP without contacting server',
    () async {
      final failed = bloc.stream.firstWhere(
        (state) => state.status == VerificationStatus.failure,
      );
      bloc.add(
        const VerifyEmailSubmitted(email: 'student@example.com', otp: '12345'),
      );
      expect((await failed).failure!.fieldErrors, contains('otp'));
      expect(remote.verifyCalls, 0);
    },
  );
  test(
    'verification prevents duplicate submissions and succeeds without creating session',
    () async {
      final pending = Completer<void>();
      remote.onVerifyEmail = (_, _) => pending.future;
      final busy = bloc.stream.firstWhere((state) => state.busy);
      bloc.add(
        const VerifyEmailSubmitted(email: 'student@example.com', otp: '123456'),
      );
      await busy;
      bloc.add(
        const VerifyEmailSubmitted(email: 'student@example.com', otp: '123456'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(remote.verifyCalls, 1);
      final verified = bloc.stream.firstWhere(
        (state) => state.status == VerificationStatus.success,
      );
      pending.complete();
      await verified;
      expect(repository.credential, isNull);
    },
  );
  test('expired OTP remains a field error and can be retried', () async {
    remote.onVerifyEmail = (_, _) async => throw const ApiException(
      AuthFailure(
        FailureKind.validation,
        'Mã đã hết hạn.',
        fieldErrors: {'otp': 'Mã đã hết hạn.'},
      ),
    );
    final failed = bloc.stream.firstWhere(
      (state) => state.status == VerificationStatus.failure,
    );
    bloc.add(
      const VerifyEmailSubmitted(email: 'student@example.com', otp: '123456'),
    );
    expect((await failed).failure!.fieldErrors['otp'], 'Mã đã hết hạn.');
  });
  test(
    'successful resend activates cooldown and cannot be immediately repeated',
    () async {
      final resent = bloc.stream.firstWhere(
        (state) => state.cooldown == 60 && !state.busy,
      );
      bloc.add(const VerificationResendRequested('student@example.com'));
      await resent;
      bloc.add(const VerificationResendRequested('student@example.com'));
      await Future<void>.delayed(Duration.zero);
      expect(remote.resendCalls, 1);
    },
  );
  test('invalid email cannot request an OTP', () async {
    final failed = bloc.stream.firstWhere(
      (state) => state.status == VerificationStatus.failure,
    );
    bloc.add(const VerificationResendRequested('invalid'));
    expect((await failed).failure!.fieldErrors, contains('email'));
    expect(remote.resendCalls, 0);
  });

  test('already verified email does not start a resend cooldown', () async {
    remote.onResendEmail = (_) async =>
        VerificationResendOutcome.alreadyVerified;
    final acknowledged = bloc.stream.firstWhere(
      (state) => state.message != null,
    );
    bloc.add(const VerificationResendRequested('student@example.com'));
    final state = await acknowledged;
    expect(state.message, contains('đã được xác minh'));
    expect(state.cooldown, 0);
    expect(state.status, VerificationStatus.idle);
  });
}
