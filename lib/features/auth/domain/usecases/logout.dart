import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';

class Logout {
  const Logout(this.repository);
  final AuthRepository repository;
  Future<String?> call() => repository.logout();
}
