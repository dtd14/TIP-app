import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/core/widgets/app_button.dart';
import 'package:tip_app/core/widgets/app_text_field.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/domain/usecases/verify_email.dart';
import 'package:tip_app/features/auth/presentation/bloc/verify_email/verify_email_bloc.dart';
import 'package:tip_app/features/auth/presentation/widgets/auth_header.dart';

class VerificationArguments {
  const VerificationArguments({
    this.email = '',
    this.otpSent = false,
    this.message,
  });
  final String email;
  final bool otpSent;
  final String? message;
}

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({
    super.key,
    this.arguments = const VerificationArguments(),
  });
  final VerificationArguments arguments;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => VerifyEmailBloc(
      VerifyEmail(context.read<AuthRepository>()),
      ResendVerificationEmail(context.read<AuthRepository>()),
      otpSent: arguments.otpSent,
    ),
    child: _VerificationView(arguments),
  );
}

class _VerificationView extends StatefulWidget {
  const _VerificationView(this.arguments);
  final VerificationArguments arguments;
  @override
  State<_VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<_VerificationView> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.arguments.email);
  final _otp = TextEditingController();
  void _submit() {
    if (context.read<VerifyEmailBloc>().state.busy ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<VerifyEmailBloc>().add(
      VerifyEmailSubmitted(email: _email.text, otp: _otp.text),
    );
  }

  void _edited(String _) =>
      context.read<VerifyEmailBloc>().add(const VerificationEdited());
  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<VerifyEmailBloc, VerificationState>(
    listenWhen: (previous, current) =>
        previous.status != current.status ||
        previous.message != current.message,
    listener: (context, state) {
      if (state.status == VerificationStatus.success) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Email đã được xác minh. Bạn có thể đăng nhập; hồ sơ sinh viên cần được nhà trường cấp.',
            ),
          ),
        );
      } else if (state.message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.message!),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
      }
    },
    builder: (context, state) => PopScope(
      canPop: !state.busy,
      child: AuthLayout(
        title: 'Xác minh email',
        form: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthMessage(
                error: false,
                message:
                    widget.arguments.message ??
                    'Nhập mã 6 chữ số được gửi tới email của bạn. Mã có hiệu lực trong 5 phút.',
              ),
              if (state.failure != null)
                AuthMessage(message: state.failure!.message),
              AppTextField(
                key: const Key('verifyEmail'),
                label: 'Email',
                controller: _email,
                icon: Icons.alternate_email,
                enabled: !state.busy,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                serverError: state.failure?.fieldErrors['email'],
                onChanged: _edited,
              ),
              AppTextField(
                key: const Key('verifyOtp'),
                label: 'Mã xác minh',
                controller: _otp,
                icon: Icons.mark_email_read_outlined,
                enabled: !state.busy,
                keyboardType: TextInputType.number,
                validator: Validators.otp,
                serverError: state.failure?.fieldErrors['otp'],
                onChanged: _edited,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              AppButton(
                key: const Key('verifySubmit'),
                label: 'Xác minh email',
                loading: state.status == VerificationStatus.verifying,
                onPressed: state.busy ? null : _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('resendOtp'),
                onPressed: state.busy || state.cooldown > 0
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        context.read<VerifyEmailBloc>().add(
                          VerificationResendRequested(_email.text),
                        );
                      },
                child: Text(
                  state.status == VerificationStatus.resending
                      ? 'Đang gửi mã…'
                      : state.cooldown > 0
                      ? 'Gửi lại mã sau ${state.cooldown}s'
                      : 'Gửi lại mã',
                ),
              ),
            ],
          ),
        ),
        footer: TextButton(
          onPressed: state.busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Quay về đăng nhập'),
        ),
      ),
    ),
  );
}
