import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';

class GetApplication {
  const GetApplication(this.repository);
  final ApplicationRepository repository;
  Future<ApplicationDetail> call(String id, AuthUser user) =>
      repository.getApplication(id, user);
}
