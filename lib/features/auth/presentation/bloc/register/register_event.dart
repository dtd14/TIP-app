import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

sealed class RegisterEvent {
  const RegisterEvent();
}

class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({required this.input, required this.confirmPassword});
  final RegistrationInput input;
  final String confirmPassword;
}

class RegisterEdited extends RegisterEvent {
  const RegisterEdited();
}
