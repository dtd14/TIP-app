import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/router/app_routes.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/domain/usecases/login.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_state.dart';
import 'package:tip_app/features/auth/presentation/widgets/auth_header.dart';
import 'package:tip_app/features/auth/presentation/widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => LoginBloc(Login(context.read<AuthRepository>())),
    child: BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.status == LoginStatus.success && state.user != null) {
          context.read<AuthBloc>().add(AuthSessionAccepted(state.user!));
        }
      },
      builder: (context, state) => PopScope(
        canPop: !state.isSubmitting,
        child: AuthLayout(
          title: 'Đăng nhập',
          form: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null) AuthMessage(message: message!, error: false),
              const LoginForm(),
              TextButton(
                key: const Key('openVerification'),
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        final result = await Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.verifyEmail);
                        if (context.mounted && result is String) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(result)));
                        }
                      },
                child: Text(
                  state.failure?.kind == FailureKind.emailUnverified
                      ? 'Xác minh email để đăng nhập'
                      : 'Chưa xác minh email?',
                ),
              ),
            ],
          ),
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Chưa có tài khoản?'),
              TextButton(
                key: const Key('openRegister'),
                onPressed: state.isSubmitting
                    ? null
                    : () async {
                        final result = await Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.register);
                        if (context.mounted && result is String) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(result)));
                        }
                      },
                child: const Text('Đăng ký ngay'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
