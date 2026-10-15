import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/features/auth/domain/usecases/login.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._login) : super(const LoginState()) {
    on<LoginSubmitted>((event, emit) async {
      if (state.isSubmitting || state.status == LoginStatus.success) return;
      final errors = <String, String>{};
      final identifier = Validators.requiredText(
        event.identifier,
        'tên đăng nhập',
      );
      final password = Validators.loginPassword(event.password);
      if (identifier != null) errors['identifier'] = identifier;
      if (password != null) errors['password'] = password;
      if (errors.isNotEmpty) {
        emit(
          LoginState(
            status: LoginStatus.failure,
            failure: AuthFailure(
              FailureKind.validation,
              'Vui lòng kiểm tra thông tin đăng nhập.',
              fieldErrors: errors,
            ),
          ),
        );
        return;
      }
      emit(const LoginState(status: LoginStatus.submitting));
      try {
        final user = await _login(
          identifier: event.identifier.trim(),
          password: event.password,
        );
        emit(LoginState(status: LoginStatus.success, user: user));
      } on AuthFailure catch (failure) {
        emit(LoginState(status: LoginStatus.failure, failure: failure));
      } on Object {
        emit(
          const LoginState(
            status: LoginStatus.failure,
            failure: AuthFailure(
              FailureKind.unexpected,
              'Có lỗi xảy ra. Vui lòng thử lại.',
            ),
          ),
        );
      }
    });
    on<LoginEdited>((event, emit) {
      if (!state.isSubmitting && state.status != LoginStatus.success) {
        emit(const LoginState());
      }
    });
  }
  final Login _login;
}
