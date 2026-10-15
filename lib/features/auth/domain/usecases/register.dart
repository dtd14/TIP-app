import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';

class Register {
  const Register(this.repository);
  final AuthRepository repository;
  Future<RegistrationOutcome> call(RegistrationInput input) =>
      repository.register(input);
}
