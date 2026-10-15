sealed class LoginEvent {
  const LoginEvent();
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.identifier, required this.password});
  final String identifier;
  final String password;
}

class LoginEdited extends LoginEvent {
  const LoginEdited();
}
