import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/usecases/verify_email.dart';

sealed class VerifyEmailEvent {
  const VerifyEmailEvent();
}

class VerifyEmailSubmitted extends VerifyEmailEvent {
  const VerifyEmailSubmitted({required this.email, required this.otp});
  final String email;
  final String otp;
}

class VerificationResendRequested extends VerifyEmailEvent {
  const VerificationResendRequested(this.email);
  final String email;
}

class VerificationEdited extends VerifyEmailEvent {
  const VerificationEdited();
}

class _CooldownTick extends VerifyEmailEvent {
  const _CooldownTick();
}

enum VerificationStatus { idle, verifying, resending, success, failure }

class VerificationState {
  const VerificationState({
    this.status = VerificationStatus.idle,
    this.failure,
    this.cooldown = 0,
    this.message,
  });
  final VerificationStatus status;
  final AuthFailure? failure;
  final int cooldown;
  final String? message;
  bool get busy =>
      status == VerificationStatus.verifying ||
      status == VerificationStatus.resending;
}

class VerifyEmailBloc extends Bloc<VerifyEmailEvent, VerificationState> {
  VerifyEmailBloc(this.verify, this.resend, {bool otpSent = false})
    : super(VerificationState(cooldown: otpSent ? 60 : 0)) {
    on<VerifyEmailSubmitted>((event, emit) async {
      if (state.busy || state.status == VerificationStatus.success) return;
      final errors = <String, String>{};
      final email = Validators.email(event.email);
      final otp = Validators.otp(event.otp);
      if (email != null) errors['email'] = email;
      if (otp != null) errors['otp'] = otp;
      if (errors.isNotEmpty) {
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            cooldown: state.cooldown,
            failure: AuthFailure(
              FailureKind.validation,
              'Vui lòng kiểm tra email và mã xác minh.',
              fieldErrors: errors,
            ),
          ),
        );
        return;
      }
      emit(
        VerificationState(
          status: VerificationStatus.verifying,
          cooldown: state.cooldown,
        ),
      );
      try {
        await verify(email: event.email.trim(), otp: event.otp);
        _timer?.cancel();
        emit(const VerificationState(status: VerificationStatus.success));
      } on AuthFailure catch (failure) {
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            failure: failure,
            cooldown: state.cooldown,
          ),
        );
      } on Object {
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            cooldown: state.cooldown,
            failure: const AuthFailure(
              FailureKind.unexpected,
              'Không thể xác minh email. Vui lòng thử lại.',
            ),
          ),
        );
      }
    });
    on<VerificationResendRequested>((event, emit) async {
      if (state.busy ||
          state.cooldown > 0 ||
          state.status == VerificationStatus.success) {
        return;
      }
      final invalid = Validators.email(event.email);
      if (invalid != null) {
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            cooldown: state.cooldown,
            failure: AuthFailure(
              FailureKind.validation,
              invalid,
              fieldErrors: {'email': invalid},
            ),
          ),
        );
        return;
      }
      emit(
        VerificationState(
          status: VerificationStatus.resending,
          cooldown: state.cooldown,
        ),
      );
      try {
        final outcome = await resend(event.email.trim());
        if (outcome == VerificationResendOutcome.alreadyVerified) {
          emit(
            const VerificationState(
              message: 'Email này đã được xác minh. Bạn có thể đăng nhập.',
            ),
          );
          return;
        }
        emit(
          const VerificationState(
            cooldown: 60,
            message:
                'Yêu cầu gửi mã xác minh đã được xử lý. Nếu email đã đăng ký và chưa xác minh, hãy kiểm tra hộp thư đến và thư rác.',
          ),
        );
        _startCooldown();
      } on AuthFailure catch (failure) {
        final cooldown = failure.kind == FailureKind.rateLimited
            ? 60
            : state.cooldown;
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            failure: failure,
            cooldown: cooldown,
          ),
        );
        if (cooldown > 0) _startCooldown();
      } on Object {
        emit(
          VerificationState(
            status: VerificationStatus.failure,
            cooldown: state.cooldown,
            failure: const AuthFailure(
              FailureKind.unexpected,
              'Không thể gửi mã. Vui lòng thử lại.',
            ),
          ),
        );
      }
    });
    on<VerificationEdited>((event, emit) {
      if (!state.busy && state.status != VerificationStatus.success) {
        emit(VerificationState(cooldown: state.cooldown));
      }
    });
    on<_CooldownTick>((event, emit) {
      if (state.cooldown <= 1) _timer?.cancel();
      emit(
        VerificationState(
          status: state.status,
          failure: state.failure,
          message: state.message,
          cooldown: state.cooldown > 0 ? state.cooldown - 1 : 0,
        ),
      );
    });
    if (otpSent) _startCooldown();
  }
  final VerifyEmail verify;
  final ResendVerificationEmail resend;
  Timer? _timer;
  void _startCooldown() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const _CooldownTick()),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
