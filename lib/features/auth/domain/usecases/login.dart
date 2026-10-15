import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';

class Login {
  const Login(this.repository);
  final AuthRepository repository;
  Future<AuthUser> call({
    required String identifier,
    required String password,
  }) => repository.login(identifier: identifier, password: password);
}
