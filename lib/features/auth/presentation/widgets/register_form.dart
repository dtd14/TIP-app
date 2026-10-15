import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/core/widgets/app_button.dart';
import 'package:tip_app/core/widgets/app_text_field.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/register/register_state.dart';
import 'package:tip_app/features/auth/presentation/widgets/auth_header.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});
  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  void _edited(String _) =>
      context.read<RegisterBloc>().add(const RegisterEdited());
  void _submit() {
    final bloc = context.read<RegisterBloc>();
    if (bloc.state.isSubmitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final phone = _phone.text.trim();
    bloc.add(
      RegisterSubmitted(
        input: RegistrationInput(
          fullName: _name.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          phone: phone.isEmpty ? null : phone,
          password: _password.text,
        ),
        confirmPassword: _confirm.text,
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RegisterBloc, RegisterState>(
        builder: (context, state) {
          final errors = state.failure?.fieldErrors ?? const <String, String>{};
          return AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.failure != null)
                    AuthMessage(message: state.failure!.message),
                  AppTextField(
                    key: const Key('registerName'),
                    label: 'Họ và tên đầy đủ',
                    controller: _name,
                    icon: Icons.person_outline,
                    hint: 'Nguyễn Văn An',
                    enabled: !state.isSubmitting,
                    validator: (value) =>
                        Validators.limitedText(value, 'Họ và tên', 150),
                    serverError: errors['fullName'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.name],
                  ),
                  AppTextField(
                    key: const Key('registerUsername'),
                    label: 'Tên đăng nhập',
                    controller: _username,
                    icon: Icons.account_circle_outlined,
                    hint: 'Tên đăng nhập của bạn',
                    enabled: !state.isSubmitting,
                    validator: (value) =>
                        Validators.limitedText(value, 'Tên đăng nhập', 64),
                    serverError: errors['username'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.newUsername],
                  ),
                  AppTextField(
                    key: const Key('registerEmail'),
                    label: 'Email trường / Email cá nhân',
                    controller: _email,
                    icon: Icons.alternate_email,
                    hint: 'sinhvien@tip.edu.vn',
                    enabled: !state.isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    serverError: errors['email'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.email],
                  ),
                  AppTextField(
                    key: const Key('registerPhone'),
                    label: 'Số điện thoại (không bắt buộc)',
                    controller: _phone,
                    icon: Icons.phone_outlined,
                    enabled: !state.isSubmitting,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    serverError: errors['phone'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  AppTextField(
                    key: const Key('registerPassword'),
                    label: 'Mật khẩu',
                    controller: _password,
                    icon: Icons.lock_outline,
                    hint: 'Nhập mật khẩu',
                    password: true,
                    enabled: !state.isSubmitting,
                    validator: Validators.password,
                    serverError: errors['password'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  AppTextField(
                    key: const Key('registerConfirm'),
                    label: 'Xác nhận mật khẩu',
                    controller: _confirm,
                    icon: Icons.lock_reset_outlined,
                    hint: 'Nhập lại mật khẩu',
                    password: true,
                    enabled: !state.isSubmitting,
                    validator: (value) =>
                        Validators.confirmPassword(value, _password.text),
                    serverError: errors['confirmPassword'],
                    onChanged: _edited,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  AppButton(
                    key: const Key('registerSubmit'),
                    label: 'Tạo tài khoản',
                    loading: state.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          );
        },
      );
}
