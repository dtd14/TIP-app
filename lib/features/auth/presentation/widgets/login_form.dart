import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/core/widgets/app_button.dart';
import 'package:tip_app/core/widgets/app_text_field.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/login/login_state.dart';
import 'package:tip_app/features/auth/presentation/widgets/auth_header.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  void _submit() {
    final bloc = context.read<LoginBloc>();
    if (bloc.state.isSubmitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    bloc.add(
      LoginSubmitted(identifier: _identifier.text, password: _password.text),
    );
  }

  void _edited(String _) => context.read<LoginBloc>().add(const LoginEdited());
  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<LoginBloc, LoginState>(
    builder: (context, state) => AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.failure != null)
              AuthMessage(message: state.failure!.message),
            AppTextField(
              key: const Key('loginIdentifier'),
              label: 'Tên đăng nhập',
              controller: _identifier,
              icon: Icons.alternate_email,
              hint: 'Nhập tên đăng nhập của bạn',
              enabled: !state.isSubmitting,
              validator: (value) =>
                  Validators.requiredText(value, 'tên đăng nhập'),
              serverError: state.failure?.fieldErrors['identifier'],
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              onChanged: _edited,
            ),
            AppTextField(
              key: const Key('loginPassword'),
              label: 'Mật khẩu',
              controller: _password,
              icon: Icons.lock_outline,
              hint: 'Nhập mật khẩu',
              password: true,
              enabled: !state.isSubmitting,
              validator: Validators.loginPassword,
              serverError: state.failure?.fieldErrors['password'],
              autofillHints: const [AutofillHints.password],
              onChanged: _edited,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            AppButton(
              key: const Key('loginSubmit'),
              label: 'Đăng nhập →',
              loading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
