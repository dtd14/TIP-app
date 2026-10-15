import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

enum LoginStatus { initial, submitting, success, failure }

class LoginState {
  const LoginState({
    this.status = LoginStatus.initial,
    this.failure,
    this.user,
  });
  final LoginStatus status;
  final AuthFailure? failure;
  final AuthUser? user;
  bool get isSubmitting => status == LoginStatus.submitting;
}
