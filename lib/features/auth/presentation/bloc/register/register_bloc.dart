import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/features/auth/domain/usecases/register.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._register) : super(const RegisterState()) {
    on<RegisterSubmitted>((event, emit) async {
      if (state.isSubmitting || state.status == RegisterStatus.success) return;
      final input = event.input;
      final checks = <String, String?>{
        'fullName': Validators.limitedText(input.fullName, 'Họ và tên', 150),
        'username': Validators.limitedText(input.username, 'Tên đăng nhập', 64),
        'phone': Validators.phone(input.phone),
        'email': Validators.email(input.email),
        'password': Validators.password(input.password),
        'confirmPassword': Validators.confirmPassword(
          event.confirmPassword,
          input.password,
        ),
      };
      final errors = <String, String>{
        for (final entry in checks.entries)
          if (entry.value != null) entry.key: entry.value!,
      };
      if (errors.isNotEmpty) {
        emit(
          RegisterState(
            status: RegisterStatus.failure,
            failure: AuthFailure(
              FailureKind.validation,
              'Vui lòng kiểm tra thông tin đăng ký.',
              fieldErrors: errors,
            ),
          ),
        );
        return;
      }
      emit(const RegisterState(status: RegisterStatus.submitting));
      try {
        final outcome = await _register(input);
        emit(RegisterState(status: RegisterStatus.success, outcome: outcome));
      } on AuthFailure catch (failure) {
        emit(RegisterState(status: RegisterStatus.failure, failure: failure));
      } on Object {
        emit(
          const RegisterState(
            status: RegisterStatus.failure,
            failure: AuthFailure(
              FailureKind.unexpected,
              'Có lỗi xảy ra. Vui lòng thử lại.',
            ),
          ),
        );
      }
    });
    on<RegisterEdited>((event, emit) {
      if (!state.isSubmitting && state.status != RegisterStatus.success) {
        emit(const RegisterState());
      }
    });
  }
  final Register _register;
}
