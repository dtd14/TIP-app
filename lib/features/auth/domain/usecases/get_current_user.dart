import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser {
  const GetCurrentUser(this.repository);
  final AuthRepository repository;
  Future<AuthUser?> call() => repository.getCurrentUser();
}
