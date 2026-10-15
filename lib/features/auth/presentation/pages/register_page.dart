import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/router/app_routes.dart';
import 'package:tip_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/domain/usecases/register.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_state.dart';
import 'package:tip_app/features/auth/presentation/widgets/auth_header.dart';
import 'package:tip_app/features/auth/presentation/widgets/register_form.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => RegisterBloc(Register(context.read<AuthRepository>())),
    child: BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state.status == RegisterStatus.success && state.outcome != null) {
          final outcome = state.outcome!;
          if (outcome.user != null) {
            context.read<AuthBloc>().add(AuthSessionAccepted(outcome.user!));
          } else if (outcome.verificationEmail != null) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.verifyEmail,
              arguments: VerificationArguments(
                email: outcome.verificationEmail!,
                otpSent: outcome.otpSent,
                message: outcome.message,
              ),
            );
          } else {
            Navigator.of(context).pop(outcome.message);
          }
        }
      },
      builder: (context, state) => PopScope(
        canPop: !state.isSubmitting,
        child: AuthLayout(
          title: 'Đăng ký',
          form: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthMessage(
                error: false,
                message:
                    'Tài khoản mới cần xác minh email. Hồ sơ sinh viên do nhà trường cấp.',
              ),
              RegisterForm(),
            ],
          ),
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Đã có tài khoản sinh viên?'),
              TextButton(
                key: const Key('backToLogin'),
                onPressed: state.isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Đăng nhập ngay →'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
