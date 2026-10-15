import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/domain/usecases/get_current_user.dart';
import 'package:tip_app/features/auth/domain/usecases/logout.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(AuthRepository repository)
    : _getCurrentUser = GetCurrentUser(repository),
      _logout = Logout(repository),
      super(const AuthState()) {
    _expirySubscription = repository.sessionExpired.listen(
      (failure) => add(AuthSessionExpired(failure: failure)),
    );
    on<AuthRestoreRequested>((event, emit) async {
      if (_restoring || state.status == AuthStatus.signingOut) return;
      _restoring = true;
      final generation = _generation;
      if (!event.preserveNavigation ||
          state.status != AuthStatus.authenticated) {
        emit(const AuthState());
      }
      try {
        final user = await _getCurrentUser();
        if (generation != _generation) return;
        emit(
          user == null
              ? const AuthState(status: AuthStatus.unauthenticated)
              : _stateFor(user),
        );
      } on AuthFailure catch (failure) {
        if (generation != _generation) return;
        emit(
          AuthState(
            status: failure.kind == FailureKind.sessionExpired
                ? AuthStatus.unauthenticated
                : failure.kind == FailureKind.inactiveAccount
                ? AuthStatus.restricted
                : AuthStatus.restoreFailed,
            failure: failure,
            message: failure.message,
          ),
        );
      } on Object {
        if (generation != _generation) return;
        emit(
          const AuthState(
            status: AuthStatus.restoreFailed,
            failure: AuthFailure(
              FailureKind.unexpected,
              'Không thể kiểm tra phiên. Vui lòng thử lại.',
            ),
          ),
        );
      } finally {
        _restoring = false;
      }
    });
    on<AuthSessionAccepted>((event, emit) {
      if (state.status == AuthStatus.signingOut ||
          state.status == AuthStatus.logoutFailed) {
        return;
      }
      _generation++;
      emit(_stateFor(event.user));
    });
    on<AuthLogoutRequested>((event, emit) async {
      if (state.status == AuthStatus.signingOut) return;
      _generation++;
      emit(const AuthState(status: AuthStatus.signingOut));
      try {
        final warning = await _logout();
        emit(AuthState(status: AuthStatus.unauthenticated, message: warning));
      } on AuthFailure catch (failure) {
        emit(AuthState(status: AuthStatus.logoutFailed, failure: failure));
      } on Object {
        emit(
          const AuthState(
            status: AuthStatus.logoutFailed,
            failure: AuthFailure(
              FailureKind.storage,
              'Không thể xóa phiên. Vui lòng thử đăng xuất lại.',
            ),
          ),
        );
      }
    });
    on<AuthAccessRestricted>((event, emit) {
      if (state.status != AuthStatus.authenticated) return;
      _generation++;
      emit(
        AuthState(
          status: AuthStatus.restricted,
          user: state.user,
          failure: event.failure,
        ),
      );
    });
    on<AuthSessionExpired>((event, emit) {
      if (state.status == AuthStatus.signingOut ||
          state.status == AuthStatus.logoutFailed) {
        return;
      }
      _generation++;
      if (event.failure != null) {
        emit(
          AuthState(status: AuthStatus.logoutFailed, failure: event.failure),
        );
        return;
      }
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          message: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
        ),
      );
    });
  }
  final GetCurrentUser _getCurrentUser;
  final Logout _logout;
  late final StreamSubscription<AuthFailure?> _expirySubscription;
  bool _restoring = false;
  int _generation = 0;
  AuthState _stateFor(AuthUser user) => AuthState(
    status: user.canAccessHome
        ? AuthStatus.authenticated
        : AuthStatus.restricted,
    user: user,
  );
  @override
  Future<void> close() async {
    await _expirySubscription.cancel();
    return super.close();
  }
}
