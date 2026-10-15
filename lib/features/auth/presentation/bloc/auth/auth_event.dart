import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

sealed class AuthEvent {
  const AuthEvent();
}

class AuthRestoreRequested extends AuthEvent {
  const AuthRestoreRequested({this.preserveNavigation = false});
  final bool preserveNavigation;
}

class AuthSessionAccepted extends AuthEvent {
  const AuthSessionAccepted(this.user);
  final AuthUser user;
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthAccessRestricted extends AuthEvent {
  const AuthAccessRestricted(this.failure);
  final AuthFailure failure;
}

class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired({this.failure});
  final AuthFailure? failure;
}
