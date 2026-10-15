import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

enum AuthStatus {
  restoring,
  unauthenticated,
  authenticated,
  restricted,
  restoreFailed,
  signingOut,
  logoutFailed,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.user,
    this.failure,
    this.message,
  });
  final AuthStatus status;
  final AuthUser? user;
  final AuthFailure? failure;
  final String? message;
}
