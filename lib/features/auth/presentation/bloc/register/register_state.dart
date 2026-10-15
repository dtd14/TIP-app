import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

enum RegisterStatus { initial, submitting, success, failure }

class RegisterState {
  const RegisterState({
    this.status = RegisterStatus.initial,
    this.failure,
    this.outcome,
  });
  final RegisterStatus status;
  final AuthFailure? failure;
  final RegistrationOutcome? outcome;
  bool get isSubmitting => status == RegisterStatus.submitting;
}
